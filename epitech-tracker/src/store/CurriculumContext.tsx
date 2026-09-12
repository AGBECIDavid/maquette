/**
 * État de l'application.
 *
 * Une seule source : le document `Curriculum`. Tout le reste (arbre calculé,
 * alertes, compteurs) en dérive à chaque rendu — rien n'est dupliqué, donc
 * rien ne peut désynchroniser.
 *
 * La persistance passe par l'interface `Repository` : changer de support ne
 * touchera pas ce fichier au-delà de la ligne qui construit le dépôt.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { createLocalStorageRepository } from '../data/localStorageRepository';
import { dataKeyFor } from '../data/profiles';
import { mockCurriculum } from '../data/mock';
import { newCurriculum, parseCurriculum } from '../data/schema';
import { buildAlerts, type Alert } from '../domain/alerts';
import { moveItem, nextOrder, type Direction } from '../domain/ordering';
import { today as currentDay } from '../domain/dates';
import {
  buildView,
  dashboardStats,
  scopeToYear,
  type CurriculumView,
  type DashboardStats,
} from '../domain/selectors';
import { buildNextYear, buildRepeatYear, isYearOver, nextLevel } from '../domain/promotion';
import type {
  AcademicYear,
  Curriculum,
  Id,
  Module,
  Project,
  Roadblock,
  Settings,
} from '../domain/types';

type Entity = 'years' | 'roadblocks' | 'modules' | 'projects';

interface CurriculumStore {
  data: Curriculum;
  /** Vue restreinte à l'année courante — ce que le dashboard et les listes montrent. */
  view: CurriculumView;
  /** Vue de tout le cursus — parcours, recherche, et pages de détail. */
  fullView: CurriculumView;
  stats: DashboardStats;
  alerts: Alert[];
  today: string;

  currentYear: AcademicYear | null;
  /** L'année courante est-elle terminée ? Sert à proposer un passage. */
  currentYearOver: boolean;
  setCurrentYear: (id: Id) => void;
  /** Ouvre une nouvelle année au niveau suivant. L'ancienne est conservée. */
  promote: () => void;
  /** Ouvre une nouvelle année au même niveau : un redoublement. */
  repeatYear: () => void;

  upsertYear: (year: AcademicYear) => void;
  upsertRoadblock: (roadblock: Roadblock) => void;
  upsertModule: (module: Module) => void;
  upsertProject: (project: Project) => void;

  removeYear: (id: Id) => void;
  removeRoadblock: (id: Id) => void;
  removeModule: (id: Id) => void;
  removeProject: (id: Id) => void;

  moveRoadblock: (id: Id, direction: Direction) => void;
  moveModule: (id: Id, direction: Direction) => void;
  moveProject: (id: Id, direction: Direction) => void;

  /** Ce que la suppression d'une année emporterait avec elle. */
  yearImpact: (id: Id) => { roadblocks: number; modules: number; projects: number };

  updateSettings: (settings: Partial<Settings>) => void;
  replaceAll: (data: Curriculum) => void;
  loadMock: () => void;
  reset: () => void;
  importJson: (raw: string) => { ok: true } | { ok: false; error: string };
  exportJson: () => string;
}

const Context = createContext<CurriculumStore | null>(null);

/**
 * Déplace un élément à l'intérieur de sa fratrie seule : un module ne se
 * réordonne que parmi les modules de son Roadblock, jamais parmi tous.
 */
function moveWithinGroup<T extends { id: Id; order: number }>(
  all: T[],
  id: Id,
  direction: Direction,
  groupKey: (item: T) => string,
): T[] {
  const target = all.find((item) => item.id === id);
  if (target === undefined) return all;
  const key = groupKey(target);
  const siblings = all.filter((item) => groupKey(item) === key);
  const others = all.filter((item) => groupKey(item) !== key);
  return [...others, ...moveItem(siblings, id, direction)];
}

function upsert<T extends { id: Id }>(items: T[], item: T): T[] {
  const index = items.findIndex((existing) => existing.id === item.id);
  if (index === -1) return [...items, item];
  const next = [...items];
  next[index] = item;
  return next;
}

