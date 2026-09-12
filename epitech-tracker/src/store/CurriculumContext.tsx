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
import { mockCurriculum } from '../data/mock';
import { emptyCurriculum, parseCurriculum } from '../data/schema';
import { buildAlerts, type Alert } from '../domain/alerts';
import { today as currentDay } from '../domain/dates';
import { buildView, dashboardStats, type CurriculumView, type DashboardStats } from '../domain/selectors';
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
  view: CurriculumView;
  stats: DashboardStats;
  alerts: Alert[];
  today: string;

  upsertYear: (year: AcademicYear) => void;
  upsertRoadblock: (roadblock: Roadblock) => void;
  upsertModule: (module: Module) => void;
  upsertProject: (project: Project) => void;

  removeRoadblock: (id: Id) => void;
  removeModule: (id: Id) => void;
  removeProject: (id: Id) => void;

  updateSettings: (settings: Partial<Settings>) => void;
  replaceAll: (data: Curriculum) => void;
  loadMock: () => void;
  reset: () => void;
  importJson: (raw: string) => { ok: true } | { ok: false; error: string };
  exportJson: () => string;
}

const Context = createContext<CurriculumStore | null>(null);

function upsert<T extends { id: Id }>(items: T[], item: T): T[] {
  const index = items.findIndex((existing) => existing.id === item.id);
  if (index === -1) return [...items, item];
  const next = [...items];
  next[index] = item;
  return next;
}

export function CurriculumProvider({ children }: { children: ReactNode }) {
  const repository = useRef(createLocalStorageRepository()).current;

  // Premier démarrage : rien en mémoire → on charge le jeu d'exemple, pour
  // que l'application montre quelque chose plutôt qu'un écran vide.
  const [data, setData] = useState<Curriculum>(
    () => repository.load() ?? mockCurriculum(),
  );

  useEffect(() => {
    repository.save(data);
  }, [data, repository]);

  const today = useMemo(() => currentDay(), []);
  const view = useMemo(() => buildView(data, today), [data, today]);
  const stats = useMemo(() => dashboardStats(view), [view]);
  const alerts = useMemo(() => buildAlerts(view, data.settings), [view, data.settings]);

  const patch = useCallback(
    <K extends Entity>(key: K, updater: (items: Curriculum[K]) => Curriculum[K]) => {
      setData((current) => ({ ...current, [key]: updater(current[key]) }));
    },
    [],
  );

  const store: CurriculumStore = {
    data,
    view,
    stats,
    alerts,
    today,

    upsertYear: useCallback((year) => patch('years', (items) => upsert(items, year)), [patch]),
    upsertRoadblock: useCallback((rb) => patch('roadblocks', (items) => upsert(items, rb)), [patch]),
    upsertModule: useCallback((m) => patch('modules', (items) => upsert(items, m)), [patch]),
    upsertProject: useCallback((p) => patch('projects', (items) => upsert(items, p)), [patch]),

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

    updateSettings: useCallback((settings) => {
      setData((current) => ({ ...current, settings: { ...current.settings, ...settings } }));
    }, []),

    replaceAll: useCallback((next) => setData(next), []),

    loadMock: useCallback(() => setData(mockCurriculum()), []),

    reset: useCallback(() => {
      const fresh = emptyCurriculum();
      fresh.years = [
        {
          id: crypto.randomUUID(),
          label: `${new Date().getFullYear()}-${new Date().getFullYear() + 1}`,
          order: 1,
          startDate: null,
          endDate: null,
        },
      ];
      setData(fresh);
    }, []),

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
