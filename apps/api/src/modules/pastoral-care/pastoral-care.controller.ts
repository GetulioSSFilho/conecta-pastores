import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PastoralCareService } from './pastoral-care.service';
import { CareQueryDto, CreateCareDto, UpdateCareDto } from './dto/pastoral-care.dto';

@ApiTags('Cuidado Pastoral')
@ApiBearerAuth()
@Controller('care')
export class PastoralCareController {
  constructor(private readonly care: PastoralCareService) {}

  @Get('types')
  @RequirePermissions(PERMISSIONS.CARE_READ)
  @ApiOperation({ summary: 'Tipos de acompanhamento disponiveis' })
  types() {
    return this.care.types();
  }

  @Get()
  @RequirePermissions(PERMISSIONS.CARE_READ)
  @ApiOperation({ summary: 'Lista acompanhamentos (respeita escopo e confidencialidade)' })
  list(@CurrentUser() user: AuthenticatedUser, @Query() query: CareQueryDto) {
    return this.care.list(user, query);
  }

  @Get('timeline/:pastorId')
  @RequirePermissions(PERMISSIONS.CARE_READ)
  @ApiOperation({ summary: 'Linha do tempo de cuidado de um pastor, com indicadores' })
  timeline(
    @CurrentUser() user: AuthenticatedUser,
    @Param('pastorId', ParseUUIDPipe) pastorId: string,
    @Query('take') take?: string,
  ) {
    return this.care.timeline(user, pastorId, take ? Number(take) : 20);
  }

  @Get(':id')
  @RequirePermissions(PERMISSIONS.CARE_READ)
  @ApiOperation({ summary: 'Detalha um acompanhamento' })
  get(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.care.get(user, id);
  }

  @Post()
  @RequirePermissions(PERMISSIONS.CARE_WRITE)
  @ApiOperation({ summary: 'Registra um acompanhamento' })
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateCareDto) {
    return this.care.create(user, dto);
  }

  @Patch(':id')
  @RequirePermissions(PERMISSIONS.CARE_WRITE)
  @ApiOperation({ summary: 'Atualiza um acompanhamento' })
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCareDto,
  ) {
    return this.care.update(user, id, dto);
  }

  @Delete(':id')
  @RequirePermissions(PERMISSIONS.CARE_DELETE)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove (soft delete) um acompanhamento' })
  remove(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.care.remove(user, id);
  }
}
