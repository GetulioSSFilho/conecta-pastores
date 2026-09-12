import { Module } from '@nestjs/common';
import { RequestsController } from './requests.controller';
import { RequestsService } from './requests.service';

/** Modulo reservado para a central de solicitacoes. */
@Module({ controllers: [RequestsController], providers: [RequestsService] })
export class RequestsModule {}
