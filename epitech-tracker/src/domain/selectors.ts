/**
 * Agrégations : transforme les données brutes en vues calculées.
 *
 * Aucune règle académique ici — tout ce qui décide de la validation ou des
 * crédits vient de `rules.ts`. Ce fichier ne fait qu'assembler l'arbre et
 * additionner.
 */

import { daysBetween } from './dates';
import {
  isProjectLate,
  moduleObtainedCredits,
  moduleStatus,
  projectCredits,
  projectEarnsCredits,
  ratio,
  roadblockObtainedCredits,
  roadblockStatus,
  roundCredits,
} from './rules';
import type {
  Curriculum,
  Id,
  IsoDate,
  Module,
  ProgressStatus,
  Project,
  Roadblock,
} from './types';

export interface ProjectView extends Project {
  /** Poids effectif du projet, part égale comprise. */
  credits: number;
  obtainedCredits: number;
  moduleId: Id;
  moduleName: string;
  roadblockId: Id;
  roadblockName: string;
  /** Jours avant la deadline ; négatif si dépassée, `null` si pas de deadline. */
  daysLeft: number | null;
  isLate: boolean;
  isDueSoon: boolean;
}

export interface ModuleView extends Module {
  projects: ProjectView[];
  roadblockName: string;
  obtainedCredits: number;
  remainingCredits: number;
  progress: number | null;
  status: ProgressStatus;
  validatedProjects: number;
  totalProjects: number;
}

export interface RoadblockView extends Roadblock {
  modules: ModuleView[];
  yearLabel: string;
  obtainedCredits: number;
  remainingCredits: number;
  progress: number | null;
  status: ProgressStatus;
  validatedModules: number;
  totalModules: number;
  /** Crédits encore atteignables via les projets non validés du Roadblock. */
  reachableCredits: number;
}

export interface CurriculumView {
  roadblocks: RoadblockView[];
  modules: ModuleView[];
  projects: ProjectView[];
  today: IsoDate;
}

export interface DashboardStats {
  credits: { obtained: number; total: number; remaining: number };
  modules: { validated: number; inProgress: number; total: number };
  projects: { done: number; total: number; remaining: number };
  roadblocks: { validated: number; inProgress: number; total: number };
  /** Progression globale = crédits obtenus / crédits requis (règle 5). */
  progress: number | null;
  lateProjects: number;
  dueSoonProjects: number;
}

function sorted<T extends { order: number; name?: string }>(items: T[]): T[] {
  return [...items].sort((a, b) => a.order - b.order);
}

/**
 * Construit l'arbre calculé du cursus à une date donnée.
 * `today` est un paramètre, jamais lu depuis l'horloge : c'est ce qui rend
 * les tests reproductibles.
 */
export function buildView(data: Curriculum, today: IsoDate): CurriculumView {
  const yearLabel = new Map(data.years.map((y) => [y.id, y.label]));
  const projectsByModule = new Map<Id, Project[]>();
  for (const project of data.projects) {
    const list = projectsByModule.get(project.moduleId);
    if (list) list.push(project);
    else projectsByModule.set(project.moduleId, [project]);
  }
  const modulesByRoadblock = new Map<Id, Module[]>();
  for (const module of data.modules) {
    const list = modulesByRoadblock.get(module.roadblockId);
    if (list) list.push(module);
    else modulesByRoadblock.set(module.roadblockId, [module]);
  }

  const allProjects: ProjectView[] = [];
  const allModules: ModuleView[] = [];

  const roadblocks = sorted(data.roadblocks).map((roadblock) =>
    buildRoadblock(
      roadblock,
      modulesByRoadblock.get(roadblock.id) ?? [],
      projectsByModule,
      yearLabel.get(roadblock.yearId) ?? '—',
      data.settings.deadlineSoonDays,
      today,
      allModules,
      allProjects,
    ),
  );

  return { roadblocks, modules: allModules, projects: allProjects, today };
}

