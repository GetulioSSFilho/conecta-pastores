import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsISO31661Alpha2,
  IsISO31661Alpha3,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
  Min,
} from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class CreateCountryDto {
  @ApiProperty({ example: 'BR', description: 'ISO 3166-1 alpha-2' })
  @IsISO31661Alpha2()
  code!: string;

  @ApiProperty({ example: 'BRA', description: 'ISO 3166-1 alpha-3' })
  @IsISO31661Alpha3()
  code3!: string;

  @ApiProperty({ example: 'Brasil' })
  @IsString()
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  nativeName?: string;

  @ApiProperty({ example: '55' })
  @IsString()
  @MaxLength(6)
  phoneCode!: string;

  @ApiPropertyOptional({ example: 'BRL' })
  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @ApiPropertyOptional({ example: 'pt-BR' })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  defaultLocale?: string;

  @ApiPropertyOptional({ example: 'America/Sao_Paulo' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  defaultTimezone?: string;
}

export class UpdateCountryDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) nativeName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(6) phoneCode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @Length(3, 3) currency?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10) defaultLocale?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(60) defaultTimezone?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isActive?: boolean;
}

export class CreateRegionDto {
  @ApiProperty() @IsUUID() countryId!: string;

  @ApiPropertyOptional({ description: 'Regiao pai, para subdivisoes.' })
  @IsOptional()
  @IsUUID()
  parentId?: string;

  @ApiProperty({ example: 'BR-MG' })
  @IsString()
  @MaxLength(20)
  code!: string;

  @ApiProperty({ example: 'Minas Gerais' })
  @IsString()
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  level?: number;
}

export class UpdateRegionDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) code?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() parentId?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isActive?: boolean;
}

export class RegionQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() countryId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() parentId?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() onlyActive?: boolean;
}
