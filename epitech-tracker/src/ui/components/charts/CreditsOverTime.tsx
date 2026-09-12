import { useMemo, useState } from 'react';
import type { CumulativePoint } from '../../../domain/stats';
import { daysBetween, formatDate } from '../../../domain/dates';
import { formatCredits } from '../../labels';
import { ChartFrame, Tooltip } from './ChartFrame';

const VIEW_W = 600;
const VIEW_H = 180;

/**
 * Crédits cumulés dans le temps — une seule série, donc pas de légende : le
 * titre la nomme. L'axe des abscisses est le temps réel, pas le rang des
 * projets : deux validations le même jour ne doivent pas écarter la courbe.
 */
export function CreditsOverTime({
  points,
  undated,
}: {
  points: CumulativePoint[];
  undated: number;
}) {
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);

  const geometry = useMemo(() => {
    if (points.length === 0) return null;
    const first = points[0]!;
    const last = points[points.length - 1]!;
    const span = Math.max(daysBetween(first.date, last.date), 1);
    const maxCredits = Math.max(...points.map((p) => p.credits), 1);

    const coords = points.map((point) => ({
      point,
      // Part horizontale et verticale, entre 0 et 1.
      fx: daysBetween(first.date, point.date) / span,
      fy: point.credits / maxCredits,
    }));

    return { coords, maxCredits };
  }, [points]);

  if (geometry === null) {
    return (
      <ChartFrame title="Crédits validés dans le temps">
        <p className="text-sm text-ink-400">
          Aucun projet validé avec une date de fin : la courbe n’a rien à tracer.
        </p>
      </ChartFrame>
    );
  }

  const { coords, maxCredits } = geometry;
  const toX = (fx: number) => fx * VIEW_W;
  const toY = (fy: number) => VIEW_H - fy * (VIEW_H - 12) - 6;

  // Une marche : les crédits ne montent qu'au moment d'une validation.
  const line = coords
    .map((c, index) => {
      const x = toX(c.fx);
      const y = toY(c.fy);
      const previous = coords[index - 1];
      if (previous === undefined) return `M ${x} ${y}`;
      return `L ${x} ${toY(previous.fy)} L ${x} ${y}`;
    })
    .join(' ');

  const area = `${line} L ${VIEW_W} ${toY(coords[coords.length - 1]!.fy)} L ${VIEW_W} ${VIEW_H} L 0 ${VIEW_H} Z`;
  const hovered = hoverIndex === null ? undefined : coords[hoverIndex];

  return (
    <ChartFrame
      title="Crédits validés dans le temps"
      note={
        undated > 0
          ? `${formatCredits(undated)} crédit(s) validés sans date de fin ne figurent pas sur la courbe.`
          : undefined
      }
    >
      <div
        className="relative"
        onMouseLeave={() => setHoverIndex(null)}
        onMouseMove={(event) => {
          const box = event.currentTarget.getBoundingClientRect();
          const ratio = (event.clientX - box.left) / box.width;
          let nearest = 0;
          for (let i = 1; i < coords.length; i += 1) {
            if (Math.abs(coords[i]!.fx - ratio) < Math.abs(coords[nearest]!.fx - ratio)) {
              nearest = i;
            }
          }
          setHoverIndex(nearest);
        }}
      >
        <svg
          viewBox={`0 0 ${VIEW_W} ${VIEW_H}`}
          preserveAspectRatio="none"
          className="h-44 w-full"
          role="img"
          aria-label={`Crédits validés cumulés, de ${formatDate(coords[0]!.point.date)} à ${formatDate(coords[coords.length - 1]!.point.date)}`}
        >
          {/* Grille : filets pleins, un ton au-dessus du fond. Jamais en pointillés. */}
          {[0, 0.5, 1].map((step) => (
            <line
              key={step}
              x1="0"
              x2={VIEW_W}
              y1={toY(step)}
              y2={toY(step)}
              stroke="var(--color-ink-800)"
              strokeWidth="1"
              vectorEffect="non-scaling-stroke"
            />
          ))}
          <path d={area} fill="var(--color-accent)" opacity="0.12" />
          <path
            d={line}
            fill="none"
            stroke="var(--color-accent)"
            strokeWidth="2"
            strokeLinejoin="round"
            vectorEffect="non-scaling-stroke"
          />
          {hovered !== undefined && (
            <line
              x1={toX(hovered.fx)}
              x2={toX(hovered.fx)}
              y1="0"
              y2={VIEW_H}
              stroke="var(--color-ink-600)"
              strokeWidth="1"
              vectorEffect="non-scaling-stroke"
            />
          )}
        </svg>

        {/* Le point de survol est en HTML : un cercle SVG serait déformé par
            l'étirement horizontal du viewBox. */}
        {hovered !== undefined && (
          <span
            className="pointer-events-none absolute size-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-accent ring-2 ring-ink-900"
            style={{
              left: `${hovered.fx * 100}%`,
              top: `${(toY(hovered.fy) / VIEW_H) * 100}%`,
            }}
          />
        )}

        {hovered !== undefined && (
          <Tooltip left={`${hovered.fx * 100}%`} top={`${(toY(hovered.fy) / VIEW_H) * 100}%`}>
            <span className="block font-medium">{formatDate(hovered.point.date)}</span>
            <span className="block text-ink-300">
              {formatCredits(hovered.point.credits)} crédits cumulés
            </span>
            <span className="block text-ink-400">{hovered.point.projects} projets validés</span>
          </Tooltip>
        )}

        <div className="mt-2 flex justify-between text-xs tabular-nums text-ink-400">
          <span>{formatDate(coords[0]!.point.date)}</span>
          <span>maximum : {formatCredits(maxCredits)} crédits</span>
          <span>{formatDate(coords[coords.length - 1]!.point.date)}</span>
        </div>
      </div>
    </ChartFrame>
  );
}
