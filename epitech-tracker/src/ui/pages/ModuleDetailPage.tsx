import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { MoveButtons } from '../components/MoveButtons';
import { formatDate } from '../../domain/dates';
import { Button, Card, EmptyState, PageHeader, SectionTitle } from '../components/Primitives';
import { ProgressBar } from '../components/ProgressBar';
import { LateBadge, ProjectStatusBadge, SoonBadge, StatusBadge } from '../components/Badge';
import { ModuleForm } from '../forms/ModuleForm';
import { ProjectForm } from '../forms/ProjectForm';
import { formatCredits, formatDaysLeft, formatPercent, PROJECT_STATUS_ICON } from '../labels';

export function ModuleDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { view, data, removeModule, moveProject } = useCurriculum();
  const [editing, setEditing] = useState(false);
  const [addingProject, setAddingProject] = useState(false);

  const module = view.modules.find((m) => m.id === id);
  if (module === undefined) return <EmptyState title="Module introuvable." />;
  const raw = data.modules.find((m) => m.id === module.id);

  return (
    <>
      <Link
        to={`/roadblocks/${module.roadblockId}`}
        className="mb-3 inline-block text-xs text-ink-400 hover:text-ink-100"
      >
        ← {module.roadblockName}
      </Link>

      <PageHeader
        title={module.name}
        subtitle={`${formatDate(module.startDate)} → ${formatDate(module.endDate)}`}
        action={
          <div className="flex gap-2">
            <Button onClick={() => setEditing(true)}>Modifier</Button>
            <Button
              variant="danger"
              onClick={() => {
                if (window.confirm(`Supprimer « ${module.name} » et ses projets ?`)) {
                  removeModule(module.id);
                  navigate('/modules');
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
            {formatPercent(module.progress)}
          </p>
          <div className="mt-3">
            <ProgressBar value={module.progress} tone={module.status === 'validated' ? 'ok' : 'accent'} />
          </div>
        </Card>
        <Card>
          <p className="text-xs text-ink-400 uppercase">Crédits</p>
          <p className="mt-1 text-3xl font-semibold tabular-nums text-ink-100">
            {formatCredits(module.obtainedCredits)}
            <span className="text-base text-ink-400"> / {formatCredits(module.credits)}</span>
          </p>
          <p className="mt-3 text-xs text-ink-400">
            {formatCredits(module.remainingCredits)} restant(s)
          </p>
        </Card>
        <Card>
          <p className="text-xs text-ink-400 uppercase">Statut</p>
          <div className="mt-2">
            <StatusBadge status={module.status} />
          </div>
          <p className="mt-3 text-xs text-ink-400">
            Note : {module.grade ?? '—'} · {module.validatedProjects} / {module.totalProjects} projets validés
          </p>
        </Card>
      </div>

      {module.description !== '' && (
        <p className="mt-4 text-sm text-ink-300">{module.description}</p>
      )}
      {module.notes !== '' && (
        <Card className="mt-4">
          <p className="text-xs text-ink-400 uppercase">Commentaires</p>
          <p className="mt-2 whitespace-pre-wrap text-sm text-ink-300">{module.notes}</p>
        </Card>
      )}

      <section className="mt-8">
        <SectionTitle action={<Button onClick={() => setAddingProject(true)}>+ Projet</Button>}>
          Projets
        </SectionTitle>

        {module.projects.length === 0 ? (
          <EmptyState
            title="Aucun projet dans ce module."
            hint="Sans projet, le module ne peut rapporter aucun crédit."
          />
        ) : (
          <ul className="flex flex-col gap-2">
            {module.projects.map((project, index) => (
              <li
                key={project.id}
                className="flex items-center gap-2 rounded-xl border border-ink-800 bg-ink-900 pr-3 transition-colors hover:border-ink-700"
              >
                <Link
                  to={`/projects/${project.id}`}
                  className="flex flex-1 flex-wrap items-center gap-3 px-4 py-3"
                >
                  <span aria-hidden className="text-base">{PROJECT_STATUS_ICON[project.status]}</span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm text-ink-100">{project.name}</span>
                    <span className="block text-xs text-ink-400">
                      {formatCredits(project.credits)} crédit(s) · deadline {formatDate(project.deadline)}
                    </span>
                  </span>
                  {project.isLate && <LateBadge />}
                  {project.isDueSoon && <SoonBadge />}
                  <ProjectStatusBadge status={project.status} />
                  <span className="w-24 shrink-0 text-right text-xs tabular-nums text-ink-400">
                    {formatDaysLeft(project.daysLeft)}
                  </span>
                </Link>
                <MoveButtons
                  label={project.name}
                  canUp={index > 0}
                  canDown={index < module.projects.length - 1}
                  onMove={(direction) => moveProject(project.id, direction)}
                />
              </li>
            ))}
          </ul>
        )}
      </section>

      {editing && raw !== undefined && <ModuleForm initial={raw} onClose={() => setEditing(false)} />}
      {addingProject && <ProjectForm moduleId={module.id} onClose={() => setAddingProject(false)} />}
    </>
  );
}
