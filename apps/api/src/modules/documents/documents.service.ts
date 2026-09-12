import { Injectable } from '@nestjs/common';
import { AuditAction, DocumentCategory, DocumentVisibility, Prisma } from '@prisma/client';
import { PageDto } from '../../common/dto/pagination.dto';
import { AppError } from '../../common/errors/app-error';
import { StorageService } from '../../infra/storage/storage.service';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { DocumentQueryDto, UploadDocumentDto } from './dto/document.dto';

@Injectable()
export class DocumentsService {
  constructor(private readonly prisma: PrismaService, private readonly storage: StorageService, private readonly acl: AccessControlService, private readonly audit: AuditService) {}
  async list(user: AuthenticatedUser, query: DocumentQueryDto) { const scope = await this.acl.pastorWhere(user, PERMISSIONS.DOCUMENT_READ); const where: Prisma.DocumentWhereInput = { deletedAt: null, ...(query.category ? { category: query.category } : {}), ...(query.pastorId ? { pastorId: query.pastorId } : {}), OR: [{ uploadedById: user.id }, { pastor: { is: scope } }, { visibility: DocumentVisibility.ADMIN_ONLY, uploadedById: user.id }] }; const [total, data] = await this.prisma.$transaction([this.prisma.document.count({ where }), this.prisma.document.findMany({ where, orderBy: { createdAt: 'desc' }, skip: query.skip, take: query.take, select: { id: true, title: true, description: true, category: true, mimeType: true, sizeBytes: true, visibility: true, confidentiality: true, issuedAt: true, expiresAt: true, pastorId: true, createdAt: true } })]); return PageDto.of(data.map((item) => ({ ...item, sizeBytes: Number(item.sizeBytes) })), total, query); }
  async get(user: AuthenticatedUser, id: string) { const document = await this.prisma.document.findFirst({ where: { id, deletedAt: null }, include: { pastor: { select: { id: true, pastoralName: true } } } }); if (!document) throw AppError.notFound('Documento nao encontrado.'); await this.assertAccess(user, document); return { ...document, sizeBytes: Number(document.sizeBytes) }; }
  async upload(user: AuthenticatedUser, dto: UploadDocumentDto, file: Express.Multer.File) { if (!file) throw AppError.validation('Arquivo obrigatorio.'); const pastorId = dto.pastorId ?? user.pastorId; if (pastorId) await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.DOCUMENT_WRITE); const key = this.storage.buildKey(pastorId ? ['pastors', pastorId, 'documents'] : ['documents'], file.originalname); const stored = await this.storage.upload(key, file.buffer, file.mimetype, file.size); const document = await this.prisma.document.create({ data: { title: dto.title.trim(), description: dto.description, category: dto.category, visibility: dto.visibility, confidentiality: dto.confidentiality, issuedAt: dto.issuedAt ? new Date(dto.issuedAt) : undefined, expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined, pastorId, uploadedById: user.id, storageKey: stored.key, storageBucket: stored.bucket, mimeType: stored.mimeType, sizeBytes: stored.sizeBytes } }); await this.audit.record({ userId: user.id, action: AuditAction.CREATE, entity: 'Document', entityId: document.id }); return { ...document, sizeBytes: Number(document.sizeBytes) }; }
  async download(user: AuthenticatedUser, id: string) { const document = await this.get(user, id); return { url: await this.storage.signedDownloadUrl(document.storageKey, document.title), expiresInSeconds: 300 }; }

  /** Resolve uma URL assinada em um stream. A permissao foi checada na emissao do link. */
  async streamSigned(token: string) {
    const { key, filename } = this.storage.verifyDownloadToken(token);
    const document = await this.prisma.document.findFirst({ where: { storageKey: key, deletedAt: null }, select: { mimeType: true, title: true } });
    if (!document) throw AppError.notFound('Documento nao encontrado.');
    const extension = key.includes('.') ? key.slice(key.lastIndexOf('.')) : '';
    const base = filename ?? document.title;
    return { stream: await this.storage.readStream(key), mimeType: document.mimeType, filename: base.endsWith(extension) ? base : `${base}${extension}` };
  }
  async remove(user: AuthenticatedUser, id: string) { this.acl.assert(user, PERMISSIONS.DOCUMENT_DELETE); const document = await this.prisma.document.findFirst({ where: { id, deletedAt: null }, select: { id: true, storageKey: true, pastorId: true, uploadedById: true } }); if (!document) throw AppError.notFound('Documento nao encontrado.'); if (document.uploadedById !== user.id && document.pastorId) await this.acl.assertPastorAccess(user, document.pastorId, PERMISSIONS.DOCUMENT_DELETE); await this.prisma.document.update({ where: { id }, data: { deletedAt: new Date() } }); await this.storage.delete(document.storageKey); await this.audit.record({ userId: user.id, action: AuditAction.DELETE, entity: 'Document', entityId: id }); }
  private async assertAccess(user: AuthenticatedUser, document: { uploadedById: string; pastorId: string | null; visibility: DocumentVisibility }) { if (document.uploadedById === user.id) return; if (document.visibility === DocumentVisibility.ADMIN_ONLY) throw AppError.forbidden(); if (!document.pastorId) throw AppError.forbidden(); await this.acl.assertPastorAccess(user, document.pastorId, PERMISSIONS.DOCUMENT_READ); }
}
