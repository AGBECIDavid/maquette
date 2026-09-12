/**
 * Passage d'un niveau au suivant, et redoublement.
 *
 * ─────────────────────────────────────────────────────────────────────────
 *  Le passage n'est JAMAIS automatique.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Un étudiant peut redoubler, partir en césure, faire un stage long, changer
 * de campus, ou s'arrêter. Déduire « on est en septembre, donc tu es en
 * TEK2 » ferait prendre à l'application une décision qui ne lui appartient
 * pas — et la première fois qu'elle se trompe, l'étudiant cesse de croire
 * tous les autres chiffres.
 *
 * Ce module ne fait que deux choses : proposer le moment (`isYearOver`) et
 * construire l'année suivante quand l'utilisateur l'a décidé.
 */

import { isAfter } from './dates';
import { nextOrder } from './ordering';
import type { AcademicYear, Id, IsoDate, TekLevel } from './types';
import { TEK_LEVELS } from './types';

/** Le niveau qui suit. `null` au bout de TEK5 : plus rien après. */
export function nextLevel(level: TekLevel | null): TekLevel | null {
  if (level === null) return null;
  const index = TEK_LEVELS.indexOf(level);
  return TEK_LEVELS[index + 1] ?? null;
}

/**
 * Le libellé de l'année suivante, déduit du précédent.
 *
 * "2026-2027" → "2027-2028". On cherche le premier millésime où qu'il soit
 * dans le libellé : « 2026-2027 (exemple) » ou « A1 2026/2027 » doivent
 * s'enchaîner correctement. Sans cela le repli sur l'année civile produirait
 * le MÊME libellé que l'année précédente, et le sélecteur afficherait deux
 * lignes identiques.
 *
 * Un libellé sans aucun millésime n'est pas deviné : on repart de l'année
 * civile plutôt que d'inventer une suite à un texte quelconque.
 */
export function nextYearLabel(previous: string, fallbackYear: number): string {
  const match = /(\d{4})/.exec(previous);
  const start = match === null ? fallbackYear : Number(match[1]) + 1;
  return `${start}-${start + 1}`;
}

/** L'année courante est-elle terminée ? Sert à proposer, pas à décider. */
export function isYearOver(year: AcademicYear | null, today: IsoDate): boolean {
  if (year === null || year.endDate === null) return false;
  return isAfter(today, year.endDate);
}

export interface PromotionInput {
  years: readonly AcademicYear[];
  from: AcademicYear;
  /** Niveau de la nouvelle année : le suivant, ou le même si redoublement. */
  level: TekLevel | null;
  id: Id;
  fallbackYear: number;
}

/**
 * Construit l'année suivante. L'année précédente n'est **pas** modifiée :
 * elle reste consultable telle qu'elle était, avec ses Roadblocks, ses
 * crédits et son statut.
 */
export function buildNextYear(input: PromotionInput): AcademicYear {
  return {
    id: input.id,
    label: nextYearLabel(input.from.label, input.fallbackYear),
    level: input.level,
    order: nextOrder(input.years),
    startDate: null,
    endDate: null,
  };
}

/** Un redoublement, c'est la même chose au même niveau. */
export function buildRepeatYear(
  input: Omit<PromotionInput, 'level'>,
): AcademicYear {
  return buildNextYear({ ...input, level: input.from.level });
}
