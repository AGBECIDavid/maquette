import type { Priority, ProgressStatus, ProjectStatus } from '../../domain/types';
import {
  PRIORITY_DOT,
  PRIORITY_LABEL,
  PROGRESS_STATUS_LABEL,
  PROJECT_STATUS_LABEL,
} from '../labels';

const TONE = {
  ok: 'border-ok/30 bg-ok/10 text-ok',
  busy: 'border-busy/30 bg-busy/10 text-busy',
  wait: 'border-ink-700 bg-ink-800 text-ink-400',
  bad: 'border-bad/30 bg-bad/10 text-bad',
  info: 'border-accent/30 bg-accent/10 text-accent-soft',
};

function Pill({ tone, children }: { tone: keyof typeof TONE; children: string }) {
  return (
    <span
      className={`inline-flex shrink-0 items-center rounded-full border px-2 py-0.5 text-xs font-medium ${TONE[tone]}`}
    >
      {children}
    </span>
  );
}

const PROGRESS_TONE: Record<ProgressStatus, keyof typeof TONE> = {
  validated: 'ok',
  in_progress: 'busy',
  upcoming: 'wait',
  failed: 'bad',
};

const PROJECT_TONE: Record<ProjectStatus, keyof typeof TONE> = {
  validated: 'ok',
  done: 'info',
  in_progress: 'busy',
  todo: 'wait',
};

export function StatusBadge({ status }: { status: ProgressStatus }) {
  return <Pill tone={PROGRESS_TONE[status]}>{PROGRESS_STATUS_LABEL[status]}</Pill>;
}

export function ProjectStatusBadge({ status }: { status: ProjectStatus }) {
  return <Pill tone={PROJECT_TONE[status]}>{PROJECT_STATUS_LABEL[status]}</Pill>;
}

export function PriorityBadge({ priority }: { priority: Priority }) {
  return (
    <span className="inline-flex items-center gap-1 text-xs text-ink-400">
      <span aria-hidden>{PRIORITY_DOT[priority]}</span>
      {PRIORITY_LABEL[priority]}
    </span>
  );
}

export function LateBadge() {
  return <Pill tone="bad">En retard</Pill>;
}

export function SoonBadge() {
  return <Pill tone="busy">Échéance proche</Pill>;
}
