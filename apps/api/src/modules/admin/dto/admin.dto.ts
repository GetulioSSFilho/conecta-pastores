import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsArray, IsEnum, IsInt, IsISO8601, IsOptional, IsString, IsUUID, MaxLength, Min, MinLength } from 'class-validator';
import { ScopeType } from '@prisma/client';

export class CreateRoleDto {
  @ApiProperty() @IsString() @MinLength(2) @MaxLength(60) key!: string;
  @ApiProperty() @IsString() @MinLength(2) @MaxLength(120) name!: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) description?: string;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @Type(() => Number) @IsInt() rank?: number;
  @ApiPropertyOptional({ type: [String], default: [] }) @IsOptional() @IsArray() @IsString({ each: true }) permissionKeys?: string[];
}

export class UpdateRoleDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(2) @MaxLength(120) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) description?: string;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() rank?: number;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @IsString({ each: true }) permissionKeys?: string[];
}

export class ReplaceRolePermissionsDto {
  @ApiProperty({ type: [String] }) @IsArray() @IsString({ each: true }) permissionKeys!: string[];
}

export class ReplaceUserRolesDto {
  @ApiProperty({ type: [String] }) @IsArray() @IsString({ each: true }) roleKeys!: string[];
}

export class CreateScopeDto {
  @ApiProperty({ enum: ScopeType }) @IsEnum(ScopeType) type!: ScopeType;
  @ApiPropertyOptional() @IsOptional() @IsUUID() refId?: string;
  @ApiPropertyOptional({ type: [String], default: [] }) @IsOptional() @IsArray() @IsString({ each: true }) permissionKeys?: string[];
  @ApiPropertyOptional() @IsOptional() @IsISO8601() expiresAt?: string;
}
