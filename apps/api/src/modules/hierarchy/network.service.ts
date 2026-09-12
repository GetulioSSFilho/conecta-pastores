import { Injectable } from '@nestjs/common';
import { PastorStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError } from '../../common/errors/app-error';
import { PageDto } from '../../common/dto/pagination.dto';
import { daysSince, daysUntil } from '../../common/utils/date.util';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import type { NetworkQueryDto } from './dto/network.dto';

/**
 * "Minha Rede": visao operacional dos pastores sob responsabilidade do usuario.
 *
 * Indicadores sao FATOS, nunca julgamentos.
 * Correto:   "63 dias sem acompanhamento".
 * Proibido:  "pastor em risco".
 */
@Injectable()
export class NetworkService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly acl: AccessControlService,
  ) {}

  /** Pastor raiz da rede do usuario. */
  private rootPastorId(user: AuthenticatedUser, requested?: string): string {
    const root = requested ?? user.pastorId;
    if (!root) {
      throw AppError.validation('Usuario sem pastor vinculado. Informe o pastor raiz da rede.');
    }
    return root;
  }

  /**
   * Lista plana da rede, com filtros e paginacao server-side.
   * O `where` combina a subarvore pedida com o escopo do usuario: pedir a rede
   * de outra pessoa nao contorna a autorizacao.
   */
  async list(user: AuthenticatedUser, query: NetworkQueryDto) {
    const rootId = this.rootPastorId(user, query.rootPastorId);
    if (query.rootPastorId) {
      await this.acl.assertPastorAccess(user, query.rootPastorId, PERMISSIONS.NETWORK_READ);
    }

    const scopeWhere = await this.acl.pastorWhere(user, PERMISSIONS.NETWORK_READ);

    const where: Prisma.PastorWhereInput = {
      AND: [
        { deletedAt: null },
        scopeWhere,
        {
          ancestorsClosure: {
            some: {
              ancestorId: rootId,
              depth: query.includeSelf ? { gte: 0 } : { gt: 0 },
              ...(query.maxDepth ? { depth: { gt: 0, lte: query.maxDepth } } : {}),
            },
          },
        },
        ...(query.status ? [{ status: query.status }] : []),
        ...(query.churchId ? [{ churchId: query.churchId }] : []),
        ...(query.regionId ? [{ regionId: query.regionId }] : []),
        ...(query.countryId ? [{ countryId: query.countryId }] : []),
        ...(query.search
          ? [
              {
                OR: [
                  { pastoralName: { contains: query.search, mode: 'insensitive' as const } },
                  { firstName: { contains: query.search, mode: 'insensitive' as const } },
                  { lastName: { contains: query.search, mode: 'insensitive' as const } },
                  { email: { contains: query.search, mode: 'insensitive' as const } },
                ],
              },
            ]
          : []),
        ...(query.careOverdueDays
          ? [
              {
                OR: [
                  { lastCareAt: null },
                  { lastCareAt: { lt: new Date(Date.now() - query.careOverdueDays * 86_400_000) } },
                ],
              },
            ]
          : []),
        ...(query.neverCared ? [{ lastCareAt: null }] : []),
      ],
    };

    const orderBy = this.buildOrderBy(query);

    const [total, rows] = await this.prisma.$transaction([
      this.prisma.pastor.count({ where }),
      this.prisma.pastor.findMany({
        where,
        orderBy,
        skip: query.skip,
        take: query.take,
        select: {
          id: true,
          pastoralName: true,
          firstName: true,
          lastName: true,
          photoUrl: true,
          ministryTitle: true,
          status: true,
          lastCareAt: true,
          nextCareAt: true,
          phoneE164: true,
          whatsappE164: true,
          email: true,
          church: { select: { id: true, name: true, city: true } },
          region: { select: { id: true, name: true, code: true } },
          country: { select: { id: true, name: true, code: true } },
          ancestorsClosure: {
            where: { ancestorId: rootId },
            select: { depth: true },
            take: 1,
          },
        },
      }),
    ]);

    const data = rows.map((p) => ({
      ...p,
      depth: p.ancestorsClosure[0]?.depth ?? 0,
      ancestorsClosure: undefined,
      indicators: this.indicators(p),
    }));

    return PageDto.of(data, total, query);
  }

  /** Resumo da rede para o dashboard do lider. */
  async summary(user: AuthenticatedUser, rootPastorId?: string) {
    const rootId = this.rootPastorId(user, rootPastorId);
    if (rootPastorId) {
      await this.acl.assertPastorAccess(user, rootPastorId, PERMISSIONS.NETWORK_READ);
    }

    const scopeWhere = await this.acl.pastorWhere(user, PERMISSIONS.NETWORK_READ);
    const inNetwork: Prisma.PastorWhereInput = {
      AND: [
        { deletedAt: null },
        scopeWhere,
        { ancestorsClosure: { some: { ancestorId: rootId, depth: { gt: 0 } } } },
      ],
    };

    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 86_400_000);
    const sevenDaysAhead = new Date(now.getTime() + 7 * 86_400_000);

    const [total, active, neverCared, overdue30, upcoming, directReports] =
      await this.prisma.$transaction([
        this.prisma.pastor.count({ where: inNetwork }),
        this.prisma.pastor.count({ where: { AND: [inNetwork, { status: PastorStatus.ACTIVE }] } }),
        this.prisma.pastor.count({ where: { AND: [inNetwork, { lastCareAt: null }] } }),
        this.prisma.pastor.count({
          where: { AND: [inNetwork, { lastCareAt: { lt: thirtyDaysAgo } }] },
        }),
        this.prisma.pastor.count({
          where: { AND: [inNetwork, { nextCareAt: { gte: now, lte: sevenDaysAhead } }] },
        }),
        this.prisma.pastoralClosure.count({ where: { ancestorId: rootId, depth: 1 } }),
      ]);

    return {
      rootPastorId: rootId,
      totalInNetwork: total,
      activePastors: active,
      directReports,
      neverCared,
      careOverdue30Days: overdue30,
      upcomingCareNext7Days: upcoming,
    };
  }

  /**
   * Indicadores factuais por pastor.
   * Nada de classificacao subjetiva - apenas contagem de dias e datas.
   */
  private indicators(pastor: { lastCareAt: Date | null; nextCareAt: Date | null }) {
    return {
      daysSinceLastCare: daysSince(pastor.lastCareAt),
      neverCared: pastor.lastCareAt === null,
      daysUntilNextCare: daysUntil(pastor.nextCareAt),
      hasScheduledCare: pastor.nextCareAt !== null && pastor.nextCareAt > new Date(),
    };
  }

  private buildOrderBy(query: NetworkQueryDto): Prisma.PastorOrderByWithRelationInput[] {
    const direction = query.sortOrder ?? 'asc';
    switch (query.sortBy) {
      case 'lastCareAt':
        // nulls first em asc: quem nunca foi acompanhado aparece primeiro.
        return [{ lastCareAt: { sort: direction, nulls: 'first' } }];
      case 'nextCareAt':
        return [{ nextCareAt: { sort: direction, nulls: 'last' } }];
      case 'status':
        return [{ status: direction }, { pastoralName: 'asc' }];
      case 'church':
        return [{ church: { name: direction } }, { pastoralName: 'asc' }];
      default:
        return [{ pastoralName: direction }];
    }
  }
}
