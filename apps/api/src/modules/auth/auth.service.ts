import { Injectable, Logger } from '@nestjs/common';
import { AuditAction, UserStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError, ErrorCode } from '../../common/errors/app-error';
import { randomToken, sha256 } from '../../common/utils/crypto.util';
import { AuditService } from '../audit/audit.service';
import { PasswordService } from './services/password.service';
import { SessionService, type SessionContext } from './services/session.service';
import { TokenService } from './services/token.service';
import { UserPrincipalService } from './services/user-principal.service';
import type {
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginDto,
  LoginResponseDto,
  ResetPasswordDto,
} from './dto/auth.dto';
import type { AuthenticatedUser } from '../authorization/authorization.types';

/** Bloqueio progressivo apos tentativas falhas. */
const MAX_FAILED_ATTEMPTS = 5;
const LOCK_MINUTES = 15;
const RESET_TOKEN_TTL_MINUTES = 30;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
    private readonly sessions: SessionService,
    private readonly principals: UserPrincipalService,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  async login(dto: LoginDto, ctx: SessionContext): Promise<LoginResponseDto> {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email, deletedAt: null },
      select: {
        id: true,
        email: true,
        passwordHash: true,
        status: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        locale: true,
        timezone: true,
        mustChangePassword: true,
        failedLoginCount: true,
        lockedUntil: true,
      },
    });

    // Mesma resposta para usuario inexistente e senha errada: evita enumeracao.
    if (!user) {
      await this.passwords.verify(null, dto.password);
      await this.audit.record({
        action: AuditAction.LOGIN_FAILED,
        entity: 'User',
        metadata: { email: dto.email, reason: 'USER_NOT_FOUND' },
        ip: ctx.ip,
        userAgent: ctx.userAgent,
      });
      throw AppError.unauthorized(ErrorCode.INVALID_CREDENTIALS, 'E-mail ou senha invalidos.');
    }

    if (user.lockedUntil && user.lockedUntil > new Date()) {
      throw AppError.unauthorized(
        ErrorCode.ACCOUNT_LOCKED,
        'Conta temporariamente bloqueada por tentativas invalidas.',
      );
    }

    if (user.status === UserStatus.DISABLED || user.status === UserStatus.SUSPENDED) {
      throw AppError.unauthorized(ErrorCode.ACCOUNT_DISABLED, 'Conta desativada.');
    }

    const valid = await this.passwords.verify(user.passwordHash, dto.password);
    if (!valid) {
      await this.registerFailedAttempt(user.id, user.failedLoginCount);
      await this.audit.record({
        userId: user.id,
        action: AuditAction.LOGIN_FAILED,
        entity: 'User',
        entityId: user.id,
        metadata: { reason: 'INVALID_PASSWORD' },
        ip: ctx.ip,
        userAgent: ctx.userAgent,
      });
      throw AppError.unauthorized(ErrorCode.INVALID_CREDENTIALS, 'E-mail ou senha invalidos.');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        failedLoginCount: 0,
        lockedUntil: null,
        lastLoginAt: new Date(),
        status: user.status === UserStatus.INVITED ? UserStatus.ACTIVE : user.status,
      },
    });

    const pair = await this.startSession(user.id, { ...ctx, deviceName: dto.deviceName, platform: dto.platform });
    const principal = await this.principals.build(user.id, pair.sessionId);

    await this.audit.record({
      userId: user.id,
      action: AuditAction.LOGIN,
      entity: 'User',
      entityId: user.id,
      metadata: { sessionId: pair.sessionId, platform: dto.platform },
      ip: ctx.ip,
      userAgent: ctx.userAgent,
    });

    return {
      tokens: {
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        expiresIn: this.tokens.accessTtlSeconds(),
        tokenType: 'Bearer',
      },
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatarUrl: user.avatarUrl,
        locale: user.locale,
        timezone: user.timezone,
        pastorId: principal.pastorId,
        roles: principal.roles,
        permissions: principal.permissions,
        mustChangePassword: user.mustChangePassword,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  async refresh(refreshToken: string, ctx: SessionContext) {
    const session = await this.sessions.findByToken(refreshToken);
    if (!session) {
      throw AppError.unauthorized(ErrorCode.TOKEN_INVALID, 'Refresh token invalido.');
    }

    // Reuso de token revogado: trata como comprometimento e derruba tudo.
    if (session.revokedAt) {
      this.logger.warn({ userId: session.userId, sessionId: session.id }, 'Reuso de refresh token revogado');
      await this.sessions.revokeAllForUser(session.userId, 'REFRESH_REUSE_DETECTED');
      this.principals.invalidate(session.userId);
      throw AppError.unauthorized(ErrorCode.SESSION_REVOKED, 'Sessao revogada. Faca login novamente.');
    }

    if (session.expiresAt <= new Date()) {
      throw AppError.unauthorized(ErrorCode.TOKEN_EXPIRED, 'Sessao expirada.');
    }

    const newRefresh = this.tokens.issueRefreshToken();
    const next = await this.sessions.rotate(session, newRefresh, this.tokens.refreshExpiryDate(), ctx);
    const accessToken = await this.tokens.issueAccessToken(session.userId, next.id);

    await this.audit.record({
      userId: session.userId,
      action: AuditAction.TOKEN_REFRESH,
      entity: 'Session',
      entityId: next.id,
      ip: ctx.ip,
      userAgent: ctx.userAgent,
    });

    return {
      accessToken,
      refreshToken: newRefresh,
      expiresIn: this.tokens.accessTtlSeconds(),
      tokenType: 'Bearer',
    };
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  async logout(user: AuthenticatedUser, allDevices: boolean, ctx: SessionContext): Promise<void> {
    if (allDevices) {
      await this.sessions.revokeAllForUser(user.id, 'LOGOUT_ALL');
    } else {
      await this.sessions.revoke(user.sessionId, 'LOGOUT');
    }
    this.principals.invalidate(user.id);

    await this.audit.record({
      userId: user.id,
      action: AuditAction.LOGOUT,
      entity: 'Session',
      entityId: user.sessionId,
      metadata: { allDevices },
      ip: ctx.ip,
      userAgent: ctx.userAgent,
    });
  }

  // ---------------------------------------------------------------------------
  // Senhas
  // ---------------------------------------------------------------------------

  async changePassword(
    user: AuthenticatedUser,
    dto: ChangePasswordDto,
    ctx: SessionContext,
  ): Promise<void> {
    const record = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      select: { passwordHash: true },
    });

    const valid = await this.passwords.verify(record.passwordHash, dto.currentPassword);
    if (!valid) {
      throw AppError.forbidden(ErrorCode.INVALID_CREDENTIALS, 'Senha atual incorreta.');
    }
    if (dto.currentPassword === dto.newPassword) {
      throw AppError.validation('A nova senha deve ser diferente da atual.');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: await this.passwords.hash(dto.newPassword),
        mustChangePassword: false,
      },
    });

    // Mantem a sessao atual, derruba as demais.
    await this.sessions.revokeAllForUser(user.id, 'PASSWORD_CHANGED', user.sessionId);
    this.principals.invalidate(user.id);

    await this.audit.record({
      userId: user.id,
      action: AuditAction.PASSWORD_CHANGE,
      entity: 'User',
      entityId: user.id,
      ip: ctx.ip,
      userAgent: ctx.userAgent,
    });
  }

  /**
   * Sempre retorna sucesso, exista ou nao o e-mail: nao revela cadastro.
   * Em DEV o token e devolvido para permitir teste sem servico de e-mail.
   */
  async forgotPassword(dto: ForgotPasswordDto, ctx: SessionContext): Promise<{ devToken?: string }> {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email, deletedAt: null, status: { not: UserStatus.DISABLED } },
      select: { id: true },
    });

    if (!user) return {};

    const token = randomToken(32);
    await this.prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash: sha256(token),
        expiresAt: new Date(Date.now() + RESET_TOKEN_TTL_MINUTES * 60_000),
      },
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.PASSWORD_RESET_REQUEST,
      entity: 'User',
      entityId: user.id,
      ip: ctx.ip,
      userAgent: ctx.userAgent,
    });

    // TODO(fase 10): enfileirar envio de e-mail com o link de reset.
    return process.env.APP_ENV === 'DEV' ? { devToken: token } : {};
  }

  async resetPassword(dto: ResetPasswordDto, ctx: SessionContext): Promise<void> {
    const record = await this.prisma.passwordResetToken.findUnique({
      where: { tokenHash: sha256(dto.token) },
      select: { id: true, userId: true, expiresAt: true, usedAt: true },
    });

    if (!record || record.usedAt || record.expiresAt <= new Date()) {
      throw AppError.forbidden(ErrorCode.TOKEN_INVALID, 'Token de recuperacao invalido ou expirado.');
    }

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: record.userId },
        data: {
          passwordHash: await this.passwords.hash(dto.newPassword),
          mustChangePassword: false,
          failedLoginCount: 0,
          lockedUntil: null,
          status: UserStatus.ACTIVE,
        },
      }),
      this.prisma.passwordResetToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
    ]);

    await this.sessions.revokeAllForUser(record.userId, 'PASSWORD_RESET');
    this.principals.invalidate(record.userId);

    await this.audit.record({
      userId: record.userId,
      action: AuditAction.PASSWORD_RESET,
      entity: 'User',
      entityId: record.userId,
      ip: ctx.ip,
      userAgent: ctx.userAgent,
    });
  }

  // ---------------------------------------------------------------------------
  // Sessoes
  // ---------------------------------------------------------------------------

  async listSessions(user: AuthenticatedUser) {
    const sessions = await this.sessions.listActive(user.id);
    return sessions.map((s) => ({
      id: s.id,
      deviceName: s.deviceName,
      platform: s.platform,
      ip: s.ip,
      lastUsedAt: s.lastUsedAt,
      createdAt: s.createdAt,
      current: s.id === user.sessionId,
    }));
  }

  async revokeSession(user: AuthenticatedUser, sessionId: string): Promise<void> {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { userId: true },
    });
    if (!session || session.userId !== user.id) {
      throw AppError.notFound('Sessao nao encontrada.');
    }
    await this.sessions.revoke(sessionId, 'REVOKED_BY_USER');
  }

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  private async startSession(userId: string, ctx: SessionContext) {
    const refreshToken = this.tokens.issueRefreshToken();
    const session = await this.sessions.create(
      userId,
      refreshToken,
      this.tokens.refreshExpiryDate(),
      ctx,
    );
    const accessToken = await this.tokens.issueAccessToken(userId, session.id);
    return { accessToken, refreshToken, sessionId: session.id };
  }

  private async registerFailedAttempt(userId: string, currentCount: number): Promise<void> {
    const next = currentCount + 1;
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        failedLoginCount: next,
        lockedUntil:
          next >= MAX_FAILED_ATTEMPTS ? new Date(Date.now() + LOCK_MINUTES * 60_000) : null,
      },
    });
  }
}
