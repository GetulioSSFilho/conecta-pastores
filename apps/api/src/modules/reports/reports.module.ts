import { Module } from '@nestjs/common';
import { ReportsController } from './reports.controller';
import { DashboardService } from './dashboard.service';

/** Modulo reservado para dashboards e relatorios com escopo server-side. */
@Module({ controllers: [ReportsController], providers: [DashboardService] })
export class ReportsModule {}
