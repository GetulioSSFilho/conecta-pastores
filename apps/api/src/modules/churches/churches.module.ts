import { Module } from '@nestjs/common';
import { ChurchesController } from './churches.controller';
import { ChurchesService } from './churches.service';
import { MinistryRolesController } from './ministry-roles.controller';
import { MinistryRolesService } from './ministry-roles.service';

@Module({
  controllers: [ChurchesController, MinistryRolesController],
  providers: [ChurchesService, MinistryRolesService],
  exports: [ChurchesService, MinistryRolesService],
})
export class ChurchesModule {}