function buildRoadblock(
  roadblock: Roadblock,
  rawModules: Module[],
  projectsByModule: Map<Id, Project[]>,
  yearLabelValue: string,
  deadlineSoonDays: number,
  today: IsoDate,
  collectModules: ModuleView[],
  collectProjects: ProjectView[],
): RoadblockView {
  const modules = sorted(rawModules).map((module) => {
    const rawProjects = sorted(projectsByModule.get(module.id) ?? []);
    const projects = rawProjects.map((project): ProjectView => {
      const credits = projectCredits(project, module, rawProjects);
      const daysLeft =
        project.deadline === null ? null : daysBetween(today, project.deadline);
      const view: ProjectView = {
        ...project,
        credits,
        obtainedCredits: projectEarnsCredits(project) ? credits : 0,
        moduleName: module.name,
        roadblockId: roadblock.id,
        roadblockName: roadblock.name,
        daysLeft,
        isLate: isProjectLate(project, today),
        isDueSoon:
          daysLeft !== null &&
          daysLeft >= 0 &&
          daysLeft <= deadlineSoonDays &&
          project.status !== 'done' &&
          project.status !== 'validated',
      };
      collectProjects.push(view);
      return view;
    });

    const obtainedCredits = moduleObtainedCredits(module, rawProjects);
    const view: ModuleView = {
      ...module,
      projects,
      roadblockName: roadblock.name,
      obtainedCredits,
      remainingCredits: roundCredits(
        Math.max(module.credits - obtainedCredits, 0),
      ),
      progress: ratio(obtainedCredits, module.credits),
      status: moduleStatus(module, rawProjects, today),
      validatedProjects: projects.filter(projectEarnsCredits).length,
      totalProjects: projects.length,
    };
    collectModules.push(view);
    return view;
  });

  const obtainedCredits = roadblockObtainedCredits(modules);
  const hasStarted = modules.some((m) => m.status !== 'upcoming');
  const reachableCredits = roundCredits(
    modules.reduce((sum, m) => sum + m.remainingCredits, 0),
  );

  return {
    ...roadblock,
    modules,
    yearLabel: yearLabelValue,
    obtainedCredits,
    remainingCredits: roundCredits(
      Math.max(roadblock.requiredCredits - obtainedCredits, 0),
    ),
    progress: ratio(obtainedCredits, roadblock.requiredCredits),
    status: roadblockStatus(roadblock, obtainedCredits, hasStarted, today),
    validatedModules: modules.filter((m) => m.status === 'validated').length,
    totalModules: modules.length,
    reachableCredits,
  };
}

export function dashboardStats(view: CurriculumView): DashboardStats {
  const totalCredits = view.roadblocks.reduce(
    (sum, r) => sum + r.requiredCredits,
    0,
  );
  const obtainedCredits = roundCredits(
    view.roadblocks.reduce((sum, r) => sum + r.obtainedCredits, 0),
  );
  const doneProjects = view.projects.filter(
    (p) => p.status === 'validated' || p.status === 'done',
  ).length;

  return {
    credits: {
      obtained: obtainedCredits,
      total: totalCredits,
      remaining: roundCredits(Math.max(totalCredits - obtainedCredits, 0)),
    },
    modules: {
      validated: view.modules.filter((m) => m.status === 'validated').length,
      inProgress: view.modules.filter((m) => m.status === 'in_progress').length,
      total: view.modules.length,
    },
    projects: {
      done: doneProjects,
      total: view.projects.length,
      remaining: view.projects.length - doneProjects,
    },
    roadblocks: {
      validated: view.roadblocks.filter((r) => r.status === 'validated').length,
      inProgress: view.roadblocks.filter((r) => r.status === 'in_progress')
        .length,
      total: view.roadblocks.length,
    },
    progress: ratio(obtainedCredits, totalCredits),
    lateProjects: view.projects.filter((p) => p.isLate).length,
    dueSoonProjects: view.projects.filter((p) => p.isDueSoon).length,
  };
}
