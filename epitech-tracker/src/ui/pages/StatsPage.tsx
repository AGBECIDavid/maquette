import { useMemo } from 'react';
import { useCurriculum } from '../../store/CurriculumContext';
import {
  creditsByRoadblock,
  projectStatusDistribution,
  undatedValidatedCredits,
  validatedOverTime,
} from '../../domain/stats';
import { EmptyState, PageHeader } from '../components/Primitives';
import { CreditsBars } from '../components/charts/CreditsBars';
import { StatusShare } from '../components/charts/StatusShare';
import { CreditsOverTime } from '../components/charts/CreditsOverTime';

export function StatsPage() {
  const { view } = useCurriculum();

  const credits = useMemo(() => creditsByRoadblock(view), [view]);
  const statuses = useMemo(() => projectStatusDistribution(view), [view]);
  const timeline = useMemo(() => validatedOverTime(view), [view]);
  const undated = useMemo(() => undatedValidatedCredits(view), [view]);

  if (view.roadblocks.length === 0) {
    return (
      <>
        <PageHeader title="Statistiques" />
        <EmptyState title="Rien à représenter pour l’instant." hint="Crée un Roadblock et ses modules." />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title="Statistiques"
        subtitle="Ce que les chiffres du dashboard donnent dans le temps et par Roadblock."
      />

      <div className="grid gap-4 xl:grid-cols-2">
        <CreditsBars data={credits} />
        <StatusShare slices={statuses} total={view.projects.length} />
        <div className="xl:col-span-2">
          <CreditsOverTime points={timeline} undated={undated} />
        </div>
      </div>
    </>
  );
}
