import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { ChannelQueryDto, CreateChannelPostDto } from './dto/channel.dto';
import { ChannelService } from './channel.service';

@ApiTags('Canal') @ApiBearerAuth() @Controller('channel')
export class ChannelController { constructor(private readonly channel: ChannelService) {} @Get() @RequirePermissions(PERMISSIONS.CHANNEL_READ) list(@CurrentUser() user: AuthenticatedUser, @Query() query: ChannelQueryDto) { return this.channel.list(user, query); } @Get(':id') @RequirePermissions(PERMISSIONS.CHANNEL_READ) get(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.channel.get(user, id); } @Post() @RequirePermissions(PERMISSIONS.CHANNEL_WRITE) create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateChannelPostDto) { return this.channel.create(user, dto); } @Post(':id/publish') @RequirePermissions(PERMISSIONS.CHANNEL_PUBLISH) publish(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.channel.publish(user, id); } @Post(':id/read') @RequirePermissions(PERMISSIONS.CHANNEL_READ) read(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body('acknowledged') acknowledged?: boolean) { return this.channel.read(user, id, acknowledged === true); } }
