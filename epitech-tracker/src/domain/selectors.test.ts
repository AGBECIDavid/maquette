import { describe, expect, it } from 'vitest';
import { buildView, dashboardStats } from './selectors';
import { makeCurriculum, makeModule, makeProject, makeRoadblock } from './testFixtures';
import { mockCurriculum } from '../data/mock';

const TODAY = '2026-09-12';

function twoRoadblockCurriculum() {
  return makeCurriculum({
    roadblocks: [
      makeRoadblock({ id: 'rb1', requiredCredits: 12, order: 1 }),
      makeRoadblock({ id: 'rb2', name: 'Roadblock 2', requiredCredits: 12, order: 2 }),
    ],
    modules: [
      makeModule({ id: 'm1', roadblockId: 'rb1', credits: 6 }),
      makeModule({ id: 'm2', roadblockId: 'rb1', credits: 6, order: 2 }),
      makeModule({ id: 'm3', roadblockId: 'rb2', credits: 12 }),
    ],
    projects: [
      makeProject({ id: 'p1', moduleId: 'm1', status: 'validated' }),
      makeProject({ id: 'p2', moduleId: 'm1', status: 'validated', order: 2 }),
      makeProject({ id: 'p3', moduleId: 'm2', status: 'validated' }),
      makeProject({ id: 'p4', moduleId: 'm2', status: 'todo', order: 2 }),
      makeProject({ id: 'p5', moduleId: 'm3', status: 'todo' }),
    ],
  });
}

describe('construction de l’arbre', () => {
  const view = buildView(twoRoadblockCurriculum(), TODAY);

  it('remonte les crédits des projets vers le module', () => {
    const m2 = view.modules.find((m) => m.id === 'm2')!;
    expect(m2.obtainedCredits).toBe(3);
    expect(m2.remainingCredits).toBe(3);
    expect(m2.progress).toBe(0.5);
  });

  it('remonte les crédits des modules vers le Roadblock', () => {
    const rb1 = view.roadblocks.find((r) => r.id === 'rb1')!;
    expect(rb1.obtainedCredits).toBe(9);
    expect(rb1.remainingCredits).toBe(3);
    expect(rb1.validatedModules).toBe(1);
    expect(rb1.totalModules).toBe(2);
    expect(rb1.status).toBe('in_progress');
  });

  it('calcule les crédits encore atteignables dans le Roadblock', () => {
    const rb1 = view.roadblocks.find((r) => r.id === 'rb1')!;
    expect(rb1.reachableCredits).toBe(3);
  });

  it('rattache chaque projet à son module et à son Roadblock', () => {
    const p5 = view.projects.find((p) => p.id === 'p5')!;
    expect(p5.moduleName).toBe('Module 1');
    expect(p5.roadblockId).toBe('rb2');
  });
});

describe('compteurs du dashboard', () => {
  const stats = dashboardStats(buildView(twoRoadblockCurriculum(), TODAY));

  it('additionne les crédits obtenus et requis', () => {
    expect(stats.credits).toEqual({ obtained: 9, total: 24, remaining: 15 });
  });

  it('compte les modules validés et en cours', () => {
    expect(stats.modules.validated).toBe(1);
    expect(stats.modules.total).toBe(3);
  });

  it('compte les projets rendus, corrigés ou non', () => {
    expect(stats.projects).toEqual({ done: 3, total: 5, remaining: 2 });
  });

  it('donne la progression globale en crédits', () => {
    expect(stats.progress).toBe(9 / 24);
  });
});

describe('deadlines', () => {
  const data = makeCurriculum({
    projects: [
      makeProject({ id: 'late', deadline: '2026-09-05' }),
      makeProject({ id: 'soon', deadline: '2026-09-15', order: 2 }),
      makeProject({ id: 'far', deadline: '2026-12-01', order: 3 }),
      makeProject({ id: 'done', deadline: '2026-09-01', status: 'done', order: 4 }),
    ],
  });
  const view = buildView(data, TODAY);
  const byId = (id: string) => view.projects.find((p) => p.id === id)!;

  it('compte les jours restants, négatifs si dépassés', () => {
    expect(byId('late').daysLeft).toBe(-7);
    expect(byId('soon').daysLeft).toBe(3);
  });

  it('signale les projets en retard', () => {
    expect(byId('late').isLate).toBe(true);
    expect(byId('done').isLate).toBe(false);
  });

  it('signale les deadlines proches selon le réglage', () => {
    expect(byId('soon').isDueSoon).toBe(true);
    expect(byId('far').isDueSoon).toBe(false);
    expect(byId('late').isDueSoon).toBe(false);
  });

  it('remonte les compteurs au dashboard', () => {
    const stats = dashboardStats(view);
    expect(stats.lateProjects).toBe(1);
    expect(stats.dueSoonProjects).toBe(1);
  });
});

describe('jeu de données d’exemple', () => {
  const data = mockCurriculum(TODAY);
  const view = buildView(data, TODAY);

  it('est marqué comme mocké', () => {
    expect(data.settings.source).toBe('mock');
  });

  it('produit un cursus cohérent', () => {
    const stats = dashboardStats(view);
    expect(stats.credits.total).toBe(120);
    expect(stats.roadblocks.total).toBe(5);
    expect(stats.credits.obtained).toBeGreaterThan(0);
    expect(stats.credits.obtained).toBeLessThanOrEqual(stats.credits.total);
  });

  it('n’a aucun projet orphelin', () => {
    expect(view.projects).toHaveLength(data.projects.length);
    expect(view.modules).toHaveLength(data.modules.length);
  });
});
