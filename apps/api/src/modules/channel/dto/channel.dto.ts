import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsArray, IsBoolean, IsEnum, IsISO8601, IsOptional, IsString, IsUUID, MaxLength, MinLength, ValidateNested } from 'class-validator';
import { AudienceType, PostType } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class ChannelQueryDto extends PaginationQueryDto { @ApiPropertyOptional({ enum: PostType }) @IsOptional() @IsEnum(PostType) type?: PostType; @ApiPropertyOptional() @IsOptional() @Transform(({ value }) => value === true || value === 'true' || value === '1') @IsBoolean() pinnedOnly?: boolean; }
export class ChannelAudienceDto {
  @ApiProperty({ enum: AudienceType }) @IsEnum(AudienceType) type!: AudienceType;
  @ApiPropertyOptional({ description: 'Country/Region/Church/MinistryRole/User/Pastor conforme o tipo.' }) @IsOptional() @IsUUID() refId?: string;
}

export class CreateChannelPostDto { @ApiPropertyOptional({ type: [ChannelAudienceDto], description: 'Segmentacao da publicacao. Vazio = todos.' }) @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => ChannelAudienceDto) audiences?: ChannelAudienceDto[]; @ApiProperty({ enum: PostType }) @IsEnum(PostType) type!: PostType; @ApiProperty() @IsString() @MinLength(2) @MaxLength(180) title!: string; @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) summary?: string; @ApiProperty() @IsString() @MinLength(2) @MaxLength(50000) content!: string; @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(1000) coverUrl?: string; @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(1000) videoUrl?: string; @ApiPropertyOptional() @IsOptional() @IsBoolean() isPinned?: boolean; @ApiPropertyOptional() @IsOptional() @IsBoolean() requiresAck?: boolean; @ApiPropertyOptional() @IsOptional() @IsBoolean() allowedComments?: boolean; @ApiPropertyOptional() @IsOptional() @IsISO8601() publishedAt?: string; @ApiPropertyOptional() @IsOptional() @IsISO8601() expiresAt?: string; @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @IsUUID(undefined, { each: true }) audienceUserIds?: string[]; }
