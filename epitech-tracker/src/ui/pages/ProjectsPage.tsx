import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { EMPTY_PROJECT_FILTERS, filterProjects, type ProjectFilters } from '../../domain/search';
import { formatDate } from '../../domain/dates';
import { Button, EmptyState, PageHeader } from '../components/Primitives';
import { LateBadge, PriorityBadge, ProjectStatusBadge, SoonBadge } from '../components/Badge';
import { Select, TextInput } from '../components/Form';
import { ProjectForm } from '../forms/ProjectForm';
import { formatCredits, formatDaysLeft, PRIORITY_LABEL, PROJECT_STATUS_LABEL } from '../labels';

export function ProjectsPage() {
  const { view } = useCurriculum();
  const [filters, setFilters] = useState<ProjectFilters>(EMPTY_PROJECT_FILTERS);
  const [creating, setCreating] = useState(false);

  const projects = useMemo(() => filterProjects(view.projects, filters), [view.projects, filters]);
  const set = <K extends keyof ProjectFilters>(key: K, value: ProjectFilters[K]) =>
    setFilters((current) => ({ ...current, [key]: value }));

  return (
    <>
      <PageHeader
        title="Projets"
        subtitle={`${view.projects.length} projet(s) — ${view.projects.filter((p) => p.isLate).length} en retard`}
        action={<Button variant="primary" onClick={() => setCreating(true)}>+ Projet</Button>}
      />

      <div className="mb-5 flex flex-wrap gap-3">
        <div className="w-full sm:w-56">
          <TextInput value={filters.query} onChange={(v) => set('query', v)} placeholder="Rechercher…" />
        </div>
        <div className="w-full sm:w-40">
          <Select
            value={filters.status}
            onChange={(v) => set('status', v)}
            options={[
              { value: 'all', label: 'Tous les statuts' },
              ...(['todo', 'in_progress', 'done', 'validated'] as const).map((s) => ({
                value: s,
                label: PROJECT_STATUS_LABEL[s],
              })),
            ]}
          />
        </div>
        <div className="w-full sm:w-40">
          <Select
            value={filters.priority}
            onChange={(v) => set('priority', v)}
            options={[
              { value: 'all', label: 'Toutes priorités' },
              ...(['critical', 'high', 'normal', 'low'] as const).map((p) => ({
                value: p,
                label: PRIORITY_LABEL[p],
              })),
            ]}
          />
        </div>
        <div className="w-full sm:w-52">
          <Select
            value={filters.roadblockId}
            onChange={(v) => set('roadblockId', v)}
            options={[
              { value: 'all', label: 'Tous les Roadblocks' },
              ...view.roadblocks.map((r) => ({ value: r.id, label: r.name })),
            ]}
          />
        </div>
        <label className="flex items-center gap-2 text-sm text-ink-300">
          <input
            type="checkbox"
            checked={filters.lateOnly}
            onChange={(event) => set('lateOnly', event.target.checked)}
            className="size-4 accent-[var(--color-accent)]"
          />
          En retard uniquement
        </label>
      </div>

      {projects.length === 0 ? (
        <EmptyState title="Aucun projet ne correspond." />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-ink-800">
          <table className="w-full min-w-[48rem] text-sm">
            <thead className="bg-ink-900 text-left text-xs text-ink-400 uppercase">
              <tr>
                <th className="px-4 py-3 font-medium">Projet</th>
                <th className="px-4 py-3 font-medium">Module</th>
                <th className="px-4 py-3 font-medium">Statut</th>
                <th className="px-4 py-3 font-medium">Priorité</th>
                <th className="px-4 py-3 font-medium">Crédits</th>
                <th className="px-4 py-3 font-medium">Deadline</th>
                <th className="px-4 py-3 font-medium">Échéance</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-ink-800 bg-ink-950/40">
              {projects.map((project) => (
                <tr key={project.id} className="hover:bg-ink-900">
                  <td className="px-4 py-3">
                    <Link to={`/projects/${project.id}`} className="flex items-center gap-2 text-ink-100 hover:underline">
                      {project.name}
                      {project.isLate && <LateBadge />}
                      {project.isDueSoon && <SoonBadge />}
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-ink-400">{project.moduleName}</td>
                  <td className="px-4 py-3"><ProjectStatusBadge status={project.status} /></td>
                  <td className="px-4 py-3"><PriorityBadge priority={project.priority} /></td>
                  <td className="px-4 py-3 tabular-nums text-ink-300">{formatCredits(project.credits)}</td>
                  <td className="px-4 py-3 tabular-nums text-ink-300">{formatDate(project.deadline)}</td>
                  <td
                    className={`px-4 py-3 tabular-nums ${
                      project.isLate ? 'text-bad' : project.isDueSoon ? 'text-busy' : 'text-ink-400'
                    }`}
                  >
                    {formatDaysLeft(project.daysLeft)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {creating && <ProjectForm onClose={() => setCreating(false)} />}
    </>
  );
}
