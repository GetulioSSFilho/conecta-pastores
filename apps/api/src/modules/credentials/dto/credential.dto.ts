import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsISO8601, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { CredentialStatus, CredentialType } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class CredentialQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: CredentialStatus }) @IsOptional() @IsEnum(CredentialStatus) status?: CredentialStatus;
  @ApiPropertyOptional() @IsOptional() @IsUUID() pastorId?: string;
}

export class CreateCredentialDto {
  @ApiProperty() @IsUUID() pastorId!: string;
  @ApiProperty() @IsString() @MaxLength(80) number!: string;
  @ApiProperty({ enum: CredentialType }) @IsEnum(CredentialType) type!: CredentialType;
  @ApiProperty() @IsISO8601() issuedAt!: string;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() expiresAt?: string;
}

export class RevokeCredentialDto { @ApiProperty() @IsString() @MaxLength(500) reason!: string; }
