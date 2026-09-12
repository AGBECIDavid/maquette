/**
 * Projection : « à ce rythme, ce Roadblock serait validé le … »
 *
 * ─────────────────────────────────────────────────────────────────────
 *  C'est une EXTRAPOLATION du passé, pas une prédiction.
 * ─────────────────────────────────────────────────────────────────────
 *
 * Trois refus délibérés, parce qu'une fausse date est pire que pas de date :
 *
 *   1. Sans aucun crédit validé et daté, il n'y a pas de rythme : on rend
 *      `no_pace`, jamais une date par défaut.
 *   2. Si les crédits encore atteignables ne couvrent pas ce qui manque, le
 *      seuil est hors de portée : on rend `unreachable` plutôt qu'une date
 *      que le cursus ne permet pas d'atteindre.
 *   3. Le rythme retenu est annoncé (`basis`) : récent ou depuis le début.
 *      Deux rythmes donnent deux dates, et l'utilisateur doit savoir laquelle
 *      il regarde.
 *
 * La règle de validation employée reste celle de `rules.ts` : le seuil de
 * crédits. La projection ne décide rien, elle date.
 */

import { addDays, daysBetween } from './dates';
import { roundCredits } from './rules';
import { validatedOverTime } from './stats';
import type { CurriculumView } from './selectors';
import type { Id, IsoDate } from './types';

/** Fenêtre du « rythme récent », en jours. */
export const RECENT_WINDOW_DAYS = 90;

export interface Pace {
  /** Crédits validés par jour. Zéro si rien n'est mesurable. */
  creditsPerDay: number;
  /** Sur quoi le rythme est mesuré. */
  basis: 'recent' | 'overall' | 'none';
  /** Crédits pris en compte dans la mesure. */
  credits: number;
  /** Durée observée, en jours. */
  days: number;
}

export type ProjectionStatus = 'validated' | 'projected' | 'unreachable' | 'no_pace';

export interface RoadblockProjection {
  id: Id;
  name: string;
  status: ProjectionStatus;
  remainingCredits: number;
  /** Date projetée, uniquement quand `status === 'projected'`. */
  date: IsoDate | null;
  /**
   * Crédits à valider avant d'atteindre ce seuil, Roadblocks précédents
   * compris : c'est cette somme que la date traduit en jours.
   */
  cumulativeCredits: number;
  /** Jours d'ici la date projetée. */
  daysAway: number | null;
  /**
   * Écart avec la date de fin du Roadblock : négatif = en avance,
   * positif = en retard. `null` si l'un des deux manque.
   */
  vsDeadline: number | null;
  deadline: IsoDate | null;
}

export interface Projection {
  pace: Pace;
  roadblocks: RoadblockProjection[];
  /** Projection de fin de cursus, mêmes règles que pour un Roadblock. */
  cursus: {
    status: ProjectionStatus;
    remainingCredits: number;
    date: IsoDate | null;
    daysAway: number | null;
  };
}

/**
 * Rythme de validation.
 *
 * On mesure d'abord la fenêtre récente : c'est elle qui reflète le rythme
 * actuel. Si rien n'y a été validé, on retombe sur le rythme depuis la
 * première validation — moins actuel, mais mesuré plutôt qu'inventé.
 */
export function measurePace(view: CurriculumView): Pace {
  const points = validatedOverTime(view);
  const first = points[0];
  const last = points[points.length - 1];
  if (first === undefined || last === undefined) {
    return { creditsPerDay: 0, basis: 'none', credits: 0, days: 0 };
  }

  const windowStart = addDays(view.today, -RECENT_WINDOW_DAYS);
  const before = points.filter((p) => p.date < windowStart).pop();
  const creditsInWindow = roundCredits(last.credits - (before?.credits ?? 0));

  if (creditsInWindow > 0) {
    // La fenêtre est bornée par la première validation : un étudiant qui a
    // commencé il y a 20 jours ne doit pas voir son rythme divisé par 90.
    const observed = Math.min(
      RECENT_WINDOW_DAYS,
      Math.max(daysBetween(first.date, view.today), 1),
    );
    return {
      creditsPerDay: creditsInWindow / observed,
      basis: 'recent',
      credits: creditsInWindow,
      days: observed,
    };
  }

  const span = Math.max(daysBetween(first.date, last.date), 1);
  return {
    creditsPerDay: last.credits / span,
    basis: 'overall',
    credits: last.credits,
    days: span,
  };
}

function projectDays(remaining: number, pace: Pace): number | null {
  if (pace.creditsPerDay <= 0) return null;
  return Math.ceil(remaining / pace.creditsPerDay);
}

export function buildProjection(view: CurriculumView): Projection {
  const pace = measurePace(view);

  /*
   * Les Roadblocks sont séquentiels et partagent un seul rythme : on ne peut
   * pas dater chacun comme si tout le temps disponible lui était consacré.
   * Les crédits restants se cumulent donc dans l'ordre du cursus — sans quoi
   * un Roadblock entier de 24 crédits apparaîtrait sept jours après le
   * précédent, et la dernière date contredirait celle du cursus.
   */
  let cumulative = 0;

  const roadblocks = view.roadblocks.map((roadblock): RoadblockProjection => {
    const base = {
      id: roadblock.id,
      name: roadblock.name,
      remainingCredits: roadblock.remainingCredits,
      deadline: roadblock.endDate,
    };

    if (roadblock.status === 'validated') {
      return {
        ...base,
        status: 'validated',
        date: null,
        daysAway: null,
        vsDeadline: null,
        cumulativeCredits: cumulative,
      };
    }
    if (roadblock.remainingCredits > roadblock.reachableCredits) {
      // Un seuil hors de portée n'entre pas dans le cumul : il ne sera jamais
      // franchi, et l'y ajouter repousserait indéfiniment tous les suivants.
      return {
        ...base,
        status: 'unreachable',
        date: null,
        daysAway: null,
        vsDeadline: null,
        cumulativeCredits: cumulative,
      };
    }

    cumulative = roundCredits(cumulative + roadblock.remainingCredits);
    const days = projectDays(cumulative, pace);
    if (days === null) {
      return {
        ...base,
        status: 'no_pace',
        date: null,
        daysAway: null,
        vsDeadline: null,
        cumulativeCredits: cumulative,
      };
    }

    const date = addDays(view.today, days);
    return {
      ...base,
      status: 'projected',
      date,
      daysAway: days,
      vsDeadline: roadblock.endDate === null ? null : daysBetween(roadblock.endDate, date),
      cumulativeCredits: cumulative,
    };
  });

  const remainingCredits = roundCredits(
    view.roadblocks.reduce((sum, r) => sum + r.remainingCredits, 0),
  );
  const cursusDays = remainingCredits === 0 ? 0 : projectDays(remainingCredits, pace);

  return {
    pace,
    roadblocks,
    cursus:
      remainingCredits === 0
        ? { status: 'validated', remainingCredits: 0, date: null, daysAway: null }
        : cursusDays === null
          ? { status: 'no_pace', remainingCredits, date: null, daysAway: null }
          : {
              status: 'projected',
              remainingCredits,
              date: addDays(view.today, cursusDays),
              daysAway: cursusDays,
            },
  };
}
