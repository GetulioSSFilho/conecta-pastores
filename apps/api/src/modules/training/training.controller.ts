import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Put, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { BulkEnrollDto, CreateTrainingDto, CreateTrainingModuleDto, EnrollTrainingDto, EnrollmentQueryDto, ProgressDto, TrainingQueryDto, UpdateTrainingDto } from './dto/training.dto';
import { TrainingService } from './training.service';

@ApiTags('Formacao') @ApiBearerAuth() @Controller('training')
export class TrainingController {
  constructor(private readonly training: TrainingService) {}
  @Get('catalog') @RequirePermissions(PERMISSIONS.TRAINING_READ) @ApiOperation({ summary: 'Lista treinamentos publicados' }) catalog(@CurrentUser() user: AuthenticatedUser, @Query() query: TrainingQueryDto) { return this.training.catalog(user, query); }
  @Get('enrollments') @RequirePermissions(PERMISSIONS.TRAINING_READ) enrollments(@CurrentUser() user: AuthenticatedUser, @Query() query: EnrollmentQueryDto) { return this.training.enrollments(user, query); }
  @Get('summary/:pastorId') @RequirePermissions(PERMISSIONS.TRAINING_READ) summary(@CurrentUser() user: AuthenticatedUser, @Param('pastorId', ParseUUIDPipe) pastorId: string) { return this.training.summary(user, pastorId); }
  @Get('certificates/:token') @Public() @Throttle({ default: { limit: 30, ttl: 60_000 } }) verify(@Param('token') token: string) { return this.training.verify(token); }
  @Get(':id') @RequirePermissions(PERMISSIONS.TRAINING_READ) get(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.training.get(user, id); }
  @Post() @RequirePermissions(PERMISSIONS.TRAINING_WRITE) create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateTrainingDto) { return this.training.create(user, dto); }
  @Put(':id') @RequirePermissions(PERMISSIONS.TRAINING_WRITE) update(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateTrainingDto) { return this.training.update(user, id, dto); }
  @Post(':id/publish') @RequirePermissions(PERMISSIONS.TRAINING_WRITE) publish(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.training.publish(user, id); }
  @Post(':id/modules') @RequirePermissions(PERMISSIONS.TRAINING_WRITE) addModule(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CreateTrainingModuleDto) { return this.training.addModule(user, id, dto); }
  @Post('enroll') @RequirePermissions(PERMISSIONS.TRAINING_ENROLL) enroll(@CurrentUser() user: AuthenticatedUser, @Body() dto: EnrollTrainingDto) { return this.training.enroll(user, dto); }
  @Post('enrollments') @RequirePermissions(PERMISSIONS.TRAINING_MANAGE_ENROLLMENTS) bulkEnroll(@CurrentUser() user: AuthenticatedUser, @Body() dto: BulkEnrollDto) { return this.training.bulkEnroll(user, dto); }
  @Put('enrollments/:id/progress') @RequirePermissions(PERMISSIONS.TRAINING_ENROLL) progress(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ProgressDto) { return this.training.progress(user, id, dto); }
}
