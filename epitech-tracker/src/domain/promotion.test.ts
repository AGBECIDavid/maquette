import { describe, expect, it } from 'vitest';
import { buildNextYear, buildRepeatYear, isYearOver, nextLevel, nextYearLabel } from './promotion';
import { makeYear } from './testFixtures';

const TODAY = '2026-09-12';

describe('niveau suivant', () => {
  it('avance d’un cran', () => {
    expect(nextLevel('TEK1')).toBe('TEK2');
    expect(nextLevel('TEK4')).toBe('TEK5');
  });

  it('n’invente rien après TEK5', () => {
    expect(nextLevel('TEK5')).toBeNull();
  });

  it('ne devine pas le niveau d’une année qui n’en a pas', () => {
    expect(nextLevel(null)).toBeNull();
  });
});

describe('libellé de l’année suivante', () => {
  it('enchaîne une année scolaire', () => {
    expect(nextYearLabel('2026-2027', 2030)).toBe('2027-2028');
    expect(nextYearLabel(' 2029 - 2030 ', 2030)).toBe('2030-2031');
  });

  it('trouve le millésime même suffixé ou décoré', () => {
    // Le libellé du jeu d'exemple porte un suffixe : sans cette recherche,
    // le repli produirait deux années portant exactement le même nom.
    expect(nextYearLabel('2026-2027 (exemple)', 2026)).toBe('2027-2028');
    expect(nextYearLabel('A1 2026/2027', 2026)).toBe('2027-2028');
  });

  it('repart de l’année civile si le libellé ne porte aucun millésime', () => {
    expect(nextYearLabel('Ma première année', 2027)).toBe('2027-2028');
  });

  it('ne reproduit jamais le libellé qu’on lui donne', () => {
    for (const label of ['2026-2027', '2026-2027 (exemple)', 'Première année']) {
      expect(nextYearLabel(label, 2026)).not.toBe(label);
    }
  });
});

describe('fin d’année', () => {
  it('se signale une fois la date de fin passée', () => {
    expect(isYearOver(makeYear({ endDate: '2026-09-01' }), TODAY)).toBe(true);
  });

  it('ne se signale pas le jour même', () => {
    expect(isYearOver(makeYear({ endDate: TODAY }), TODAY)).toBe(false);
  });

  it('ne se signale pas sans date de fin — on ne devine pas', () => {
    expect(isYearOver(makeYear({ endDate: null }), TODAY)).toBe(false);
    expect(isYearOver(null, TODAY)).toBe(false);
  });
});

describe('construction de l’année suivante', () => {
  const from = makeYear({ id: 'y1', label: '2026-2027', level: 'TEK1', order: 1 });
  const years = [from];

  it('crée une année vierge au niveau suivant', () => {
    const next = buildNextYear({ years, from, level: 'TEK2', id: 'y2', fallbackYear: 2027 });
    expect(next).toEqual({
      id: 'y2',
      label: '2027-2028',
      level: 'TEK2',
      order: 2,
      startDate: null,
      endDate: null,
    });
  });

  it('laisse l’année précédente intacte', () => {
    buildNextYear({ years, from, level: 'TEK2', id: 'y2', fallbackYear: 2027 });
    expect(from).toEqual(makeYear({ id: 'y1', label: '2026-2027', level: 'TEK1', order: 1 }));
  });

  it('redouble au même niveau', () => {
    const repeat = buildRepeatYear({ years, from, id: 'y2', fallbackYear: 2027 });
    expect(repeat.level).toBe('TEK1');
    expect(repeat.label).toBe('2027-2028');
  });

  it('se place après la dernière année existante', () => {
    const third = buildNextYear({
      years: [from, makeYear({ id: 'y2', order: 2 })],
      from,
      level: 'TEK2',
      id: 'y3',
      fallbackYear: 2027,
    });
    expect(third.order).toBe(3);
  });
});
