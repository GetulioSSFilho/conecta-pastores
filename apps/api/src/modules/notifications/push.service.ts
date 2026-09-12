import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppConfigService } from '../../config/config.service';

export interface PushPayload { title: string; body: string; link?: string; data?: Record<string, string>; }

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  constructor(private readonly prisma: PrismaService, private readonly config: AppConfigService) {}

  async sendToUsers(userIds: string[], payload: PushPayload): Promise<void> {
    if (!this.config.push.enabled) {
      this.logger.debug(`Push desabilitado; notificacao mantida apenas no inbox (${userIds.length} usuarios).`);
      return;
    }
    const devices = await this.prisma.notificationDevice.findMany({
      where: { userId: { in: userIds }, isActive: true },
      select: { id: true, token: true },
    });
    // Firebase Admin nao entra nesta primeira versao para evitar acoplamento de credenciais
    // no processo da API. O ponto de integracao fica isolado e pronto para um adapter FCM.
    this.logger.warn(`FCM habilitado, mas adapter ainda nao configurado (${devices.length} dispositivos).`);
    void payload;
  }
}
