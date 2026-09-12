import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import {
  AuthTokensDto,
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginDto,
  LoginResponseDto,
  LogoutDto,
  RefreshDto,
  ResetPasswordDto,
  SessionDto,
} from './dto/auth.dto';
import type { SessionContext } from './services/session.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';

/** Extrai IP e user-agent para auditoria e vinculo de sessao. */
function contextOf(req: Request): SessionContext {
  return {
    ip: (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ?? req.ip,
    userAgent: req.headers['user-agent'],
  };
}

@ApiTags('Autenticacao')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ auth: { limit: 10, ttl: 300_000 } })
  @ApiOperation({ summary: 'Autentica e emite par de tokens' })
  @ApiOkResponse({ type: LoginResponseDto })
  login(@Body() dto: LoginDto, @Req() req: Request): Promise<LoginResponseDto> {
    return this.auth.login(dto, contextOf(req));
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @Throttle({ auth: { limit: 30, ttl: 300_000 } })
  @ApiOperation({ summary: 'Renova o access token (rotaciona o refresh token)' })
  @ApiOkResponse({ type: AuthTokensDto })
  refresh(@Body() dto: RefreshDto, @Req() req: Request) {
    return this.auth.refresh(dto.refreshToken, contextOf(req));
  }

  @Post('logout')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Encerra a sessao atual ou todas' })
  @ApiNoContentResponse()
  async logout(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: LogoutDto,
    @Req() req: Request,
  ): Promise<void> {
    await this.auth.logout(user, dto.allDevices === true, contextOf(req));
  }

  @Post('change-password')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Troca a senha do usuario autenticado' })
  @ApiNoContentResponse()
  async changePassword(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ChangePasswordDto,
    @Req() req: Request,
  ): Promise<void> {
    await this.auth.changePassword(user, dto, contextOf(req));
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.ACCEPTED)
  @Throttle({ auth: { limit: 5, ttl: 900_000 } })
  @ApiOperation({ summary: 'Solicita recuperacao de senha' })
  forgotPassword(@Body() dto: ForgotPasswordDto, @Req() req: Request) {
    return this.auth.forgotPassword(dto, contextOf(req));
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ auth: { limit: 10, ttl: 900_000 } })
  @ApiOperation({ summary: 'Redefine a senha usando token de recuperacao' })
  @ApiNoContentResponse()
  async resetPassword(@Body() dto: ResetPasswordDto, @Req() req: Request): Promise<void> {
    await this.auth.resetPassword(dto, contextOf(req));
  }

  @Get('me')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Dados do usuario autenticado, com permissoes e escopos' })
  me(@CurrentUser() user: AuthenticatedUser) {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      locale: user.locale,
      timezone: user.timezone,
      pastorId: user.pastorId,
      roles: user.roles,
      permissions: user.permissions,
      scopes: user.scopes,
    };
  }

  @Get('sessions')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Lista sessoes ativas do usuario' })
  @ApiOkResponse({ type: [SessionDto] })
  sessions(@CurrentUser() user: AuthenticatedUser) {
    return this.auth.listSessions(user);
  }

  @Delete('sessions/:id')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Revoga uma sessao especifica' })
  @ApiNoContentResponse()
  async revokeSession(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
  ): Promise<void> {
    await this.auth.revokeSession(user, id);
  }
}
