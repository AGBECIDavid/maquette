import type { ReactNode } from 'react';
import { ProgressBar } from './ProgressBar';

/**
 * Tuile de compteur du dashboard : un chiffre lisible de loin, une mesure
 * secondaire, et la barre qui situe l'un par rapport à l'autre.
 */
export function StatTile({
  label,
  value,
  total,
  detail,
  progress,
  tone = 'accent',
}: {
  label: string;
  value: ReactNode;
  total?: ReactNode;
  detail?: string;
  progress?: number | null;
  tone?: 'accent' | 'ok' | 'busy' | 'bad';
}) {
  return (
    <div className="rounded-xl border border-ink-800 bg-ink-900 p-4">
      <p className="text-xs font-medium tracking-wide text-ink-400 uppercase">
        {label}
      </p>
      <p className="mt-2 flex items-baseline gap-1.5">
        <span className="text-3xl font-semibold tabular-nums text-ink-100">{value}</span>
        {total !== undefined && (
          <span className="text-sm text-ink-400 tabular-nums">/ {total}</span>
        )}
      </p>
      {progress !== undefined && (
        <div className="mt-3">
          <ProgressBar value={progress} tone={tone} />
        </div>
      )}
      {detail !== undefined && <p className="mt-2 text-xs text-ink-400">{detail}</p>}
    </div>
  );
}
