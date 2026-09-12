import { Module } from '@nestjs/common';
import { RolesController } from './roles.controller';
import { ScopesController } from './scopes.controller';
import { RolesService } from './roles.service';
import { ScopesService } from './scopes.service';

@Module({
  controllers: [RolesController, ScopesController],
  providers: [RolesService, ScopesService],
})
export class AdminModule {}
