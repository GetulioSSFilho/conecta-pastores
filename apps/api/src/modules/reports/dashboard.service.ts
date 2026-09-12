import { Injectable } from '@nestjs/common';
import { CareStatus, EnrollmentStatus, PastorStatus, Prisma, RequestStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { NetworkService } from '../hierarchy/network.service';

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService, private readonly acl: AccessControlService, private readonly network: NetworkService) {}

  async pastor(user: AuthenticatedUser) {
    const pastorId = user.pastorId;
    if (!pastorId) return { nextEvent: null, church: null, leadership: null, unreadNotifications: 0, openRequests: 0, expiringDocuments: 0, training: null };
    const now = new Date(); const in60 = new Date(now.getTime() + 60 * 86_400_000);
    const [pastor, nextEvent, unreadNotifications, openRequests, expiringDocuments, training] = await this.prisma.$transaction([
      this.prisma.pastor.findUnique({ where: { id: pastorId }, select: { church: { select: { id: true, name: true, city: true } } } }),
      this.prisma.event.findFirst({ where: { deletedAt: null, startsAt: { gte: now }, OR: [{ participants: { some: { pastorId } } }, { participants: { some: { userId: user.id } } }] }, orderBy: { startsAt: 'asc' }, select: { id: true, title: true, startsAt: true, endsAt: true } }),
      this.prisma.notification.count({ where: { userId: user.id, readAt: null } }),
      this.prisma.request.count({ where: { requesterId: user.id, deletedAt: null, status: { in: [RequestStatus.OPEN, RequestStatus.IN_PROGRESS, RequestStatus.WAITING] } } }),
      this.prisma.document.count({ where: { pastorId, deletedAt: null, expiresAt: { gte: now, lte: in60 } } }),
      this.prisma.trainingEnrollment.findMany({ where: { pastorId }, select: { status: true, progressPct: true } }),
    ]);
    const leadership = await this.prisma.pastoralClosure.findFirst({ where: { descendantId: pastorId, depth: 1 }, select: { ancestor: { select: { id: true, pastoralName: true } } } });
    return { nextEvent, church: pastor?.church ?? null, leadership: leadership?.ancestor ?? null, unreadNotifications, openRequests, expiringDocuments, training: { total: training.length, completed: training.filter((item) => item.status === EnrollmentStatus.COMPLETED).length, progressPct: training.length ? Math.round(training.reduce((sum, item) => sum + item.progressPct, 0) / training.length) : 0 } };
  }

  async leader(user: AuthenticatedUser) {
    const scope = await this.acl.pastorWhere(user, PERMISSIONS.CARE_READ);
    // SUBTREE inclui o proprio lider (depth 0); ele nao entra nos proprios indicadores.
    const others = user.pastorId ? { id: { not: user.pastorId } } : {};
    const now = new Date(); const day = new Date(now); day.setHours(0, 0, 0, 0); const week = new Date(day); week.setDate(day.getDate() - day.getDay()); const old = new Date(now.getTime() - 30 * 86_400_000);
    const [today, thisWeek, withoutCare, openRequests, nextCare] = await this.prisma.$transaction([
      this.prisma.pastoralCare.count({ where: { deletedAt: null, occurredAt: { gte: day }, pastor: { is: scope } } }),
      this.prisma.pastoralCare.count({ where: { deletedAt: null, occurredAt: { gte: week }, pastor: { is: scope } } }),
      this.prisma.pastor.count({ where: { AND: [scope, others, { deletedAt: null }, { OR: [{ lastCareAt: null }, { lastCareAt: { lt: old } }] }] } }),
      this.prisma.request.count({ where: { deletedAt: null, assigneeId: user.id, status: { in: [RequestStatus.OPEN, RequestStatus.IN_PROGRESS, RequestStatus.WAITING] } } }),
      this.prisma.pastor.findMany({ where: { AND: [scope, others, { deletedAt: null }, { nextCareAt: { gte: now } }] }, orderBy: { nextCareAt: 'asc' }, take: 5, select: { id: true, pastoralName: true, nextCareAt: true } }),
    ]);
    return { network: await this.network.summary(user), care: { today, thisWeek, withoutCareOver30Days: withoutCare }, openRequests, nextCare };
  }

  async global(user: AuthenticatedUser) {
    const pastors = await this.acl.pastorWhere(user, PERMISSIONS.REPORT_READ); const churches = await this.acl.churchWhere(user, PERMISSIONS.REPORT_READ);
    const [totalPastors, activePastors, totalChurches, countries, regions, newPastors] = await this.prisma.$transaction([
      this.prisma.pastor.count({ where: { AND: [pastors, { deletedAt: null }] } }), this.prisma.pastor.count({ where: { AND: [pastors, { deletedAt: null, status: PastorStatus.ACTIVE }] } }), this.prisma.church.count({ where: { AND: [churches, { deletedAt: null }] } }), this.prisma.country.count({ where: { pastors: { some: pastors } } }), this.prisma.region.count({ where: { pastors: { some: pastors }, deletedAt: null } }), this.prisma.pastor.count({ where: { AND: [pastors, { deletedAt: null, createdAt: { gte: new Date(Date.now() - 30 * 86_400_000) } }] } }),
    ]);
    return { totalPastors, activePastors, totalChurches, countries, regions, newPastors };
  }

  /** Pastores e igrejas por pais, sempre dentro do escopo do usuario (base do mapa e do dashboard). */
  async countryDistribution(user: AuthenticatedUser) {
    const [pastorScope, churchScope] = await Promise.all([
      this.acl.pastorWhere(user, PERMISSIONS.PASTOR_READ),
      this.acl.churchWhere(user, PERMISSIONS.CHURCH_READ),
    ]);
    const [pastors, churches, countries] = await Promise.all([
      this.prisma.pastor.groupBy({ by: ['countryId'], where: { AND: [pastorScope, { deletedAt: null }] }, _count: { _all: true } }),
      this.prisma.church.groupBy({ by: ['countryId'], where: { AND: [churchScope, { deletedAt: null }] }, _count: { _all: true } }),
      this.prisma.country.findMany({ where: { isActive: true }, select: { id: true, code: true, name: true } }),
    ]);
    const pastorsBy = new Map(pastors.map((row) => [row.countryId, row._count._all]));
    const churchesBy = new Map(churches.map((row) => [row.countryId, row._count._all]));
    return countries
      .map((country) => ({ ...country, pastors: pastorsBy.get(country.id) ?? 0, churches: churchesBy.get(country.id) ?? 0 }))
      .filter((country) => country.pastors > 0 || country.churches > 0)
      .sort((a, b) => b.pastors - a.pastors || a.name.localeCompare(b.name));
  }

  /**
   * Acompanhamentos realizados por semana na rede do usuario (fatos, sem julgamento).
   * Agrega em memoria apenas timestamps: volume pequeno (~1 registro por pastor a cada 2 semanas).
   */
  async careActivity(user: AuthenticatedUser, weeks: number) {
    const scope = await this.acl.pastorWhere(user, PERMISSIONS.CARE_READ);
    const others = user.pastorId ? { id: { not: user.pastorId } } : {};
    const weekMs = 7 * 86_400_000;
    const start = DashboardService.startOfWeekUtc(new Date(Date.now() - (weeks - 1) * weekMs));
    const rows = await this.prisma.pastoralCare.findMany({
      where: { deletedAt: null, status: CareStatus.DONE, occurredAt: { gte: start, lte: new Date() }, pastor: { is: { AND: [scope, others] } } },
      select: { occurredAt: true },
    });
    const counts = new Array<number>(weeks).fill(0);
    for (const row of rows) {
      const index = Math.floor((row.occurredAt.getTime() - start.getTime()) / weekMs);
      if (index >= 0 && index < weeks) counts[index]++;
    }
    return counts.map((count, i) => ({ weekStart: new Date(start.getTime() + i * weekMs).toISOString(), count }));
  }

  /** Segunda-feira 00:00 UTC da semana da data. */
  private static startOfWeekUtc(date: Date): Date {
    const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
    d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
    return d;
  }
}
