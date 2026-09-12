import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { EMPTY_MODULE_FILTERS, filterModules, type ModuleFilters } from '../../domain/search';
import { Button, EmptyState, PageHeader } from '../components/Primitives';
import { ProgressBar } from '../components/ProgressBar';
import { StatusBadge } from '../components/Badge';
import { Select, TextInput } from '../components/Form';
import { ModuleForm } from '../forms/ModuleForm';
import { formatCredits, PROGRESS_STATUS_LABEL } from '../labels';

export function ModulesPage() {
  const { view } = useCurriculum();
  const [filters, setFilters] = useState<ModuleFilters>(EMPTY_MODULE_FILTERS);
  const [creating, setCreating] = useState(false);

  const modules = useMemo(() => filterModules(view.modules, filters), [view.modules, filters]);
  const set = <K extends keyof ModuleFilters>(key: K, value: ModuleFilters[K]) =>
    setFilters((current) => ({ ...current, [key]: value }));

  return (
    <>
      <PageHeader
        title="Modules"
        subtitle={`${view.modules.length} module(s) — ${view.modules.filter((m) => m.status === 'validated').length} validé(s)`}
        action={<Button variant="primary" onClick={() => setCreating(true)}>+ Module</Button>}
      />

      <div className="mb-5 flex flex-wrap gap-3">
        <div className="w-full sm:w-64">
          <TextInput value={filters.query} onChange={(v) => set('query', v)} placeholder="Rechercher…" />
        </div>
        <div className="w-full sm:w-44">
          <Select
            value={filters.status}
            onChange={(v) => set('status', v)}
            options={[
              { value: 'all', label: 'Tous les statuts' },
              ...(['upcoming', 'in_progress', 'validated', 'failed'] as const).map((s) => ({
                value: s,
                label: PROGRESS_STATUS_LABEL[s],
              })),
            ]}
          />
        </div>
        <div className="w-full sm:w-56">
          <Select
            value={filters.roadblockId}
            onChange={(v) => set('roadblockId', v)}
            options={[
              { value: 'all', label: 'Tous les Roadblocks' },
              ...view.roadblocks.map((r) => ({ value: r.id, label: r.name })),
            ]}
          />
        </div>
      </div>

      {modules.length === 0 ? (
        <EmptyState title="Aucun module ne correspond." />
      ) : (
        <div className="grid gap-3 lg:grid-cols-2 2xl:grid-cols-3">
          {modules.map((module) => (
            <Link
              key={module.id}
              to={`/modules/${module.id}`}
              className="rounded-xl border border-ink-800 bg-ink-900 p-5 transition-colors hover:border-ink-700"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <h3 className="truncate text-base font-medium text-ink-100">{module.name}</h3>
                  <p className="mt-0.5 truncate text-xs text-ink-400">{module.roadblockName}</p>
                </div>
                <StatusBadge status={module.status} />
              </div>

              <div className="mt-4">
                <ProgressBar
                  value={module.progress}
                  tone={module.status === 'validated' ? 'ok' : 'accent'}
                  showLabel
                />
              </div>

              <p className="mt-3 text-xs text-ink-400">
                {formatCredits(module.obtainedCredits)} / {formatCredits(module.credits)} crédits ·{' '}
                {module.validatedProjects} / {module.totalProjects} projets
              </p>
            </Link>
          ))}
        </div>
      )}

      {creating && <ModuleForm onClose={() => setCreating(false)} />}
    </>
  );
}
