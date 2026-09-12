import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { UsersService } from './users.service';
import { CreateUserDto, UpdateMeDto, UpdateUserDto, UserQueryDto } from './dto/user.dto';

@ApiTags('Usuarios')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @RequirePermissions(PERMISSIONS.USER_READ)
  @ApiOperation({ summary: 'Lista usuarios administrativos' })
  list(@Query() query: UserQueryDto) {
    return this.users.list(query);
  }

  @Get('me')
  @ApiOperation({ summary: 'Atualiza os dados basicos do usuario autenticado' })
  me(@CurrentUser() user: AuthenticatedUser) {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      locale: user.locale,
      timezone: user.timezone,
      pastorId: user.pastorId,
    };
  }

  @Get(':id')
  @RequirePermissions(PERMISSIONS.USER_READ)
  @ApiOperation({ summary: 'Detalha um usuario' })
  getById(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.getById(id);
  }

  @Post()
  @RequirePermissions(PERMISSIONS.USER_WRITE)
  @ApiOperation({ summary: 'Cadastra um usuario' })
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateUserDto) {
    return this.users.create(user, dto);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Atualiza os dados basicos do usuario autenticado' })
  updateMe(@CurrentUser() user: AuthenticatedUser, @Body() dto: UpdateMeDto) {
    return this.users.updateMe(user, dto);
  }

  @Patch(':id')
  @RequirePermissions(PERMISSIONS.USER_WRITE)
  @ApiOperation({ summary: 'Atualiza um usuario' })
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserDto,
  ) {
    return this.users.update(user, id, dto);
  }

  @Post(':id/reset-password')
  @RequirePermissions(PERMISSIONS.USER_WRITE)
  @ApiOperation({ summary: 'Gera uma senha temporaria para um usuario' })
  resetPassword(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.users.resetPassword(user, id);
  }

  @Delete(':id')
  @RequirePermissions(PERMISSIONS.USER_WRITE)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiNoContentResponse()
  @ApiOperation({ summary: 'Desativa um usuario' })
  remove(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.users.remove(user, id);
  }
}
