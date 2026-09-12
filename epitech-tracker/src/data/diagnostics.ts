/**
 * Rapport de diagnostic, pour les retours de bêta.
 *
 * Un signalement utile tient en trois choses : la version exacte, le contexte
 * d'exécution, et les données qui ont produit le comportement. Sans elles, un
 * bug se reproduit par devinettes.
 *
 * Le rapport contient **tout le cursus**, notes et commentaires personnels
 * compris. L'interface le dit avant de produire le fichier : c'est à
 * l'utilisateur de décider ce qu'il envoie.
 */

import { findOrphans } from './schema';
import { buildView, dashboardStats } from '../domain/selectors';
import type { Curriculum } from '../domain/types';

export interface DiagnosticInput {
  curriculum: Curriculum;
  profileName: string;
  version: string;
  stage: string;
  today: string;
  generatedAt: string;
  environment: { userAgent: string; language: string; screen: string };
}

export interface DiagnosticReport {
  kind: 'epitech-tracker-diagnostic';
  version: string;
  stage: string;
  generatedAt: string;
  profileName: string;
  environment: DiagnosticInput['environment'];
  counts: {
    years: number;
    roadblocks: number;
    modules: number;
    projects: number;
    lateProjects: number;
  };
  credits: { obtained: number; total: number };
  /** Incohérences détectées : orphelins, références cassées. */
  integrity: string[];
  settings: Curriculum['settings'];
  curriculum: Curriculum;
}

export function buildDiagnostics(input: DiagnosticInput): DiagnosticReport {
  const view = buildView(input.curriculum, input.today);
  const stats = dashboardStats(view);

  return {
    kind: 'epitech-tracker-diagnostic',
    version: input.version,
    stage: input.stage,
    generatedAt: input.generatedAt,
    profileName: input.profileName,
    environment: input.environment,
    counts: {
      years: input.curriculum.years.length,
      roadblocks: input.curriculum.roadblocks.length,
      modules: input.curriculum.modules.length,
      projects: input.curriculum.projects.length,
      lateProjects: stats.lateProjects,
    },
    credits: { obtained: stats.credits.obtained, total: stats.credits.total },
    integrity: findOrphans(input.curriculum),
    settings: input.curriculum.settings,
    curriculum: input.curriculum,
  };
}
