import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MaxLength,
} from 'class-validator';
import { ChurchStatus, ChurchType } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toUpperCase() : value;

export class CreateChurchDto {
  @ApiProperty({ example: 'BR-SP-001', description: 'Codigo unico da igreja.' })
  @Transform(upper)
  @IsString()
  @MaxLength(40)
  code!: string;

  @ApiProperty() @Transform(trim) @IsString() @MaxLength(160) name!: string;

  @ApiPropertyOptional({ enum: ChurchType, default: ChurchType.MAIN })
  @IsOptional()
  @IsEnum(ChurchType)
  type?: ChurchType;

  @ApiPropertyOptional({ enum: ChurchStatus, default: ChurchStatus.ACTIVE })
  @IsOptional()
  @IsEnum(ChurchStatus)
  status?: ChurchStatus;

  @ApiPropertyOptional({ description: 'Igreja sede, quando esta for campus/congregacao.' })
  @IsOptional()
  @IsUUID()
  parentId?: string;

  @ApiProperty() @IsUUID() countryId!: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() regionId?: string;

  @ApiProperty() @Transform(trim) @IsString() @MaxLength(120) city!: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(255) address?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) postalCode?: string;

  @ApiPropertyOptional({ description: 'Latitude decimal, para o mapa mundial.' })
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional({ description: 'Longitude decimal, para o mapa mundial.' })
  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;

  @ApiPropertyOptional({ description: 'Telefone em qualquer formato; normalizado para E.164.' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @ApiPropertyOptional() @IsOptional() @IsEmail() @MaxLength(255) email?: string;
  @ApiPropertyOptional({ default: 'America/Sao_Paulo' }) @IsOptional() @IsString() @MaxLength(60) timezone?: string;

  @ApiPropertyOptional({ format: 'date' }) @IsOptional() @IsDateString() foundedAt?: string;

  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(0) membersEstimate?: number;
}

export class UpdateChurchDto {
  @ApiPropertyOptional() @IsOptional() @Transform(upper) @IsString() @MaxLength(40) code?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(160) name?: string;
  @ApiPropertyOptional({ enum: ChurchType }) @IsOptional() @IsEnum(ChurchType) type?: ChurchType;
  @ApiPropertyOptional({ enum: ChurchStatus }) @IsOptional() @IsEnum(ChurchStatus) status?: ChurchStatus;

  @ApiPropertyOptional({ description: 'Enviar null para desvincular da igreja sede.' })
  @IsOptional()
  @IsUUID()
  parentId?: string;

  @ApiPropertyOptional() @IsOptional() @IsUUID() countryId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() regionId?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(120) city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(255) address?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) postalCode?: string;

  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsLatitude() latitude?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsLongitude() longitude?: number;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(30) phone?: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() @MaxLength(255) email?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(60) timezone?: string;
  @ApiPropertyOptional({ format: 'date' }) @IsOptional() @IsDateString() foundedAt?: string;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(0) membersEstimate?: number;
}

export class ChurchQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() countryId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() regionId?: string;
  @ApiPropertyOptional({ enum: ChurchStatus }) @IsOptional() @IsEnum(ChurchStatus) status?: ChurchStatus;
  @ApiPropertyOptional({ enum: ChurchType }) @IsOptional() @IsEnum(ChurchType) type?: ChurchType;
  @ApiPropertyOptional({ description: 'Filtra por igreja sede.' }) @IsOptional() @IsUUID() parentId?: string;
}

export class ChurchMapQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() countryId?: string;
}

export class SetLeadPastorDto {
  @ApiProperty() @IsUUID() pastorId!: string;
}
