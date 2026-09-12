import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/** Hash determinístico usado para indexar tokens opacos (refresh, reset). */
export function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

/** Token opaco url-safe. */
export function randomToken(bytes = 48): string {
  return randomBytes(bytes).toString('base64url');
}

/** Assinatura HMAC-SHA256 url-safe (URLs assinadas de download). */
export function hmacSign(value: string, secret: string): string {
  return createHmac('sha256', secret).update(value).digest('base64url');
}

/** Comparacao resistente a timing attack. */
export function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}
