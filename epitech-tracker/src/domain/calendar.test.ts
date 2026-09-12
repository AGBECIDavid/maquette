import { describe, expect, it } from 'vitest';
import { buildEvents, busyMonths, monthGrid } from './calendar';
import { shiftMonth, weekdayIndex } from './dates';
import { buildView } from './selectors';
import { makeCurriculum, makeModule, makeProject } from './testFixtures';

const TODAY = '2026-09-12';

const view = buildView(
  makeCurriculum({
    modules: [makeModule({ startDate: '2026-09-01', endDate: '2026-09-30' })],
    projects: [
      makeProject({ id: 'p1', startDate: '2026-09-05', deadline: '2026-09-20' }),
      makeProject({ id: 'p2', deadline: '2026-09-05', order: 2 }),
      makeProject({ id: 'p3', order: 3 }), // sans aucune date
    ],
  }),
  TODAY,
);

describe('événements', () => {
  const events = buildEvents(view);

  it('produit un événement par date connue', () => {
    // 2 pour le module, 2 pour p1, 1 pour p2, 0 pour p3.
    expect(events).toHaveLength(5);
  });

  it('ignore un projet sans aucune date plutôt que d’inventer', () => {
    expect(events.some((e) => e.target.id === 'p3')).toBe(false);
  });

  it('marque une deadline dépassée comme en retard', () => {
    const late = events.find((e) => e.id === 'pd:p2');
    expect(late?.late).toBe(true);
  });

  it('liste les mois qui portent des événements', () => {
    expect(busyMonths(events)).toEqual(['2026-09']);
  });
});

describe('grille mensuelle', () => {
  const grid = monthGrid('2026-09', buildEvents(view), TODAY);

  it('fait toujours six semaines pleines', () => {
    expect(grid).toHaveLength(42);
  });

  it('commence un lundi', () => {
    expect(weekdayIndex(grid[0]!.date)).toBe(0);
  });

  it('marque les jours des mois voisins', () => {
    // Le 1er septembre 2026 est un mardi : la grille démarre au 31 août.
    expect(grid[0]!.date).toBe('2026-08-31');
    expect(grid[0]!.inMonth).toBe(false);
    expect(grid[1]!.inMonth).toBe(true);
  });

  it('marque aujourd’hui une seule fois', () => {
    expect(grid.filter((day) => day.isToday)).toHaveLength(1);
  });

  it('place chaque événement sur son jour', () => {
    const day = grid.find((d) => d.date === '2026-09-05');
    expect(day?.events.map((e) => e.id).sort()).toEqual(['pd:p2', 'ps:p1']);
  });
});

describe('navigation entre mois', () => {
  it('recule et avance sans déborder sur l’année', () => {
    expect(shiftMonth('2026-01', -1)).toBe('2025-12');
    expect(shiftMonth('2026-12', 1)).toBe('2027-01');
  });
});
