import { useState } from 'react';
import { newId, nextOrder, useCurriculum } from '../../store/CurriculumContext';
import type { ProgressStatus, Roadblock } from '../../domain/types';
import { Modal } from '../components/Modal';
import { Button } from '../components/Primitives';
import { DateInput, Field, FieldGrid, NumberInput, Select, TextArea, TextInput } from '../components/Form';
import { PROGRESS_STATUS_LABEL } from '../labels';

const STATUS_OPTIONS: { value: ProgressStatus | 'auto'; label: string }[] = [
  { value: 'auto', label: 'Automatique (déduit des crédits)' },
  ...(['upcoming', 'in_progress', 'validated', 'failed'] as const).map((s) => ({
    value: s,
    label: `Forcer : ${PROGRESS_STATUS_LABEL[s]}`,
  })),
];

export function RoadblockForm({
  initial,
  onClose,
}: {
  initial?: Roadblock;
  onClose: () => void;
}) {
  const { data, upsertRoadblock, upsertYear } = useCurriculum();
  const [draft, setDraft] = useState<Roadblock>(
    initial ?? {
      id: newId(),
      yearId: data.years[0]?.id ?? '',
      name: '',
      description: '',
      order: nextOrder(data.roadblocks),
      requiredCredits: 24,
      startDate: null,
      endDate: null,
      statusOverride: null,
    },
  );

  const set = <K extends keyof Roadblock>(key: K, value: Roadblock[K]) =>
    setDraft((current) => ({ ...current, [key]: value }));

  const save = () => {
    let yearId = draft.yearId;
    // Aucune année encore créée : on en ouvre une plutôt que de bloquer
    // l'utilisateur sur un champ obligatoire vide.
    if (yearId === '') {
      const year = {
        id: newId(),
        label: `${new Date().getFullYear()}-${new Date().getFullYear() + 1}`,
        order: 1,
        startDate: null,
        endDate: null,
      };
      upsertYear(year);
      yearId = year.id;
    }
    upsertRoadblock({ ...draft, name: draft.name.trim(), yearId });
    onClose();
  };

  return (
    <Modal
      title={initial === undefined ? 'Nouveau Roadblock' : 'Modifier le Roadblock'}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Annuler</Button>
          <Button variant="primary" onClick={save} disabled={draft.name.trim() === ''}>
            Enregistrer
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Field label="Nom">
          <TextInput value={draft.name} onChange={(v) => set('name', v)} autoFocus placeholder="Roadblock 4" />
        </Field>

        <Field label="Description">
          <TextArea value={draft.description} onChange={(v) => set('description', v)} />
        </Field>

        <FieldGrid>
          <Field label="Année">
            <Select
              value={draft.yearId}
              onChange={(v) => set('yearId', v)}
              options={
                data.years.length > 0
                  ? data.years.map((y) => ({ value: y.id, label: y.label }))
                  : [{ value: '', label: 'Créer une année automatiquement' }]
              }
            />
          </Field>
          <Field label="Crédits nécessaires" hint="Seuil à atteindre pour valider ce Roadblock">
            <NumberInput
              value={draft.requiredCredits}
              onChange={(v) => set('requiredCredits', v ?? 0)}
            />
          </Field>
          <Field label="Date de début">
            <DateInput value={draft.startDate} onChange={(v) => set('startDate', v)} />
          </Field>
          <Field label="Date de fin">
            <DateInput value={draft.endDate} onChange={(v) => set('endDate', v)} />
          </Field>
        </FieldGrid>

        <Field label="Statut" hint="Laisse « automatique » sauf cas particulier">
          <Select
            value={draft.statusOverride ?? 'auto'}
            onChange={(v) => set('statusOverride', v === 'auto' ? null : v)}
            options={STATUS_OPTIONS}
          />
        </Field>
      </div>
    </Modal>
  );
}
