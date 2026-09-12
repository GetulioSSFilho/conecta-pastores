import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PastorsService } from './pastors.service';
import { CreatePastorDto, PastorQueryDto, UpdatePastorDto } from './dto/pastor.dto';

/**
 * Perfil 360: cada secao e um endpoint proprio.
 * O Flutter carrega a aba visivel, nao o perfil inteiro.
 */
@ApiTags('Pastores')
@ApiBearerAuth()
@Controller('pastors')
export class PastorsController {
  constructor(private readonly pastors: PastorsService) {}

  @Get()
  @RequirePermissions(PERMISSIONS.PASTOR_READ)
  @ApiOperation({ summary: 'Diretorio de pastores (paginado, filtrado pelo escopo)' })
  list(@CurrentUser() user: AuthenticatedUser, @Query() query: PastorQueryDto) {
    return this.pastors.list(user, query);
  }

  @Post()
  @RequirePermissions(PERMISSIONS.PASTOR_WRITE)
  @ApiOperation({ summary: 'Cadastra um pastor' })
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreatePastorDto) {
    return this.pastors.create(user, dto);
  }

  @Get(':id')
  @RequirePermissions(PERMISSIONS.PASTOR_READ)
  @ApiOperation({ summary: 'Secao RESUMO do perfil 360' })
  summary(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.pastors.summarySection(user, id);
  }

  @Get(':id/ministry')
  @RequirePermissions(PERMISSIONS.PASTOR_READ)
  @ApiOperation({ summary: 'Secao MINISTERIO / IGREJA' })
  ministry(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.pastors.ministrySection(user, id);
  }

  @Get(':id/leadership')
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Secao LIDERANCA (cadeia de supervisao)' })
  leadership(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.pastors.leadershipSection(user, id);
  }

  @Get(':id/network')
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Secao MINHA REDE do pastor' })
  network(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.pastors.networkSection(user, id);
  }

  @Get(':id/history')
  @RequirePermissions(PERMISSIONS.PASTOR_READ, PERMISSIONS.AUDIT_READ)
  @ApiOperation({ summary: 'Secao HISTORICO (auditoria da entidade)' })
  history(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.pastors.historySection(user, id);
  }

  @Patch(':id')
  @RequirePermissions(PERMISSIONS.PASTOR_WRITE)
  @ApiOperation({ summary: 'Atualiza um pastor' })
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePastorDto,
  ) {
    return this.pastors.update(user, id, dto);
  }

  @Delete(':id')
  @RequirePermissions(PERMISSIONS.PASTOR_DELETE)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Desliga um pastor (soft delete)' })
  remove(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.pastors.remove(user, id);
  }
}
