import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { AppError } from '../../common/errors/app-error';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { AccessControlService } from '../authorization/access-control.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { HierarchyService } from './hierarchy.service';
import { NetworkService } from './network.service';
import { NetworkQueryDto, SetSupervisorDto } from './dto/network.dto';

@ApiTags('Minha Rede / Hierarquia')
@ApiBearerAuth()
@Controller('network')
export class HierarchyController {
  constructor(
    private readonly hierarchy: HierarchyService,
    private readonly network: NetworkService,
    private readonly acl: AccessControlService,
  ) {}

  @Get()
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Lista plana da rede, com filtros e indicadores' })
  list(@CurrentUser() user: AuthenticatedUser, @Query() query: NetworkQueryDto) {
    return this.network.list(user, query);
  }

  @Get('summary')
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Resumo da rede para o dashboard do lider' })
  summary(@CurrentUser() user: AuthenticatedUser, @Query('rootPastorId') rootPastorId?: string) {
    return this.network.summary(user, rootPastorId);
  }

  @Get('tree')
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Arvore da rede a partir de um pastor' })
  async tree(
    @CurrentUser() user: AuthenticatedUser,
    @Query('rootPastorId') rootPastorId?: string,
    @Query('maxDepth') maxDepth?: string,
  ) {
    const root = rootPastorId ?? user.pastorId;
    if (!root) throw AppError.validation('Informe rootPastorId.');
    await this.acl.assertPastorAccess(user, root, PERMISSIONS.NETWORK_READ);
    return this.hierarchy.tree(root, maxDepth ? Number(maxDepth) : 6);
  }

  @Get(':pastorId/ancestors')
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Cadeia de lideranca acima do pastor' })
  async ancestors(
    @CurrentUser() user: AuthenticatedUser,
    @Param('pastorId', ParseUUIDPipe) pastorId: string,
  ) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.NETWORK_READ);
    return this.hierarchy.ancestors(pastorId);
  }

  @Get(':pastorId/direct-reports')
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Subordinados diretos do pastor' })
  async directReports(
    @CurrentUser() user: AuthenticatedUser,
    @Param('pastorId', ParseUUIDPipe) pastorId: string,
  ) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.NETWORK_READ);
    return this.hierarchy.directReports(pastorId);
  }

  @Get(':pastorId/stats')
  @RequirePermissions(PERMISSIONS.NETWORK_READ)
  @ApiOperation({ summary: 'Metricas da rede do pastor' })
  async stats(
    @CurrentUser() user: AuthenticatedUser,
    @Param('pastorId', ParseUUIDPipe) pastorId: string,
  ) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.NETWORK_READ);
    return this.hierarchy.stats(pastorId);
  }

  @Put(':pastorId/supervisor')
  @RequirePermissions(PERMISSIONS.NETWORK_WRITE)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Define ou remove o supervisor de um pastor' })
  async setSupervisor(
    @CurrentUser() user: AuthenticatedUser,
    @Param('pastorId', ParseUUIDPipe) pastorId: string,
    @Body() dto: SetSupervisorDto,
  ): Promise<void> {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.NETWORK_WRITE);
    if (dto.supervisorId) {
      await this.acl.assertPastorAccess(user, dto.supervisorId, PERMISSIONS.NETWORK_WRITE);
    }
    await this.hierarchy.setSupervisor(pastorId, dto.supervisorId ?? null, user, dto.notes);
  }
}
