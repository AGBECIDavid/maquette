import { describe, expect, it } from 'vitest';
import {
  isProjectLate,
  isRoadblockValidated,
  moduleObtainedCredits,
  moduleStatus,
  projectCredits,
  ratio,
  roadblockStatus,
} from './rules';
import { makeModule, makeProject, makeRoadblock } from './testFixtures';

const TODAY = '2026-09-12';

describe('poids en crédits d’un projet', () => {
  it('partage les crédits du module à parts égales', () => {
    const module = makeModule({ credits: 6 });
    const projects = [makeProject({ id: 'a' }), makeProject({ id: 'b' }), makeProject({ id: 'c' })];
    expect(projectCredits(projects[0]!, module, projects)).toBe(2);
  });

  it('respecte un poids forcé et répartit le reste', () => {
    const module = makeModule({ credits: 6 });
    const projects = [
      makeProject({ id: 'a', creditsOverride: 4 }),
      makeProject({ id: 'b' }),
      makeProject({ id: 'c' }),
    ];
    expect(projectCredits(projects[0]!, module, projects)).toBe(4);
    expect(projectCredits(projects[1]!, module, projects)).toBe(1);
  });

  it('ne distribue rien pour un module sans projet', () => {
    const module = makeModule({ credits: 6 });
    expect(projectCredits(makeProject(), module, [])).toBe(0);
  });
});

describe('crédits obtenus sur un module', () => {
  it('ne compte que les projets validés', () => {
    const module = makeModule({ credits: 6 });
    const projects = [
      makeProject({ id: 'a', status: 'validated' }),
      makeProject({ id: 'b', status: 'done' }),
      makeProject({ id: 'c', status: 'in_progress' }),
    ];
    expect(moduleObtainedCredits(module, projects)).toBe(2);
  });

  it('« terminé » ne rapporte aucun crédit', () => {
    const module = makeModule({ credits: 4 });
    const projects = [makeProject({ id: 'a', status: 'done' }), makeProject({ id: 'b', status: 'done' })];
    expect(moduleObtainedCredits(module, projects)).toBe(0);
  });

  it('rend la totalité quand tous les projets sont validés', () => {
    const module = makeModule({ credits: 7 });
    const projects = [
      makeProject({ id: 'a', status: 'validated' }),
      makeProject({ id: 'b', status: 'validated' }),
      makeProject({ id: 'c', status: 'validated' }),
    ];
    // 7/3 ne tombe pas juste : l'arrondi ne doit pas dépasser le total.
    expect(moduleObtainedCredits(module, projects)).toBe(7);
  });

  it('ne rapporte rien tant qu’un module n’a aucun projet', () => {
    expect(moduleObtainedCredits(makeModule({ credits: 6 }), [])).toBe(0);
  });
});

describe('statut d’un module', () => {
  it('est validé quand tous ses projets le sont', () => {
    const projects = [
      makeProject({ id: 'a', status: 'validated' }),
      makeProject({ id: 'b', status: 'validated' }),
    ];
    expect(moduleStatus(makeModule(), projects, TODAY)).toBe('validated');
  });

  it('est en cours dès qu’un projet a bougé', () => {
    const projects = [makeProject({ id: 'a', status: 'in_progress' }), makeProject({ id: 'b' })];
    expect(moduleStatus(makeModule(), projects, TODAY)).toBe('in_progress');
  });

  it('est en cours si la date du jour tombe dans sa période', () => {
    const module = makeModule({ startDate: '2026-09-01', endDate: '2026-09-30' });
    expect(moduleStatus(module, [makeProject()], TODAY)).toBe('in_progress');
  });

  it('est à venir si rien n’a commencé', () => {
    const module = makeModule({ startDate: '2026-10-01', endDate: '2026-10-30' });
    expect(moduleStatus(module, [makeProject()], TODAY)).toBe('upcoming');
  });

  it('n’est jamais validé sans projet', () => {
    expect(moduleStatus(makeModule(), [], TODAY)).toBe('upcoming');
  });

  it('laisse la main au statut forcé', () => {
    const module = makeModule({ statusOverride: 'failed' });
    const projects = [makeProject({ status: 'validated' })];
    expect(moduleStatus(module, projects, TODAY)).toBe('failed');
  });
});

describe('validation d’un Roadblock', () => {
  const roadblock = makeRoadblock({ requiredCredits: 24 });

  it('n’est pas validé sous le seuil', () => {
    expect(isRoadblockValidated(roadblock, 23.9)).toBe(false);
  });

  it('est validé au seuil exact', () => {
    expect(isRoadblockValidated(roadblock, 24)).toBe(true);
  });

  it('est validé au-delà du seuil', () => {
    expect(isRoadblockValidated(roadblock, 30)).toBe(true);
  });

  it('est non validé si la date de fin est passée sans le seuil', () => {
    const past = makeRoadblock({ requiredCredits: 24, endDate: '2026-08-01' });
    expect(roadblockStatus(past, 12, true, TODAY)).toBe('failed');
  });

  it('reste validé même après la date de fin', () => {
    const past = makeRoadblock({ requiredCredits: 24, endDate: '2026-08-01' });
    expect(roadblockStatus(past, 24, true, TODAY)).toBe('validated');
  });

  it('est à venir tant qu’aucun module n’a démarré', () => {
    const future = makeRoadblock({ startDate: '2026-11-01', endDate: '2027-02-01' });
    expect(roadblockStatus(future, 0, false, TODAY)).toBe('upcoming');
  });
});

describe('progression', () => {
  it('rapporte une part entre 0 et 1', () => {
    expect(ratio(12, 24)).toBe(0.5);
  });

  it('plafonne à 100 % au-delà du requis', () => {
    expect(ratio(30, 24)).toBe(1);
  });

  it('rend « inconnu » plutôt que 0 quand rien n’est requis', () => {
    expect(ratio(0, 0)).toBeNull();
  });
});

describe('retard d’un projet', () => {
  it('est en retard après sa deadline s’il n’est pas rendu', () => {
    expect(isProjectLate(makeProject({ deadline: '2026-09-11' }), TODAY)).toBe(true);
  });

  it('n’est pas en retard le jour même', () => {
    expect(isProjectLate(makeProject({ deadline: TODAY }), TODAY)).toBe(false);
  });

  it('n’est pas en retard une fois rendu', () => {
    const project = makeProject({ deadline: '2026-09-01', status: 'done' });
    expect(isProjectLate(project, TODAY)).toBe(false);
  });

  it('n’est pas en retard sans deadline', () => {
    expect(isProjectLate(makeProject({ deadline: null }), TODAY)).toBe(false);
  });
});
