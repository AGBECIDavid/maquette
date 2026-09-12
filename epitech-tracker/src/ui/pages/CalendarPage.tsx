import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import {
  buildEvents,
  defaultMonth,
  monthGrid,
  shiftMonth,
  type CalendarEvent,
  type CalendarEventKind,
} from '../../domain/calendar';
import { formatMonth } from '../../domain/dates';
import { Button, PageHeader } from '../components/Primitives';
import { PRIORITY_LABEL } from '../labels';

const WEEKDAYS = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

const KIND_LABEL: Record<CalendarEventKind, string> = {
  module_start: 'Début de module',
  module_end: 'Fin de module',
  project_start: 'Début de projet',
  project_deadline: 'Deadline',
};

/**
 * Chaque type d'événement a sa forme en plus de sa couleur : un carré pour un
 * module, un rond pour un projet, un rond plein pour une deadline. La forme
 * reste lisible en noir et blanc et pour un œil daltonien.
 */
function EventMark({ event }: { event: CalendarEvent }) {
  if (event.kind === 'module_start' || event.kind === 'module_end') {
    return (
      <span
        aria-hidden
        className={`size-2 shrink-0 rounded-[2px] ${event.kind === 'module_start' ? 'bg-accent' : 'border border-accent'}`}
      />
    );
  }
  const tone = event.late ? 'bg-bad' : event.done ? 'bg-ok' : 'bg-busy';
  return (
    <span
      aria-hidden
      className={`size-2 shrink-0 rounded-full ${event.kind === 'project_deadline' ? tone : `border ${event.done ? 'border-ok' : 'border-busy'}`}`}
    />
  );
}

export function CalendarPage() {
  const { view, today } = useCurriculum();
  const [month, setMonth] = useState(() => defaultMonth(today));

  const events = useMemo(() => buildEvents(view), [view]);
  const grid = useMemo(() => monthGrid(month, events, today), [month, events, today]);
  const monthEvents = useMemo(
    () => grid.filter((day) => day.inMonth).flatMap((day) => day.events),
    [grid],
  );

  return (
    <>
      <PageHeader
        title="Calendrier"
        subtitle={`${monthEvents.length} événement(s) ce mois-ci.`}
        action={
          <div className="flex items-center gap-2">
            <Button onClick={() => setMonth((m) => shiftMonth(m, -1))} aria-label="Mois précédent">
              ←
            </Button>
            <span className="min-w-40 text-center text-sm text-ink-100">{formatMonth(month)}</span>
            <Button onClick={() => setMonth((m) => shiftMonth(m, 1))} aria-label="Mois suivant">
              →
            </Button>
            <Button onClick={() => setMonth(defaultMonth(today))}>Aujourd’hui</Button>
          </div>
        }
      />

      <ul className="mb-4 flex flex-wrap gap-x-5 gap-y-2 text-xs text-ink-400">
        <li className="flex items-center gap-2">
          <span aria-hidden className="size-2 rounded-[2px] bg-accent" /> Début de module
        </li>
        <li className="flex items-center gap-2">
          <span aria-hidden className="size-2 rounded-[2px] border border-accent" /> Fin de module
        </li>
        <li className="flex items-center gap-2">
          <span aria-hidden className="size-2 rounded-full border border-busy" /> Début de projet
        </li>
        <li className="flex items-center gap-2">
          <span aria-hidden className="size-2 rounded-full bg-busy" /> Deadline
        </li>
        <li className="flex items-center gap-2">
          <span aria-hidden className="size-2 rounded-full bg-bad" /> Deadline dépassée
        </li>
        <li className="flex items-center gap-2">
          <span aria-hidden className="size-2 rounded-full bg-ok" /> Rendu
        </li>
      </ul>

      <div className="overflow-x-auto">
        <div className="min-w-[44rem]">
          <div className="grid grid-cols-7 gap-1 pb-1 text-center text-xs text-ink-400">
            {WEEKDAYS.map((day) => (
              <div key={day}>{day}</div>
            ))}
          </div>

          <div className="grid grid-cols-7 gap-1">
            {grid.map((day) => (
              <div
                key={day.date}
                className={`min-h-24 rounded-lg border p-1.5 ${
                  day.isToday
                    ? 'border-accent bg-accent/5'
                    : day.inMonth
                      ? 'border-ink-800 bg-ink-900'
                      : 'border-ink-850 bg-ink-950'
                }`}
              >
                <span
                  className={`block text-right text-xs tabular-nums ${
                    day.isToday ? 'font-semibold text-accent-soft' : day.inMonth ? 'text-ink-400' : 'text-ink-700'
                  }`}
                >
                  {Number(day.date.slice(8, 10))}
                </span>

                <ul className="mt-1 flex flex-col gap-1">
                  {day.events.slice(0, 3).map((event) => (
                    <li key={event.id}>
                      <Link
                        to={`/${event.target.kind === 'module' ? 'modules' : 'projects'}/${event.target.id}`}
                        title={`${KIND_LABEL[event.kind]} — ${event.label}${event.priority !== null ? ` · priorité ${PRIORITY_LABEL[event.priority].toLowerCase()}` : ''}`}
                        className="flex items-center gap-1.5 rounded px-1 py-0.5 text-[11px] leading-tight text-ink-300 hover:bg-ink-800 hover:text-ink-100"
                      >
                        <EventMark event={event} />
                        <span className="truncate">{event.label}</span>
                      </Link>
                    </li>
                  ))}
                  {day.events.length > 3 && (
                    <li className="px-1 text-[11px] text-ink-400">
                      +{day.events.length - 3} autre(s)
                    </li>
                  )}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
