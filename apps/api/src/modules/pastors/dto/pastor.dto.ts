import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { MaritalStatus, PastorStatus } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const lower = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class CreatePastorDto {
  @ApiProperty() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) firstName!: string;
  @ApiProperty() @Transform(trim) @IsString() @MinLength(2) @MaxLength(80) lastName!: string;

  @ApiPropertyOptional({ description: 'Como e conhecido. Se ausente, derivado do nome.' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(120)
  pastoralName?: string;

  @ApiPropertyOptional() @IsOptional() @Transform(lower) @IsEmail() @MaxLength(255) email?: string;

  @ApiPropertyOptional({ description: 'Telefone em qualquer formato; normalizado para E.164.' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(30)
  whatsapp?: string;

  @ApiPropertyOptional({ format: 'date' }) @IsOptional() @IsDateString() birthDate?: string;
  @ApiPropertyOptional({ enum: MaritalStatus }) @IsOptional() @IsEnum(MaritalStatus) maritalStatus?: MaritalStatus;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) spouseName?: string;
  @ApiPropertyOptional({ format: 'date' }) @IsOptional() @IsDateString() spouseBirthDate?: string;

  @ApiProperty() @IsUUID() countryId!: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() regionId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(255) address?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) postalCode?: string;

  @ApiPropertyOptional({ default: 'pt-BR' }) @IsOptional() @IsString() @MaxLength(10) locale?: string;
  @ApiPropertyOptional({ default: 'America/Sao_Paulo' }) @IsOptional() @IsString() @MaxLength(60) timezone?: string;

  @ApiPropertyOptional() @IsOptional() @IsUUID() churchId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() ministryRoleId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(80) ministryTitle?: string;

  @ApiPropertyOptional({ format: 'date' }) @IsOptional() @IsDateString() joinedAt?: string;
  @ApiPropertyOptional({ format: 'date' }) @IsOptional() @IsDateString() ordainedAt?: string;

  @ApiPropertyOptional({ enum: PastorStatus, default: PastorStatus.ACTIVE })
  @IsOptional()
  @IsEnum(PastorStatus)
  status?: PastorStatus;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) biography?: string;

  @ApiPropertyOptional({ description: 'Requer permissao pastor.read_admin_notes para ler.' })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  adminNotes?: string;

  @ApiPropertyOptional({ description: 'Supervisor inicial na hierarquia.' })
  @IsOptional()
  @IsUUID()
  supervisorId?: string;

  @ApiPropertyOptional({ description: 'Cria usuario de acesso e envia convite.' })
  @IsOptional()
  @IsBoolean()
  createUserAccount?: boolean;
}

export class UpdatePastorDto extends CreatePastorDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() declare countryId: string;
  @ApiPropertyOptional() @IsOptional() @IsString() declare firstName: string;
  @ApiPropertyOptional() @IsOptional() @IsString() declare lastName: string;
}

export class PastorQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: PastorStatus }) @IsOptional() @IsEnum(PastorStatus) status?: PastorStatus;
  @ApiPropertyOptional() @IsOptional() @IsUUID() countryId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() regionId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() churchId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() ministryRoleId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() supervisorId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) city?: string;

  @ApiPropertyOptional({ description: 'Sem acompanhamento ha N dias ou mais.' })
  @IsOptional()
  @Type(() => Number)
  careOverdueDays?: number;
}

export class PastorSummaryDto {
  @ApiProperty() id!: string;
  @ApiProperty() pastoralName!: string;
  @ApiProperty({ nullable: true }) photoUrl!: string | null;
  @ApiProperty({ enum: PastorStatus }) status!: PastorStatus;
  @ApiProperty({ nullable: true }) ministryTitle!: string | null;
}
