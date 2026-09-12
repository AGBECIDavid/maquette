/**
 * Alertes affichées dans l'application (pas de notification système).
 *
 * Une alerte se déduit de l'état, elle ne se stocke pas : elle disparaît
 * d'elle-même quand la situation qui l'a produite se résout.
 */

import { daysBetween } from './dates';
import type { CurriculumView } from './selectors';
import type { Id, Settings } from './types';

export type AlertLevel = 'danger' | 'warning' | 'info' | 'success';
export type AlertTargetKind = 'roadblock' | 'module' | 'project';

export interface Alert {
  id: string;
  level: AlertLevel;
  title: string;
  detail: string;
  target: { kind: AlertTargetKind; id: Id };
}

const LEVEL_ORDER: Record<AlertLevel, number> = {
  danger: 0,
  warning: 1,
  info: 2,
  success: 3,
};

export function buildAlerts(
  view: CurriculumView,
  settings: Settings,
): Alert[] {
  const alerts: Alert[] = [];

  for (const project of view.projects) {
    if (project.isLate && project.daysLeft !== null) {
      const late = -project.daysLeft;
      alerts.push({
        id: `late:${project.id}`,
        level: 'danger',
        title: `${project.name} est en retard`,
        detail: `Deadline dépassée de ${late} jour${late > 1 ? 's' : ''} — ${project.moduleName}`,
        target: { kind: 'project', id: project.id },
      });
    } else if (project.isDueSoon && project.daysLeft !== null) {
      alerts.push({
        id: `soon:${project.id}`,
        level: 'warning',
        title: `${project.name} arrive à échéance`,
        detail:
          project.daysLeft === 0
            ? `Deadline aujourd'hui — ${project.moduleName}`
            : `Deadline dans ${project.daysLeft} jour${project.daysLeft > 1 ? 's' : ''} — ${project.moduleName}`,
        target: { kind: 'project', id: project.id },
      });
    }
  }

  for (const module of view.modules) {
    if (module.status === 'validated' || module.endDate === null) continue;
    const daysLeft = daysBetween(view.today, module.endDate);
    if (daysLeft >= 0 && daysLeft <= settings.deadlineSoonDays) {
      alerts.push({
        id: `module-ending:${module.id}`,
        level: 'warning',
        title: `${module.name} se termine bientôt`,
        detail: `Fin dans ${daysLeft} jour${daysLeft > 1 ? 's' : ''} — ${module.remainingCredits} crédit(s) encore à obtenir`,
        target: { kind: 'module', id: module.id },
      });
    }
  }

  for (const roadblock of view.roadblocks) {
    if (roadblock.status === 'validated') {
      alerts.push({
        id: `rb-ok:${roadblock.id}`,
        level: 'success',
        title: `${roadblock.name} est validé`,
        detail: `${roadblock.obtainedCredits} / ${roadblock.requiredCredits} crédits`,
        target: { kind: 'roadblock', id: roadblock.id },
      });
      continue;
    }

    // Les crédits encore atteignables ne couvrent plus ce qui manque :
    // le Roadblock ne peut plus être validé en l'état.
    if (roadblock.remainingCredits > roadblock.reachableCredits) {
      alerts.push({
        id: `rb-unreachable:${roadblock.id}`,
        level: 'danger',
        title: `${roadblock.name} : crédits insuffisants`,
        detail: `Il manque ${roadblock.remainingCredits} crédit(s) et seuls ${roadblock.reachableCredits} restent atteignables dans ce Roadblock`,
        target: { kind: 'roadblock', id: roadblock.id },
      });
      continue;
    }

    const progress = roadblock.progress;
    if (progress !== null && progress >= settings.roadblockAlmostDoneRatio) {
      alerts.push({
        id: `rb-almost:${roadblock.id}`,
        level: 'info',
        title: `${roadblock.name} est bientôt validé`,
        detail: `Encore ${roadblock.remainingCredits} crédit(s) sur ${roadblock.requiredCredits}`,
        target: { kind: 'roadblock', id: roadblock.id },
      });
    }
  }

  return alerts.sort((a, b) => LEVEL_ORDER[a.level] - LEVEL_ORDER[b.level]);
}
