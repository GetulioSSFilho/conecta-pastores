import { Module } from '@nestjs/common';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';

/** Modulo reservado para agenda e eventos. */
@Module({ controllers: [EventsController], providers: [EventsService] })
export class EventsModule {}
