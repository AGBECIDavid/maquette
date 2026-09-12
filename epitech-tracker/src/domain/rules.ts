/**
 * RÈGLES ACADÉMIQUES — le seul fichier à modifier si une règle Epitech change.
 *
 * Rien d'autre dans l'application ne décide ce qui rapporte des crédits ni ce
 * qui vaut validation. Les agrégations (`selectors.ts`) et l'interface se
 * contentent d'appeler ces fonctions.
 *
 * Règles confirmées par l'utilisateur :
 *
 *   1. Un module rapporte ses crédits PROPORTIONNELLEMENT à ses projets
 *      validés. Un module de 6 crédits dont 2 projets sur 3 sont validés
 *      rapporte 4 crédits.
 *   2. Le poids d'un projet est par défaut une part égale des crédits du
 *      module, sauf poids forcé sur le projet.
 *   3. Seul le statut `validated` rapporte des crédits. `done` (rendu, en
 *      attente de correction) ne rapporte rien.
 *   4. Un Roadblock est validé dès que ses crédits obtenus atteignent son
 *      seuil, quels que soient les modules qui les ont apportés.
 *   5. Progression globale = crédits obtenus / crédits totaux requis.
 *
 * HYPOTHÈSES non confirmées, marquées comme telles, à revalider :
 *
 *   H1. Un module est « validé » quand tous ses projets sont validés,
 *       « en cours » dès qu'un projet a bougé ou que la période est ouverte,
 *       « à venir » sinon. L'échec d'un module ne se déduit pas : il se
 *       force à la main (`statusOverride`).
 *   H2. Un Roadblock dont la date de fin est passée sans que le seuil soit
 *       atteint est « non validé ». Si Epitech autorise un rattrapage
 *       au-delà de la date de fin, c'est cette règle qu'il faut retirer.
 */

import { isAfter, isWithin } from './dates';
import type {
  IsoDate,
  Module,
  ProgressStatus,
  Project,
  Roadblock,
} from './types';

/**
 * La période est-elle ouverte aujourd'hui ?
 *
 * Deux bornes inconnues ne font pas une période : sans aucune date, on ne
 * peut pas affirmer qu'un module est en cours, et `isWithin` répondrait
 * « oui » pour toute date. Une donnée absente ne devient pas une déduction.
 */
function isPeriodOpen(
  today: IsoDate,
  start: IsoDate | null,
  end: IsoDate | null,
): boolean {
  if (start === null && end === null) return false;
  return isWithin(today, start, end);
}

/** Arrondi d'affichage : les parts égales tombent souvent sur des tiers. */
export function roundCredits(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * Poids en crédits d'un projet (règle 2).
 * Un module sans projet ne distribue rien : ses crédits restent à obtenir.
 */
export function projectCredits(
  project: Project,
  module: Module,
  siblings: readonly Project[],
): number {
  if (project.creditsOverride !== null) return project.creditsOverride;
  if (siblings.length === 0) return 0;

  const forced = siblings.reduce(
    (sum, p) => sum + (p.creditsOverride ?? 0),
    0,
  );
  const free = siblings.filter((p) => p.creditsOverride === null).length;
  if (free === 0) return 0;

  return roundCredits(Math.max(module.credits - forced, 0) / free);
}

/** Un projet rapporte-t-il ses crédits ? (règle 3) */
export function projectEarnsCredits(project: Project): boolean {
  return project.status === 'validated';
}

/** Crédits obtenus sur un module (règle 1). */
export function moduleObtainedCredits(
  module: Module,
  projects: readonly Project[],
): number {
  if (projects.length === 0) return 0;

  // Un module dont tous les projets sont validés rapporte exactement ses
  // crédits. Sans ce cas, un module de 7 crédits partagé en trois n'en
  // rapporterait que 6,99 : l'arrondi ne doit jamais coûter un crédit.
  if (projects.every(projectEarnsCredits)) return module.credits;

  const earned = projects
    .filter(projectEarnsCredits)
    .reduce((sum, p) => sum + projectCredits(p, module, projects), 0);
  return roundCredits(Math.min(earned, module.credits));
}

/** Statut d'un module (hypothèse H1), sauf statut forcé à la main. */
export function moduleStatus(
  module: Module,
  projects: readonly Project[],
  today: IsoDate,
): ProgressStatus {
  if (module.statusOverride !== null) return module.statusOverride;

  if (projects.length > 0 && projects.every(projectEarnsCredits)) {
    return 'validated';
  }
  const started = projects.some((p) => p.status !== 'todo');
  if (started) return 'in_progress';
  if (isPeriodOpen(today, module.startDate, module.endDate)) return 'in_progress';
  return 'upcoming';
}

/** Crédits obtenus sur un Roadblock : la somme de ceux de ses modules. */
export function roadblockObtainedCredits(
  modules: readonly { obtainedCredits: number }[],
): number {
  return roundCredits(
    modules.reduce((sum, m) => sum + m.obtainedCredits, 0),
  );
}

/** Un Roadblock est validé au seuil de crédits (règle 4). */
export function isRoadblockValidated(
  roadblock: Roadblock,
  obtainedCredits: number,
): boolean {
  return obtainedCredits >= roadblock.requiredCredits;
}

/** Statut d'un Roadblock (règle 4 + hypothèse H2), sauf statut forcé. */
export function roadblockStatus(
  roadblock: Roadblock,
  obtainedCredits: number,
  hasStartedModules: boolean,
  today: IsoDate,
): ProgressStatus {
  if (roadblock.statusOverride !== null) return roadblock.statusOverride;
  if (isRoadblockValidated(roadblock, obtainedCredits)) return 'validated';
  if (roadblock.endDate !== null && isAfter(today, roadblock.endDate)) {
    return 'failed'; // H2
  }
  if (hasStartedModules) return 'in_progress';
  if (isPeriodOpen(today, roadblock.startDate, roadblock.endDate)) {
    return 'in_progress';
  }
  return 'upcoming';
}

/**
 * Progression : une part entre 0 et 1, jamais au-delà.
 * Un dénominateur nul rend `null` — « inconnu », pas 0 %.
 */
export function ratio(obtained: number, required: number): number | null {
  if (required <= 0) return null;
  return Math.min(Math.max(obtained / required, 0), 1);
}

/** Un projet est en retard si sa deadline est passée sans qu'il soit rendu. */
export function isProjectLate(project: Project, today: IsoDate): boolean {
  if (project.deadline === null) return false;
  if (project.status === 'done' || project.status === 'validated') return false;
  return isAfter(today, project.deadline);
}

export const PRIORITY_ORDER: Record<Project['priority'], number> = {
  critical: 0,
  high: 1,
  normal: 2,
  low: 3,
};
