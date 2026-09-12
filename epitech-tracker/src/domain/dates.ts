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

/** Mois ISO d'une date : "2026-09-12" → "2026-09". */
export function monthOf(date: IsoDate): string {
  return date.slice(0, 7);
}

/** Premier jour d'un mois ISO : "2026-09" → "2026-09-01". */
export function startOfMonth(month: string): IsoDate {
  return `${month}-01`;
}

/** Décale un mois ISO : ("2026-09", -1) → "2026-08". */
export function shiftMonth(month: string, delta: number): string {
  const year = Number(month.slice(0, 4));
  const index = Number(month.slice(5, 7)) - 1 + delta;
  const shifted = new Date(Date.UTC(year, index, 1));
  return shifted.toISOString().slice(0, 7);
}

/** Jour de la semaine, lundi = 0 — la semaine française commence au lundi. */
export function weekdayIndex(date: IsoDate): number {
  const day = new Date(`${date}T00:00:00Z`).getUTCDay();
  return (day + 6) % 7;
}

/** "2026-09" → "septembre 2026". */
export function formatMonth(month: string): string {
  const label = new Date(`${month}-01T00:00:00Z`).toLocaleDateString('fr-FR', {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  });
  return label.charAt(0).toUpperCase() + label.slice(1);
}

/** "2026-09-12" → "12/09/2026". Renvoie "—" pour une date inconnue. */
export function formatDate(date: IsoDate | null): string {
  if (date === null) return '—';
  const [y, m, d] = date.split('-');
  return `${d}/${m}/${y}`;
}
