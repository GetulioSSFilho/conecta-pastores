import { Injectable } from '@nestjs/common';
import { AuditAction, Confidentiality, Prisma, RequestStatus } from '@prisma/client';
import { PageDto } from '../../common/dto/pagination.dto';
import { AppError } from '../../common/errors/app-error';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AssignRequestDto, ChangeRequestStatusDto, CreateRequestCommentDto, CreateRequestDto, RequestQueryDto } from './dto/request.dto';

const transitions: Record<RequestStatus, RequestStatus[]> = {
  OPEN: [RequestStatus.IN_PROGRESS, RequestStatus.WAITING, RequestStatus.CLOSED],
  IN_PROGRESS: [RequestStatus.WAITING, RequestStatus.RESOLVED, RequestStatus.CLOSED],
  WAITING: [RequestStatus.IN_PROGRESS, RequestStatus.RESOLVED, RequestStatus.CLOSED],
  RESOLVED: [RequestStatus.CLOSED, RequestStatus.IN_PROGRESS],
  CLOSED: [],
};

@Injectable()
export class RequestsService {
  constructor(private readonly prisma: PrismaService, private readonly acl: AccessControlService, private readonly audit: AuditService, private readonly notifications: NotificationsService) {}

  async categories() { return this.prisma.requestCategory.findMany({ where: { isActive: true }, orderBy: [{ rank: 'asc' }, { name: 'asc' }] }); }

