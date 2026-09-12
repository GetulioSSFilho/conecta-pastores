import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { AiCopilotService } from './ai-copilot.service';

@ApiTags('Inteligência Artificial')
@ApiBearerAuth()
@Controller('ai')
export class AiController {
  constructor(private readonly copilot: AiCopilotService) {}

  @Get('copilot')
  @ApiOperation({ summary: 'Sugestões práticas do copiloto pastoral dentro do escopo do usuário' })
  copilotFor(@CurrentUser() user: AuthenticatedUser) {
    return this.copilot.getFor(user);
  }
}
