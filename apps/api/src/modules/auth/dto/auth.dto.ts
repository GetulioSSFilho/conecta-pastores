import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEmail, IsEnum, IsNotEmpty, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { DevicePlatform } from '@prisma/client';

const PASSWORD_RULE =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{10,}$/;
const PASSWORD_MESSAGE =
  'A senha deve ter ao menos 10 caracteres, com letra maiuscula, minuscula e numero.';

const normalizeEmail = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class LoginDto {
  @ApiProperty({ example: 'admin@pastoral.app' })
  @Transform(normalizeEmail)
  @IsEmail({}, { message: 'E-mail invalido.' })
  @MaxLength(255)
  email!: string;

  @ApiProperty({ example: 'Pastoral@2025' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  password!: string;

  @ApiPropertyOptional({ description: 'Nome amigavel do dispositivo.' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  deviceName?: string;

  @ApiPropertyOptional({ enum: DevicePlatform })
  @IsOptional()
  @IsEnum(DevicePlatform)
  platform?: DevicePlatform;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  refreshToken!: string;
}

export class LogoutDto {
  @ApiPropertyOptional({ description: 'Se true, encerra todas as sessoes do usuario.' })
  @IsOptional()
  allDevices?: boolean;
}

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  currentPassword!: string;

  @ApiProperty({ description: PASSWORD_MESSAGE })
  @IsString()
  @Matches(PASSWORD_RULE, { message: PASSWORD_MESSAGE })
  @MaxLength(128)
  newPassword!: string;
}

export class ForgotPasswordDto {
  @ApiProperty()
  @Transform(normalizeEmail)
  @IsEmail({}, { message: 'E-mail invalido.' })
  @MaxLength(255)
  email!: string;
}

export class ResetPasswordDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  token!: string;

  @ApiProperty({ description: PASSWORD_MESSAGE })
  @IsString()
  @Matches(PASSWORD_RULE, { message: PASSWORD_MESSAGE })
  @MaxLength(128)
  newPassword!: string;
}

// ----------------------------------------------------------------------------
// Respostas
// ----------------------------------------------------------------------------

export class AuthUserDto {
  @ApiProperty() id!: string;
  @ApiProperty() email!: string;
  @ApiProperty() firstName!: string;
  @ApiProperty() lastName!: string;
  @ApiProperty({ nullable: true }) avatarUrl!: string | null;
  @ApiProperty() locale!: string;
  @ApiProperty() timezone!: string;
  @ApiProperty({ nullable: true }) pastorId!: string | null;
  @ApiProperty({ type: [String] }) roles!: string[];
  @ApiProperty({ type: [String] }) permissions!: string[];
  @ApiProperty() mustChangePassword!: boolean;
}

export class AuthTokensDto {
  @ApiProperty() accessToken!: string;
  @ApiProperty() refreshToken!: string;
  @ApiProperty({ description: 'Validade do access token em segundos.' }) expiresIn!: number;
  @ApiProperty() tokenType!: string;
}

export class LoginResponseDto {
  @ApiProperty({ type: AuthTokensDto }) tokens!: AuthTokensDto;
  @ApiProperty({ type: AuthUserDto }) user!: AuthUserDto;
}

export class SessionDto {
  @ApiProperty() id!: string;
  @ApiProperty({ nullable: true }) deviceName!: string | null;
  @ApiProperty({ nullable: true }) platform!: string | null;
  @ApiProperty({ nullable: true }) ip!: string | null;
  @ApiProperty() lastUsedAt!: Date;
  @ApiProperty() createdAt!: Date;
  @ApiProperty() current!: boolean;
}
