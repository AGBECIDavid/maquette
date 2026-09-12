import type { MouseEvent } from 'react';

/**
 * Monter / descendre un élément dans sa fratrie.
 *
 * Les boutons vivent en dehors du lien de la ligne : un bouton imbriqué dans
 * un `<a>` est du HTML invalide, et le clic partirait dans la navigation
 * plutôt que dans l'action.
 */
export function MoveButtons({
  label,
  canUp,
  canDown,
  onMove,
}: {
  label: string;
  canUp: boolean;
  canDown: boolean;
  onMove: (direction: -1 | 1) => void;
}) {
  const click = (direction: -1 | 1) => (event: MouseEvent) => {
    event.preventDefault();
    event.stopPropagation();
    onMove(direction);
  };

  const style =
    'rounded-md border border-ink-800 px-2 py-0.5 text-xs text-ink-400 transition-colors hover:border-ink-600 hover:text-ink-100 disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:border-ink-800 disabled:hover:text-ink-400';

  return (
    <span className="flex shrink-0 gap-1">
      <button type="button" className={style} disabled={!canUp} onClick={click(-1)} aria-label={`Monter ${label}`}>
        ↑
      </button>
      <button type="button" className={style} disabled={!canDown} onClick={click(1)} aria-label={`Descendre ${label}`}>
        ↓
      </button>
    </span>
  );
}
