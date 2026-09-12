import { Global, Module } from '@nestjs/common';
import { ReportsModule } from '../reports/reports.module';
import { AiController } from './ai.controller';
import { AiCopilotService } from './ai-copilot.service';
import { NvidiaAiService } from './nvidia-ai.service';

@Global()
@Module({
  imports: [ReportsModule],
  controllers: [AiController],
  providers: [NvidiaAiService, AiCopilotService],
  exports: [NvidiaAiService, AiCopilotService],
})
export class AiModule {}
