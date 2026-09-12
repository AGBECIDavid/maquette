import { newId, nextOrder, useCurriculum } from '../../store/CurriculumContext';
import { byOrder } from '../../domain/ordering';
import { Button } from './Primitives';
import { DateInput, TextInput } from './Form';

/**
 * Gestion des années académiques.
 *
 * Les champs s'enregistrent à la frappe, comme les réglages d'alerte : une
 * année n'a que trois informations, un formulaire modal pour si peu serait
 * une cérémonie inutile.
 */
export function YearsEditor() {
  const { data, upsertYear, removeYear, yearImpact } = useCurriculum();
  const years = byOrder(data.years);

  const add = () => {
    const start = new Date().getFullYear();
    upsertYear({
      id: newId(),
      label: `${start}-${start + 1}`,
      order: nextOrder(data.years),
      startDate: null,
      endDate: null,
    });
  };

  return (
    <>
      {years.length === 0 ? (
        <p className="mb-4 text-sm text-ink-400">
          Aucune année. Une année sera créée automatiquement au premier Roadblock.
        </p>
      ) : (
        <ul className="mb-4 flex flex-col gap-3">
          {years.map((year) => {
            const impact = yearImpact(year.id);
            return (
              <li
                key={year.id}
                className="grid gap-3 rounded-lg border border-ink-800 p-3 sm:grid-cols-[1fr_auto_auto_auto] sm:items-end"
              >
                <label className="block">
                  <span className="mb-1 block text-xs text-ink-400">Libellé</span>
                  <TextInput
                    value={year.label}
                    onChange={(label) => upsertYear({ ...year, label })}
                  />
                </label>
                <label className="block sm:w-40">
                  <span className="mb-1 block text-xs text-ink-400">Début</span>
                  <DateInput
                    value={year.startDate}
                    onChange={(startDate) => upsertYear({ ...year, startDate })}
                  />
                </label>
                <label className="block sm:w-40">
                  <span className="mb-1 block text-xs text-ink-400">Fin</span>
                  <DateInput
                    value={year.endDate}
                    onChange={(endDate) => upsertYear({ ...year, endDate })}
                  />
                </label>
                <Button
                  variant="danger"
                  onClick={() => {
                    // On annonce ce que la suppression emporte avant de la faire :
                    // une année supprimée vide tout le cursus qu'elle porte.
                    const detail =
                      impact.roadblocks === 0
                        ? ''
                        : `\n\nElle contient ${impact.roadblocks} Roadblock(s), ${impact.modules} module(s) et ${impact.projects} projet(s), qui seront supprimés avec elle.`;
                    if (window.confirm(`Supprimer l’année « ${year.label} » ?${detail}`)) {
                      removeYear(year.id);
                    }
                  }}
                >
                  Supprimer
                </Button>
              </li>
            );
          })}
        </ul>
      )}

      <Button onClick={add}>+ Année</Button>
    </>
  );
}
