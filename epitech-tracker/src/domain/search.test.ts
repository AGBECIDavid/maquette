import { describe, expect, it } from 'vitest';
import { EMPTY_PROJECT_FILTERS, filterProjects, searchAll } from './search';
import { urgentProjects } from './priorities';
import { buildView } from './selectors';
import { makeCurriculum, makeModule, makeProject } from './testFixtures';

const TODAY = '2026-09-12';

const data = makeCurriculum({
  modules: [makeModule({ name: 'Réseaux & Protocoles' })],
  projects: [
    makeProject({ id: 'p1', name: 'myftp', status: 'in_progress', deadline: '2026-09-20', priority: 'low' }),
    makeProject({ id: 'p2', name: 'myteams', status: 'todo', deadline: '2026-09-14', priority: 'normal', order: 2 }),
    makeProject({ id: 'p3', name: 'Rapport', status: 'validated', deadline: '2026-09-13', order: 3 }),
    makeProject({ id: 'p4', name: 'Sans date', status: 'todo', priority: 'critical', order: 4 }),
  ],
});
const view = buildView(data, TODAY);

describe('recherche globale', () => {
  it('ignore la casse et les accents', () => {
    const results = searchAll(view, 'reseaux');
    expect(results.some((r) => r.kind === 'module')).toBe(true);
  });

  it('ne rend rien pour une recherche vide', () => {
    expect(searchAll(view, '   ')).toHaveLength(0);
  });

  it('trouve un projet par son nom', () => {
    expect(searchAll(view, 'myftp').map((r) => r.id)).toEqual(['p1']);
  });
});

describe('filtres projets', () => {
  it('filtre par statut', () => {
    const result = filterProjects(view.projects, { ...EMPTY_PROJECT_FILTERS, status: 'todo' });
    expect(result.map((p) => p.id)).toEqual(['p2', 'p4']);
  });

  it('combine texte et statut', () => {
    const result = filterProjects(view.projects, {
      ...EMPTY_PROJECT_FILTERS,
      query: 'my',
      status: 'in_progress',
    });
    expect(result.map((p) => p.id)).toEqual(['p1']);
  });
});

describe('à faire en priorité', () => {
  it('classe par deadline avant la priorité déclarée', () => {
    const urgent = urgentProjects(view);
    expect(urgent.map((p) => p.id)).toEqual(['p2', 'p1', 'p4']);
  });

  it('écarte les projets déjà rendus', () => {
    expect(urgentProjects(view).map((p) => p.id)).not.toContain('p3');
  });
});
