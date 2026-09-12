import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { formatDate } from '../../domain/dates';
import { Button, Card, EmptyState, PageHeader } from '../components/Primitives';
import { LateBadge, PriorityBadge, ProjectStatusBadge, SoonBadge } from '../components/Badge';
import { ProjectForm } from '../forms/ProjectForm';
import { formatCredits, formatDaysLeft } from '../labels';
import type { ProjectStatus } from '../../domain/types';
import { PROJECT_STATUS_LABEL } from '../labels';

const NEXT_STATUS: Record<ProjectStatus, ProjectStatus | null> = {
  todo: 'in_progress',
  in_progress: 'done',
  done: 'validated',
  validated: null,
};

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-ink-800 py-2 last:border-0">
      <dt className="text-xs text-ink-400">{label}</dt>
      <dd className="text-sm tabular-nums text-ink-100">{value}</dd>
    </div>
  );
}

export function ProjectDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { view, data, removeProject, upsertProject, today } = useCurriculum();
  const [editing, setEditing] = useState(false);

  const project = view.projects.find((p) => p.id === id);
  if (project === undefined) return <EmptyState title="Projet introuvable." />;
  const raw = data.projects.find((p) => p.id === project.id);
  const next = NEXT_STATUS[project.status];

  return (
    <>
      <Link
        to={`/modules/${project.moduleId}`}
        className="mb-3 inline-block text-xs text-ink-400 hover:text-ink-100"
      >
        ← {project.moduleName}
      </Link>

      <PageHeader
        title={project.name}
        subtitle={`${project.roadblockName} · ${project.moduleName}`}
        action={
          <div className="flex flex-wrap gap-2">
            {next !== null && raw !== undefined && (
              <Button
                variant="primary"
                onClick={() =>
                  upsertProject({
                    ...raw,
                    status: next,
                    completedAt:
                      (next === 'done' || next === 'validated') && raw.completedAt === null
                        ? today
                        : raw.completedAt,
                  })
                }
              >
                Passer à « {PROJECT_STATUS_LABEL[next]} »
              </Button>
            )}
            <Button onClick={() => setEditing(true)}>Modifier</Button>
            <Button
              variant="danger"
              onClick={() => {
                if (window.confirm(`Supprimer « ${project.name} » ?`)) {
                  removeProject(project.id);
                  navigate('/projects');
                }
              }}
            >
              Supprimer
            </Button>
          </div>
        }
      />

      <div className="flex flex-wrap items-center gap-2">
        <ProjectStatusBadge status={project.status} />
        <PriorityBadge priority={project.priority} />
        {project.isLate && <LateBadge />}
        {project.isDueSoon && <SoonBadge />}
      </div>

      <div className="mt-5 grid gap-3 lg:grid-cols-2">
        <Card>
          <dl>
            <Row label="Crédits" value={formatCredits(project.credits)} />
            <Row label="Crédits obtenus" value={formatCredits(project.obtainedCredits)} />
            <Row label="Note" value={project.grade ?? '—'} />
            <Row
              label="Poids"
              value={project.creditsOverride === null ? 'Part égale du module' : 'Forcé'}
            />
          </dl>
        </Card>
        <Card>
          <dl>
            <Row label="Début" value={formatDate(project.startDate)} />
            <Row label="Deadline" value={formatDate(project.deadline)} />
            <Row label="Fin réelle" value={formatDate(project.completedAt)} />
            <Row label="Temps restant" value={formatDaysLeft(project.daysLeft)} />
          </dl>
        </Card>
      </div>

      {project.description !== '' && (
        <p className="mt-4 text-sm text-ink-300">{project.description}</p>
      )}

      {project.repoUrl !== null && (
        <a
          href={project.repoUrl}
          target="_blank"
          rel="noreferrer noopener"
          className="mt-4 inline-block text-sm text-accent-soft hover:underline"
        >
          {project.repoUrl}
        </a>
      )}

      {project.notes !== '' && (
        <Card className="mt-4">
          <p className="text-xs text-ink-400 uppercase">Commentaires</p>
          <p className="mt-2 whitespace-pre-wrap text-sm text-ink-300">{project.notes}</p>
        </Card>
      )}

      {editing && raw !== undefined && <ProjectForm initial={raw} onClose={() => setEditing(false)} />}
    </>
  );
}
