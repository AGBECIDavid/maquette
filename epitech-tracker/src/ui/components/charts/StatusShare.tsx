import type { StatusSlice } from '../../../domain/stats';
import type { ProjectStatus } from '../../../domain/types';
import { PROJECT_STATUS_ICON, PROJECT_STATUS_LABEL } from '../../labels';
import { ChartFrame } from './ChartFrame';

/**
 * Répartition des projets par statut.
 *
 * Couleurs de statut, pas couleurs de série : le vert veut dire « validé »
 * ici comme sur les badges des listes. Elles ne sont donc jamais seules —
 * chaque segment est repris dans la légende avec son icône et son compte.
 */
const FILL: Record<ProjectStatus, string> = {
  validated: 'bg-ok',
  done: 'bg-accent-soft',
  in_progress: 'bg-busy',
  todo: 'bg-ink-600',
};

export function StatusShare({ slices, total }: { slices: StatusSlice[]; total: number }) {
  const shown = slices.filter((slice) => slice.count > 0);

  return (
    <ChartFrame title="Projets par statut" note={`${total} projet(s) au total.`}>
      {total === 0 ? (
        <p className="text-sm text-ink-400">Aucun projet enregistré.</p>
      ) : (
        <>
          {/* Écart de 2px entre segments : une séparation par le fond, pas
              une bordure autour des marques. */}
          <div className="flex h-3 w-full gap-0.5 overflow-hidden rounded">
            {shown.map((slice) => (
              <div
                key={slice.status}
                className={`h-full rounded-[2px] ${FILL[slice.status]}`}
                style={{ width: `${slice.share * 100}%` }}
              />
            ))}
          </div>

          <ul className="mt-4 grid gap-2 sm:grid-cols-2">
            {slices.map((slice) => (
              <li key={slice.status} className="flex items-center gap-2 text-sm">
                <span className={`size-2.5 shrink-0 rounded-[2px] ${FILL[slice.status]}`} aria-hidden />
                <span aria-hidden className="text-xs">{PROJECT_STATUS_ICON[slice.status]}</span>
                <span className="flex-1 truncate text-ink-300">
                  {PROJECT_STATUS_LABEL[slice.status]}
                </span>
                <span className="tabular-nums text-ink-100">{slice.count}</span>
                <span className="w-10 text-right tabular-nums text-ink-400">
                  {Math.round(slice.share * 100)} %
                </span>
              </li>
            ))}
          </ul>
        </>
      )}
    </ChartFrame>
  );
}
