import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { CreateScopeDto, ReplaceUserRolesDto } from './dto/admin.dto';
import { ScopesService } from './scopes.service';

@ApiTags('Administracao - Escopos')
@ApiBearerAuth()
@Controller('admin/scopes')
@RequirePermissions(PERMISSIONS.SCOPE_MANAGE)
export class ScopesController {
  constructor(private readonly scopes: ScopesService) {}
  @Get('users/:userId') @ApiOperation({ summary: 'Consulta roles e escopos do usuario' }) access(@Param('userId', ParseUUIDPipe) userId: string) { return this.scopes.userAccess(userId); }
  @Put('users/:userId/roles') @ApiOperation({ summary: 'Substitui roles do usuario' }) roles(@CurrentUser() actor: AuthenticatedUser, @Param('userId', ParseUUIDPipe) userId: string, @Body() dto: ReplaceUserRolesDto) { return this.scopes.replaceRoles(actor, userId, dto); }
  @Post('users/:userId/scopes') @ApiOperation({ summary: 'Concede escopo ao usuario' }) grant(@CurrentUser() actor: AuthenticatedUser, @Param('userId', ParseUUIDPipe) userId: string, @Body() dto: CreateScopeDto) { return this.scopes.grant(actor, userId, dto); }
  @Delete('scopes/:scopeId') @HttpCode(204) @ApiNoContentResponse() @ApiOperation({ summary: 'Revoga escopo' }) revoke(@CurrentUser() actor: AuthenticatedUser, @Param('scopeId', ParseUUIDPipe) scopeId: string) { return this.scopes.revoke(actor, scopeId); }
}
