import { Global, Module } from '@nestjs/common';
import { HierarchyController } from './hierarchy.controller';
import { HierarchyService } from './hierarchy.service';
import { NetworkService } from './network.service';

/** Global: PastorsService e o seed precisam registrar pastores na closure. */
@Global()
@Module({
  controllers: [HierarchyController],
  providers: [HierarchyService, NetworkService],
  exports: [HierarchyService, NetworkService],
})
export class HierarchyModule {}
