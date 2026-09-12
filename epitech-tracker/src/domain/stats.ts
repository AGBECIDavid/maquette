/**
 * Séries pour les graphiques.
 *
 * Les composants reçoivent des nombres prêts à dessiner : aucune agrégation
 * n'est refaite dans du JSX, donc aucune ne peut diverger de celle du
 * dashboard.
 */

import { roundCredits } from './rules';
import type { CurriculumView } from './selectors';
import type { Id, IsoDate, ProjectStatus } from './types';

export interface RoadblockCredits {
  id: Id;
  name: string;
  obtained: number;
  required: number;
  /** Crédits encore atteignables au-delà de ceux déjà obtenus. */
  reachable: number;
  validatedModules: number;
  totalModules: number;
}

export function creditsByRoadblock(view: CurriculumView): RoadblockCredits[] {
  return view.roadblocks.map((roadblock) => ({
    id: roadblock.id,
    name: roadblock.name,
    obtained: roadblock.obtainedCredits,
    required: roadblock.requiredCredits,
    reachable: roadblock.reachableCredits,
    validatedModules: roadblock.validatedModules,
    totalModules: roadblock.totalModules,
  }));
}

export interface StatusSlice {
  status: ProjectStatus;
  count: number;
  /** Part du total, entre 0 et 1. Zéro projet → part nulle, pas NaN. */
  share: number;
}

/** Répartition des projets par statut, dans l'ordre d'avancement. */
export function projectStatusDistribution(view: CurriculumView): StatusSlice[] {
  const order: ProjectStatus[] = ['validated', 'done', 'in_progress', 'todo'];
  const total = view.projects.length;

  return order.map((status) => {
    const count = view.projects.filter((p) => p.status === status).length;
    return { status, count, share: total === 0 ? 0 : count / total };
  });
}

export interface CumulativePoint {
  date: IsoDate;
  /** Projets validés depuis le début, à cette date. */
  projects: number;
  /** Crédits cumulés à cette date. */
  credits: number;
}

/**
 * Crédits validés dans le temps.
 *
 * Seuls les projets validés ET datés comptent : un projet validé sans date de
 * fin ne peut pas être placé sur un axe temporel, et l'inventer fausserait la
 * courbe. Le total de la courbe peut donc être inférieur aux crédits obtenus —
 * c'est voulu, et la page le dit.
 */
export function validatedOverTime(view: CurriculumView): CumulativePoint[] {
  const dated = view.projects
    .filter((p) => p.status === 'validated' && p.completedAt !== null)
    .sort((a, b) => (a.completedAt! < b.completedAt! ? -1 : 1));

  // Le cumul suit la même règle que le reste de l'application : tant qu'un
  // module est partiellement validé on somme les parts de ses projets, mais
  // dès qu'il est entièrement validé il vaut exactement ses crédits. Sans
  // cela, des parts égales non entières feraient dériver la courbe du
  // compteur du dashboard — 74,01 au lieu de 74.
  const moduleOf = new Map(view.modules.map((m) => [m.id, m]));
  const progress = new Map<Id, { partial: number; validated: number }>();

  const points: CumulativePoint[] = [];
  let projects = 0;
  let credits = 0;

  for (const project of dated) {
    const module = moduleOf.get(project.moduleId);
    const state = progress.get(project.moduleId) ?? { partial: 0, validated: 0 };

    let delta = project.credits;
    if (module !== undefined) {
      state.validated += 1;
      if (state.validated === module.totalProjects) {
        // Dernier projet du module : on remplace les parts accumulées par le
        // total exact du module.
        delta = module.credits - state.partial;
        state.partial = module.credits;
      } else {
        state.partial += project.credits;
      }
      progress.set(project.moduleId, state);
    }

    projects += 1;
    credits = roundCredits(credits + delta);

    const date = project.completedAt!;
    const last = points[points.length - 1];
    // Plusieurs projets validés le même jour ne font qu'un point.
    if (last !== undefined && last.date === date) {
      last.projects = projects;
      last.credits = credits;
    } else {
      points.push({ date, projects, credits });
    }
  }

  return points;
}

/** Crédits validés mais non datés : la courbe ne peut pas les porter. */
export function undatedValidatedCredits(view: CurriculumView): number {
  return roundCredits(
    view.projects
      .filter((p) => p.status === 'validated' && p.completedAt === null)
      .reduce((sum, p) => sum + p.credits, 0),
  );
}
