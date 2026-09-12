import { parsePhoneNumberFromString } from 'libphonenumber-js';

/**
 * Normaliza telefone para E.164. Retorna null quando o numero e invalido.
 */
export function toE164(raw: string | null | undefined, defaultCountry = 'BR'): string | null {
  if (!raw) return null;
  const parsed = parsePhoneNumberFromString(raw, defaultCountry as never);
  return parsed?.isValid() ? parsed.number : null;
}

export function isE164(value: string): boolean {
  return /^\+[1-9]\d{6,14}$/.test(value);
}
