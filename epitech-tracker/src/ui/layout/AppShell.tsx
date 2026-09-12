import { useMemo, useState, type ReactNode } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useCurriculum } from '../../store/CurriculumContext';
import { searchAll } from '../../domain/search';
import { formatPercent } from '../labels';
import { Logo, TAGLINE } from '../components/Logo';

const NAV = [
  { to: '/', label: 'Dashboard', icon: '◎', end: true },
  { to: '/roadblocks', label: 'Roadblocks', icon: '▤', end: false },
  { to: '/modules', label: 'Modules', icon: '▥', end: false },
  { to: '/projects', label: 'Projets', icon: '▦', end: false },
  { to: '/calendrier', label: 'Calendrier', icon: '▨', end: false },
  { to: '/statistiques', label: 'Statistiques', icon: '▩', end: false },
  { to: '/parametres', label: 'Paramètres', icon: '⚙', end: false },
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
  const { view, stats, data } = useCurriculum();
  const [query, setQuery] = useState('');
  const navigate = useNavigate();

  const results = useMemo(() => searchAll(view, query).slice(0, 8), [view, query]);

  return (
    <div className="flex min-h-full">
      <aside className="hidden w-56 shrink-0 flex-col border-r border-ink-800 bg-ink-900 p-4 md:flex">
        <div className="mb-6 px-2">
          <Logo />
          <p className="mt-2 text-[11px] tracking-wide text-ink-400">{TAGLINE}</p>
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
              <span aria-hidden className="w-4 text-center">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="mt-auto rounded-lg border border-ink-800 p-3">
          <p className="text-xs text-ink-400">Progression globale</p>
          <p className="text-xl font-semibold tabular-nums text-ink-100">
            {formatPercent(stats.progress)}
          </p>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b border-ink-800 bg-ink-950/90 backdrop-blur">
          <div className="flex items-center gap-4 px-4 py-3 sm:px-8">
            <div className="relative w-full max-w-md">
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

            {data.settings.source === 'mock' && (
              <span className="ml-auto shrink-0 rounded-full border border-busy/40 bg-busy/10 px-3 py-1 text-xs font-medium text-busy">
                Données d’exemple
              </span>
            )}
          </div>

          <nav className="flex gap-1 overflow-x-auto border-t border-ink-800 px-2 py-2 md:hidden">
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) =>
                  `rounded-lg px-3 py-1.5 text-sm whitespace-nowrap ${
                    isActive ? 'bg-accent/15 text-accent-soft' : 'text-ink-300'
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </header>

        <main className="flex-1 px-4 py-6 sm:px-8">{children}</main>
      </div>
    </div>
  );
}
