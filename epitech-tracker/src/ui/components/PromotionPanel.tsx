import { useCurriculum } from '../../store/CurriculumContext';
import { nextLevel } from '../../domain/promotion';
import { formatDate } from '../../domain/dates';
import { Button, Card } from './Primitives';

/**
 * Passage au niveau suivant, ou redoublement.
 *
 * Toujours déclenché par l'utilisateur. L'application peut proposer quand la
 * date de fin est passée, jamais décider : un étudiant peut redoubler, partir
 * en césure, faire un stage long ou s'arrêter, et une app qui se trompe
 * là-dessus perd la confiance qu'on accorde à tous ses autres chiffres.
 */
export function PromotionPanel({ compact = false }: { compact?: boolean }) {
  const { currentYear, currentYearOver, promote, repeatYear } = useCurriculum();
  if (currentYear === null) return null;

  const next = nextLevel(currentYear.level);
  const label = currentYear.level === null ? currentYear.label : `${currentYear.level} · ${currentYear.label}`;

  const confirmAnd = (action: () => void, message: string) => () => {
    if (window.confirm(message)) action();
  };

  const actions = (
    <div className="flex flex-wrap gap-2">
      {next !== null && (
        <Button
          variant="primary"
          onClick={confirmAnd(
            promote,
            `Ouvrir une nouvelle année en ${next} ?\n\nL’année ${label} est conservée : ses Roadblocks, ses crédits et sa progression restent consultables.`,
          )}
        >
          Passer en {next}
        </Button>
      )}
      <Button
        onClick={confirmAnd(
          repeatYear,
          `Ouvrir une nouvelle année au même niveau${currentYear.level === null ? '' : ` (${currentYear.level})`} ?\n\nL’année ${label} est conservée telle quelle.`,
        )}
      >
        Redoubler ce niveau
      </Button>
    </div>
  );

  if (compact) {
    if (!currentYearOver) return null;
    return (
      <div className="mb-4 rounded-xl border border-busy/40 bg-busy/5 p-5">
        <h2 className="text-sm font-semibold text-ink-100">
          L’année {label} est terminée depuis le {formatDate(currentYear.endDate)}
        </h2>
        <p className="mt-1 mb-4 text-sm text-ink-300">
          Rien n’a été décidé à ta place. Passe au niveau suivant, redouble, ou laisse en l’état si
          ta situation ne rentre dans aucune des deux.
        </p>
        {actions}
      </div>
    );
  }

  return (
    <Card>
      <p className="text-sm text-ink-300">
        Année courante : <strong className="text-ink-100">{label}</strong>
        {currentYear.level === null && (
          <span className="text-ink-400"> — aucun niveau précisé, à renseigner ci-dessus</span>
        )}
      </p>
      <p className="mt-2 mb-4 text-xs text-ink-400">
        Passer au niveau suivant ouvre une <strong>nouvelle année vierge</strong> et la rend
        courante. L’année quittée n’est ni modifiée ni supprimée : elle reste accessible par le
        sélecteur d’année, en haut de l’écran.
        {next === null &&
          currentYear.level !== null &&
          ' TEK5 est le dernier niveau : il n’y a pas de passage au-delà.'}
      </p>
      {actions}
    </Card>
  );
}
