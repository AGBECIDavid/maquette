/**
 * Vue calendrier : les dates du cursus posées sur une grille mensuelle.
 *
 * Un événement n'est jamais stocké : il se déduit des dates déjà saisies sur
 * les modules et les projets. Rien à tenir à jour en double.
 */

import { addDays, monthOf, shiftMonth, startOfMonth, weekdayIndex } from './dates';
import type { CurriculumView } from './selectors';
import type { Id, IsoDate, Priority } from './types';

export type CalendarEventKind =
  | 'module_start'
  | 'module_end'
  | 'project_start'
  | 'project_deadline';

export interface CalendarEvent {
  id: string;
  kind: CalendarEventKind;
  date: IsoDate;
  label: string;
  target: { kind: 'module' | 'project'; id: Id };
  priority: Priority | null;
  /** Deadline dépassée sans que le projet soit rendu. */
  late: boolean;
  done: boolean;
}

export interface CalendarDay {
  date: IsoDate;
  /** Faux pour les jours des mois voisins qui complètent la grille. */
  inMonth: boolean;
  isToday: boolean;
  events: CalendarEvent[];
}

export function buildEvents(view: CurriculumView): CalendarEvent[] {
  const events: CalendarEvent[] = [];

  for (const module of view.modules) {
    if (module.startDate !== null) {
      events.push({
        id: `ms:${module.id}`,
        kind: 'module_start',
        date: module.startDate,
        label: module.name,
        target: { kind: 'module', id: module.id },
        priority: null,
        late: false,
        done: module.status === 'validated',
      });
    }
    if (module.endDate !== null) {
      events.push({
        id: `me:${module.id}`,
        kind: 'module_end',
        date: module.endDate,
        label: module.name,
        target: { kind: 'module', id: module.id },
        priority: null,
        late: false,
        done: module.status === 'validated',
      });
    }
  }

  for (const project of view.projects) {
    const done = project.status === 'done' || project.status === 'validated';
    if (project.startDate !== null) {
      events.push({
        id: `ps:${project.id}`,
        kind: 'project_start',
        date: project.startDate,
        label: project.name,
        target: { kind: 'project', id: project.id },
        priority: project.priority,
        late: false,
        done,
      });
    }
    if (project.deadline !== null) {
      events.push({
        id: `pd:${project.id}`,
        kind: 'project_deadline',
        date: project.deadline,
        label: project.name,
        target: { kind: 'project', id: project.id },
        priority: project.priority,
        late: project.isLate,
        done,
      });
    }
  }

  return events;
}

/**
 * Grille du mois : toujours six semaines de sept jours, lundi en tête.
 * Un nombre de cases constant évite que la page saute d'un mois à l'autre.
 */
export function monthGrid(
  month: string,
  events: readonly CalendarEvent[],
  today: IsoDate,
): CalendarDay[] {
  const first = startOfMonth(month);
  const start = addDays(first, -weekdayIndex(first));

  const byDate = new Map<IsoDate, CalendarEvent[]>();
  for (const event of events) {
    const list = byDate.get(event.date);
    if (list) list.push(event);
    else byDate.set(event.date, [event]);
  }

  return Array.from({ length: 42 }, (_, index) => {
    const date = addDays(start, index);
    return {
      date,
      inMonth: monthOf(date) === month,
      isToday: date === today,
      events: byDate.get(date) ?? [],
    };
  });
}

/** Les mois qui portent au moins un événement, du plus ancien au plus récent. */
export function busyMonths(events: readonly CalendarEvent[]): string[] {
  return [...new Set(events.map((event) => monthOf(event.date)))].sort();
}

/** Le mois à ouvrir par défaut : celui d'aujourd'hui. */
export function defaultMonth(today: IsoDate): string {
  return monthOf(today);
}

export { shiftMonth };
