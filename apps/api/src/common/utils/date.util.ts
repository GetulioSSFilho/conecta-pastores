const MS_PER_DAY = 86_400_000;

/** Dias inteiros decorridos entre `from` e agora (UTC). */
export function daysSince(from: Date | null | undefined, now: Date = new Date()): number | null {
  if (!from) return null;
  return Math.floor((now.getTime() - from.getTime()) / MS_PER_DAY);
}

/** Dias inteiros restantes ate `to` (UTC). Negativo = atrasado. */
export function daysUntil(to: Date | null | undefined, now: Date = new Date()): number | null {
  if (!to) return null;
  return Math.ceil((to.getTime() - now.getTime()) / MS_PER_DAY);
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * MS_PER_DAY);
}

export function startOfUtcDay(date: Date = new Date()): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
