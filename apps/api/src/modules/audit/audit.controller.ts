import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuditAction } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID } from 'class-validator';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { PaginationQueryDto, PageDto } from '../../common/dto/pagination.dto';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import { PERMISSIONS } from '../authorization/permissions.constants';

class AuditQueryDto extends PaginationQueryDto {
  @IsOptional() @IsEnum(AuditAction) action?: AuditAction;
  @IsOptional() @IsString() entity?: string;
  @IsOptional() @IsUUID() entityId?: string;
  @IsOptional() @IsUUID() userId?: string;
}

@ApiTags('Auditoria')
@ApiBearerAuth()
@Controller('admin/audit')
export class AuditController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @RequirePermissions(PERMISSIONS.AUDIT_READ)
  @ApiOperation({ summary: 'Lista registros de auditoria' })
  @ApiOkResponse({ description: 'Pagina de registros de auditoria.' })
  async list(@Query() query: AuditQueryDto) {
    const where = {
      ...(query.action ? { action: query.action } : {}),
      ...(query.entity ? { entity: query.entity } : {}),
      ...(query.entityId ? { entityId: query.entityId } : {}),
      ...(query.userId ? { userId: query.userId } : {}),
    };

    const [total, data] = await this.prisma.$transaction([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          user: { select: { id: true, firstName: true, lastName: true, email: true } },
        },
      }),
    ]);

    return PageDto.of(data, total, query);
  }
}
