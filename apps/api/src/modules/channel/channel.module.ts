import { Module } from '@nestjs/common';
import { ChannelController } from './channel.controller';
import { ChannelService } from './channel.service';

/** Modulo reservado para o canal institucional dos pastores. */
@Module({ controllers: [ChannelController], providers: [ChannelService] })
export class ChannelModule {}
