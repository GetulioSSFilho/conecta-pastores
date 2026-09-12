import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { MinistryRolesService } from './ministry-roles.service';
import { CreateMinistryRoleDto, UpdateMinistryRoleDto } from './dto/ministry-role.dto';

/**
 * Controller separado (mesmo modulo) porque a funcao ministerial e um
 * catalogo de apoio, nao um sub-recurso de igreja.
 */
@ApiTags('Funcoes Ministeriais')
@ApiBearerAuth()
@Controller('ministry-roles')
export class MinistryRolesController {
  constructor(private readonly ministryRoles: MinistryRolesService) {}

  @Get()
  @ApiOperation({ summary: 'Lista funcoes ministeriais (requer church.write ou geography.read)' })
  list(@CurrentUser() user: AuthenticatedUser, @Query('onlyActive') onlyActive?: string) {
    return this.ministryRoles.list(user, onlyActive === 'true');
  }

  @Get(':id')
  @ApiOperation({ summary: 'Detalha uma funcao ministerial' })
  getById(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.ministryRoles.getById(user, id);
  }

  @Post()
  @RequirePermissions(PERMISSIONS.CHURCH_WRITE)
  @ApiOperation({ summary: 'Cadastra uma funcao ministerial' })
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateMinistryRoleDto) {
    return this.ministryRoles.create(user, dto);
  }

  @Patch(':id')
  @RequirePermissions(PERMISSIONS.CHURCH_WRITE)
  @ApiOperation({ summary: 'Atualiza uma funcao ministerial' })
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMinistryRoleDto,
  ) {
    return this.ministryRoles.update(user, id, dto);
  }
}
