import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsEnum, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';
import { CareStatus, Confidentiality } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class CreateCareDto {
  @ApiProperty() @IsUUID() pastorId!: string;
  @ApiProperty() @IsUUID() typeId!: string;

  @ApiProperty({ format: 'date-time', description: 'Sempre em UTC (ISO 8601).' })
  @IsDateString()
  occurredAt!: string;

  @ApiProperty({ description: 'Resumo curto exibido em listas.' })
  @IsString()
  @MaxLength(200)
  summary!: string;

  @ApiPropertyOptional({ description: 'Anotacao completa, sujeita a confidencialidade.' })
  @IsOptional()
  @IsString()
  @MaxLength(8000)
  notes?: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(300) nextAction?: string;
  @ApiPropertyOptional({ format: 'date-time' }) @IsOptional() @IsDateString() nextCareAt?: string;

  @ApiPropertyOptional({ enum: CareStatus, default: CareStatus.DONE })
  @IsOptional()
  @IsEnum(CareStatus)
  status?: CareStatus;

  @ApiPropertyOptional({ enum: Confidentiality, default: Confidentiality.NORMAL })
  @IsOptional()
  @IsEnum(Confidentiality)
  confidentiality?: Confidentiality;

  @ApiPropertyOptional({ description: 'Duracao em minutos.' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1440)
  durationMinutes?: number;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) location?: string;

  @ApiPropertyOptional({ description: 'Responsavel pelo acompanhamento. Padrao: usuario atual.' })
  @IsOptional()
  @IsUUID()
  performedById?: string;
}

export class UpdateCareDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() typeId?: string;
  @ApiPropertyOptional({ format: 'date-time' }) @IsOptional() @IsDateString() occurredAt?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) summary?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(8000) notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(300) nextAction?: string;
  @ApiPropertyOptional({ format: 'date-time' }) @IsOptional() @IsDateString() nextCareAt?: string;
  @ApiPropertyOptional({ enum: CareStatus }) @IsOptional() @IsEnum(CareStatus) status?: CareStatus;
  @ApiPropertyOptional({ enum: Confidentiality }) @IsOptional() @IsEnum(Confidentiality) confidentiality?: Confidentiality;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(1440) durationMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) location?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() performedById?: string;
}

export class CareQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() pastorId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() typeId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() performedById?: string;
  @ApiPropertyOptional({ enum: CareStatus }) @IsOptional() @IsEnum(CareStatus) status?: CareStatus;
  @ApiPropertyOptional({ format: 'date-time' }) @IsOptional() @IsDateString() from?: string;
  @ApiPropertyOptional({ format: 'date-time' }) @IsOptional() @IsDateString() to?: string;
}
