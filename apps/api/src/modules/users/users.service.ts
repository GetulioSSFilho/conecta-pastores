import { Injectable } from '@nestjs/common';
import { AuditAction, Prisma, UserStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError } from '../../common/errors/app-error';
import { PageDto } from '../../common/dto/pagination.dto';
import { randomToken } from '../../common/utils/crypto.util';
import { AuditService } from '../audit/audit.service';
import { PasswordService } from '../auth/services/password.service';
import { SessionService } from '../auth/services/session.service';
import { UserPrincipalService } from '../auth/services/user-principal.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import type { CreateUserDto, UpdateMeDto, UpdateUserDto, UserQueryDto } from './dto/user.dto';

/** Status que revogam sessao imediatamente ao serem atribuidos. */
const DEACTIVATING_STATUSES: UserStatus[] = [UserStatus.DISABLED, UserStatus.SUSPENDED];

/** Campos seguros para expor - passwordHash NUNCA sai daqui. */
const SAFE_SELECT = {
  id: true,
  email: true,
  firstName: true,
  lastName: true,
  avatarUrl: true,
  locale: true,
  timezone: true,
  status: true,
  mustChangePassword: true,
  lastLoginAt: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserSelect;

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly passwords: PasswordService,
    private readonly sessions: SessionService,
    private readonly principals: UserPrincipalService,
  ) {}

  // ---------------------------------------------------------------------------
  // Leitura
  // ---------------------------------------------------------------------------

  async list(query: UserQueryDto) {
    const where: Prisma.UserWhereInput = {
      AND: [
        { deletedAt: null },
        ...(query.status ? [{ status: query.status }] : []),
        ...(query.roleKey ? [{ roles: { some: { role: { key: query.roleKey } } } }] : []),
        ...(query.search
          ? [
              {
                OR: [
                  { firstName: { contains: query.search, mode: 'insensitive' as const } },
                  { lastName: { contains: query.search, mode: 'insensitive' as const } },
                  { email: { contains: query.search, mode: 'insensitive' as const } },
                ],
              },
            ]
          : []),
      ],
    };

    const [total, data] = await this.prisma.$transaction([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        orderBy: [{ firstName: 'asc' }, { lastName: 'asc' }],
        skip: query.skip,
        take: query.take,
        select: {
          ...SAFE_SELECT,
          roles: { select: { role: { select: { key: true, name: true } } } },
        },
      }),
    ]);

    return PageDto.of(
      data.map((u) => ({ ...u, roles: u.roles.map((r) => r.role) })),
      total,
      query,
    );
  }

  async getById(id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      select: {
        ...SAFE_SELECT,
        roles: { select: { role: { select: { id: true, key: true, name: true } } } },
        scopes: {
          select: { id: true, type: true, refId: true, permissionKeys: true, expiresAt: true },
        },
        pastor: { select: { id: true, pastoralName: true, status: true } },
        _count: { select: { sessions: true } },
      },
    });
    if (!user) throw AppError.notFound('Usuario nao encontrado.');

    const activeSessions = await this.sessions.listActive(id);

    return {
      ...user,
      roles: user.roles.map((r) => r.role),
      activeSessionsCount: activeSessions.length,
    };
  }

  // ---------------------------------------------------------------------------
  // Escrita
  // ---------------------------------------------------------------------------

  async create(actor: AuthenticatedUser, dto: CreateUserDto) {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) throw AppError.conflict('Ja existe um usuario com este e-mail.');

    if (dto.pastorId) {
      const pastor = await this.prisma.pastor.findFirst({
        where: { id: dto.pastorId, deletedAt: null },
        select: { id: true, userId: true },
      });
      if (!pastor) throw AppError.validation('Pastor invalido.');
      if (pastor.userId) throw AppError.conflict('Este pastor ja possui usuario vinculado.');
    }

    // Sem senha informada: gera uma temporaria e forca troca no primeiro login.
    const plainPassword = dto.password ?? this.generateTemporaryPassword();
    if (dto.password) {
      const errors = PasswordService.validate(dto.password);
      if (errors.length > 0) throw AppError.validation('Senha nao atende a politica minima.', errors);
    }

    const created = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash: await this.passwords.hash(plainPassword),
        firstName: dto.firstName,
        lastName: dto.lastName,
        locale: dto.locale ?? 'pt-BR',
        timezone: dto.timezone ?? 'America/Sao_Paulo',
        status: UserStatus.INVITED,
        mustChangePassword: true,
        pastor: dto.pastorId ? { connect: { id: dto.pastorId } } : undefined,
      },
      select: SAFE_SELECT,
    });

    await this.audit.record({
      userId: actor.id,
      action: AuditAction.CREATE,
      entity: 'User',
      entityId: created.id,
      metadata: { email: created.email, pastorId: dto.pastorId },
    });

    return created;
  }

  async update(actor: AuthenticatedUser, id: string, dto: UpdateUserDto) {
    const current = await this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      select: { id: true, status: true },
    });
    if (!current) throw AppError.notFound('Usuario nao encontrado.');

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        firstName: dto.firstName,
        lastName: dto.lastName,
        locale: dto.locale,
        timezone: dto.timezone,
        avatarUrl: dto.avatarUrl,
        status: dto.status,
      },
      select: SAFE_SELECT,
    });

    // Desativacao tem efeito imediato: sem isso o usuario continuaria
    // acessando com o token atual ate ele expirar.
    if (dto.status && DEACTIVATING_STATUSES.includes(dto.status) && !DEACTIVATING_STATUSES.includes(current.status)) {
      await this.sessions.revokeAllForUser(id, 'ADMIN_DEACTIVATED');
      this.principals.invalidate(id);
    }

    await this.audit.record({
      userId: actor.id,
      action: AuditAction.UPDATE,
      entity: 'User',
      entityId: id,
      metadata: { fields: Object.keys(dto) },
    });

    return updated;
  }

  /** O proprio usuario atualizando seus dados basicos - nao exige user.write. */
  async updateMe(user: AuthenticatedUser, dto: UpdateMeDto) {
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        firstName: dto.firstName,
        lastName: dto.lastName,
        locale: dto.locale,
        timezone: dto.timezone,
        avatarUrl: dto.avatarUrl,
      },
      select: SAFE_SELECT,
    });

    // Refresca o cache do principal para refletir nome/locale/timezone novos.
    this.principals.invalidate(user.id);

    await this.audit.record({
      userId: user.id,
      action: AuditAction.UPDATE,
      entity: 'User',
      entityId: user.id,
      metadata: { fields: Object.keys(dto), self: true },
    });

    return updated;
  }

  async remove(actor: AuthenticatedUser, id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      select: { id: true },
    });
    if (!user) throw AppError.notFound('Usuario nao encontrado.');

    await this.prisma.user.update({
      where: { id },
      data: { deletedAt: new Date(), status: UserStatus.DISABLED },
    });
    await this.sessions.revokeAllForUser(id, 'USER_DELETED');
    this.principals.invalidate(id);

    await this.audit.record({
      userId: actor.id,
      action: AuditAction.DELETE,
      entity: 'User',
      entityId: id,
    });
  }

  /**
   * Reset administrativo. A senha temporaria so e devolvida em DEV -
   * em producao o TODO e enviar por e-mail, nunca retornar no corpo da resposta.
   */
  async resetPassword(actor: AuthenticatedUser, id: string): Promise<{ temporaryPassword?: string; ok: true }> {
    const user = await this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      select: { id: true },
    });
    if (!user) throw AppError.notFound('Usuario nao encontrado.');

    const temporaryPassword = this.generateTemporaryPassword();
    await this.prisma.user.update({
      where: { id },
      data: {
        passwordHash: await this.passwords.hash(temporaryPassword),
        mustChangePassword: true,
        failedLoginCount: 0,
        lockedUntil: null,
      },
    });

    await this.sessions.revokeAllForUser(id, 'ADMIN_PASSWORD_RESET');
    this.principals.invalidate(id);

    await this.audit.record({
      userId: actor.id,
      action: AuditAction.PASSWORD_RESET,
      entity: 'User',
      entityId: id,
    });

    // TODO: enviar senha temporaria por e-mail quando houver servico de envio.
    if (process.env.APP_ENV === 'DEV') {
      return { temporaryPassword, ok: true };
    }
    return { ok: true };
  }

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  /** Gera senha aleatoria que sempre satisfaz PasswordService.validate. */
  private generateTemporaryPassword(): string {
    const random = randomToken(16).replace(/[^a-zA-Z0-9]/g, '');
    return `Tmp${random}9`;
  }
}
