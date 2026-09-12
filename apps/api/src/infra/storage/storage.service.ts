import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { createReadStream, createWriteStream, existsSync } from 'node:fs';
import { mkdir, stat, unlink } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import { AppConfigService } from '../../config/config.service';
import { AppError, ErrorCode } from '../../common/errors/app-error';
import { hmacSign, safeEqual } from '../../common/utils/crypto.util';

export interface StoredObject {
  key: string;
  bucket: string;
  sizeBytes: number;
  mimeType: string;
}

/**
 * Abstracao de storage compativel com S3/MinIO.
 *
 * Em DEV o driver `local` grava em disco para nao exigir MinIO rodando.
 * A interface e identica: trocar STORAGE_DRIVER=s3 nao muda nenhum service.
 *
 * Regra: a API nunca devolve URL publica direta. Todo download passa por URL
 * assinada de curta duracao, emitida somente apos checagem de permissao.
 */
@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private client?: S3Client;

  constructor(private readonly config: AppConfigService) {}

  async onModuleInit(): Promise<void> {
    const { driver } = this.config.storage;
    if (driver === 's3') {
      this.client = this.buildClient();
      try {
        await this.client.send(new HeadBucketCommand({ Bucket: this.config.storage.bucket }));
        this.logger.log(`Storage S3 pronto (bucket ${this.config.storage.bucket}).`);
      } catch {
        this.logger.warn(
          `Bucket ${this.config.storage.bucket} inacessivel. Uploads falharao ate ser criado.`,
        );
      }
    } else {
      await mkdir(this.localRoot(), { recursive: true });
      this.logger.log(`Storage local em ${this.localRoot()}.`);
    }
  }

  /** Gera chave determinística por dominio: pastors/<id>/documents/<uuid>-<nome>. */
  buildKey(parts: string[], filename: string): string {
    const safe = filename.replace(/[^\w.\-]/g, '_').slice(-120);
    return [...parts, `${randomUUID()}-${safe}`].join('/');
  }

  async upload(
    key: string,
    body: Buffer | Readable,
    mimeType: string,
    sizeBytes: number,
  ): Promise<StoredObject> {
    const bucket = this.config.storage.bucket;

    if (this.config.storage.driver === 's3') {
      await this.s3().send(
        new PutObjectCommand({ Bucket: bucket, Key: key, Body: body, ContentType: mimeType }),
      );
    } else {
      const target = join(this.localRoot(), key);
      await mkdir(dirname(target), { recursive: true });
      if (Buffer.isBuffer(body)) {
        await pipeline(Readable.from(body), createWriteStream(target));
      } else {
        await pipeline(body, createWriteStream(target));
      }
    }

    return { key, bucket, sizeBytes, mimeType };
  }

  /**
   * URL de download temporaria.
   * Chame apenas DEPOIS de validar a permissao do usuario sobre o documento.
   */
  async signedDownloadUrl(key: string, filename?: string): Promise<string> {
    const { driver, bucket, signedUrlTtl } = this.config.storage;

    if (driver === 's3') {
      const command = new GetObjectCommand({
        Bucket: bucket,
        Key: key,
        ...(filename
          ? { ResponseContentDisposition: `attachment; filename="${encodeURIComponent(filename)}"` }
          : {}),
      });
      return getSignedUrl(this.s3(), command, { expiresIn: signedUrlTtl });
    }

    // Driver local: a API emite um link assinado equivalente ao presigned do S3.
    const token = this.signDownloadToken(key, filename);
    return `${this.config.app.publicUrl}/${this.config.app.globalPrefix}/documents/stream?token=${token}`;
  }

  /**
   * Assina um download do driver local.
   *
   * O token carrega apenas a chave do objeto e a expiracao - nunca identidade -
   * e so e emitido depois da checagem de permissao feita no service. Equivale ao
   * presigned URL do S3: quem tem o link baixa, e o link morre em minutos.
   */
  signDownloadToken(key: string, filename?: string): string {
    const expiresAt = Date.now() + this.config.storage.signedUrlTtl * 1000;
    const payload = Buffer.from(JSON.stringify({ k: key, f: filename, e: expiresAt })).toString(
      'base64url',
    );
    return `${payload}.${hmacSign(payload, this.signingSecret())}`;
  }

  /** Valida o token assinado e devolve a chave do objeto. */
  verifyDownloadToken(token: string): { key: string; filename?: string } {
    const [payload, signature] = (token ?? '').split('.');
    if (!payload || !signature) throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Link de download invalido.');
    if (!safeEqual(signature, hmacSign(payload, this.signingSecret()))) {
      throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Link de download invalido.');
    }

    let data: { k: string; f?: string; e: number };
    try {
      data = JSON.parse(Buffer.from(payload, 'base64url').toString()) as typeof data;
    } catch {
      throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Link de download invalido.');
    }

    if (!data.k || !data.e || data.e < Date.now()) {
      throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Link de download expirado.');
    }
    return { key: data.k, filename: data.f };
  }

  private signingSecret(): string {
    const secret = this.config.jwt.accessSecret;
    if (!secret) {
      throw new AppError(ErrorCode.STORAGE_ERROR, 'Assinatura de download indisponivel.', 500);
    }
    return secret;
  }

  /** Stream de leitura. Usado pelo driver local e por geracao de PDFs. */
  async readStream(key: string): Promise<Readable> {
    if (this.config.storage.driver === 's3') {
      const result = await this.s3().send(
        new GetObjectCommand({ Bucket: this.config.storage.bucket, Key: key }),
      );
      return result.Body as Readable;
    }
    const path = join(this.localRoot(), key);
    if (!existsSync(path)) throw AppError.notFound('Arquivo nao encontrado.');
    return createReadStream(path);
  }

  async delete(key: string): Promise<void> {
    try {
      if (this.config.storage.driver === 's3') {
        await this.s3().send(
          new DeleteObjectCommand({ Bucket: this.config.storage.bucket, Key: key }),
        );
      } else {
        const path = join(this.localRoot(), key);
        if (existsSync(path)) await unlink(path);
      }
    } catch (error) {
      this.logger.error({ err: error, key }, 'Falha ao remover objeto do storage');
      throw new AppError(ErrorCode.STORAGE_ERROR, 'Falha ao remover arquivo.', 500);
    }
  }

  async size(key: string): Promise<number> {
    if (this.config.storage.driver === 'local') {
      const info = await stat(join(this.localRoot(), key));
      return info.size;
    }
    const result = await this.s3().send(
      new GetObjectCommand({ Bucket: this.config.storage.bucket, Key: key }),
    );
    return Number(result.ContentLength ?? 0);
  }

  private s3(): S3Client {
    if (!this.client) this.client = this.buildClient();
    return this.client;
  }

  private buildClient(): S3Client {
    const { endpoint, region, accessKey, secretKey, forcePathStyle } = this.config.storage;
    return new S3Client({
      endpoint,
      region,
      forcePathStyle,
      credentials: { accessKeyId: accessKey, secretAccessKey: secretKey },
    });
  }

  private localRoot(): string {
    return resolve(process.cwd(), this.config.storage.localPath);
  }
}
