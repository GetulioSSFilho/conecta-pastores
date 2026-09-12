import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { ChurchesService } from './churches.service';
import {
  ChurchMapQueryDto,
  ChurchQueryDto,
  CreateChurchDto,
  SetLeadPastorDto,
  UpdateChurchDto,
} from './dto/church.dto';

@ApiTags('Igrejas')
@ApiBearerAuth()
@Controller('churches')
export class ChurchesController {
  constructor(private readonly churches: ChurchesService) {}

  // Rota estatica precisa vir antes de ':id' para nao ser capturada por ela.
  @Get('map')
  @RequirePermissions(PERMISSIONS.CHURCH_READ)
  @ApiOperation({ summary: 'Pontos de igrejas com coordenadas, para o mapa mundial' })
  map(@CurrentUser() user: AuthenticatedUser, @Query() query: ChurchMapQueryDto) {
    return this.churches.mapPoints(user, query);
  }

  @Get()
  @RequirePermissions(PERMISSIONS.CHURCH_READ)
  @ApiOperation({ summary: 'Lista igrejas (paginado, filtrado pelo escopo)' })
  list(@CurrentUser() user: AuthenticatedUser, @Query() query: ChurchQueryDto) {
    return this.churches.list(user, query);
  }

  @Get(':id')
  @RequirePermissions(PERMISSIONS.CHURCH_READ)
  @ApiOperation({ summary: 'Detalha uma igreja' })
  getById(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.churches.getById(user, id);
  }

  @Get(':id/pastors')
  @RequirePermissions(PERMISSIONS.CHURCH_READ, PERMISSIONS.PASTOR_READ)
  @ApiOperation({ summary: 'Pastores vinculados a igreja' })
  pastors(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: PaginationQueryDto,
  ) {
    return this.churches.pastorsOfChurch(user, id, query);
  }

  @Post()
  @RequirePermissions(PERMISSIONS.CHURCH_WRITE)
  @ApiOperation({ summary: 'Cadastra uma igreja' })
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateChurchDto) {
    return this.churches.create(user, dto);
  }

  @Patch(':id')
  @RequirePermissions(PERMISSIONS.CHURCH_WRITE)
  @ApiOperation({ summary: 'Atualiza uma igreja' })
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateChurchDto,
  ) {
    return this.churches.update(user, id, dto);
  }

  @Put(':id/lead-pastor')
  @RequirePermissions(PERMISSIONS.CHURCH_WRITE)
  @ApiOperation({ summary: 'Define o pastor responsavel pela igreja' })
  setLeadPastor(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetLeadPastorDto,
  ) {
    return this.churches.setLeadPastor(user, id, dto.pastorId);
  }

  @Delete(':id')
  @RequirePermissions(PERMISSIONS.CHURCH_DELETE)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove (soft delete) uma igreja' })
  remove(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.churches.remove(user, id);
  }
}
