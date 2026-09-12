import { useState } from 'react';
import { newId, useCurriculum } from '../../store/CurriculumContext';
import type { Priority, Project, ProjectStatus } from '../../domain/types';
import { Modal } from '../components/Modal';
import { Button } from '../components/Primitives';
import { DateInput, Field, FieldGrid, NumberInput, Select, TextArea, TextInput } from '../components/Form';
import { PRIORITY_LABEL, PROJECT_STATUS_LABEL } from '../labels';
import { today } from '../../domain/dates';

const STATUS_OPTIONS = (['todo', 'in_progress', 'done', 'validated'] as const).map(
  (s): { value: ProjectStatus; label: string } => ({ value: s, label: PROJECT_STATUS_LABEL[s] }),
);

const PRIORITY_OPTIONS = (['critical', 'high', 'normal', 'low'] as const).map(
  (p): { value: Priority; label: string } => ({ value: p, label: PRIORITY_LABEL[p] }),
);

export function ProjectForm({
  initial,
  moduleId,
  onClose,
}: {
  initial?: Project;
  moduleId?: string;
  onClose: () => void;
}) {
  const { data, upsertProject } = useCurriculum();
  const [draft, setDraft] = useState<Project>(
    initial ?? {
      id: newId(),
      moduleId: moduleId ?? data.modules[0]?.id ?? '',
      name: '',
      description: '',
      order: data.projects.length + 1,
      creditsOverride: null,
      startDate: null,
      deadline: null,
      completedAt: null,
      status: 'todo',
      priority: 'normal',
      grade: null,
      repoUrl: null,
      notes: '',
    },
  );

  const set = <K extends keyof Project>(key: K, value: Project[K]) =>
    setDraft((current) => ({ ...current, [key]: value }));

  /**
   * Passer un projet à « terminé » ou « validé » date la fin automatiquement
   * si elle est vide : personne n'a envie de ressaisir la date du jour.
   */
  const setStatus = (status: ProjectStatus) => {
    setDraft((current) => {
      const finished = status === 'done' || status === 'validated';
      return {
        ...current,
        status,
        completedAt: finished && current.completedAt === null ? today() : current.completedAt,
      };
    });
  };

  const canSave = draft.name.trim() !== '' && draft.moduleId !== '';

  return (
    <Modal
      title={initial === undefined ? 'Nouveau projet' : 'Modifier le projet'}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Annuler</Button>
          <Button
            variant="primary"
            disabled={!canSave}
            onClick={() => {
              upsertProject({ ...draft, name: draft.name.trim() });
              onClose();
            }}
          >
            Enregistrer
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Field label="Nom">
          <TextInput value={draft.name} onChange={(v) => set('name', v)} autoFocus placeholder="my_printf" />
        </Field>

        <Field label="Description">
          <TextArea value={draft.description} onChange={(v) => set('description', v)} />
        </Field>

        <FieldGrid>
          <Field label="Module">
            <Select
              value={draft.moduleId}
              onChange={(v) => set('moduleId', v)}
              options={
                data.modules.length > 0
                  ? data.modules.map((m) => ({ value: m.id, label: m.name }))
                  : [{ value: '', label: 'Créez d’abord un module' }]
              }
            />
          </Field>
          <Field
            label="Poids en crédits"
            hint="Vide = part égale des crédits du module"
          >
            <NumberInput
              value={draft.creditsOverride}
              onChange={(v) => set('creditsOverride', v)}
              step={0.5}
              placeholder="Part égale"
            />
          </Field>
          <Field label="Statut">
            <Select value={draft.status} onChange={setStatus} options={STATUS_OPTIONS} />
          </Field>
          <Field label="Priorité">
            <Select value={draft.priority} onChange={(v) => set('priority', v)} options={PRIORITY_OPTIONS} />
          </Field>
          <Field label="Date de début">
            <DateInput value={draft.startDate} onChange={(v) => set('startDate', v)} />
          </Field>
          <Field label="Deadline">
            <DateInput value={draft.deadline} onChange={(v) => set('deadline', v)} />
          </Field>
          <Field label="Date de fin réelle">
            <DateInput value={draft.completedAt} onChange={(v) => set('completedAt', v)} />
          </Field>
          <Field label="Note">
            <TextInput value={draft.grade ?? ''} onChange={(v) => set('grade', v === '' ? null : v)} placeholder="A, 15/20…" />
          </Field>
        </FieldGrid>

        <Field label="Dépôt GitHub">
          <TextInput
            value={draft.repoUrl ?? ''}
            onChange={(v) => set('repoUrl', v === '' ? null : v)}
            placeholder="https://github.com/…"
          />
        </Field>

        <Field label="Commentaires">
          <TextArea value={draft.notes} onChange={(v) => set('notes', v)} />
        </Field>
      </div>
    </Modal>
  );
}
