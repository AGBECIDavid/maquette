/**
 * Réordonnancement d'une fratrie.
 *
 * Le rang n'est jamais déduit de la position dans le tableau : il est porté
 * par `order`, et c'est lui qui fait foi. Un déplacement renumérote toute la
 * fratrie de 1 à N, ce qui répare au passage les rangs dupliqués ou troués
 * qu'un import ou une suppression peut laisser.
 */

import type { Id } from './types';

export interface Ordered {
  id: Id;
  order: number;
}

export type Direction = -1 | 1;

/** Trie une fratrie par rang, en départageant les ex æquo par identifiant. */
export function byOrder<T extends Ordered>(items: readonly T[]): T[] {
  return [...items].sort((a, b) => a.order - b.order || (a.id < b.id ? -1 : 1));
}

/**
 * Renumérote de 1 à N **dans l'ordre du tableau reçu**, sans le retrier.
 *
 * C'est volontaire : après un déplacement, c'est la position physique qui
 * porte l'intention, et retrier par l'ancien rang annulerait le déplacement.
 * Pour réparer des rangs dupliqués ou troués, composer : `normalizeOrder(byOrder(items))`.
 */
export function normalizeOrder<T extends Ordered>(items: readonly T[]): T[] {
  return items.map((item, index) => ({ ...item, order: index + 1 }));
}

/**
 * Déplace un élément d'un cran. Aux extrémités, la liste est rendue telle
 * quelle : buter en haut ne doit pas faire redescendre l'élément à la fin.
 */
export function moveItem<T extends Ordered>(
  items: readonly T[],
  id: Id,
  direction: Direction,
): T[] {
  const sorted = byOrder(items);
  const index = sorted.findIndex((item) => item.id === id);
  if (index === -1) return sorted;

  const target = index + direction;
  if (target < 0 || target >= sorted.length) return normalizeOrder(sorted);

  const moved = [...sorted];
  const [item] = moved.splice(index, 1);
  moved.splice(target, 0, item!);
  return normalizeOrder(moved);
}

/** Le rang à donner au prochain élément d'une fratrie. */
export function nextOrder(items: readonly Ordered[]): number {
  return items.reduce((max, item) => Math.max(max, item.order), 0) + 1;
}

export function canMove(
  items: readonly Ordered[],
  id: Id,
  direction: Direction,
): boolean {
  const sorted = byOrder(items);
  const index = sorted.findIndex((item) => item.id === id);
  if (index === -1) return false;
  const target = index + direction;
  return target >= 0 && target < sorted.length;
}
