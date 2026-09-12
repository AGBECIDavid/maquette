/**
 * Recherche et filtres, partagés par la recherche globale et les listes.
 */

import type { CurriculumView, ModuleView, ProjectView, RoadblockView } from './selectors';
import type { Id, Priority, ProgressStatus, ProjectStatus } from './types';

export type SearchResult =
  | { kind: 'roadblock'; id: Id; label: string; context: string }
  | { kind: 'module'; id: Id; label: string; context: string }
  | { kind: 'project'; id: Id; label: string; context: string };

/** Insensible à la casse et aux accents : « reseau » trouve « Réseau ». */
export function normalize(text: string): string {
  return text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .trim();
}

function matches(query: string, ...fields: string[]): boolean {
  const needle = normalize(query);
  if (needle === '') return true;
  return fields.some((field) => normalize(field).includes(needle));
}

export function searchAll(view: CurriculumView, query: string): SearchResult[] {
  if (normalize(query) === '') return [];
  const results: SearchResult[] = [];

  for (const r of view.roadblocks) {
    if (matches(query, r.name, r.description)) {
      results.push({
        kind: 'roadblock',
        id: r.id,
        label: r.name,
        context: `${r.yearLabel} · ${r.obtainedCredits}/${r.requiredCredits} crédits`,
      });
    }
  }
  for (const m of view.modules) {
    if (matches(query, m.name, m.description, m.notes)) {
      results.push({
        kind: 'module',
        id: m.id,
        label: m.name,
        context: `${m.roadblockName} · ${m.credits} crédits`,
      });
    }
  }
  for (const p of view.projects) {
    if (matches(query, p.name, p.description, p.notes)) {
      results.push({
        kind: 'project',
        id: p.id,
        label: p.name,
        context: `${p.moduleName} · ${p.roadblockName}`,
      });
    }
  }
  return results;
}

export interface ProjectFilters {
  query: string;
  status: ProjectStatus | 'all';
  priority: Priority | 'all';
  roadblockId: Id | 'all';
  moduleId: Id | 'all';
  lateOnly: boolean;
}

export const EMPTY_PROJECT_FILTERS: ProjectFilters = {
  query: '',
  status: 'all',
  priority: 'all',
  roadblockId: 'all',
  moduleId: 'all',
  lateOnly: false,
};

export function filterProjects(
  projects: readonly ProjectView[],
  filters: ProjectFilters,
): ProjectView[] {
  return projects.filter((p) => {
    if (!matches(filters.query, p.name, p.description, p.moduleName)) return false;
    if (filters.status !== 'all' && p.status !== filters.status) return false;
    if (filters.priority !== 'all' && p.priority !== filters.priority) return false;
    if (filters.roadblockId !== 'all' && p.roadblockId !== filters.roadblockId) return false;
    if (filters.moduleId !== 'all' && p.moduleId !== filters.moduleId) return false;
    if (filters.lateOnly && !p.isLate) return false;
    return true;
  });
}

export interface ModuleFilters {
  query: string;
  status: ProgressStatus | 'all';
  roadblockId: Id | 'all';
}

export const EMPTY_MODULE_FILTERS: ModuleFilters = {
  query: '',
  status: 'all',
  roadblockId: 'all',
};

export function filterModules(
  modules: readonly ModuleView[],
  filters: ModuleFilters,
): ModuleView[] {
  return modules.filter((m) => {
    if (!matches(filters.query, m.name, m.description)) return false;
    if (filters.status !== 'all' && m.status !== filters.status) return false;
    if (filters.roadblockId !== 'all' && m.roadblockId !== filters.roadblockId) return false;
    return true;
  });
}

export function filterRoadblocks(
  roadblocks: readonly RoadblockView[],
  query: string,
  yearId: Id | 'all',
): RoadblockView[] {
  return roadblocks.filter((r) => {
    if (!matches(query, r.name, r.description)) return false;
    if (yearId !== 'all' && r.yearId !== yearId) return false;
    return true;
  });
}
