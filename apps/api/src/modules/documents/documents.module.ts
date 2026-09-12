import { Module } from '@nestjs/common';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';

/** Modulo reservado para documentos no storage S3/MinIO. */
@Module({ controllers: [DocumentsController], providers: [DocumentsService] })
export class DocumentsModule {}
