import { Injectable } from '@nestjs/common';
import { Prisma, NotificationType } from '@prisma/client';
import { PageDto } from '../../common/dto/pagination.dto';
import { AppError } from '../../common/errors/app-error';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { PushService } from './push.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import type { NotificationEntry, NotificationQueryDto, RegisterDeviceDto } from './dto/notification.dto';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService, private readonly push: PushService) {}

  async list(user: AuthenticatedUser, query: NotificationQueryDto) {
    const where: Prisma.NotificationWhereInput = {
      userId: user.id,
      ...(query.unreadOnly ? { readAt: null } : {}),
      ...(query.type ? { type: query.type } : {}),
    };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.notification.count({ where }),
      this.prisma.notification.findMany({ where, orderBy: { createdAt: 'desc' }, skip: query.skip, take: query.take }),
    ]);
    return PageDto.of(data, total, query);
  }

  unreadCount(user: AuthenticatedUser) {
    return this.prisma.notification.count({ where: { userId: user.id, readAt: null } }).then((count) => ({ count }));
  }

  async markRead(user: AuthenticatedUser, id: string) {
    const result = await this.prisma.notification.updateMany({ where: { id, userId: user.id }, data: { readAt: new Date() } });
    if (!result.count) throw AppError.notFound('Notificacao nao encontrada.');
  }

  async markAllRead(user: AuthenticatedUser) {
    await this.prisma.notification.updateMany({ where: { userId: user.id, readAt: null }, data: { readAt: new Date() } });
  }

  async remove(user: AuthenticatedUser, id: string) {
    const result = await this.prisma.notification.deleteMany({ where: { id, userId: user.id } });
    if (!result.count) throw AppError.notFound('Notificacao nao encontrada.');
  }

  async registerDevice(user: AuthenticatedUser, dto: RegisterDeviceDto) {
    return this.prisma.notificationDevice.upsert({
      where: { token: dto.token },
      create: { userId: user.id, token: dto.token, platform: dto.platform, deviceName: dto.deviceName, locale: dto.locale ?? 'pt-BR', isActive: true, lastSeenAt: new Date() },
      update: { userId: user.id, platform: dto.platform, deviceName: dto.deviceName, locale: dto.locale ?? 'pt-BR', isActive: true, lastSeenAt: new Date() },
    });
  }

  async removeDevice(user: AuthenticatedUser, token: string) {
    const result = await this.prisma.notificationDevice.updateMany({ where: { token, userId: user.id }, data: { isActive: false } });
    if (!result.count) throw AppError.notFound('Dispositivo nao encontrado.');
  }

  async create(entry: NotificationEntry) {
    const notification = await this.prisma.notification.create({ data: this.toCreateInput(entry) });
    await this.push.sendToUsers([entry.userId], { title: entry.title, body: entry.body, link: entry.link });
    return notification;
  }

  async createMany(entries: NotificationEntry[]) {
    if (!entries.length) return { count: 0 };
    const result = await this.prisma.notification.createMany({ data: entries.map((entry) => this.toCreateInput(entry)) });
    const byUser = new Map<string, NotificationEntry>();
    for (const entry of entries) byUser.set(entry.userId, entry);
    await Promise.all([...byUser.entries()].map(([userId, entry]) => this.push.sendToUsers([userId], { title: entry.title, body: entry.body, link: entry.link })));
    return result;
  }

  private toCreateInput(entry: NotificationEntry): Prisma.NotificationUncheckedCreateInput {
    return { userId: entry.userId, type: entry.type, title: entry.title, body: entry.body, link: entry.link, entity: entry.entity, entityId: entry.entityId, data: entry.data as Prisma.InputJsonValue | undefined };
  }
}