  async list(user: AuthenticatedUser, query: RequestQueryDto) {
    const scope = await this.acl.pastorWhere(user, PERMISSIONS.REQUEST_READ);
    // Perfil 360: filtrar por pastor exige acesso a esse pastor no escopo de request.read.
    if (query.pastorId) await this.acl.assertPastorAccess(user, query.pastorId, PERMISSIONS.REQUEST_READ);
    const canSeeConfidential = this.acl.has(user, PERMISSIONS.CARE_READ_CONFIDENTIAL);
    const where: Prisma.RequestWhereInput = {
      deletedAt: null,
      ...(query.pastorId ? { pastorId: query.pastorId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.priority ? { priority: query.priority } : {}),
      ...(query.search ? { OR: [{ subject: { contains: query.search, mode: 'insensitive' } }, { description: { contains: query.search, mode: 'insensitive' } }] } : {}),
      AND: [
        { OR: [{ requesterId: user.id }, { assigneeId: user.id }, { pastor: { is: scope } }] },
        // CONFIDENCIAL: somente solicitante, responsavel ou quem tem care.read_confidential (mesma regra do detalhe).
        ...(canSeeConfidential ? [] : [{ OR: [{ confidentiality: { not: 'CONFIDENTIAL' as const } }, { requesterId: user.id }, { assigneeId: user.id }] }]),
      ],
    };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.request.count({ where }),
      this.prisma.request.findMany({ where, orderBy: { createdAt: 'desc' }, skip: query.skip, take: query.take, include: { category: true, requester: { select: { id: true, firstName: true, lastName: true } }, assignee: { select: { id: true, firstName: true, lastName: true } }, pastor: { select: { id: true, pastoralName: true } } } }),
    ]);
    return PageDto.of(data, total, query);
  }

  async get(user: AuthenticatedUser, id: string) {
    const request = await this.prisma.request.findFirst({ where: { id, deletedAt: null }, include: { category: true, requester: { select: { id: true, firstName: true, lastName: true } }, assignee: { select: { id: true, firstName: true, lastName: true } }, pastor: { select: { id: true, pastoralName: true } }, timeline: { orderBy: { createdAt: 'asc' }, include: { author: { select: { id: true, firstName: true, lastName: true } } } } } });
    if (!request) throw AppError.notFound('Solicitacao nao encontrada.');
    await this.assertAccess(user, request);
    return request;
  }

  async create(user: AuthenticatedUser, dto: CreateRequestDto) {
    const category = await this.prisma.requestCategory.findFirst({ where: { id: dto.categoryId, isActive: true }, select: { id: true } });
    if (!category) throw AppError.validation('Categoria invalida.');
    const pastorId = dto.pastorId ?? user.pastorId;
    if (pastorId) await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.REQUEST_WRITE);
    const confidentiality = dto.confidentiality ?? Confidentiality.NORMAL;
    if (confidentiality !== Confidentiality.NORMAL && !this.acl.has(user, PERMISSIONS.CARE_READ_RESTRICTED)) throw AppError.forbidden();
    const request = await this.prisma.request.create({ data: { categoryId: dto.categoryId, requesterId: user.id, pastorId, subject: dto.subject.trim(), description: dto.description.trim(), priority: dto.priority, confidentiality, dueAt: dto.dueAt ? new Date(dto.dueAt) : undefined, timeline: { create: { authorId: user.id, kind: 'SYSTEM', message: 'Solicitacao criada.' } } }, include: { category: true } });
    await this.audit.record({ userId: user.id, action: AuditAction.CREATE, entity: 'Request', entityId: request.id });
    return request;
  }

  async comment(user: AuthenticatedUser, id: string, dto: CreateRequestCommentDto) {
    const request = await this.get(user, id);
    if (dto.isInternal) this.acl.assert(user, PERMISSIONS.REQUEST_ASSIGN);
    const entry = await this.prisma.requestTimelineEntry.create({ data: { requestId: request.id, authorId: user.id, kind: 'COMMENT', message: dto.message.trim(), isInternal: dto.isInternal } });
    const recipient = request.requesterId === user.id ? request.assigneeId : request.requesterId;
    if (recipient) await this.notifications.create({ userId: recipient, type: 'REQUEST', title: 'Nova atualizacao de solicitacao', body: `Solicitacao #${request.number} recebeu uma atualizacao.`, link: `/requests/${request.id}`, entity: 'Request', entityId: request.id });
    return entry;
  }

  async assign(user: AuthenticatedUser, id: string, dto: AssignRequestDto) {
    this.acl.assert(user, PERMISSIONS.REQUEST_ASSIGN);
    const current = await this.prisma.request.findFirst({ where: { id, deletedAt: null }, select: { id: true, assigneeId: true, status: true, requesterId: true, number: true } });
    if (!current) throw AppError.notFound('Solicitacao nao encontrada.');
    if (dto.assigneeId) {
      const assignee = await this.prisma.user.findFirst({ where: { id: dto.assigneeId, deletedAt: null }, select: { id: true } });
      if (!assignee) throw AppError.validation('Responsavel invalido.');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.request.update({ where: { id }, data: { assigneeId: dto.assigneeId ?? null, status: RequestStatus.IN_PROGRESS } });
      await tx.requestTimelineEntry.create({ data: { requestId: id, authorId: user.id, kind: 'ASSIGNMENT', metadata: { from: current.assigneeId, to: dto.assigneeId ?? null } } });
      return result;
    });
    await this.audit.record({ userId: user.id, action: AuditAction.UPDATE, entity: 'Request', entityId: id, metadata: { operation: 'ASSIGN' } });
    if (dto.assigneeId) await this.notifications.create({ userId: dto.assigneeId, type: 'REQUEST', title: 'Solicitacao atribuida', body: `A solicitacao #${current.number} foi atribuida a voce.`, link: `/requests/${id}`, entity: 'Request', entityId: id });
    return updated;
  }

  async changeStatus(user: AuthenticatedUser, id: string, dto: ChangeRequestStatusDto) {
    this.acl.assert(user, PERMISSIONS.REQUEST_RESOLVE);
    const current = await this.prisma.request.findFirst({ where: { id, deletedAt: null }, select: { status: true, requesterId: true, number: true } });
    if (!current) throw AppError.notFound('Solicitacao nao encontrada.');
    if (!transitions[current.status].includes(dto.status)) throw AppError.conflict(`Transicao ${current.status} -> ${dto.status} nao permitida.`);
    if (dto.status === RequestStatus.RESOLVED && !dto.resolution?.trim()) throw AppError.validation('Informe a resolucao.');
    const now = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.request.update({ where: { id }, data: { status: dto.status, resolution: dto.resolution?.trim(), resolvedAt: dto.status === RequestStatus.RESOLVED ? now : undefined, closedAt: dto.status === RequestStatus.CLOSED ? now : undefined } });
      await tx.requestTimelineEntry.create({ data: { requestId: id, authorId: user.id, kind: 'STATUS_CHANGE', metadata: { from: current.status, to: dto.status }, message: dto.resolution } });
      return result;
    });
    await this.audit.record({ userId: user.id, action: AuditAction.UPDATE, entity: 'Request', entityId: id, metadata: { from: current.status, to: dto.status } });
    if (current.requesterId !== user.id) await this.notifications.create({ userId: current.requesterId, type: 'REQUEST', title: 'Status da solicitacao atualizado', body: `A solicitacao #${current.number} agora esta ${dto.status}.`, link: `/requests/${id}`, entity: 'Request', entityId: id });
    return updated;
  }

  async remove(user: AuthenticatedUser, id: string) { this.acl.assert(user, PERMISSIONS.REQUEST_ASSIGN); const result = await this.prisma.request.updateMany({ where: { id, deletedAt: null }, data: { deletedAt: new Date() } }); if (!result.count) throw AppError.notFound('Solicitacao nao encontrada.'); await this.audit.record({ userId: user.id, action: AuditAction.DELETE, entity: 'Request', entityId: id }); }

  private async assertAccess(user: AuthenticatedUser, request: { requesterId: string; assigneeId: string | null; pastorId: string | null; confidentiality: Confidentiality }) {
    if (request.requesterId === user.id || request.assigneeId === user.id) return;
    if (request.confidentiality !== Confidentiality.NORMAL && !this.acl.has(user, PERMISSIONS.CARE_READ_RESTRICTED)) throw AppError.forbidden();
    if (!request.pastorId) throw AppError.forbidden();
    await this.acl.assertPastorAccess(user, request.pastorId, PERMISSIONS.REQUEST_READ);
  }
}
