import { Controller, Get, ParseIntPipe, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { DashboardService } from './dashboard.service';

/** Dashboards e indicadores. Todo numero respeita o escopo do usuario. */
@ApiTags('Relatorios')
@ApiBearerAuth()
@Controller('reports')
export class ReportsController {
  constructor(private readonly dashboard: DashboardService) {}

  /** Dados sempre do proprio usuario (pastorId/userId do token): nao exige report.read. */
  @Get('dashboard/pastor')
  @ApiOperation({ summary: 'Dashboard do pastor' })
  pastor(@CurrentUser() user: AuthenticatedUser) {
    return this.dashboard.pastor(user);
  }

  @Get('dashboard/leader')
  @RequirePermissions(PERMISSIONS.REPORT_READ)
  @ApiOperation({ summary: 'Dashboard da lideranca' })
  leader(@CurrentUser() user: AuthenticatedUser) {
    return this.dashboard.leader(user);
  }

  @Get('dashboard/global')
  @RequirePermissions(PERMISSIONS.REPORT_READ_GLOBAL)
  @ApiOperation({ summary: 'Dashboard global dentro do escopo do usuario' })
  global(@CurrentUser() user: AuthenticatedUser) {
    return this.dashboard.global(user);
  }

  @Get('distribution/countries')
  @RequirePermissions(PERMISSIONS.REPORT_READ)
  @ApiOperation({ summary: 'Pastores e igrejas por pais, dentro do escopo' })
  countryDistribution(@CurrentUser() user: AuthenticatedUser) {
    return this.dashboard.countryDistribution(user);
  }

  @Get('care/activity')
  @RequirePermissions(PERMISSIONS.REPORT_READ)
  @ApiQuery({ name: 'weeks', required: false, description: 'Semanas (4-52). Padrao 12.' })
  @ApiOperation({ summary: 'Acompanhamentos realizados por semana, dentro do escopo' })
  careActivity(
    @CurrentUser() user: AuthenticatedUser,
    @Query('weeks', new ParseIntPipe({ optional: true })) weeks?: number,
  ) {
    return this.dashboard.careActivity(user, Math.min(52, Math.max(4, weeks ?? 12)));
  }
}
