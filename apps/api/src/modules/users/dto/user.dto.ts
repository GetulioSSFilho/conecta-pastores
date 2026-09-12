import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEmail, IsEnum, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';
import { UserStatus } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const lower = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class CreateUserDto {
  @ApiProperty() @Transform(lower) @IsEmail() @MaxLength(255) email!: string;
  @ApiProperty() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) firstName!: string;
  @ApiProperty() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) lastName!: string;

  @ApiPropertyOptional({
    description: 'Se ausente, uma senha temporaria e gerada e mustChangePassword fica true.',
  })
  @IsOptional()
  @IsString()
  password?: string;

  @ApiPropertyOptional({ default: 'pt-BR' }) @IsOptional() @IsString() @MaxLength(10) locale?: string;
  @ApiPropertyOptional({ default: 'America/Sao_Paulo' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  timezone?: string;

  @ApiPropertyOptional({ description: 'Vincula a um cadastro de pastor existente.' })
  @IsOptional()
  @IsUUID()
  pastorId?: string;
}

export class UpdateUserDto {
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) firstName?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) lastName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10) locale?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(60) timezone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) avatarUrl?: string;
  @ApiPropertyOptional({ enum: UserStatus }) @IsOptional() @IsEnum(UserStatus) status?: UserStatus;
}

export class UpdateMeDto {
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) firstName?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) lastName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10) locale?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(60) timezone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) avatarUrl?: string;
}

export class UserQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: UserStatus }) @IsOptional() @IsEnum(UserStatus) status?: UserStatus;
  @ApiPropertyOptional({ description: 'Chave da role, ex: GLOBAL_ADMIN.' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  roleKey?: string;
}
