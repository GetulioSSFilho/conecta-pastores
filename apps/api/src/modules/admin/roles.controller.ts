import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { CreateRoleDto, ReplaceRolePermissionsDto, UpdateRoleDto } from './dto/admin.dto';
import { RolesService } from './roles.service';

@ApiTags('Administracao - Roles')
@ApiBearerAuth()
@Controller('admin/roles')
@RequirePermissions(PERMISSIONS.ROLE_MANAGE)
export class RolesController {
  constructor(private readonly roles: RolesService) {}
  @Get() @ApiOperation({ summary: 'Lista roles' }) list() { return this.roles.list(); }
  @Get('permissions') @ApiOperation({ summary: 'Lista catalogo de permissoes' }) permissions() { return this.roles.permissions(); }
  @Post() @ApiOperation({ summary: 'Cria role' }) create(@CurrentUser() actor: AuthenticatedUser, @Body() dto: CreateRoleDto) { return this.roles.create(actor, dto); }
  @Patch(':id') @ApiOperation({ summary: 'Atualiza role' }) update(@CurrentUser() actor: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateRoleDto) { return this.roles.update(actor, id, dto); }
  @Put(':id/permissions') @ApiOperation({ summary: 'Substitui permissoes da role' }) replacePermissions(@CurrentUser() actor: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReplaceRolePermissionsDto) { return this.roles.replacePermissions(actor, id, dto); }
  @Delete(':id') @HttpCode(204) @ApiNoContentResponse() @ApiOperation({ summary: 'Remove role' }) remove(@CurrentUser() actor: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.roles.remove(actor, id); }
}
