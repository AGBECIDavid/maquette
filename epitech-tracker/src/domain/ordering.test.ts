import { describe, expect, it } from 'vitest';
import { byOrder, canMove, moveItem, nextOrder, normalizeOrder } from './ordering';

const list = [
  { id: 'a', order: 1 },
  { id: 'b', order: 2 },
  { id: 'c', order: 3 },
];

describe('réordonnancement', () => {
  it('descend un élément d’un cran', () => {
    expect(moveItem(list, 'a', 1).map((i) => i.id)).toEqual(['b', 'a', 'c']);
  });

  it('remonte un élément d’un cran', () => {
    expect(moveItem(list, 'c', -1).map((i) => i.id)).toEqual(['a', 'c', 'b']);
  });

  it('ne fait pas boucler un élément aux extrémités', () => {
    expect(moveItem(list, 'a', -1).map((i) => i.id)).toEqual(['a', 'b', 'c']);
    expect(moveItem(list, 'c', 1).map((i) => i.id)).toEqual(['a', 'b', 'c']);
  });

  it('renumérote de 1 à N après déplacement', () => {
    expect(moveItem(list, 'a', 1).map((i) => i.order)).toEqual([1, 2, 3]);
  });

  it('ignore un identifiant inconnu sans casser la liste', () => {
    expect(moveItem(list, 'zzz', 1).map((i) => i.id)).toEqual(['a', 'b', 'c']);
  });

  it('renumérote sans retrier : la position reçue fait foi', () => {
    const shuffled = [
      { id: 'c', order: 3 },
      { id: 'a', order: 1 },
    ];
    expect(normalizeOrder(shuffled)).toEqual([
      { id: 'c', order: 1 },
      { id: 'a', order: 2 },
    ]);
  });

  it('répare des rangs dupliqués ou troués une fois trié', () => {
    const broken = [
      { id: 'x', order: 7 },
      { id: 'y', order: 7 },
      { id: 'z', order: 0 },
    ];
    expect(normalizeOrder(byOrder(broken))).toEqual([
      { id: 'z', order: 1 },
      { id: 'x', order: 2 },
      { id: 'y', order: 3 },
    ]);
  });

  it('départage deux rangs égaux de façon stable', () => {
    const tied = [
      { id: 'b', order: 1 },
      { id: 'a', order: 1 },
    ];
    expect(byOrder(tied).map((i) => i.id)).toEqual(['a', 'b']);
  });

  it('donne le rang suivant, même après une suppression', () => {
    expect(nextOrder(list)).toBe(4);
    expect(nextOrder([{ id: 'a', order: 9 }])).toBe(10);
    expect(nextOrder([])).toBe(1);
  });

  it('sait si un déplacement est possible', () => {
    expect(canMove(list, 'a', -1)).toBe(false);
    expect(canMove(list, 'a', 1)).toBe(true);
    expect(canMove(list, 'c', 1)).toBe(false);
  });
});
