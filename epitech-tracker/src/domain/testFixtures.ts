/** Fabriques d'objets pour les tests : seuls les champs utiles sont passés. */

import { DEFAULT_SETTINGS, SCHEMA_VERSION } from '../data/schema';
import type {
  AcademicYear,
  Curriculum,
  Module,
  Project,
  Roadblock,
} from './types';

export function makeYear(over: Partial<AcademicYear> = {}): AcademicYear {
  return { id: 'y1', label: '2026-2027', level: 'TEK1', order: 1, startDate: null, endDate: null, ...over };
}

export function makeRoadblock(over: Partial<Roadblock> = {}): Roadblock {
  return {
    id: 'rb1',
    yearId: 'y1',
    name: 'Roadblock 1',
    description: '',
    order: 1,
    requiredCredits: 12,
    startDate: null,
    endDate: null,
    statusOverride: null,
    ...over,
  };
}

export function makeModule(over: Partial<Module> = {}): Module {
  return {
    id: 'm1',
    roadblockId: 'rb1',
    name: 'Module 1',
    description: '',
    order: 1,
    credits: 6,
    startDate: null,
    endDate: null,
    statusOverride: null,
    grade: null,
    notes: '',
    ...over,
  };
}

export function makeProject(over: Partial<Project> = {}): Project {
  return {
    id: 'p1',
    moduleId: 'm1',
    name: 'Projet 1',
    description: '',
    order: 1,
    creditsOverride: null,
    startDate: null,
    deadline: null,
    completedAt: null,
    status: 'todo',
    priority: 'normal',
    grade: null,
    repoUrl: null,
    notes: '',
    ...over,
  };
}

export function makeCurriculum(over: Partial<Curriculum> = {}): Curriculum {
  return {
    schemaVersion: SCHEMA_VERSION,
    years: [makeYear()],
    roadblocks: [makeRoadblock()],
    modules: [makeModule()],
    projects: [makeProject()],
    settings: { ...DEFAULT_SETTINGS, currentYearId: 'y1' },
    ...over,
  };
}
