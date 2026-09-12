import { Module } from '@nestjs/common';
import { TrainingController } from './training.controller';
import { TrainingService } from './training.service';

/** Modulo reservado para formacao, matriculas e certificados. */
@Module({ controllers: [TrainingController], providers: [TrainingService] })
export class TrainingModule {}
