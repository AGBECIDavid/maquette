import { Link } from 'react-router-dom';
import type { Alert, AlertLevel } from '../../domain/alerts';
import { EmptyState } from './Primitives';

const STYLE: Record<AlertLevel, { border: string; icon: string }> = {
  danger: { border: 'border-bad/40 bg-bad/5', icon: '⛔' },
  warning: { border: 'border-busy/40 bg-busy/5', icon: '⚠️' },
  info: { border: 'border-accent/40 bg-accent/5', icon: 'ℹ️' },
  success: { border: 'border-ok/40 bg-ok/5', icon: '✅' },
};

const PATH = {
  roadblock: 'roadblocks',
  module: 'modules',
  project: 'projects',
} as const;

export function AlertList({ alerts, limit }: { alerts: Alert[]; limit?: number }) {
  if (alerts.length === 0) {
    return <EmptyState title="Aucune alerte." hint="Rien en retard, rien à l’échéance." />;
  }

  const shown = limit === undefined ? alerts : alerts.slice(0, limit);

  return (
    <ul className="flex flex-col gap-2">
      {shown.map((alert) => (
        <li key={alert.id}>
          <Link
            to={`/${PATH[alert.target.kind]}/${alert.target.id}`}
            className={`flex items-start gap-3 rounded-xl border px-4 py-3 transition-colors hover:brightness-125 ${STYLE[alert.level].border}`}
          >
            <span aria-hidden>{STYLE[alert.level].icon}</span>
            <span className="min-w-0">
              <span className="block text-sm text-ink-100">{alert.title}</span>
              <span className="block text-xs text-ink-400">{alert.detail}</span>
            </span>
          </Link>
        </li>
      ))}
    </ul>
  );
}
