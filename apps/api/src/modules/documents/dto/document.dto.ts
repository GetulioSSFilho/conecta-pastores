import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsISO8601, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { Confidentiality, DocumentCategory, DocumentVisibility } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class DocumentQueryDto extends PaginationQueryDto { @ApiPropertyOptional({ enum: DocumentCategory }) @IsOptional() @IsEnum(DocumentCategory) category?: DocumentCategory; @ApiPropertyOptional() @IsOptional() @IsUUID() pastorId?: string; }
export class UploadDocumentDto { @ApiProperty() @IsString() @MaxLength(180) title!: string; @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10000) description?: string; @ApiPropertyOptional({ enum: DocumentCategory }) @IsOptional() @IsEnum(DocumentCategory) category?: DocumentCategory; @ApiPropertyOptional({ enum: DocumentVisibility }) @IsOptional() @IsEnum(DocumentVisibility) visibility?: DocumentVisibility; @ApiPropertyOptional({ enum: Confidentiality }) @IsOptional() @IsEnum(Confidentiality) confidentiality?: Confidentiality; @ApiPropertyOptional() @IsOptional() @IsUUID() pastorId?: string; @ApiPropertyOptional() @IsOptional() @IsISO8601() issuedAt?: string; @ApiPropertyOptional() @IsOptional() @IsISO8601() expiresAt?: string; }
