import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuditAction } from '@prisma/client';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { Audited } from '../../common/decorators/audit.decorator';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { GeographyService } from './geography.service';
import {
  CreateCountryDto,
  CreateRegionDto,
  RegionQueryDto,
  UpdateCountryDto,
  UpdateRegionDto,
} from './dto/geography.dto';

@ApiTags('Geografia')
@ApiBearerAuth()
@Controller()
export class GeographyController {
  constructor(private readonly geography: GeographyService) {}

  // ---------------------------- Paises ----------------------------

  @Get('countries')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_READ)
  @ApiOperation({ summary: 'Lista paises' })
  listCountries(@Query('onlyActive') onlyActive?: string) {
    return this.geography.listCountries(onlyActive !== 'false');
  }

  @Get('countries/:id')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_READ)
  @ApiOperation({ summary: 'Detalha um pais' })
  getCountry(@Param('id', ParseUUIDPipe) id: string) {
    return this.geography.getCountry(id);
  }

  @Post('countries')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_WRITE)
  @Audited({ action: AuditAction.CREATE, entity: 'Country' })
  @ApiOperation({ summary: 'Cadastra um pais' })
  createCountry(@Body() dto: CreateCountryDto) {
    return this.geography.createCountry(dto);
  }

  @Patch('countries/:id')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_WRITE)
  @Audited({ action: AuditAction.UPDATE, entity: 'Country', idParam: 'id' })
  @ApiOperation({ summary: 'Atualiza um pais' })
  updateCountry(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCountryDto) {
    return this.geography.updateCountry(id, dto);
  }

  // ---------------------------- Regioes ----------------------------

  @Get('regions')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_READ)
  @ApiOperation({ summary: 'Lista regioes com paginacao' })
  listRegions(@Query() query: RegionQueryDto) {
    return this.geography.listRegions(query);
  }

  @Get('regions/tree/:countryId')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_READ)
  @ApiOperation({ summary: 'Arvore de regioes de um pais' })
  regionTree(@Param('countryId', ParseUUIDPipe) countryId: string) {
    return this.geography.regionTree(countryId);
  }

  @Get('regions/:id')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_READ)
  @ApiOperation({ summary: 'Detalha uma regiao' })
  getRegion(@Param('id', ParseUUIDPipe) id: string) {
    return this.geography.getRegion(id);
  }

  @Post('regions')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_WRITE)
  @Audited({ action: AuditAction.CREATE, entity: 'Region' })
  @ApiOperation({ summary: 'Cadastra uma regiao' })
  createRegion(@Body() dto: CreateRegionDto) {
    return this.geography.createRegion(dto);
  }

  @Patch('regions/:id')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_WRITE)
  @Audited({ action: AuditAction.UPDATE, entity: 'Region', idParam: 'id' })
  @ApiOperation({ summary: 'Atualiza uma regiao' })
  updateRegion(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateRegionDto) {
    return this.geography.updateRegion(id, dto);
  }

  @Delete('regions/:id')
  @RequirePermissions(PERMISSIONS.GEOGRAPHY_WRITE)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Audited({ action: AuditAction.DELETE, entity: 'Region', idParam: 'id' })
  @ApiOperation({ summary: 'Remove (soft delete) uma regiao' })
  removeRegion(@Param('id', ParseUUIDPipe) id: string) {
    return this.geography.removeRegion(id);
  }
}
