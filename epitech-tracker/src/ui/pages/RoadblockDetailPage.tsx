import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { MoveButtons } from '../components/MoveButtons';
import { ProjectionLine } from '../components/ProjectionPanel';
import { buildProjection } from '../../domain/projection';
import { formatDate } from '../../domain/dates';
import { Button, Card, EmptyState, PageHeader, SectionTitle } from '../components/Primitives';
import { ProgressBar } from '../components/ProgressBar';
import { StatusBadge } from '../components/Badge';
import { RoadblockForm } from '../forms/RoadblockForm';
import { ModuleForm } from '../forms/ModuleForm';
import { formatCredits, formatPercent, PROGRESS_STATUS_ICON } from '../labels';

export function RoadblockDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { view, fullView, data, removeRoadblock, moveModule } = useCurriculum();
  const [editing, setEditing] = useState(false);
  const [addingModule, setAddingModule] = useState(false);

  const roadblock = fullView.roadblocks.find((r) => r.id === id);
  if (roadblock === undefined) {
    return <EmptyState title="Roadblock introuvable." />;
  }
  const raw = data.roadblocks.find((r) => r.id === roadblock.id);

  const projection = buildProjection(view).roadblocks.find((p) => p.id === roadblock.id);
  const missingModules = roadblock.modules.filter((m) => m.status !== 'validated');
  const blocked = roadblock.remainingCredits > roadblock.reachableCredits;

  return (
    <>
      <Link to="/roadblocks" className="mb-3 inline-block text-xs text-ink-400 hover:text-ink-100">
        ← Roadblocks
      </Link>

      <PageHeader
        title={roadblock.name}
        subtitle={`${roadblock.yearLabel} · ${formatDate(roadblock.startDate)} → ${formatDate(roadblock.endDate)}`}
        action={
          <div className="flex gap-2">
            <Button onClick={() => setEditing(true)}>Modifier</Button>
            <Button
              variant="danger"
              onClick={() => {
                if (window.confirm(`Supprimer « ${roadblock.name} », ses modules et leurs projets ?`)) {
                  removeRoadblock(roadblock.id);
                  navigate('/roadblocks');
                }
              }}
            >
              Supprimer
            </Button>
          </div>
        }
      />

      <div className="grid gap-3 sm:grid-cols-3">
        <Card>
          <p className="text-xs text-ink-400 uppercase">Progression</p>
          <p className="mt-1 text-3xl font-semibold tabular-nums text-ink-100">
            {formatPercent(roadblock.progress)}
          </p>
          <div className="mt-3">
            <ProgressBar
              value={roadblock.progress}
              tone={roadblock.status === 'validated' ? 'ok' : roadblock.status === 'failed' ? 'bad' : 'accent'}
            />
          </div>
        </Card>
        <Card>
          <p className="text-xs text-ink-400 uppercase">Crédits</p>
          <p className="mt-1 text-3xl font-semibold tabular-nums text-ink-100">
            {formatCredits(roadblock.obtainedCredits)}
            <span className="text-base text-ink-400"> / {formatCredits(roadblock.requiredCredits)}</span>
          </p>
          <p className="mt-3 text-xs text-ink-400">
            {formatCredits(roadblock.remainingCredits)} restant(s) · {formatCredits(roadblock.reachableCredits)} encore atteignable(s)
          </p>
        </Card>
        <Card>
          <p className="text-xs text-ink-400 uppercase">Statut</p>
          <div className="mt-2">
            <StatusBadge status={roadblock.status} />
          </div>
          <p className="mt-3 text-xs text-ink-400">
            {roadblock.validatedModules} / {roadblock.totalModules} modules validés
          </p>
        </Card>
      </div>

      {/* « Pourquoi mon Roadblock n'est-il pas validé ? » — la réponse, en clair. */}
      {roadblock.status !== 'validated' && (
        <div
          className={`mt-4 rounded-xl border p-5 ${blocked ? 'border-bad/40 bg-bad/5' : 'border-ink-800 bg-ink-900'}`}
        >
          <h2 className="text-sm font-semibold text-ink-100">
            Pourquoi ce Roadblock n’est pas validé
          </h2>
          <p className="mt-2 text-sm text-ink-300">
            Il manque <strong>{formatCredits(roadblock.remainingCredits)}</strong> crédit(s) sur{' '}
            {formatCredits(roadblock.requiredCredits)}.
            {blocked
              ? ` Seuls ${formatCredits(roadblock.reachableCredits)} crédit(s) restent atteignables dans ce Roadblock : le seuil ne peut plus être atteint en l’état.`
              : ' Les modules ci-dessous portent les crédits manquants.'}
          </p>
          {projection !== undefined && projection.status !== 'validated' && (
            <p className="mt-3 flex flex-wrap items-baseline gap-2 text-sm">
              <span className="text-ink-400">Au rythme actuel :</span>
              <ProjectionLine item={projection} />
            </p>
          )}

          {missingModules.length > 0 && (
            <ul className="mt-3 flex flex-wrap gap-2">
              {missingModules.map((module) => (
                <li key={module.id}>
                  <Link
                    to={`/modules/${module.id}`}
                    className="inline-flex items-center gap-2 rounded-lg border border-ink-700 px-3 py-1.5 text-xs text-ink-300 hover:border-ink-600 hover:text-ink-100"
                  >
                    <span aria-hidden>{PROGRESS_STATUS_ICON[module.status]}</span>
                    {module.name}
                    <span className="tabular-nums text-ink-400">
                      +{formatCredits(module.remainingCredits)}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <section className="mt-8">
        <SectionTitle
          action={
            <Button onClick={() => setAddingModule(true)}>+ Module</Button>
          }
        >
          Modules
        </SectionTitle>

        {roadblock.modules.length === 0 ? (
          <EmptyState title="Aucun module dans ce Roadblock." />
        ) : (
          <ul className="flex flex-col gap-2">
            {roadblock.modules.map((module, index) => (
              <li
                key={module.id}
                className="flex items-center gap-2 rounded-xl border border-ink-800 bg-ink-900 pr-3 transition-colors hover:border-ink-700"
              >
                <Link
                  to={`/modules/${module.id}`}
                  className="flex flex-1 flex-wrap items-center gap-3 px-4 py-3"
                >
                  <span aria-hidden className="text-base">{PROGRESS_STATUS_ICON[module.status]}</span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm text-ink-100">{module.name}</span>
                    <span className="block text-xs text-ink-400">
                      {module.validatedProjects} / {module.totalProjects} projets ·{' '}
                      {formatCredits(module.obtainedCredits)} / {formatCredits(module.credits)} crédits
                    </span>
                  </span>
                  <span className="w-32 shrink-0">
                    <ProgressBar
                      value={module.progress}
                      tone={module.status === 'validated' ? 'ok' : 'accent'}
                      showLabel
                    />
                  </span>
                </Link>
                <MoveButtons
                  label={module.name}
                  canUp={index > 0}
                  canDown={index < roadblock.modules.length - 1}
                  onMove={(direction) => moveModule(module.id, direction)}
                />
              </li>
            ))}
          </ul>
        )}
      </section>

      {editing && raw !== undefined && (
        <RoadblockForm initial={raw} onClose={() => setEditing(false)} />
      )}
      {addingModule && (
        <ModuleForm roadblockId={roadblock.id} onClose={() => setAddingModule(false)} />
      )}
    </>
  );
}
