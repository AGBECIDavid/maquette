import { describe, expect, it } from 'vitest';
import {
  creditsByRoadblock,
  projectStatusDistribution,
  undatedValidatedCredits,
  validatedOverTime,
} from './stats';
import { buildView } from './selectors';
import { makeCurriculum, makeModule, makeProject } from './testFixtures';

const TODAY = '2026-09-12';

describe('crédits par Roadblock', () => {
  const view = buildView(
    makeCurriculum({
      modules: [makeModule({ credits: 6 })],
      projects: [
        makeProject({ id: 'a', status: 'validated' }),
        makeProject({ id: 'b', order: 2 }),
      ],
    }),
    TODAY,
  );

  it('reprend les chiffres du Roadblock sans les recalculer', () => {
    expect(creditsByRoadblock(view)[0]).toMatchObject({
      obtained: 3,
      required: 12,
      reachable: 3,
    });
  });
});

describe('répartition par statut', () => {
  const view = buildView(
    makeCurriculum({
      projects: [
        makeProject({ id: 'a', status: 'validated' }),
        makeProject({ id: 'b', status: 'todo', order: 2 }),
        makeProject({ id: 'c', status: 'todo', order: 3 }),
        makeProject({ id: 'd', status: 'in_progress', order: 4 }),
      ],
    }),
    TODAY,
  );

  it('couvre les quatre statuts dans l’ordre d’avancement', () => {
    expect(projectStatusDistribution(view).map((s) => s.status)).toEqual([
      'validated',
      'done',
      'in_progress',
      'todo',
    ]);
  });

  it('compte et calcule les parts', () => {
    const slices = projectStatusDistribution(view);
    expect(slices.find((s) => s.status === 'todo')).toMatchObject({ count: 2, share: 0.5 });
    expect(slices.find((s) => s.status === 'done')).toMatchObject({ count: 0, share: 0 });
  });

  it('ne divise pas par zéro sans projet', () => {
    const empty = buildView(makeCurriculum({ projects: [] }), TODAY);
    expect(projectStatusDistribution(empty).every((s) => s.share === 0)).toBe(true);
  });
});

describe('validés dans le temps', () => {
  const view = buildView(
    makeCurriculum({
      modules: [makeModule({ credits: 8 })],
      projects: [
        makeProject({ id: 'a', status: 'validated', completedAt: '2026-03-01' }),
        makeProject({ id: 'b', status: 'validated', completedAt: '2026-03-01', order: 2 }),
        makeProject({ id: 'c', status: 'validated', completedAt: '2026-05-10', order: 3 }),
        makeProject({ id: 'd', status: 'validated', completedAt: null, order: 4 }),
      ],
    }),
    TODAY,
  );

  it('cumule et fusionne les projets validés le même jour', () => {
    expect(validatedOverTime(view)).toEqual([
      { date: '2026-03-01', projects: 2, credits: 4 },
      { date: '2026-05-10', projects: 3, credits: 6 },
    ]);
  });

  it('écarte un projet validé sans date et le signale à part', () => {
    expect(undatedValidatedCredits(view)).toBe(2);
  });

  it('fait tomber le cumul juste quand un module est entièrement validé', () => {
    // 7 crédits en trois parts égales : 2,33 × 3 = 6,99. Le dernier projet
    // doit ramener le cumul à 7 exactement, comme le compteur du dashboard.
    const exact = buildView(
      makeCurriculum({
        modules: [makeModule({ credits: 7 })],
        projects: [
          makeProject({ id: 'a', status: 'validated', completedAt: '2026-01-01' }),
          makeProject({ id: 'b', status: 'validated', completedAt: '2026-01-02', order: 2 }),
          makeProject({ id: 'c', status: 'validated', completedAt: '2026-01-03', order: 3 }),
        ],
      }),
      TODAY,
    );
    expect(validatedOverTime(exact).map((p) => p.credits)).toEqual([2.33, 4.66, 7]);
  });
});
