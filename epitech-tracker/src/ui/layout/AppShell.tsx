import { useMemo, useState, type ReactNode } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { useSession } from '../../store/SessionContext';
import { searchAll } from '../../domain/search';
import { formatPercent } from '../labels';
import { Logo, TAGLINE } from '../components/Logo';
import { NAV_ICONS } from '../components/NavIcons';
import { MobileNav } from './MobileNav';

const NAV = [
  { to: '/', label: 'Dashboard', icon: NAV_ICONS.dashboard, end: true },
  { to: '/roadblocks', label: 'Roadblocks', icon: NAV_ICONS.roadblocks, end: false },
  { to: '/modules', label: 'Modules', icon: NAV_ICONS.modules, end: false },
  { to: '/projects', label: 'Projets', icon: NAV_ICONS.projects, end: false },
  { to: '/calendrier', label: 'Calendrier', icon: NAV_ICONS.calendar, end: false },
  { to: '/statistiques', label: 'Statistiques', icon: NAV_ICONS.stats, end: false },
  { to: '/parametres', label: 'Paramètres', icon: NAV_ICONS.settings, end: false },
];

const RESULT_PATH = {
  roadblock: 'roadblocks',
  module: 'modules',
  project: 'projects',
} as const;

const RESULT_LABEL = {
  roadblock: 'Roadblock',
  module: 'Module',
  project: 'Projet',
} as const;

export function AppShell({ children }: { children: ReactNode }) {
  const { fullView, stats, data, currentYear, setCurrentYear } = useCurriculum();
  const { activeProfile, signOut } = useSession();
  const [query, setQuery] = useState('');
  const navigate = useNavigate();

  // La recherche porte sur tout le cursus : chercher un module de TEK1
  // depuis TEK2 doit le trouver, pas répondre « aucun résultat ».
  const results = useMemo(() => searchAll(fullView, query).slice(0, 8), [fullView, query]);
  const years = useMemo(() => [...data.years].sort((a, b) => a.order - b.order), [data.years]);

  return (
    <div className="flex min-h-full">
      <aside className="hidden w-56 shrink-0 flex-col border-r border-ink-800 bg-ink-900 p-4 md:flex">
        <div className="mb-6 px-2">
          <Logo size={34} />
          <p className="mt-2 text-[11px] text-ink-400">{TAGLINE}</p>
        </div>

        <nav className="flex flex-col gap-1">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
                  isActive
                    ? 'bg-accent/15 text-accent-soft'
                    : 'text-ink-300 hover:bg-ink-850 hover:text-ink-100'
                }`
              }
            >
              {item.icon}
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="mt-auto flex flex-col gap-2">
          <div className="rounded-lg border border-ink-800 p-3">
            <p className="text-xs text-ink-400">Progression globale</p>
            <p className="text-xl font-semibold tabular-nums text-ink-100">
              {formatPercent(stats.progress)}
            </p>
          </div>

          {activeProfile !== null && (
            <div className="rounded-lg border border-ink-800 p-3">
              <p className="truncate text-sm text-ink-100">{activeProfile.name}</p>
              <button
                type="button"
                onClick={signOut}
                className="mt-1 text-xs text-ink-400 hover:text-accent-soft"
              >
                Changer de profil
              </button>
            </div>
          )}
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b border-ink-800 bg-ink-950/90 backdrop-blur">
          <div className="flex flex-wrap items-center gap-3 px-4 py-3 sm:gap-4 sm:px-8">
            <div className="relative order-2 w-full min-w-0 sm:order-1 sm:max-w-md sm:flex-1">
              <input
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Rechercher un Roadblock, un module, un projet…"
                className="w-full rounded-lg border border-ink-800 bg-ink-900 px-3 py-2 text-sm text-ink-100 outline-none placeholder:text-ink-600 focus:border-accent"
              />
              {results.length > 0 && (
                <ul className="absolute z-40 mt-1 w-full overflow-hidden rounded-lg border border-ink-700 bg-ink-850 shadow-xl">
                  {results.map((result) => (
                    <li key={`${result.kind}:${result.id}`}>
                      <button
                        type="button"
                        className="flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm hover:bg-ink-800"
                        onClick={() => {
                          navigate(`/${RESULT_PATH[result.kind]}/${result.id}`);
                          setQuery('');
                        }}
                      >
                        <span className="truncate text-ink-100">{result.label}</span>
                        <span className="shrink-0 text-xs text-ink-400">
                          {RESULT_LABEL[result.kind]} · {result.context}
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            {currentYear !== null && (
              <label className="order-1 flex min-w-0 flex-1 items-center gap-2 sm:order-2 sm:ml-auto sm:flex-none">
                <span className="sr-only">Année affichée</span>
                <select
                  value={currentYear.id}
                  onChange={(event) => setCurrentYear(event.target.value)}
                  className="w-full min-w-0 truncate rounded-lg border border-ink-800 bg-ink-900 px-3 py-2 text-sm text-ink-100 outline-none focus:border-accent sm:w-auto"
                >
                  {years.map((year) => (
                    <option key={year.id} value={year.id} className="bg-ink-850">
                      {year.level === null ? year.label : `${year.level} · ${year.label}`}
                    </option>
                  ))}
                </select>
              </label>
            )}

            {data.settings.source === 'mock' && (
              <span className="order-1 shrink-0 rounded-full border border-busy/40 bg-busy/10 px-2.5 py-1 text-xs font-medium text-busy sm:order-3">
                Exemple
              </span>
            )}
          </div>

        </header>

        <main className="flex-1 px-4 pt-6 pb-28 sm:px-8 sm:pb-10">{children}</main>

        <MobileNav />
      </div>
    </div>
  );
}
