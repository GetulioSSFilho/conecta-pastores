import { Injectable } from '@nestjs/common';
import { AuditAction, EventScopeType, Prisma } from '@prisma/client';
import { PageDto } from '../../common/dto/pagination.dto';
import { AppError } from '../../common/errors/app-error';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { CreateEventDto, EventQueryDto, UpdateEventDto } from './dto/event.dto';

@Injectable()
export class EventsService {
  constructor(private readonly prisma: PrismaService, private readonly acl: AccessControlService, private readonly audit: AuditService) {}
  async list(user: AuthenticatedUser, query: EventQueryDto) {
    // Perfil 360: com pastorId a base de autorizacao e o acesso ao pastor (escopo de event.read)
    // e a lista traz os compromissos em que ele participa. Sem pastorId: agenda do proprio usuario.
    if (query.pastorId) await this.acl.assertPastorAccess(user, query.pastorId, PERMISSIONS.EVENT_READ);
    const visibility: Prisma.EventWhereInput = query.pastorId
      ? { participants: { some: { pastorId: query.pastorId } } }
      : { OR: [{ organizerId: user.id }, { participants: { some: { OR: [{ userId: user.id }, ...(user.pastorId ? [{ pastorId: user.pastorId }] : [])] } } }, { scope: EventScopeType.GLOBAL }] };
    const where: Prisma.EventWhereInput = { deletedAt: null, ...(query.type ? { type: query.type } : {}), ...(query.from || query.to ? { startsAt: { ...(query.from ? { gte: new Date(query.from) } : {}), ...(query.to ? { lte: new Date(query.to) } : {}) } } : {}), ...visibility };
    const [total, data] = await this.prisma.$transaction([this.prisma.event.count({ where }), this.prisma.event.findMany({ where, orderBy: { startsAt: 'asc' }, skip: query.skip, take: query.take, include: { church: { select: { id: true, name: true } }, participants: { include: { pastor: { select: { id: true, pastoralName: true } } } } } })]);
    return PageDto.of(data, total, query);
  }
  async get(user: AuthenticatedUser, id: string) { const event = await this.prisma.event.findFirst({ where: { id, deletedAt: null }, include: { church: true, participants: { include: { pastor: true, user: { select: { id: true, firstName: true, lastName: true } } } } } }); if (!event) throw AppError.notFound('Evento nao encontrado.'); const allowed = event.organizerId === user.id || event.scope === EventScopeType.GLOBAL || event.participants.some((participant) => participant.userId === user.id || participant.pastorId === user.pastorId); if (!allowed) throw AppError.forbidden(); return event; }
  async create(user: AuthenticatedUser, dto: CreateEventDto) { this.acl.assert(user, PERMISSIONS.EVENT_WRITE); const startsAt = new Date(dto.startsAt); const endsAt = new Date(dto.endsAt); if (endsAt <= startsAt) throw AppError.validation('O fim deve ser posterior ao inicio.'); if (dto.scope !== EventScopeType.GLOBAL && !dto.scopeRefId && dto.scope !== EventScopeType.INDIVIDUAL) throw AppError.validation('scopeRefId obrigatorio para este escopo.'); const event = await this.prisma.event.create({ data: { type: dto.type, scope: dto.scope, scopeRefId: dto.scopeRefId, title: dto.title.trim(), description: dto.description, location: dto.location, isOnline: dto.isOnline, meetingUrl: dto.meetingUrl, startsAt, endsAt, allDay: dto.allDay, timezone: dto.timezone, churchId: dto.churchId, organizerId: user.id, participants: { create: [...(dto.pastorIds ?? []).map((pastorId) => ({ pastorId }))] } }, include: { participants: true } }); await this.audit.record({ userId: user.id, action: AuditAction.CREATE, entity: 'Event', entityId: event.id }); return event; }
  async update(user: AuthenticatedUser, id: string, dto: UpdateEventDto) { this.acl.assert(user, PERMISSIONS.EVENT_WRITE); const current = await this.prisma.event.findUnique({ where: { id }, select: { organizerId: true } }); if (!current) throw AppError.notFound('Evento nao encontrado.'); if (current.organizerId !== user.id && !this.acl.has(user, PERMISSIONS.REPORT_READ_GLOBAL)) throw AppError.forbidden(); const updated = await this.prisma.event.update({ where: { id }, data: { type: dto.type, scope: dto.scope, scopeRefId: dto.scopeRefId, title: dto.title.trim(), description: dto.description, location: dto.location, isOnline: dto.isOnline, meetingUrl: dto.meetingUrl, startsAt: new Date(dto.startsAt), endsAt: new Date(dto.endsAt), allDay: dto.allDay, timezone: dto.timezone, churchId: dto.churchId } }); await this.audit.record({ userId: user.id, action: AuditAction.UPDATE, entity: 'Event', entityId: id }); return updated; }
  async remove(user: AuthenticatedUser, id: string) { this.acl.assert(user, PERMISSIONS.EVENT_WRITE); const result = await this.prisma.event.updateMany({ where: { id, organizerId: user.id, deletedAt: null }, data: { deletedAt: new Date() } }); if (!result.count) throw AppError.notFound('Evento nao encontrado.'); await this.audit.record({ userId: user.id, action: AuditAction.DELETE, entity: 'Event', entityId: id }); }
}
