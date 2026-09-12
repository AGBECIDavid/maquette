/** Libellés et couleurs — le seul endroit où un statut devient du français. */

import type { Priority, ProgressStatus, ProjectStatus } from '../domain/types';

export const PROJECT_STATUS_LABEL: Record<ProjectStatus, string> = {
  todo: 'À faire',
  in_progress: 'En cours',
  done: 'Terminé',
  validated: 'Validé',
};

export const PROGRESS_STATUS_LABEL: Record<ProgressStatus, string> = {
  upcoming: 'À venir',
  in_progress: 'En cours',
  validated: 'Validé',
  failed: 'Non validé',
};

export const PRIORITY_LABEL: Record<Priority, string> = {
  critical: 'Critique',
  high: 'Haute',
  normal: 'Normale',
  low: 'Faible',
};

export const PROJECT_STATUS_ICON: Record<ProjectStatus, string> = {
  todo: '⏳',
  in_progress: '🔄',
  done: '📦',
  validated: '✅',
};

export const PROGRESS_STATUS_ICON: Record<ProgressStatus, string> = {
  upcoming: '⏳',
  in_progress: '🔄',
  validated: '✅',
  failed: '❌',
};

export const PRIORITY_DOT: Record<Priority, string> = {
  critical: '🔴',
  high: '🟠',
  normal: '🟡',
  low: '⚪',
};

/** Progression en pourcentage, ou « — » si elle n'a pas de sens. */
export function formatPercent(value: number | null): string {
  if (value === null) return '—';
  return `${Math.round(value * 100)} %`;
}

/** Un nombre de crédits : entier quand il tombe juste. */
export function formatCredits(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2).replace(/0$/, '');
}

export function formatDaysLeft(days: number | null): string {
  if (days === null) return '—';
  if (days === 0) return "aujourd'hui";
  if (days > 0) return `dans ${days} jour${days > 1 ? 's' : ''}`;
  return `en retard de ${-days} jour${-days > 1 ? 's' : ''}`;
}
