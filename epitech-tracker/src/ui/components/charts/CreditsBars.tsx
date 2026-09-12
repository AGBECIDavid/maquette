import { useState } from 'react';
import { Link } from 'react-router-dom';
import type { RoadblockCredits } from '../../../domain/stats';
import { formatCredits } from '../../labels';
import { ChartFrame, Tooltip } from './ChartFrame';

/**
 * Crédits obtenus par Roadblock.
 *
 * Une seule série, donc une seule teinte pour toutes les barres : la longueur
 * porte déjà la grandeur, colorer chaque barre différemment brûlerait le seul
 * canal libre pour une information déjà lisible.
 *
 * La piste derrière la barre est le seuil requis : on voit d'un coup ce qui
 * est acquis et ce qu'il reste, sans second axe.
 */
export function CreditsBars({ data }: { data: RoadblockCredits[] }) {
  const [hover, setHover] = useState<{ x: number; y: number; item: RoadblockCredits } | null>(null);

  return (
    <ChartFrame
      title="Crédits obtenus par Roadblock"
      note="La piste claire est le seuil à atteindre."
    >
      <div className="relative flex flex-col gap-3">
        {data.map((item) => {
          const share = item.required > 0 ? Math.min(item.obtained / item.required, 1) : 0;
          const complete = item.obtained >= item.required && item.required > 0;
          return (
            <Link
              key={item.id}
              to={`/roadblocks/${item.id}`}
              className="block rounded-lg px-1 py-1 focus:outline-2 focus:outline-accent"
              onMouseMove={(event) => {
                const box = event.currentTarget.getBoundingClientRect();
                const parent = event.currentTarget.offsetParent?.getBoundingClientRect();
                setHover({
                  x: event.clientX - (parent?.left ?? 0),
                  y: box.top - (parent?.top ?? 0),
                  item,
                });
              }}
              onMouseLeave={() => setHover(null)}
            >
              <div className="mb-1 flex items-baseline justify-between gap-3">
                <span className="truncate text-xs text-ink-300">{item.name}</span>
                <span className="shrink-0 text-xs tabular-nums text-ink-400">
                  {formatCredits(item.obtained)} / {formatCredits(item.required)}
                </span>
              </div>
              <div className="h-2.5 w-full overflow-hidden rounded bg-ink-800">
                <div
                  className={`h-full rounded transition-[width] duration-300 ${complete ? 'bg-ok' : 'bg-accent'}`}
                  style={{ width: `${share * 100}%` }}
                />
              </div>
            </Link>
          );
        })}

        {hover !== null && (
          <Tooltip left={`${hover.x}px`} top={`${hover.y}px`}>
            <span className="block font-medium">{hover.item.name}</span>
            <span className="block text-ink-300">
              {formatCredits(hover.item.obtained)} crédits obtenus sur{' '}
              {formatCredits(hover.item.required)}
            </span>
            <span className="block text-ink-400">
              {hover.item.validatedModules} / {hover.item.totalModules} modules validés ·{' '}
              {formatCredits(hover.item.reachable)} encore atteignable(s)
            </span>
          </Tooltip>
        )}
      </div>
    </ChartFrame>
  );
}
