import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { AiCopilotService } from './ai-copilot.service';
import { AiIntentDto } from './dto/ai-intent.dto';

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

  @Post('intent')
  @ApiOperation({ summary: 'Interpreta uma intenção e sugere uma navegação dentro das permissões' })
  intent(@CurrentUser() user: AuthenticatedUser, @Body() dto: AiIntentDto) {
    return this.copilot.navigate(user, dto.message);
  }

  @Post('ask')
  @ApiOperation({ summary: 'Responde uma pergunta com os dados autorizados do usuário ou navega por intenção explícita' })
  ask(@CurrentUser() user: AuthenticatedUser, @Body() dto: AiIntentDto) {
    return this.copilot.ask(user, dto.message);
  }
}
