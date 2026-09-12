import { Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Body, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { NotificationsService } from './notifications.service';
import { NotificationQueryDto, RegisterDeviceDto } from './dto/notification.dto';

@ApiTags('Notificacoes')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}
  @Get() @ApiOperation({ summary: 'Lista inbox do usuario' }) list(@CurrentUser() user: AuthenticatedUser, @Query() query: NotificationQueryDto) { return this.notifications.list(user, query); }
  @Get('unread-count') @ApiOperation({ summary: 'Conta notificacoes nao lidas' }) unreadCount(@CurrentUser() user: AuthenticatedUser) { return this.notifications.unreadCount(user); }
  @Post(':id/read') @HttpCode(HttpStatus.NO_CONTENT) @ApiNoContentResponse() @ApiOperation({ summary: 'Marca notificacao como lida' }) read(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.notifications.markRead(user, id); }
  @Post('read-all') @HttpCode(HttpStatus.NO_CONTENT) @ApiNoContentResponse() @ApiOperation({ summary: 'Marca inbox como lido' }) readAll(@CurrentUser() user: AuthenticatedUser) { return this.notifications.markAllRead(user); }
  @Delete(':id') @HttpCode(HttpStatus.NO_CONTENT) @ApiNoContentResponse() @ApiOperation({ summary: 'Remove notificacao' }) remove(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.notifications.remove(user, id); }
  @Post('devices') @ApiOperation({ summary: 'Registra dispositivo para push' }) registerDevice(@CurrentUser() user: AuthenticatedUser, @Body() dto: RegisterDeviceDto) { return this.notifications.registerDevice(user, dto); }
  @Delete('devices/:token') @HttpCode(HttpStatus.NO_CONTENT) @ApiNoContentResponse() @ApiOperation({ summary: 'Desativa dispositivo' }) removeDevice(@CurrentUser() user: AuthenticatedUser, @Param('token') token: string) { return this.notifications.removeDevice(user, token); }
}
