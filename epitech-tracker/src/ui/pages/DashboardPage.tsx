import { Link } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { urgentProjects } from '../../domain/priorities';
import { StatTile } from '../components/StatTile';
import { ProgressBar } from '../components/ProgressBar';
import { Card, EmptyState, PageHeader, SectionTitle } from '../components/Primitives';
import { StatusBadge } from '../components/Badge';
import { formatCredits, formatDaysLeft, formatPercent, PRIORITY_DOT } from '../labels';
import { AlertList } from '../components/AlertList';
import { PromotionPanel } from '../components/PromotionPanel';

export function DashboardPage() {
  const { view, stats, alerts, currentYear } = useCurriculum();
  const urgent = urgentProjects(view, 5);

  if (view.roadblocks.length === 0) {
    return (
      <>
        <PageHeader title="Dashboard" />
        <EmptyState
          title="Aucun Roadblock enregistré"
          hint="Commence par créer un Roadblock, puis ses modules et leurs projets."
        />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle={
          currentYear === null
            ? 'Où j’en suis, ce qu’il me reste, ce qui est urgent.'
            : `${currentYear.level === null ? '' : `${currentYear.level} · `}${currentYear.label} — où j’en suis, ce qu’il me reste, ce qui est urgent.`
        }
      />

      <PromotionPanel compact />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile
          label="Crédits"
          value={formatCredits(stats.credits.obtained)}
          total={formatCredits(stats.credits.total)}
          progress={stats.progress}
          detail={`${formatCredits(stats.credits.remaining)} crédit(s) restant(s)`}
        />
        <StatTile
          label="Modules"
          value={stats.modules.validated}
          total={stats.modules.total}
          progress={stats.modules.total > 0 ? stats.modules.validated / stats.modules.total : null}
          tone="ok"
          detail={`${stats.modules.inProgress} en cours`}
        />
        <StatTile
          label="Projets"
          value={stats.projects.done}
          total={stats.projects.total}
          progress={stats.projects.total > 0 ? stats.projects.done / stats.projects.total : null}
          tone="busy"
          detail={`${stats.projects.remaining} restant(s)`}
        />
        <StatTile
          label="Roadblocks"
          value={stats.roadblocks.validated}
          total={stats.roadblocks.total}
          progress={
            stats.roadblocks.total > 0 ? stats.roadblocks.validated / stats.roadblocks.total : null
          }
          tone="ok"
          detail={`${stats.roadblocks.inProgress} en cours`}
        />
      </div>

      <div className="mt-4">
        <Card>
          <div className="flex items-end justify-between gap-4">
            <div>
              <p className="text-xs font-medium tracking-wide text-ink-400 uppercase">
                Progression globale
              </p>
              <p className="mt-1 text-4xl font-semibold tabular-nums text-ink-100">
                {formatPercent(stats.progress)}
              </p>
            </div>
            <p className="text-sm text-ink-400">
              {formatCredits(stats.credits.obtained)} / {formatCredits(stats.credits.total)} crédits
            </p>
          </div>
          <div className="mt-4">
            <ProgressBar value={stats.progress} />
          </div>
        </Card>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-2">
        <section>
          <SectionTitle
            action={
              <Link to="/projects" className="text-xs text-accent-soft hover:underline">
                Tous les projets
              </Link>
            }
          >
            À faire en priorité
          </SectionTitle>
          {urgent.length === 0 ? (
            <EmptyState title="Rien d’urgent — tout est rendu." />
          ) : (
            <ul className="flex flex-col gap-2">
              {urgent.map((project) => (
                <li key={project.id}>
                  <Link
                    to={`/projects/${project.id}`}
                    className="flex items-center gap-3 rounded-xl border border-ink-800 bg-ink-900 px-4 py-3 transition-colors hover:border-ink-700"
                  >
                    <span aria-hidden className="text-base">{PRIORITY_DOT[project.priority]}</span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm text-ink-100">{project.name}</span>
                      <span className="block truncate text-xs text-ink-400">{project.moduleName}</span>
                    </span>
                    <span
                      className={`shrink-0 text-xs tabular-nums ${
                        project.isLate ? 'text-bad' : project.isDueSoon ? 'text-busy' : 'text-ink-400'
                      }`}
                    >
                      {formatDaysLeft(project.daysLeft)}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section>
          <SectionTitle>Alertes</SectionTitle>
          <AlertList alerts={alerts} limit={6} />
        </section>
      </div>

      <section className="mt-8">
        <SectionTitle
          action={
            <Link to="/roadblocks" className="text-xs text-accent-soft hover:underline">
              Détail
            </Link>
          }
        >
          Roadblocks
        </SectionTitle>
        <div className="flex flex-col gap-2">
          {view.roadblocks.map((roadblock) => (
            <Link
              key={roadblock.id}
              to={`/roadblocks/${roadblock.id}`}
              className="rounded-xl border border-ink-800 bg-ink-900 px-4 py-3 transition-colors hover:border-ink-700"
            >
              <div className="flex flex-wrap items-center gap-3">
                <span className="flex-1 truncate text-sm text-ink-100">{roadblock.name}</span>
                <StatusBadge status={roadblock.status} />
                <span className="text-xs tabular-nums text-ink-400">
                  {formatCredits(roadblock.obtainedCredits)} / {formatCredits(roadblock.requiredCredits)} crédits
                </span>
              </div>
              <div className="mt-2">
                <ProgressBar
                  value={roadblock.progress}
                  tone={roadblock.status === 'validated' ? 'ok' : roadblock.status === 'failed' ? 'bad' : 'accent'}
                  showLabel
                />
              </div>
            </Link>
          ))}
        </div>
      </section>
    </>
  );
}