/**
 * Les données sont celles d'un profil, et d'un seul.
 *
 * Le parent monte ce fournisseur avec `key={profileId}` : changer de profil
 * le remonte entièrement, plutôt que de faire cohabiter l'ancien état avec le
 * nouveau tiroir — un état résiduel afficherait le cursus de quelqu'un
 * d'autre le temps d'un rendu.
 */
export function CurriculumProvider({
  profileId,
  children,
}: {
  profileId: string;
  children: ReactNode;
}) {
  const repository = useRef(createLocalStorageRepository(dataKeyFor(profileId))).current;

  // Un profil sans données commence vide, avec une année ouverte : le jeu
  // d'exemple ne s'invite que si l'utilisateur l'a demandé à la création.
  const [data, setData] = useState<Curriculum>(() => repository.load() ?? newCurriculum(null, crypto.randomUUID()));

  useEffect(() => {
    repository.save(data);
  }, [data, repository]);

  const today = useMemo(() => currentDay(), []);
  const fullView = useMemo(() => buildView(data, today), [data, today]);

  const currentYear = useMemo(
    () => data.years.find((y) => y.id === data.settings.currentYearId) ?? null,
    [data.years, data.settings.currentYearId],
  );

  // Tout ce qui répond à « où j'en suis » est restreint à l'année courante.
  const view = useMemo(
    () => scopeToYear(fullView, currentYear?.id ?? null),
    [fullView, currentYear],
  );
  const stats = useMemo(() => dashboardStats(view), [view]);
  const alerts = useMemo(() => buildAlerts(view, data.settings), [view, data.settings]);

  const patch = useCallback(
    <K extends Entity>(key: K, updater: (items: Curriculum[K]) => Curriculum[K]) => {
      setData((current) => ({ ...current, [key]: updater(current[key]) }));
    },
    [],
  );

  /** Ouvre l'année suivante et l'active. L'année quittée n'est pas touchée. */
  const openNextYear = useCallback(
    (mode: 'promote' | 'repeat') => {
      setData((current) => {
        const from = current.years.find((y) => y.id === current.settings.currentYearId);
        if (from === undefined) return current;

        const input = {
          years: current.years,
          from,
          id: crypto.randomUUID(),
          fallbackYear: new Date().getFullYear(),
        };
        const year =
          mode === 'repeat'
            ? buildRepeatYear(input)
            : buildNextYear({ ...input, level: nextLevel(from.level) });

        return {
          ...current,
          years: [...current.years, year],
          settings: { ...current.settings, currentYearId: year.id },
        };
      });
    },
    [],
  );

  const store: CurriculumStore = {
    data,
    view,
    fullView,
    stats,
    alerts,
    today,

    currentYear,
    currentYearOver: isYearOver(currentYear, today),
    setCurrentYear: useCallback(
      (id) =>
        setData((current) => ({
          ...current,
          settings: { ...current.settings, currentYearId: id },
        })),
      [],
    ),
    promote: useCallback(() => openNextYear('promote'), [openNextYear]),
    repeatYear: useCallback(() => openNextYear('repeat'), [openNextYear]),

    upsertYear: useCallback(
      (year) =>
        setData((current) => ({
          ...current,
          years: upsert(current.years, year),
          settings: {
            ...current.settings,
            currentYearId: current.settings.currentYearId ?? year.id,
          },
        })),
      [],
    ),
    upsertRoadblock: useCallback((rb) => patch('roadblocks', (items) => upsert(items, rb)), [patch]),
    upsertModule: useCallback((m) => patch('modules', (items) => upsert(items, m)), [patch]),
    upsertProject: useCallback((p) => patch('projects', (items) => upsert(items, p)), [patch]),

    // Supprimer une année emporte tout ce qu'elle contient : un Roadblock
    // sans année n'apparaîtrait plus nulle part tout en pesant encore.
    removeYear: useCallback((id) => {
      setData((current) => {
        const remaining = current.years.filter((y) => y.id !== id);
        const roadblockIds = new Set(
          current.roadblocks.filter((r) => r.yearId === id).map((r) => r.id),
        );
        const moduleIds = new Set(
          current.modules.filter((m) => roadblockIds.has(m.roadblockId)).map((m) => m.id),
        );
        return {
          ...current,
          years: remaining,
          roadblocks: current.roadblocks.filter((r) => !roadblockIds.has(r.id)),
          modules: current.modules.filter((m) => !moduleIds.has(m.id)),
          projects: current.projects.filter((p) => !moduleIds.has(p.moduleId)),
          settings: {
            ...current.settings,
            // Supprimer l'année courante ne doit pas laisser l'application
            // sans année à afficher : on retombe sur la dernière restante.
            currentYearId:
              current.settings.currentYearId === id
                ? (remaining[remaining.length - 1]?.id ?? null)
                : current.settings.currentYearId,
          },
        };
      });
    }, []),

    // Suppression en cascade : un module orphelin n'apparaîtrait nulle part
    // tout en continuant à peser dans le document.
    removeRoadblock: useCallback((id) => {
      setData((current) => {
        const moduleIds = new Set(
          current.modules.filter((m) => m.roadblockId === id).map((m) => m.id),
        );
        return {
          ...current,
          roadblocks: current.roadblocks.filter((r) => r.id !== id),
          modules: current.modules.filter((m) => m.roadblockId !== id),
          projects: current.projects.filter((p) => !moduleIds.has(p.moduleId)),
        };
      });
    }, []),

    removeModule: useCallback((id) => {
      setData((current) => ({
        ...current,
        modules: current.modules.filter((m) => m.id !== id),
        projects: current.projects.filter((p) => p.moduleId !== id),
      }));
    }, []),

    removeProject: useCallback((id) => {
      setData((current) => ({
        ...current,
        projects: current.projects.filter((p) => p.id !== id),
      }));
    }, []),

    moveRoadblock: useCallback(
      (id, direction) =>
        patch('roadblocks', (items) => moveWithinGroup(items, id, direction, () => 'all')),
      [patch],
    ),

    moveModule: useCallback(
      (id, direction) =>
        patch('modules', (items) => moveWithinGroup(items, id, direction, (m) => m.roadblockId)),
      [patch],
    ),

    moveProject: useCallback(
      (id, direction) =>
        patch('projects', (items) => moveWithinGroup(items, id, direction, (p) => p.moduleId)),
      [patch],
    ),

    yearImpact: useCallback(
      (id) => {
        const roadblockIds = new Set(
          data.roadblocks.filter((r) => r.yearId === id).map((r) => r.id),
        );
        const moduleIds = new Set(
          data.modules.filter((m) => roadblockIds.has(m.roadblockId)).map((m) => m.id),
        );
        return {
          roadblocks: roadblockIds.size,
          modules: moduleIds.size,
          projects: data.projects.filter((p) => moduleIds.has(p.moduleId)).length,
        };
      },
      [data],
    ),

    updateSettings: useCallback((settings) => {
      setData((current) => ({ ...current, settings: { ...current.settings, ...settings } }));
    }, []),

    replaceAll: useCallback((next) => setData(next), []),

    loadMock: useCallback(() => setData(mockCurriculum()), []),

    reset: useCallback(() => setData(newCurriculum(null, crypto.randomUUID())), []),

    importJson: useCallback((raw) => {
      try {
        const parsed = parseCurriculum(JSON.parse(raw));
        setData({ ...parsed, settings: { ...parsed.settings, source: 'user' } });
        return { ok: true as const };
      } catch (error) {
        return {
          ok: false as const,
          error: error instanceof Error ? error.message : 'Fichier illisible',
        };
      }
    }, []),

    exportJson: useCallback(() => JSON.stringify(data, null, 2), [data]),
  };

  return <Context.Provider value={store}>{children}</Context.Provider>;
}

export function useCurriculum(): CurriculumStore {
  const store = useContext(Context);
  if (store === null) {
    throw new Error('useCurriculum doit être utilisé dans <CurriculumProvider>');
  }
  return store;
}

/** Identifiant d'une nouvelle entité. */
export function newId(): Id {
  return crypto.randomUUID();
}

export { nextOrder };
