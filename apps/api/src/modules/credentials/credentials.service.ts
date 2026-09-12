import { Injectable } from '@nestjs/common';
import { AuditAction, CredentialStatus, Prisma } from '@prisma/client';
import { PageDto } from '../../common/dto/pagination.dto';
import { AppError } from '../../common/errors/app-error';
import { randomToken } from '../../common/utils/crypto.util';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { CreateCredentialDto, CredentialQueryDto, RevokeCredentialDto } from './dto/credential.dto';

@Injectable()
export class CredentialsService {
  constructor(private readonly prisma: PrismaService, private readonly acl: AccessControlService, private readonly audit: AuditService) {}

  async list(user: AuthenticatedUser, query: CredentialQueryDto) {
    const scope = await this.acl.pastorWhere(user, PERMISSIONS.CREDENTIAL_READ);
    const where: Prisma.CredentialWhereInput = { pastor: { is: scope }, ...(query.status ? { status: query.status } : {}), ...(query.pastorId ? { pastorId: query.pastorId } : {}), ...(query.search ? { number: { contains: query.search, mode: 'insensitive' } } : {}) };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.credential.count({ where }),
      this.prisma.credential.findMany({ where, orderBy: { issuedAt: 'desc' }, skip: query.skip, take: query.take, include: { pastor: { select: { id: true, pastoralName: true } } } }),
    ]);
    return PageDto.of(data, total, query);
  }

  async get(user: AuthenticatedUser, id: string) {
    const credential = await this.prisma.credential.findUnique({ where: { id }, include: { pastor: { select: { id: true, pastoralName: true } } } });
    if (!credential) throw AppError.notFound('Credencial nao encontrada.');
    await this.acl.assertPastorAccess(user, credential.pastorId, PERMISSIONS.CREDENTIAL_READ);
    return credential;
  }

  async create(user: AuthenticatedUser, dto: CreateCredentialDto) {
    this.acl.assert(user, PERMISSIONS.CREDENTIAL_WRITE);
    await this.acl.assertPastorAccess(user, dto.pastorId, PERMISSIONS.CREDENTIAL_WRITE);
    const credential = await this.prisma.credential.create({ data: { pastorId: dto.pastorId, number: dto.number.trim(), type: dto.type, issuedAt: new Date(dto.issuedAt), expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined, status: CredentialStatus.ACTIVE, verificationToken: randomToken(24), issuedById: user.id } });
    await this.audit.record({ userId: user.id, action: AuditAction.CREATE, entity: 'Credential', entityId: credential.id });
    return credential;
  }

  async revoke(user: AuthenticatedUser, id: string, dto: RevokeCredentialDto) {
    this.acl.assert(user, PERMISSIONS.CREDENTIAL_REVOKE);
    const current = await this.prisma.credential.findUnique({ where: { id }, select: { pastorId: true, status: true } });
    if (!current) throw AppError.notFound('Credencial nao encontrada.');
    await this.acl.assertPastorAccess(user, current.pastorId, PERMISSIONS.CREDENTIAL_REVOKE);
    if (current.status === CredentialStatus.REVOKED) throw AppError.conflict('Credencial ja revogada.');
    const credential = await this.prisma.credential.update({ where: { id }, data: { status: CredentialStatus.REVOKED, revokedAt: new Date(), revokedReason: dto.reason.trim() } });
    await this.audit.record({ userId: user.id, action: AuditAction.UPDATE, entity: 'Credential', entityId: id, metadata: { operation: 'REVOKE' } });
    return credential;
  }

  async verify(token: string) {
    const credential = await this.prisma.credential.findUnique({ where: { verificationToken: token }, include: { pastor: { select: { pastoralName: true } } } });
    if (!credential || credential.status !== CredentialStatus.ACTIVE || (credential.expiresAt && credential.expiresAt < new Date())) return { valid: false };
    return { valid: true, number: credential.number, type: credential.type, status: credential.status, issuedAt: credential.issuedAt, expiresAt: credential.expiresAt, pastoralName: credential.pastor.pastoralName };
  }
}
