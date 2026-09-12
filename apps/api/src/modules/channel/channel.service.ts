import { Injectable } from '@nestjs/common';
import { AuditAction, AudienceType, NotificationType, PostStatus, PostType, Prisma } from '@prisma/client';
import { PageDto } from '../../common/dto/pagination.dto';
import { AppError } from '../../common/errors/app-error';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { CreateChannelPostDto, ChannelQueryDto } from './dto/channel.dto';

@Injectable()
export class ChannelService {
  constructor(private readonly prisma: PrismaService, private readonly acl: AccessControlService, private readonly audit: AuditService) {}
  async list(user: AuthenticatedUser, query: ChannelQueryDto) { const now = new Date(); const audienceFilter = await this.audienceFilter(user); const where: Prisma.ChannelPostWhereInput = { deletedAt: null, status: PostStatus.PUBLISHED, OR: [{ expiresAt: null }, { expiresAt: { gte: now } }], ...(query.type ? { type: query.type } : {}), ...(query.pinnedOnly ? { isPinned: true } : {}), audiences: audienceFilter }; const [total, data] = await this.prisma.$transaction([this.prisma.channelPost.count({ where }), this.prisma.channelPost.findMany({ where, orderBy: [{ isPinned: 'desc' }, { publishedAt: 'desc' }], skip: query.skip, take: query.take, select: { id: true, type: true, title: true, summary: true, coverUrl: true, isPinned: true, requiresAck: true, publishedAt: true, expiresAt: true, readCount: true, author: { select: { id: true, firstName: true, lastName: true } }, reads: { where: { userId: user.id }, select: { readAt: true, acknowledgedAt: true } } } })]); return PageDto.of(data.map((post) => ({ ...post, read: post.reads[0] ?? null, reads: undefined })), total, query); }
  async get(user: AuthenticatedUser, id: string) { const audienceFilter = await this.audienceFilter(user); const post = await this.prisma.channelPost.findFirst({ where: { id, deletedAt: null, OR: [{ status: PostStatus.PUBLISHED }, { authorId: user.id }], audiences: audienceFilter }, include: { author: { select: { id: true, firstName: true, lastName: true } }, audiences: true } }); if (!post) throw AppError.notFound('Publicacao nao encontrada.'); return post; }
  async create(user: AuthenticatedUser, dto: CreateChannelPostDto) { this.acl.assert(user, PERMISSIONS.CHANNEL_WRITE); const post = await this.prisma.channelPost.create({ data: { authorId: user.id, type: dto.type, title: dto.title.trim(), summary: dto.summary, content: dto.content, coverUrl: dto.coverUrl, videoUrl: dto.videoUrl, isPinned: dto.isPinned, requiresAck: dto.requiresAck, allowedComments: dto.allowedComments, publishedAt: dto.publishedAt ? new Date(dto.publishedAt) : undefined, expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined, status: dto.publishedAt ? PostStatus.PUBLISHED : PostStatus.DRAFT, audiences: { create: dto.audiences?.length ? dto.audiences.map((a) => ({ type: a.type, refId: a.refId ?? null })) : dto.audienceUserIds?.length ? dto.audienceUserIds.map((refId) => ({ type: AudienceType.USER, refId })) : [{ type: AudienceType.ALL }] } }, include: { audiences: true } }); await this.audit.record({ userId: user.id, action: AuditAction.CREATE, entity: 'ChannelPost', entityId: post.id }); return post; }
  async publish(user: AuthenticatedUser, id: string) { this.acl.assert(user, PERMISSIONS.CHANNEL_PUBLISH); const recipients = await this.resolveRecipients(id);
    const post = await this.prisma.channelPost.update({ where: { id }, data: { status: PostStatus.PUBLISHED, publishedAt: new Date(), audienceCount: recipients.length } });
    if (recipients.length) {
      await this.prisma.notification.createMany({
        data: recipients.map((userId) => ({
          userId,
          type: NotificationType.CHANNEL_POST,
          title: post.type === PostType.URGENT ? 'Aviso urgente' : 'Novo comunicado',
          body: post.title,
          link: `/channel/${post.id}`,
          entity: 'ChannelPost',
          entityId: post.id,
        })),
      });
    } await this.audit.record({ userId: user.id, action: AuditAction.UPDATE, entity: 'ChannelPost', entityId: id, metadata: { operation: 'PUBLISH', recipients: recipients.length } }); return post; }
  async read(user: AuthenticatedUser, id: string, acknowledged = false) { await this.get(user, id); return this.prisma.postRead.upsert({ where: { postId_userId: { postId: id, userId: user.id } }, create: { postId: id, userId: user.id, acknowledgedAt: acknowledged ? new Date() : undefined }, update: { readAt: new Date(), acknowledgedAt: acknowledged ? new Date() : undefined } }); }

