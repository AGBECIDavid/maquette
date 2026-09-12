import { useState } from 'react';
import { newId, useCurriculum } from '../../store/CurriculumContext';
import type { Module, ProgressStatus } from '../../domain/types';
import { Modal } from '../components/Modal';
import { Button } from '../components/Primitives';
import { DateInput, Field, FieldGrid, NumberInput, Select, TextArea, TextInput } from '../components/Form';
import { PROGRESS_STATUS_LABEL } from '../labels';

const STATUS_OPTIONS: { value: ProgressStatus | 'auto'; label: string }[] = [
  { value: 'auto', label: 'Automatique (déduit des projets)' },
  ...(['upcoming', 'in_progress', 'validated', 'failed'] as const).map((s) => ({
    value: s,
    label: `Forcer : ${PROGRESS_STATUS_LABEL[s]}`,
  })),
];

export function ModuleForm({
  initial,
  roadblockId,
  onClose,
}: {
  initial?: Module;
  roadblockId?: string;
  onClose: () => void;
}) {
  const { data, upsertModule } = useCurriculum();
  const [draft, setDraft] = useState<Module>(
    initial ?? {
      id: newId(),
      roadblockId: roadblockId ?? data.roadblocks[0]?.id ?? '',
      name: '',
      description: '',
      order: data.modules.length + 1,
      credits: 6,
      startDate: null,
      endDate: null,
      statusOverride: null,
      grade: null,
      notes: '',
    },
  );

  const set = <K extends keyof Module>(key: K, value: Module[K]) =>
    setDraft((current) => ({ ...current, [key]: value }));

  const canSave = draft.name.trim() !== '' && draft.roadblockId !== '';

  return (
    <Modal
      title={initial === undefined ? 'Nouveau module' : 'Modifier le module'}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Annuler</Button>
          <Button
            variant="primary"
            disabled={!canSave}
            onClick={() => {
              upsertModule({ ...draft, name: draft.name.trim() });
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
          <TextInput value={draft.name} onChange={(v) => set('name', v)} autoFocus placeholder="Web Programming" />
        </Field>

        <Field label="Description">
          <TextArea value={draft.description} onChange={(v) => set('description', v)} />
        </Field>

        <FieldGrid>
          <Field label="Roadblock">
            <Select
              value={draft.roadblockId}
              onChange={(v) => set('roadblockId', v)}
              options={
                data.roadblocks.length > 0
                  ? data.roadblocks.map((r) => ({ value: r.id, label: r.name }))
                  : [{ value: '', label: 'Créez d’abord un Roadblock' }]
              }
            />
          </Field>
          <Field label="Crédits" hint="Répartis à parts égales entre les projets">
            <NumberInput value={draft.credits} onChange={(v) => set('credits', v ?? 0)} step={0.5} />
          </Field>
          <Field label="Date de début">
            <DateInput value={draft.startDate} onChange={(v) => set('startDate', v)} />
          </Field>
          <Field label="Date de fin prévue">
            <DateInput value={draft.endDate} onChange={(v) => set('endDate', v)} />
          </Field>
          <Field label="Note">
            <TextInput value={draft.grade ?? ''} onChange={(v) => set('grade', v === '' ? null : v)} placeholder="A, B, 15/20…" />
          </Field>
          <Field label="Statut">
            <Select
              value={draft.statusOverride ?? 'auto'}
              onChange={(v) => set('statusOverride', v === 'auto' ? null : v)}
              options={STATUS_OPTIONS}
            />
          </Field>
        </FieldGrid>

        <Field label="Commentaires personnels">
          <TextArea value={draft.notes} onChange={(v) => set('notes', v)} />
        </Field>
      </div>
    </Modal>
  );
}
