import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError } from '../../common/errors/app-error';
import { PageDto } from '../../common/dto/pagination.dto';
import { ScopeResolver } from '../authorization/scope.resolver';
import type {
  CreateCountryDto,
  CreateRegionDto,
  RegionQueryDto,
  UpdateCountryDto,
  UpdateRegionDto,
} from './dto/geography.dto';

/**
 * Paises e regioes.
 *
 * Leitura e aberta a qualquer usuario autenticado com `geography.read`:
 * sao dados estruturais, sem informacao pessoal. Escrita exige `geography.write`.
 */
@Injectable()
export class GeographyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scopes: ScopeResolver,
  ) {}

  // --------------------------------------------------------------------------
  // Paises
  // --------------------------------------------------------------------------

  async listCountries(onlyActive = true) {
    return this.prisma.country.findMany({
      where: onlyActive ? { isActive: true } : {},
      orderBy: { name: 'asc' },
      select: {
        id: true,
        code: true,
        code3: true,
        name: true,
        phoneCode: true,
        defaultLocale: true,
        defaultTimezone: true,
        isActive: true,
        _count: { select: { regions: true, churches: true, pastors: true } },
      },
    });
  }

  async getCountry(id: string) {
    const country = await this.prisma.country.findUnique({
      where: { id },
      include: {
        regions: {
          where: { deletedAt: null, parentId: null },
          orderBy: { name: 'asc' },
          select: { id: true, code: true, name: true, level: true },
        },
        _count: { select: { churches: true, pastors: true } },
      },
    });
    if (!country) throw AppError.notFound('Pais nao encontrado.');
    return country;
  }

  async createCountry(dto: CreateCountryDto) {
    return this.prisma.country.create({
      data: {
        code: dto.code.toUpperCase(),
        code3: dto.code3.toUpperCase(),
        name: dto.name,
        nativeName: dto.nativeName,
        phoneCode: dto.phoneCode.replace(/\D/g, ''),
        currency: dto.currency?.toUpperCase(),
        defaultLocale: dto.defaultLocale ?? 'pt-BR',
        defaultTimezone: dto.defaultTimezone ?? 'UTC',
      },
    });
  }

  async updateCountry(id: string, dto: UpdateCountryDto) {
    await this.getCountry(id);
    return this.prisma.country.update({
      where: { id },
      data: {
        ...dto,
        phoneCode: dto.phoneCode ? dto.phoneCode.replace(/\D/g, '') : undefined,
        currency: dto.currency?.toUpperCase(),
      },
    });
  }

  // --------------------------------------------------------------------------
  // Regioes
  // --------------------------------------------------------------------------

  async listRegions(query: RegionQueryDto) {
    const where: Prisma.RegionWhereInput = {
      deletedAt: null,
      ...(query.countryId ? { countryId: query.countryId } : {}),
      ...(query.parentId ? { parentId: query.parentId } : {}),
      ...(query.onlyActive ? { isActive: true } : {}),
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' } },
              { code: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [total, data] = await this.prisma.$transaction([
      this.prisma.region.count({ where }),
      this.prisma.region.findMany({
        where,
        orderBy: [{ level: 'asc' }, { name: 'asc' }],
        skip: query.skip,
        take: query.take,
        select: {
          id: true,
          code: true,
          name: true,
          level: true,
          isActive: true,
          parentId: true,
          country: { select: { id: true, code: true, name: true } },
          _count: { select: { churches: true, pastors: true, children: true } },
        },
      }),
    ]);

    return PageDto.of(data, total, query);
  }

  /** Arvore de regioes de um pais, montada em memoria a partir de uma unica query. */
  async regionTree(countryId: string) {
    const regions = await this.prisma.region.findMany({
      where: { countryId, deletedAt: null },
      orderBy: [{ level: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        code: true,
        name: true,
        level: true,
        parentId: true,
        _count: { select: { churches: true, pastors: true } },
      },
    });

    type Node = (typeof regions)[number] & { children: Node[] };
    const byId = new Map<string, Node>();
    regions.forEach((r) => byId.set(r.id, { ...r, children: [] }));

    const roots: Node[] = [];
    for (const node of byId.values()) {
      if (node.parentId) byId.get(node.parentId)?.children.push(node);
      else roots.push(node);
    }
    return roots;
  }

  async getRegion(id: string) {
    const region = await this.prisma.region.findFirst({
      where: { id, deletedAt: null },
      include: {
        country: { select: { id: true, code: true, name: true } },
        parent: { select: { id: true, name: true } },
        children: {
          where: { deletedAt: null },
          orderBy: { name: 'asc' },
          select: { id: true, name: true, code: true },
        },
        _count: { select: { churches: true, pastors: true } },
      },
    });
    if (!region) throw AppError.notFound('Regiao nao encontrada.');
    return region;
  }

  async createRegion(dto: CreateRegionDto) {
    if (dto.parentId) {
      const parent = await this.prisma.region.findFirst({
        where: { id: dto.parentId, deletedAt: null },
        select: { countryId: true, level: true },
      });
      if (!parent) throw AppError.notFound('Regiao pai nao encontrada.');
      if (parent.countryId !== dto.countryId) {
        throw AppError.validation('A regiao pai pertence a outro pais.');
      }
    }

    const created = await this.prisma.region.create({
      data: {
        countryId: dto.countryId,
        parentId: dto.parentId,
        code: dto.code.toUpperCase(),
        name: dto.name,
        level: dto.level ?? 0,
      },
    });
    this.scopes.invalidateRegionCache();
    return created;
  }

  async updateRegion(id: string, dto: UpdateRegionDto) {
    await this.getRegion(id);

    if (dto.parentId) {
      if (dto.parentId === id) throw AppError.validation('Uma regiao nao pode ser pai de si mesma.');
      const descendants = await this.scopes.expandRegions([id]);
      if (descendants.includes(dto.parentId)) {
        throw AppError.validation('Movimento invalido: geraria ciclo na arvore de regioes.');
      }
    }

    const updated = await this.prisma.region.update({
      where: { id },
      data: { ...dto, code: dto.code?.toUpperCase() },
    });
    this.scopes.invalidateRegionCache();
    return updated;
  }

  /** Soft delete. Bloqueado enquanto houver igrejas ou pastores vinculados. */
  async removeRegion(id: string) {
    const region = await this.getRegion(id);
    if (region._count.churches > 0 || region._count.pastors > 0) {
      throw AppError.conflict('Regiao possui igrejas ou pastores vinculados.', {
        churches: region._count.churches,
        pastors: region._count.pastors,
      });
    }
    await this.prisma.region.update({ where: { id }, data: { deletedAt: new Date() } });
    this.scopes.invalidateRegionCache();
  }
}
