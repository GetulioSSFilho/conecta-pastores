import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { AssignRequestDto, ChangeRequestStatusDto, CreateRequestCommentDto, CreateRequestDto, RequestQueryDto } from './dto/request.dto';
import { RequestsService } from './requests.service';

@ApiTags('Solicitacoes') @ApiBearerAuth() @Controller('requests')
export class RequestsController {
  constructor(private readonly requests: RequestsService) {}
  @Get('categories') @RequirePermissions(PERMISSIONS.REQUEST_READ) @ApiOperation({ summary: 'Lista categorias de solicitacao' }) categories() { return this.requests.categories(); }
  @Get() @RequirePermissions(PERMISSIONS.REQUEST_READ) @ApiOperation({ summary: 'Lista solicitacoes visiveis' }) list(@CurrentUser() user: AuthenticatedUser, @Query() query: RequestQueryDto) { return this.requests.list(user, query); }
  @Get(':id') @RequirePermissions(PERMISSIONS.REQUEST_READ) @ApiOperation({ summary: 'Detalha solicitacao' }) get(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.requests.get(user, id); }
  @Post() @RequirePermissions(PERMISSIONS.REQUEST_WRITE) @ApiOperation({ summary: 'Cria solicitacao' }) create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateRequestDto) { return this.requests.create(user, dto); }
  @Post(':id/comments') @RequirePermissions(PERMISSIONS.REQUEST_WRITE) @ApiOperation({ summary: 'Adiciona comentario' }) comment(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CreateRequestCommentDto) { return this.requests.comment(user, id, dto); }
  @Put(':id/assign') @RequirePermissions(PERMISSIONS.REQUEST_ASSIGN) @ApiOperation({ summary: 'Atribui solicitacao' }) assign(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: AssignRequestDto) { return this.requests.assign(user, id, dto); }
  @Put(':id/status') @RequirePermissions(PERMISSIONS.REQUEST_RESOLVE) @ApiOperation({ summary: 'Atualiza status' }) status(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ChangeRequestStatusDto) { return this.requests.changeStatus(user, id, dto); }
  @Delete(':id') @RequirePermissions(PERMISSIONS.REQUEST_ASSIGN) @HttpCode(HttpStatus.NO_CONTENT) @ApiNoContentResponse() @ApiOperation({ summary: 'Remove solicitacao' }) remove(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.requests.remove(user, id); }
}
