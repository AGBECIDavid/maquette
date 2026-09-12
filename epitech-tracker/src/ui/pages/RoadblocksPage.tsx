import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { MoveButtons } from '../components/MoveButtons';
import { filterRoadblocks } from '../../domain/search';
import { formatDate } from '../../domain/dates';
import { Button, EmptyState, PageHeader } from '../components/Primitives';
import { ProgressBar } from '../components/ProgressBar';
import { StatusBadge } from '../components/Badge';
import { Select, TextInput } from '../components/Form';
import { RoadblockForm } from '../forms/RoadblockForm';
import { formatCredits } from '../labels';

export function RoadblocksPage() {
  const { view, data, moveRoadblock } = useCurriculum();
  const [query, setQuery] = useState('');
  const [yearId, setYearId] = useState<string>('all');
  const [creating, setCreating] = useState(false);

  const roadblocks = useMemo(
    () => filterRoadblocks(view.roadblocks, query, yearId),
    [view.roadblocks, query, yearId],
  );
  const filtered = roadblocks.length !== view.roadblocks.length;

  return (
    <>
      <PageHeader
        title="Roadblocks"
        subtitle={`${view.roadblocks.length} Roadblock(s) — ${view.roadblocks.filter((r) => r.status === 'validated').length} validé(s)`}
        action={
          <Button variant="primary" onClick={() => setCreating(true)}>
            + Roadblock
          </Button>
        }
      />

      <div className="mb-5 flex flex-wrap gap-3">
        <div className="w-full sm:w-64">
          <TextInput value={query} onChange={setQuery} placeholder="Rechercher…" />
        </div>
        <div className="w-full sm:w-48">
          <Select
            value={yearId}
            onChange={setYearId}
            options={[
              { value: 'all', label: 'Toutes les années' },
              ...data.years.map((y) => ({ value: y.id, label: y.label })),
            ]}
          />
        </div>
      </div>

      {roadblocks.length === 0 ? (
        <EmptyState title="Aucun Roadblock ne correspond." />
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {roadblocks.map((roadblock, index) => (
            <div
              key={roadblock.id}
              className="rounded-xl border border-ink-800 bg-ink-900 transition-colors hover:border-ink-700"
            >
              <Link to={`/roadblocks/${roadblock.id}`} className="block p-5 pb-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <h3 className="truncate text-base font-medium text-ink-100">{roadblock.name}</h3>
                  <p className="mt-0.5 text-xs text-ink-400">{roadblock.yearLabel}</p>
                </div>
                <StatusBadge status={roadblock.status} />
              </div>

              {roadblock.description !== '' && (
                <p className="mt-2 line-clamp-2 text-sm text-ink-400">{roadblock.description}</p>
              )}

              <div className="mt-4">
                <ProgressBar
                  value={roadblock.progress}
                  tone={roadblock.status === 'validated' ? 'ok' : roadblock.status === 'failed' ? 'bad' : 'accent'}
                  showLabel
                />
              </div>

              <dl className="mt-4 grid grid-cols-3 gap-3 text-center">
                <div>
                  <dt className="text-xs text-ink-400">Crédits</dt>
                  <dd className="text-sm tabular-nums text-ink-100">
                    {formatCredits(roadblock.obtainedCredits)} / {formatCredits(roadblock.requiredCredits)}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-ink-400">Modules</dt>
                  <dd className="text-sm tabular-nums text-ink-100">
                    {roadblock.validatedModules} / {roadblock.totalModules}
                  </dd>
                </div>
                <div>
                  <dt className="text-xs text-ink-400">Fin</dt>
                  <dd className="text-sm tabular-nums text-ink-100">{formatDate(roadblock.endDate)}</dd>
                </div>
              </dl>
              </Link>

              {/* Le réordonnancement suit l'ordre réel du cursus, pas celui de
                  la saisie. Désactivé pendant un filtre : déplacer d'un cran
                  dans une liste filtrée sauterait les éléments masqués. */}
              <div className="flex items-center justify-between border-t border-ink-800 px-4 py-2">
                <span className="text-xs text-ink-400">Rang {roadblock.order}</span>
                {filtered ? (
                  <span className="text-xs text-ink-600">Réordonner : retire les filtres</span>
                ) : (
                  <MoveButtons
                    label={roadblock.name}
                    canUp={index > 0}
                    canDown={index < roadblocks.length - 1}
                    onMove={(direction) => moveRoadblock(roadblock.id, direction)}
                  />
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {creating && <RoadblockForm onClose={() => setCreating(false)} />}
    </>
  );
}
