import { Injectable, Logger } from '@nestjs/common';
import { AuditAction, Prisma, RelationshipType } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError, ErrorCode } from '../../common/errors/app-error';
import { AuditService } from '../audit/audit.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';

/**
 * Hierarquia pastoral.
 *
 * ESTRATEGIA (ver docs/database.md):
 *   adjacency list (`pastoral_relationships`) = fonte da verdade, com historico.
 *   closure table (`pastoral_closure`)        = indice materializado para leitura.
 *
 * Por que closure e nao apenas CTE recursiva:
 *   - "Minha Rede" e o filtro de escopo SUBTREE aparecem em quase toda listagem.
 *     Com closure, "todos os descendentes de X" e um index scan; com CTE seria
 *     uma recursao por request, em cada endpoint.
 *   - A arvore muda raramente (troca de supervisor), leituras sao constantes.
 *     Pagar escrita cara e leitura barata e a troca certa aqui.
 *   - Profundidade e contagem de rede saem prontas, sem recursao.
 *
 * A closure e sempre atualizada na MESMA transacao da aresta.
 */
@Injectable()
export class HierarchyService {
  private readonly logger = new Logger(HierarchyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------------------
  // Escrita
  // ---------------------------------------------------------------------------

  /**
   * Define (ou remove, com supervisorId = null) o supervisor de um pastor.
   * Move junto toda a subarvore do subordinado.
   */
  async setSupervisor(
    subordinateId: string,
    supervisorId: string | null,
    actor: AuthenticatedUser,
    notes?: string,
  ): Promise<void> {
    if (supervisorId === subordinateId) {
      throw new AppError(ErrorCode.CYCLE_DETECTED, 'Um pastor nao pode supervisionar a si mesmo.', 422);
    }

    const subordinate = await this.prisma.pastor.findFirst({
      where: { id: subordinateId, deletedAt: null },
      select: { id: true, pastoralName: true },
    });
    if (!subordinate) throw AppError.notFound('Pastor nao encontrado.');

    if (supervisorId) {
      const supervisor = await this.prisma.pastor.findFirst({
        where: { id: supervisorId, deletedAt: null },
        select: { id: true, pastoralName: true },
      });
      if (!supervisor) throw AppError.notFound('Supervisor nao encontrado.');

      // Ciclo: o candidato a supervisor ja esta na subarvore do subordinado?
      const wouldCycle = await this.prisma.pastoralClosure.findUnique({
        where: {
          ancestorId_descendantId: { ancestorId: subordinateId, descendantId: supervisorId },
        },
        select: { depth: true },
      });
      if (wouldCycle) {
        throw new AppError(
          ErrorCode.CYCLE_DETECTED,
          'Operacao invalida: o supervisor escolhido esta abaixo deste pastor na rede.',
          422,
        );
      }
    }

    const previous = await this.currentSupervisorId(subordinateId);

    await this.prisma.$transaction(async (tx) => {
      // 1. Encerra a aresta ativa anterior (mantem historico).
      await tx.pastoralRelationship.updateMany({
        where: { subordinateId, type: RelationshipType.SUPERVISION, isActive: true },
        data: { isActive: false, endedAt: new Date() },
      });

      // 2. Destaca a subarvore do subordinado da closure atual.
      await this.detachSubtree(tx, subordinateId);

      // 3. Cria a nova aresta e reanexa, quando houver supervisor.
      if (supervisorId) {
        await tx.pastoralRelationship.create({
          data: {
            supervisorId,
            subordinateId,
            type: RelationshipType.SUPERVISION,
            createdBy: actor.id,
            notes,
          },
        });
        await this.attachSubtree(tx, subordinateId, supervisorId);
      }
    });

    await this.audit.record({
      userId: actor.id,
      action: AuditAction.SUPERVISOR_CHANGE,
      entity: 'Pastor',
      entityId: subordinateId,
      metadata: { previousSupervisorId: previous, newSupervisorId: supervisorId },
    });
  }

  /**
   * Remove da closure todas as arestas que ligam a subarvore de `rootId`
   * a ancestrais fora dela. As relacoes internas da subarvore permanecem.
   */
  private async detachSubtree(tx: Prisma.TransactionClient, rootId: string): Promise<void> {
    await tx.$executeRaw`
      DELETE FROM pastoral_closure
      WHERE descendant_id IN (
              SELECT descendant_id FROM pastoral_closure WHERE ancestor_id = ${rootId}::uuid
            )
        AND ancestor_id NOT IN (
              SELECT descendant_id FROM pastoral_closure WHERE ancestor_id = ${rootId}::uuid
            )
    `;
  }

  /**
   * Liga a subarvore de `rootId` sob `parentId`:
   * produto cartesiano entre os ancestrais de `parentId` (inclusive ele)
   * e os descendentes de `rootId` (inclusive ele).
   */
  private async attachSubtree(
    tx: Prisma.TransactionClient,
    rootId: string,
    parentId: string,
  ): Promise<void> {
    await tx.$executeRaw`
      INSERT INTO pastoral_closure (ancestor_id, descendant_id, depth)
      SELECT sup.ancestor_id, sub.descendant_id, sup.depth + 1 + sub.depth
      FROM pastoral_closure sup
      CROSS JOIN pastoral_closure sub
      WHERE sup.descendant_id = ${parentId}::uuid
        AND sub.ancestor_id = ${rootId}::uuid
      ON CONFLICT (ancestor_id, descendant_id) DO NOTHING
    `;
  }

  /** Insere a linha depth 0 de um pastor recem-criado. */
  async registerPastor(pastorId: string, tx?: Prisma.TransactionClient): Promise<void> {
    const client = tx ?? this.prisma;
    await client.pastoralClosure.createMany({
      data: [{ ancestorId: pastorId, descendantId: pastorId, depth: 0 }],
      skipDuplicates: true,
    });
  }

  // ---------------------------------------------------------------------------
  // Leitura
  // ---------------------------------------------------------------------------

  async currentSupervisorId(pastorId: string): Promise<string | null> {
    const rel = await this.prisma.pastoralRelationship.findFirst({
      where: { subordinateId: pastorId, type: RelationshipType.SUPERVISION, isActive: true },
      select: { supervisorId: true },
    });
    return rel?.supervisorId ?? null;
  }

  /** Cadeia de lideranca, do supervisor direto ate o topo. */
  async ancestors(pastorId: string) {
    return this.prisma.pastoralClosure.findMany({
      where: { descendantId: pastorId, depth: { gt: 0 } },
      orderBy: { depth: 'asc' },
      select: {
        depth: true,
        ancestor: {
          select: {
            id: true,
            pastoralName: true,
            photoUrl: true,
            ministryTitle: true,
            status: true,
            church: { select: { id: true, name: true } },
          },
        },
      },
    });
  }

  /** Subordinados diretos (depth 1). */
  async directReports(pastorId: string) {
    return this.prisma.pastor.findMany({
      where: {
        deletedAt: null,
        ancestorsClosure: { some: { ancestorId: pastorId, depth: 1 } },
      },
      orderBy: { pastoralName: 'asc' },
      select: this.networkNodeSelect(),
    });
  }

  /**
   * Arvore completa da rede a partir de um pastor.
   * Uma unica query traz a subarvore; a montagem hierarquica ocorre em memoria.
   */
  async tree(rootPastorId: string, maxDepth = 6) {
    const rows = await this.prisma.pastoralClosure.findMany({
      where: { ancestorId: rootPastorId, depth: { lte: maxDepth } },
      select: { descendantId: true, depth: true },
    });
    const ids = rows.map((r) => r.descendantId);
    if (ids.length === 0) return null;

    const [pastors, edges] = await this.prisma.$transaction([
      this.prisma.pastor.findMany({
        where: { id: { in: ids }, deletedAt: null },
        select: this.networkNodeSelect(),
      }),
      this.prisma.pastoralRelationship.findMany({
        where: {
          subordinateId: { in: ids },
          type: RelationshipType.SUPERVISION,
          isActive: true,
        },
        select: { supervisorId: true, subordinateId: true },
      }),
    ]);

    const parentOf = new Map(edges.map((e) => [e.subordinateId, e.supervisorId]));
    type Node = (typeof pastors)[number] & { children: Node[]; depth: number };
    const depthOf = new Map(rows.map((r) => [r.descendantId, r.depth]));

    const byId = new Map<string, Node>();
    pastors.forEach((p) => byId.set(p.id, { ...p, children: [], depth: depthOf.get(p.id) ?? 0 }));

    let root: Node | null = null;
    for (const node of byId.values()) {
      if (node.id === rootPastorId) {
        root = node;
        continue;
      }
      const parentId = parentOf.get(node.id);
      const parent = parentId ? byId.get(parentId) : undefined;
      if (parent) parent.children.push(node);
    }

    const sortTree = (node: Node): void => {
      node.children.sort((a, b) => a.pastoralName.localeCompare(b.pastoralName));
      node.children.forEach(sortTree);
    };
    if (root) sortTree(root);

    return root;
  }

  /** Metricas da rede de um pastor. Uma query agregada. */
  async stats(pastorId: string) {
    const [aggregate, directCount] = await this.prisma.$transaction([
      this.prisma.pastoralClosure.aggregate({
        where: { ancestorId: pastorId, depth: { gt: 0 } },
        _count: { descendantId: true },
        _max: { depth: true },
      }),
      this.prisma.pastoralClosure.count({ where: { ancestorId: pastorId, depth: 1 } }),
    ]);

    return {
      totalInNetwork: aggregate._count.descendantId,
      directReports: directCount,
      maxDepth: aggregate._max.depth ?? 0,
    };
  }

  /**
   * Reconstroi a closure inteira a partir das arestas ativas.
   * Uso: seed, migracao e manutencao. NAO chamar em request de usuario.
   */
  async rebuildClosure(): Promise<{ rows: number }> {
    await this.prisma.$transaction(
      async (tx) => {
        await tx.$executeRawUnsafe('TRUNCATE TABLE pastoral_closure');
        await tx.$executeRawUnsafe(`
          INSERT INTO pastoral_closure (ancestor_id, descendant_id, depth)
          WITH RECURSIVE edges AS (
            SELECT supervisor_id AS parent, subordinate_id AS child
            FROM pastoral_relationships
            WHERE is_active = true AND type = 'SUPERVISION'
          ),
          paths AS (
            SELECT p.id AS ancestor_id, p.id AS descendant_id, 0 AS depth
            FROM pastors p
            WHERE p.deleted_at IS NULL
            UNION ALL
            SELECT paths.ancestor_id, e.child, paths.depth + 1
            FROM paths
            JOIN edges e ON e.parent = paths.descendant_id
            WHERE paths.depth < 32
          )
          SELECT ancestor_id, descendant_id, MIN(depth)
          FROM paths
          GROUP BY ancestor_id, descendant_id
        `);
      },
      { timeout: 120_000 },
    );

    const rows = await this.prisma.pastoralClosure.count();
    this.logger.log(`Closure reconstruida: ${rows} linhas.`);
    return { rows };
  }

  private networkNodeSelect() {
    return {
      id: true,
      pastoralName: true,
      firstName: true,
      lastName: true,
      photoUrl: true,
      ministryTitle: true,
      status: true,
      lastCareAt: true,
      nextCareAt: true,
      church: { select: { id: true, name: true } },
      region: { select: { id: true, name: true, code: true } },
      country: { select: { id: true, name: true, code: true } },
    } satisfies Prisma.PastorSelect;
  }
}