  /**
   * Visibilidade do feed: o post aparece quando alguma audiencia casa com o
   * usuario (todos, pessoa, pais, regiao - inclusive regioes acima -, igreja,
   * funcao ministerial ou rede de um lider acima dele).
   */
  private async audienceFilter(user: AuthenticatedUser): Promise<Prisma.ChannelPostAudienceListRelationFilter> {
    const pastor = user.pastorId
      ? await this.prisma.pastor.findUnique({
          where: { id: user.pastorId },
          select: { countryId: true, regionId: true, churchId: true, ministryRoleId: true },
        })
      : null;

    const regionIds: string[] = [];
    let regionId = pastor?.regionId ?? null;
    for (let depth = 0; regionId && depth < 8; depth++) {
      regionIds.push(regionId);
      const parent = await this.prisma.region.findUnique({ where: { id: regionId }, select: { parentId: true } });
      regionId = parent?.parentId ?? null;
    }

    const ancestors = user.pastorId
      ? await this.prisma.pastoralClosure.findMany({ where: { descendantId: user.pastorId }, select: { ancestorId: true } })
      : [];

    const or: Prisma.ChannelPostAudienceWhereInput[] = [
      { type: AudienceType.ALL },
      { type: AudienceType.USER, refId: user.id },
    ];
    if (pastor?.countryId) or.push({ type: AudienceType.COUNTRY, refId: pastor.countryId });
    if (regionIds.length) or.push({ type: AudienceType.REGION, refId: { in: regionIds } });
    if (pastor?.churchId) or.push({ type: AudienceType.CHURCH, refId: pastor.churchId });
    if (pastor?.ministryRoleId) or.push({ type: AudienceType.MINISTRY_ROLE, refId: pastor.ministryRoleId });
    if (ancestors.length) or.push({ type: AudienceType.SUBTREE, refId: { in: ancestors.map((a) => a.ancestorId) } });
    return { some: { OR: or } };
  }

  /** Usuarios alcancados pela publicacao (snapshot de audiencia e notificacoes). */
  private async resolveRecipients(postId: string): Promise<string[]> {
    const audiences = await this.prisma.channelPostAudience.findMany({ where: { postId }, select: { type: true, refId: true } });
    const ids = new Set<string>();
    const pastorFilters: Prisma.PastorWhereInput[] = [];

    for (const audience of audiences) {
      switch (audience.type) {
        case AudienceType.ALL:
          pastorFilters.push({});
          break;
        case AudienceType.USER:
          if (audience.refId) ids.add(audience.refId);
          break;
        case AudienceType.COUNTRY:
          if (audience.refId) pastorFilters.push({ countryId: audience.refId });
          break;
        case AudienceType.REGION:
          if (audience.refId) pastorFilters.push({ OR: [{ regionId: audience.refId }, { region: { parentId: audience.refId } }] });
          break;
        case AudienceType.CHURCH:
          if (audience.refId) pastorFilters.push({ churchId: audience.refId });
          break;
        case AudienceType.MINISTRY_ROLE:
          if (audience.refId) pastorFilters.push({ ministryRoleId: audience.refId });
          break;
        case AudienceType.SUBTREE:
          if (audience.refId) pastorFilters.push({ ancestorsClosure: { some: { ancestorId: audience.refId } } });
          break;
        default:
          break;
      }
    }

    if (pastorFilters.length) {
      const pastors = await this.prisma.pastor.findMany({
        where: { deletedAt: null, userId: { not: null }, OR: pastorFilters },
        select: { userId: true },
      });
      for (const pastor of pastors) if (pastor.userId) ids.add(pastor.userId);
    }
    return [...ids];
  }
}
