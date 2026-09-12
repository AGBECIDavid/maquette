import { describe, expect, it } from 'vitest';
import { buildProjection, measurePace } from './projection';
import { buildView } from './selectors';
import { makeCurriculum, makeModule, makeProject, makeRoadblock } from './testFixtures';

const TODAY = '2026-09-12';

/** Un module de `credits` crédits découpé en projets d'un crédit chacun. */
function curriculumWith(
  required: number,
  projects: { id: string; validatedOn?: string }[],
  extra: Partial<Parameters<typeof makeRoadblock>[0]> = {},
) {
  return makeCurriculum({
    roadblocks: [makeRoadblock({ requiredCredits: required, ...extra })],
    modules: [makeModule({ credits: projects.length })],
    projects: projects.map((p, index) =>
      makeProject({
        id: p.id,
        order: index + 1,
        ...(p.validatedOn === undefined
          ? {}
          : { status: 'validated' as const, completedAt: p.validatedOn }),
      }),
    ),
  });
}

describe('mesure du rythme', () => {
  it('ne mesure rien sans validation datée', () => {
    const view = buildView(curriculumWith(10, [{ id: 'a' }, { id: 'b' }]), TODAY);
    expect(measurePace(view)).toMatchObject({ creditsPerDay: 0, basis: 'none' });
  });

  it('mesure le rythme récent quand il y a eu de l’activité', () => {
    // 2 crédits validés, premier il y a 20 jours : le rythme se rapporte aux
    // 20 jours observés, pas aux 90 jours de la fenêtre.
    const view = buildView(
      curriculumWith(10, [
        { id: 'a', validatedOn: '2026-08-23' },
        { id: 'b', validatedOn: '2026-09-01' },
      ]),
      TODAY,
    );
    const pace = measurePace(view);
    expect(pace.basis).toBe('recent');
    expect(pace.days).toBe(20);
    expect(pace.creditsPerDay).toBeCloseTo(2 / 20, 5);
  });

  it('retombe sur le rythme global quand la fenêtre récente est vide', () => {
    const view = buildView(
      curriculumWith(10, [
        { id: 'a', validatedOn: '2025-01-01' },
        { id: 'b', validatedOn: '2025-03-02' },
      ]),
      TODAY,
    );
    const pace = measurePace(view);
    expect(pace.basis).toBe('overall');
    expect(pace.days).toBe(60);
  });
});

describe('projection d’un Roadblock', () => {
  it('donne une date à partir du rythme mesuré', () => {
    // 2 crédits en 20 jours → 0,1 crédit/jour. Il reste 2 crédits sur 4
    // requis → 20 jours → 02/10/2026.
    const view = buildView(
      curriculumWith(4, [
        { id: 'a', validatedOn: '2026-08-23' },
        { id: 'b', validatedOn: '2026-09-01' },
        { id: 'c' },
        { id: 'd' },
      ]),
      TODAY,
    );
    const [projection] = buildProjection(view).roadblocks;
    expect(projection).toMatchObject({ status: 'projected', date: '2026-10-02', daysAway: 20 });
  });

  it('ne projette rien sur un Roadblock déjà validé', () => {
    const view = buildView(
      curriculumWith(2, [
        { id: 'a', validatedOn: '2026-08-23' },
        { id: 'b', validatedOn: '2026-09-01' },
      ]),
      TODAY,
    );
    expect(buildProjection(view).roadblocks[0]).toMatchObject({ status: 'validated', date: null });
  });

  it('refuse de dater un seuil hors de portée', () => {
    // 20 crédits requis, mais le Roadblock n'en porte que 2 au total.
    const view = buildView(
      curriculumWith(20, [
        { id: 'a', validatedOn: '2026-09-01' },
        { id: 'b' },
      ]),
      TODAY,
    );
    expect(buildProjection(view).roadblocks[0]).toMatchObject({
      status: 'unreachable',
      date: null,
    });
  });

  it('refuse de dater sans rythme mesurable', () => {
    const view = buildView(curriculumWith(4, [{ id: 'a' }, { id: 'b' }, { id: 'c' }, { id: 'd' }]), TODAY);
    expect(buildProjection(view).roadblocks[0]).toMatchObject({ status: 'no_pace', date: null });
  });

  it('compare la date projetée à la date de fin du Roadblock', () => {
    const view = buildView(
      curriculumWith(
        4,
        [
          { id: 'a', validatedOn: '2026-08-23' },
          { id: 'b', validatedOn: '2026-09-01' },
          { id: 'c' },
          { id: 'd' },
        ],
        { endDate: '2026-09-25' },
      ),
      TODAY,
    );
    // Projeté au 02/10 pour une fin au 25/09 : 7 jours de retard.
    expect(buildProjection(view).roadblocks[0]?.vsDeadline).toBe(7);
  });

  it('ne compare rien quand le Roadblock n’a pas de date de fin', () => {
    const view = buildView(
      curriculumWith(4, [
        { id: 'a', validatedOn: '2026-08-23' },
        { id: 'b', validatedOn: '2026-09-01' },
        { id: 'c' },
        { id: 'd' },
      ]),
      TODAY,
    );
    expect(buildProjection(view).roadblocks[0]?.vsDeadline).toBeNull();
  });
});

