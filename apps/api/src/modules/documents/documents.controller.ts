import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post, Query, Res, StreamableFile, UploadedFile, UseInterceptors, HttpCode, HttpStatus } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiConsumes, ApiNoContentResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { RequirePermissions } from '../../common/decorators/require-permissions.decorator';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { DocumentQueryDto, UploadDocumentDto } from './dto/document.dto';
import { DocumentsService } from './documents.service';

@ApiTags('Documentos') @ApiBearerAuth() @Controller('documents')
export class DocumentsController {
  constructor(private readonly documents: DocumentsService) {}
  @Get() @RequirePermissions(PERMISSIONS.DOCUMENT_READ) list(@CurrentUser() user: AuthenticatedUser, @Query() query: DocumentQueryDto) { return this.documents.list(user, query); }

  /**
   * Entrega o arquivo de uma URL assinada (driver de storage local).
   *
   * Sem sessao por necessidade: o navegador baixa o arquivo sem cabecalho
   * Authorization. A autorizacao acontece antes, em /documents/:id/download,
   * que so assina o token depois de validar a permissao sobre o documento.
   * Declarada antes de :id para nao cair no ParseUUIDPipe.
   */
  @Get('stream') @Public() @Throttle({ default: { limit: 60, ttl: 60_000 } }) @ApiOperation({ summary: 'Baixa o arquivo de uma URL assinada' })
  async stream(@Query('token') token: string, @Res({ passthrough: true }) res: Response) {
    const file = await this.documents.streamSigned(token);
    res.set({
      'Content-Type': file.mimeType,
      'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(file.filename)}`,
      'Cache-Control': 'private, no-store',
    });
    return new StreamableFile(file.stream);
  }

  @Get(':id/download') @RequirePermissions(PERMISSIONS.DOCUMENT_READ) download(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.documents.download(user, id); }
  @Get(':id') @RequirePermissions(PERMISSIONS.DOCUMENT_READ) get(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.documents.get(user, id); }
  @Post() @RequirePermissions(PERMISSIONS.DOCUMENT_WRITE) @UseInterceptors(FileInterceptor('file')) @ApiConsumes('multipart/form-data') @ApiOperation({ summary: 'Envia documento para o storage' }) upload(@CurrentUser() user: AuthenticatedUser, @Body() dto: UploadDocumentDto, @UploadedFile() file: Express.Multer.File) { return this.documents.upload(user, dto, file); }
  @Delete(':id') @RequirePermissions(PERMISSIONS.DOCUMENT_DELETE) @HttpCode(HttpStatus.NO_CONTENT) @ApiNoContentResponse() remove(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) { return this.documents.remove(user, id); }
}
