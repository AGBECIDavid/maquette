/**
 * « À faire en priorité » : ce qui doit passer en premier.
 *
 * L'urgence vient d'abord de la deadline, la priorité déclarée ne départage
 * que les projets qui tombent le même jour — une priorité « faible » dont la
 * deadline est demain reste plus urgente qu'une « critique » dans un mois.
 */

import { PRIORITY_ORDER } from './rules';
import type { CurriculumView, ProjectView } from './selectors';

export function urgentProjects(
  view: CurriculumView,
  limit = 5,
): ProjectView[] {
  return view.projects
    .filter((p) => p.status !== 'validated' && p.status !== 'done')
    .sort((a, b) => {
      // Sans deadline, un projet ne peut pas être urgent : il passe en dernier.
      if (a.daysLeft === null && b.daysLeft === null) {
        return PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority];
      }
      if (a.daysLeft === null) return 1;
      if (b.daysLeft === null) return -1;
      if (a.daysLeft !== b.daysLeft) return a.daysLeft - b.daysLeft;
      return PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority];
    })
    .slice(0, limit);
}
