import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { CreateEventDto, EventQueryDto, UpdateEventDto } from './dto/event.dto';
import { EventsService } from './events.service';

@ApiTags('Agenda') @ApiBearerAuth() @Controller('events')
export class EventsController { constructor(private readonly events: EventsService) {} @Get() @RequirePermissions(PERMISSIONS.EVENT_READ) list(@CurrentUser() user: AuthenticatedUser, @Query() query: EventQueryDto) { return this.events.list(user, query); } @Get(':id') @RequirePermissions(PERMISSIONS.EVENT_READ) get(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.events.get(user, id); } @Post() @RequirePermissions(PERMISSIONS.EVENT_WRITE) create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateEventDto) { return this.events.create(user, dto); } @Patch(':id') @RequirePermissions(PERMISSIONS.EVENT_WRITE) update(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateEventDto) { return this.events.update(user, id, dto); } @Delete(':id') @RequirePermissions(PERMISSIONS.EVENT_WRITE) @HttpCode(HttpStatus.NO_CONTENT) @ApiNoContentResponse() remove(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.events.remove(user, id); } }
