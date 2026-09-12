import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { CreateCredentialDto, CredentialQueryDto, RevokeCredentialDto } from './dto/credential.dto';
import { CredentialsService } from './credentials.service';

@ApiTags('Credenciais') @ApiBearerAuth() @Controller('credentials')
export class CredentialsController {
  constructor(private readonly credentials: CredentialsService) {}
  @Get() @RequirePermissions(PERMISSIONS.CREDENTIAL_READ) @ApiOperation({ summary: 'Lista credenciais' }) list(@CurrentUser() user: AuthenticatedUser, @Query() query: CredentialQueryDto) { return this.credentials.list(user, query); }
  @Get('verify/:token') @Public() @Throttle({ default: { limit: 30, ttl: 60_000 } }) @ApiOperation({ summary: 'Verifica uma credencial publicamente' }) verify(@Param('token') token: string) { return this.credentials.verify(token); }
  @Get(':id') @RequirePermissions(PERMISSIONS.CREDENTIAL_READ) @ApiOperation({ summary: 'Detalha credencial' }) get(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.credentials.get(user, id); }
  @Post() @RequirePermissions(PERMISSIONS.CREDENTIAL_WRITE) @ApiOperation({ summary: 'Emite credencial' }) create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateCredentialDto) { return this.credentials.create(user, dto); }
  @Patch(':id/revoke') @RequirePermissions(PERMISSIONS.CREDENTIAL_REVOKE) @ApiOperation({ summary: 'Revoga credencial' }) revoke(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: RevokeCredentialDto) { return this.credentials.revoke(user, id, dto); }
}