describe('projection du cursus', () => {
  it('cumule les crédits restants dans l’ordre du cursus', () => {
    // rb1 : 2 crédits restants, rb2 : 6. Au rythme d'1 crédit/jour, rb1 est
    // projeté à 2 jours et rb2 à 8 — pas à 6, qui supposerait que les deux
    // se font en parallèle.
    const view = buildView(
      makeCurriculum({
        roadblocks: [
          makeRoadblock({ id: 'rb1', requiredCredits: 4, order: 1 }),
          makeRoadblock({ id: 'rb2', requiredCredits: 6, order: 2 }),
        ],
        modules: [
          makeModule({ id: 'm1', roadblockId: 'rb1', credits: 4 }),
          makeModule({ id: 'm2', roadblockId: 'rb2', credits: 6 }),
        ],
        projects: [
          makeProject({ id: 'a', moduleId: 'm1', status: 'validated', completedAt: '2026-09-10' }),
          makeProject({ id: 'b', moduleId: 'm1', order: 2 }),
          makeProject({ id: 'c', moduleId: 'm2', order: 3 }),
        ],
      }),
      TODAY,
    );
    const { roadblocks, cursus } = buildProjection(view);
    expect(roadblocks[0]).toMatchObject({ cumulativeCredits: 2, daysAway: 2 });
    expect(roadblocks[1]).toMatchObject({ cumulativeCredits: 8, daysAway: 8 });
    // La dernière date du cursus ne peut pas contredire celle du dernier
    // Roadblock atteignable.
    expect(cursus.daysAway).toBe(roadblocks[1]?.daysAway);
  });

  it('additionne ce qui reste sur tous les Roadblocks', () => {
    const view = buildView(
      makeCurriculum({
        roadblocks: [
          makeRoadblock({ id: 'rb1', requiredCredits: 4, order: 1 }),
          makeRoadblock({ id: 'rb2', requiredCredits: 6, order: 2 }),
        ],
        modules: [
          makeModule({ id: 'm1', roadblockId: 'rb1', credits: 4 }),
          makeModule({ id: 'm2', roadblockId: 'rb2', credits: 6 }),
        ],
        projects: [
          makeProject({ id: 'a', moduleId: 'm1', status: 'validated', completedAt: '2026-09-02' }),
          makeProject({ id: 'b', moduleId: 'm1', order: 2 }),
          makeProject({ id: 'c', moduleId: 'm2', order: 3 }),
        ],
      }),
      TODAY,
    );
    const { cursus } = buildProjection(view);
    expect(cursus.remainingCredits).toBe(8);
    expect(cursus.status).toBe('projected');
  });

  it('n’a plus rien à projeter quand tout est acquis', () => {
    const view = buildView(
      curriculumWith(2, [
        { id: 'a', validatedOn: '2026-08-23' },
        { id: 'b', validatedOn: '2026-09-01' },
      ]),
      TODAY,
    );
    expect(buildProjection(view).cursus).toMatchObject({ status: 'validated', remainingCredits: 0 });
  });
});
