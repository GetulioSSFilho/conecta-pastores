import { Module } from '@nestjs/common';
import { CredentialsController } from './credentials.controller';
import { CredentialsService } from './credentials.service';

/** Modulo reservado para credenciais pastorais e verificacao publica. */
@Module({ controllers: [CredentialsController], providers: [CredentialsService] })
export class CredentialsModule {}
