import { Injectable, Logger } from '@nestjs/common';
import { DevicePlatform, type Session } from '@prisma/client';
import { PrismaService } from '../../../infra/prisma/prisma.service';
import { sha256 } from '../../../common/utils/crypto.util';

export interface SessionContext {
  ip?: string;
  userAgent?: string;
  deviceName?: string;
  platform?: DevicePlatform;
}

/**
 * Ciclo de vida das sessoes (refresh tokens).
 *
 * Regras:
 *  - Apenas o SHA-256 do refresh token e persistido.
 *  - Rotacao a cada refresh: o token antigo e revogado e aponta para o novo.
 *  - Reuso de token ja revogado = indicio de roubo -> revoga toda a cadeia do usuario.
 */
@Injectable()
export class SessionService {
  private readonly logger = new Logger(SessionService.name);

  /** Cache curto de sessoes ativas para nao consultar o banco a cada request. */
  private static readonly CACHE_TTL_MS = 10_000;
  private readonly activeCache = new Map<string, { active: boolean; expiresAt: number }>();

  constructor(private readonly prisma: PrismaService) {}

  async create(
    userId: string,
    refreshToken: string,
    expiresAt: Date,
    ctx: SessionContext,
  ): Promise<Session> {
    const session = await this.prisma.session.create({
      data: {
        userId,
        tokenHash: sha256(refreshToken),
        expiresAt,
        ip: ctx.ip,
        userAgent: ctx.userAgent?.slice(0, 512),
        deviceName: ctx.deviceName,
        platform: ctx.platform,
      },
    });
    this.activeCache.set(session.id, {
      active: true,
      expiresAt: Date.now() + SessionService.CACHE_TTL_MS,
    });
    return session;
  }

  async findByToken(refreshToken: string): Promise<Session | null> {
    return this.prisma.session.findUnique({ where: { tokenHash: sha256(refreshToken) } });
  }

  async isActive(sessionId: string): Promise<boolean> {
    const cached = this.activeCache.get(sessionId);
    if (cached && cached.expiresAt > Date.now()) return cached.active;

    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { revokedAt: true, expiresAt: true },
    });
    const active = session !== null && session.revokedAt === null && session.expiresAt > new Date();

    this.activeCache.set(sessionId, {
      active,
      expiresAt: Date.now() + SessionService.CACHE_TTL_MS,
    });
    return active;
  }

  /** Rotaciona: revoga a sessao atual e cria a substituta na mesma transacao. */
  async rotate(
    current: Session,
    newRefreshToken: string,
    expiresAt: Date,
    ctx: SessionContext,
  ): Promise<Session> {
    return this.prisma.$transaction(async (tx) => {
      const next = await tx.session.create({
        data: {
          userId: current.userId,
          tokenHash: sha256(newRefreshToken),
          expiresAt,
          ip: ctx.ip ?? current.ip,
          userAgent: ctx.userAgent?.slice(0, 512) ?? current.userAgent,
          deviceName: ctx.deviceName ?? current.deviceName,
          platform: ctx.platform ?? current.platform,
        },
      });
      await tx.session.update({
        where: { id: current.id },
        data: { revokedAt: new Date(), revokedReason: 'ROTATED', replacedById: next.id },
      });
      this.invalidateCache(current.id);
      return next;
    });
  }

  async revoke(sessionId: string, reason = 'LOGOUT'): Promise<void> {
    await this.prisma.session.updateMany({
      where: { id: sessionId, revokedAt: null },
      data: { revokedAt: new Date(), revokedReason: reason },
    });
    this.invalidateCache(sessionId);
  }

  /** Revoga todas as sessoes do usuario. Usado em troca de senha e suspeita de roubo. */
  async revokeAllForUser(userId: string, reason = 'REVOKE_ALL', exceptSessionId?: string): Promise<number> {
    const sessions = await this.prisma.session.findMany({
      where: {
        userId,
        revokedAt: null,
        ...(exceptSessionId ? { id: { not: exceptSessionId } } : {}),
      },
      select: { id: true },
    });
    if (sessions.length === 0) return 0;

    await this.prisma.session.updateMany({
      where: { id: { in: sessions.map((s) => s.id) } },
      data: { revokedAt: new Date(), revokedReason: reason },
    });
    sessions.forEach((s) => this.invalidateCache(s.id));
    return sessions.length;
  }

  async touch(sessionId: string): Promise<void> {
    await this.prisma.session.update({
      where: { id: sessionId },
      data: { lastUsedAt: new Date() },
    });
  }

  async listActive(userId: string): Promise<Session[]> {
    return this.prisma.session.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { lastUsedAt: 'desc' },
    });
  }

  /** Remove sessoes expiradas ha mais de 30 dias. Chamado por job diario. */
  async purgeExpired(olderThanDays = 30): Promise<number> {
    const cutoff = new Date(Date.now() - olderThanDays * 86_400_000);
    const result = await this.prisma.session.deleteMany({
      where: { expiresAt: { lt: cutoff } },
    });
    return result.count;
  }

  private invalidateCache(sessionId: string): void {
    this.activeCache.delete(sessionId);
  }
}
