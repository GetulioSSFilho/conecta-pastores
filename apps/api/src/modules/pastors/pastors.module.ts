import { Module } from '@nestjs/common';
import { PastorsController } from './pastors.controller';
import { PastorsService } from './pastors.service';

@Module({
  controllers: [PastorsController],
  providers: [PastorsService],
  exports: [PastorsService],
})
export class PastorsModule {}
