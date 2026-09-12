import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { DevicePlatform, NotificationType } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class NotificationQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ default: false }) @IsOptional() @Transform(({ value }) => value === true || value === 'true' || value === '1') @IsBoolean() unreadOnly = false;
  @ApiPropertyOptional({ enum: NotificationType }) @IsOptional() @IsEnum(NotificationType) type?: NotificationType;
}

export class RegisterDeviceDto {
  @ApiProperty() @IsString() @MaxLength(500) token!: string;
  @ApiProperty({ enum: DevicePlatform }) @IsEnum(DevicePlatform) platform!: DevicePlatform;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) deviceName?: string;
  @ApiPropertyOptional({ default: 'pt-BR' }) @IsOptional() @IsString() @MaxLength(10) locale?: string;
}

export interface NotificationEntry {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  link?: string;
  entity?: string;
  entityId?: string;
  data?: Record<string, unknown>;
}
