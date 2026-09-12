import { formatPercent } from '../labels';

/**
 * Barre de progression. Une valeur `null` (« inconnu ») se dessine en creux
 * plutôt qu'à 0 %, pour qu'on ne confonde pas « rien fait » et « rien su ».
 */
export function ProgressBar({
  value,
  tone = 'accent',
  showLabel = false,
}: {
  value: number | null;
  tone?: 'accent' | 'ok' | 'busy' | 'bad';
  showLabel?: boolean;
}) {
  const color = {
    accent: 'bg-accent',
    ok: 'bg-ok',
    busy: 'bg-busy',
    bad: 'bg-bad',
  }[tone];

  return (
    <div className="flex items-center gap-3">
      <div className="h-2 flex-1 overflow-hidden rounded-full bg-ink-800">
        {value !== null && (
          <div
            className={`h-full rounded-full transition-[width] duration-300 ${color}`}
            style={{ width: `${Math.round(value * 100)}%` }}
          />
        )}
      </div>
      {showLabel && (
        <span className="w-12 shrink-0 text-right text-xs tabular-nums text-ink-300">
          {formatPercent(value)}
        </span>
      )}
    </div>
  );
}
