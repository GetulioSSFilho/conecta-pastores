import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsISO8601, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';
import { Confidentiality, RequestPriority, RequestStatus } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class RequestQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: RequestStatus }) @IsOptional() @IsEnum(RequestStatus) status?: RequestStatus;
  @ApiPropertyOptional({ enum: RequestPriority }) @IsOptional() @IsEnum(RequestPriority) priority?: RequestPriority;
  @ApiPropertyOptional({ description: 'Filtra por pastor (exige acesso a ele).' }) @IsOptional() @IsUUID() pastorId?: string;
}

export class CreateRequestDto {
  @ApiProperty() @IsUUID() categoryId!: string;
  @ApiProperty() @IsString() @MinLength(3) @MaxLength(180) subject!: string;
  @ApiProperty() @IsString() @MinLength(3) @MaxLength(10000) description!: string;
  @ApiPropertyOptional({ enum: RequestPriority, default: RequestPriority.NORMAL }) @IsOptional() @IsEnum(RequestPriority) priority?: RequestPriority;
  @ApiPropertyOptional() @IsOptional() @IsUUID() pastorId?: string;
  @ApiPropertyOptional({ enum: Confidentiality, default: Confidentiality.NORMAL }) @IsOptional() @IsEnum(Confidentiality) confidentiality?: Confidentiality;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() dueAt?: string;
}

export class CreateRequestCommentDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(10000) message!: string;
  @ApiPropertyOptional({ default: false }) @IsOptional() @IsBoolean() isInternal = false;
}

export class AssignRequestDto { @ApiPropertyOptional() @IsOptional() @IsUUID() assigneeId?: string; }

export class ChangeRequestStatusDto {
  @ApiProperty({ enum: RequestStatus }) @IsEnum(RequestStatus) status!: RequestStatus;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10000) resolution?: string;
}
