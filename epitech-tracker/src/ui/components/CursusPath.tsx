import { useMemo } from 'react';
import { useCurriculum } from '../../store/CurriculumContext';
import { dashboardStats, scopeToYear } from '../../domain/selectors';
import { ProgressBar } from './ProgressBar';
import { Card, SectionTitle } from './Primitives';
import { formatCredits, formatPercent } from '../labels';

/**
 * Le parcours, année par année.
 *
 * C'est le seul endroit où le cumul de tout le cursus a du sens : ailleurs,
 * « où j'en suis » veut dire « cette année ».
 */
export function CursusPath() {
  const { data, fullView, currentYear, setCurrentYear } = useCurriculum();

  const rows = useMemo(() => {
    return [...data.years]
      .sort((a, b) => a.order - b.order)
      .map((year) => ({ year, stats: dashboardStats(scopeToYear(fullView, year.id)) }));
  }, [data.years, fullView]);

  const total = useMemo(() => dashboardStats(fullView), [fullView]);
  if (rows.length <= 1) return null;

  return (
    <section className="mt-8">
      <SectionTitle>Parcours</SectionTitle>
      <Card>
        <ul className="flex flex-col divide-y divide-ink-800">
          {rows.map(({ year, stats }) => (
            <li key={year.id} className="py-3">
              <div className="flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={() => setCurrentYear(year.id)}
                  className="min-w-0 flex-1 text-left"
                >
                  <span className="block text-sm text-ink-100">
                    {year.level ?? '—'} <span className="text-ink-400">· {year.label}</span>
                    {year.id === currentYear?.id && (
                      <span className="ml-2 rounded-full border border-accent/30 bg-accent/10 px-2 py-0.5 text-xs text-accent-soft">
                        année courante
                      </span>
                    )}
                  </span>
                  <span className="block text-xs text-ink-400">
                    {formatCredits(stats.credits.obtained)} / {formatCredits(stats.credits.total)}{' '}
                    crédits · {stats.roadblocks.validated} / {stats.roadblocks.total} Roadblocks
                  </span>
                </button>
                <span className="w-36 shrink-0">
                  <ProgressBar
                    value={stats.progress}
                    tone={stats.progress === 1 ? 'ok' : 'accent'}
                    showLabel
                  />
                </span>
              </div>
            </li>
          ))}
        </ul>

        <p className="mt-4 border-t border-ink-800 pt-4 text-sm text-ink-300">
          Cumul du cursus :{' '}
          <strong className="text-ink-100">
            {formatCredits(total.credits.obtained)} / {formatCredits(total.credits.total)} crédits
          </strong>{' '}
          <span className="text-ink-400">({formatPercent(total.progress)})</span>
        </p>
      </Card>
    </section>
  );
}
