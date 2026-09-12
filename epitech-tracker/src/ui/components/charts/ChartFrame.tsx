import type { ReactNode } from 'react';

/**
 * Cadre commun des graphiques : un titre qui nomme la mesure, une note qui
 * dit ce que le graphique ne montre pas, et la zone de dessin.
 *
 * Le titre nomme la série : une série unique n'a donc pas besoin de légende.
 */
export function ChartFrame({
  title,
  note,
  children,
}: {
  title: string;
  note?: string | undefined;
  children: ReactNode;
}) {
  return (
    <figure className="rounded-xl border border-ink-800 bg-ink-900 p-5">
      <figcaption className="mb-4">
        <h3 className="text-sm font-medium text-ink-100">{title}</h3>
        {note !== undefined && <p className="mt-0.5 text-xs text-ink-400">{note}</p>}
      </figcaption>
      {children}
    </figure>
  );
}

/**
 * Bulle de survol. Les positions sont des longueurs CSS (`"40%"`, `"120px"`)
 * pour que l'appelant choisisse son repère : le graphique en barres travaille
 * en pixels, la courbe en pourcentages de sa largeur.
 */
export function Tooltip({
  left,
  top,
  children,
}: {
  left: string;
  top: string;
  children: ReactNode;
}) {
  return (
    <div
      role="tooltip"
      className="pointer-events-none absolute z-20 -translate-x-1/2 -translate-y-[calc(100%+8px)] rounded-lg border border-ink-700 bg-ink-850 px-3 py-2 text-xs whitespace-nowrap text-ink-100 shadow-xl"
      style={{ left, top }}
    >
      {children}
    </div>
  );
}
