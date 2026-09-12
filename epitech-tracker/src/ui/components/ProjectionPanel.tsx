import { Link } from 'react-router-dom';
import type { Pace, Projection, RoadblockProjection } from '../../domain/projection';
import { RECENT_WINDOW_DAYS } from '../../domain/projection';
import { formatDate } from '../../domain/dates';
import { Card, SectionTitle } from './Primitives';
import { formatCredits } from '../labels';

/** Le rythme, dit en toutes lettres : deux rythmes donnent deux dates. */
function paceSentence(pace: Pace): string {
  if (pace.basis === 'none') {
    return 'Aucun projet validé et daté : aucun rythme mesurable.';
  }
  const rate = (pace.creditsPerDay * 30).toFixed(1).replace('.0', '');
  if (pace.basis === 'recent') {
    return `Rythme récent : ${formatCredits(pace.credits)} crédit(s) sur ${pace.days} jour(s), soit ~${rate} crédits par mois.`;
  }
  return `Rien de validé depuis ${RECENT_WINDOW_DAYS} jours — rythme calculé depuis la première validation : ${formatCredits(pace.credits)} crédit(s) en ${pace.days} jour(s), soit ~${rate} crédits par mois.`;
}

function DeadlineDelta({ days }: { days: number }) {
  if (days > 0) {
    return (
      <span className="shrink-0 rounded-full border border-bad/30 bg-bad/10 px-2 py-0.5 text-xs text-bad">
        {days} jour(s) après la date de fin
      </span>
    );
  }
  return (
    <span className="shrink-0 rounded-full border border-ok/30 bg-ok/10 px-2 py-0.5 text-xs text-ok">
      {-days} jour(s) d’avance
    </span>
  );
}

/** Une ligne de projection, en une phrase compréhensible sans le tableau. */
export function ProjectionLine({ item }: { item: RoadblockProjection }) {
  switch (item.status) {
    case 'validated':
      return <span className="text-sm text-ok">Validé</span>;
    case 'unreachable':
      return (
        <span className="text-sm text-bad">
          Hors de portée — il manque {formatCredits(item.remainingCredits)} crédit(s) que ce
          Roadblock ne peut plus fournir
        </span>
      );
    case 'no_pace':
      return (
        <span className="text-sm text-ink-400">
          Pas de date : aucun rythme mesurable pour l’instant
        </span>
      );
    case 'projected':
      return (
        <span className="text-sm text-ink-100">
          {formatDate(item.date)}
          <span className="text-ink-400"> · dans {item.daysAway} jour(s)</span>
        </span>
      );
  }
}

export function ProjectionPanel({ projection }: { projection: Projection }) {
  const { pace, cursus, roadblocks } = projection;
  const pending = roadblocks.filter((r) => r.status !== 'validated');

  return (
    <section>
      <SectionTitle>Projection</SectionTitle>
      <Card>
        <p className="mb-4 rounded-lg border border-ink-800 bg-ink-850 px-4 py-3 text-xs text-ink-300">
          <span className="mb-1 block text-ink-400">
            Ces dates portent sur l’année affichée, pas sur tout le cursus.
          </span>
          <strong className="text-ink-100">Ce sont des extrapolations, pas des prédictions.</strong>{' '}
          Elles prolongent ton rythme passé et ne tiennent compte ni des vacances, ni des
          soutenances, ni de la difficulté des modules à venir. Les Roadblocks se suivent : la
          date de chacun inclut les crédits de ceux qui le précèdent. {paceSentence(pace)}
        </p>

        {cursus.status === 'validated' ? (
          <p className="text-sm text-ok">Tous les seuils sont atteints.</p>
        ) : cursus.status === 'projected' ? (
          <div className="mb-5">
            <p className="text-xs text-ink-400 uppercase">
              Fin de l’année courante au rythme actuel
            </p>
            <p className="mt-1 text-3xl font-semibold tabular-nums text-ink-100">
              {formatDate(cursus.date)}
            </p>
            <p className="mt-1 text-xs text-ink-400">
              {formatCredits(cursus.remainingCredits)} crédit(s) restants · dans {cursus.daysAway}{' '}
              jour(s)
            </p>
          </div>
        ) : (
          <p className="mb-5 text-sm text-ink-400">
            Pas de date de fin d’année : il faut au moins un projet validé et daté pour mesurer un
            rythme.
          </p>
        )}

        {pending.length > 0 && (
          <ul className="flex flex-col divide-y divide-ink-800">
            {pending.map((item) => (
              <li key={item.id} className="flex flex-wrap items-center gap-3 py-2.5">
                <span className="min-w-0 flex-1">
                  <Link
                    to={`/roadblocks/${item.id}`}
                    className="block truncate text-sm text-ink-300 hover:text-ink-100"
                  >
                    {item.name}
                  </Link>
                  {item.status === 'projected' &&
                    item.cumulativeCredits !== item.remainingCredits && (
                      <span className="block text-xs text-ink-400">
                        {formatCredits(item.remainingCredits)} crédit(s) ici, {formatCredits(item.cumulativeCredits)} en
                        cumulé depuis aujourd’hui
                      </span>
                    )}
                </span>
                <ProjectionLine item={item} />
                {item.vsDeadline !== null && <DeadlineDelta days={item.vsDeadline} />}
              </li>
            ))}
          </ul>
        )}
      </Card>
    </section>
  );
}
