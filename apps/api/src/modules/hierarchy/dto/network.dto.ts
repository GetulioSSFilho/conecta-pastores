import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsEnum, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { PastorStatus } from '@prisma/client';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

const toBool = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? ['1', 'true', 'yes'].includes(value.toLowerCase()) : value;

export class NetworkQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Raiz da rede. Padrao: pastor do usuario autenticado.' })
  @IsOptional()
  @IsUUID()
  rootPastorId?: string;

  @ApiPropertyOptional({ description: 'Profundidade maxima a partir da raiz.' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  maxDepth?: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @Transform(toBool)
  @IsBoolean()
  includeSelf?: boolean;

  @ApiPropertyOptional({ enum: PastorStatus })
  @IsOptional()
  @IsEnum(PastorStatus)
  status?: PastorStatus;

  @ApiPropertyOptional() @IsOptional() @IsUUID() churchId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() regionId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() countryId?: string;

  @ApiPropertyOptional({ description: 'Somente pastores sem acompanhamento ha N dias ou mais.' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  careOverdueDays?: number;

  @ApiPropertyOptional({ description: 'Somente pastores nunca acompanhados.' })
  @IsOptional()
  @Transform(toBool)
  @IsBoolean()
  neverCared?: boolean;
}

export class SetSupervisorDto {
  @ApiPropertyOptional({ description: 'Novo supervisor. Null remove o vinculo (torna raiz).' })
  @IsOptional()
  @IsUUID()
  supervisorId?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  notes?: string;
}
