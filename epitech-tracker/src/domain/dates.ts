/**
 * Arithmétique sur des dates civiles ISO ("2026-09-12").
 *
 * Volontairement sans dépendance : les seules opérations dont le suivi a
 * besoin sont « combien de jours entre ces deux dates » et « laquelle vient
 * avant ». Les calculs passent par UTC en interne pour qu'un changement
 * d'heure d'été ne fasse pas apparaître ou disparaître un jour.
 */

import type { IsoDate } from './types';

const MS_PER_DAY = 86_400_000;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

export function isValidIsoDate(value: string): boolean {
  if (!ISO_DATE.test(value)) return false;
  const time = Date.parse(`${value}T00:00:00Z`);
  if (Number.isNaN(time)) return false;
  // Rejette les dates qui se décalent (31/02 devient 03/03).
  return new Date(time).toISOString().slice(0, 10) === value;
}

function toUtcMs(date: IsoDate): number {
  const time = Date.parse(`${date}T00:00:00Z`);
  if (Number.isNaN(time)) throw new Error(`Date ISO invalide : ${date}`);
  return time;
}

/** Jours de `from` vers `to`. Négatif si `to` est dans le passé. */
export function daysBetween(from: IsoDate, to: IsoDate): number {
  return Math.round((toUtcMs(to) - toUtcMs(from)) / MS_PER_DAY);
}

export function isBefore(a: IsoDate, b: IsoDate): boolean {
  return toUtcMs(a) < toUtcMs(b);
}

export function isAfter(a: IsoDate, b: IsoDate): boolean {
  return toUtcMs(a) > toUtcMs(b);
}

/** `date` est-elle dans [start, end] ? Une borne `null` ne contraint pas. */
export function isWithin(
  date: IsoDate,
  start: IsoDate | null,
  end: IsoDate | null,
): boolean {
  if (start !== null && isBefore(date, start)) return false;
  if (end !== null && isAfter(date, end)) return false;
  return true;
}

export function addDays(date: IsoDate, days: number): IsoDate {
  return new Date(toUtcMs(date) + days * MS_PER_DAY).toISOString().slice(0, 10);
}

/** Aujourd'hui, dans le fuseau de l'utilisateur. Le seul appel à l'horloge. */
export function today(): IsoDate {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

/** "2026-09-12" → "12/09/2026". Renvoie "—" pour une date inconnue. */
export function formatDate(date: IsoDate | null): string {
  if (date === null) return '—';
  const [y, m, d] = date.split('-');
  return `${d}/${m}/${y}`;
}
