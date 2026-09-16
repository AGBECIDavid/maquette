import { useState } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { NAV_ICONS } from '../components/NavIcons';

/**
 * Navigation mobile : une barre d'onglets en bas.
 *
 * Un bandeau d'onglets en haut obligeait à faire défiler horizontalement
 * pour atteindre la moitié des destinations — invisibles, donc jamais
 * ouvertes — et se visait mal au pouce. En bas, tout est à portée.
 *
 * Quatre destinations tiennent confortablement ; les trois autres passent
 * derrière « Plus », plutôt que de serrer sept onglets dans 390 px.
 */

const PRIMARY = [
  { to: '/', label: 'Dashboard', icon: NAV_ICONS.dashboard, end: true },
  { to: '/roadblocks', label: 'Roadblocks', icon: NAV_ICONS.roadblocks, end: false },
  { to: '/modules', label: 'Modules', icon: NAV_ICONS.modules, end: false },
  { to: '/projects', label: 'Projets', icon: NAV_ICONS.projects, end: false },
];

const SECONDARY = [
  { to: '/calendrier', label: 'Calendrier', icon: NAV_ICONS.calendar },
  { to: '/statistiques', label: 'Statistiques', icon: NAV_ICONS.stats },
  { to: '/parametres', label: 'Paramètres', icon: NAV_ICONS.settings },
];

const ITEM =
  'flex min-h-14 flex-1 flex-col items-center justify-center gap-1 px-1 text-[10px] leading-none transition-colors';

export function MobileNav() {
  const [open, setOpen] = useState(false);
  const { pathname } = useLocation();
  const secondaryActive = SECONDARY.some((item) => pathname.startsWith(item.to));

  return (
    <>
      {open && (
        <div
          className="fixed inset-0 z-40 bg-ink-950/60 md:hidden"
          onClick={() => setOpen(false)}
          aria-hidden
        />
      )}

      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-ink-800 bg-ink-900/95 backdrop-blur md:hidden">
        {open && (
          <ul className="flex flex-col border-b border-ink-800">
            {SECONDARY.map((item) => (
              <li key={item.to}>
                <NavLink
                  to={item.to}
                  onClick={() => setOpen(false)}
                  className={({ isActive }) =>
                    `flex min-h-14 items-center gap-3 px-5 text-sm ${
                      isActive ? 'text-accent' : 'text-ink-300'
                    }`
                  }
                >
                  {item.icon}
                  {item.label}
                </NavLink>
              </li>
            ))}
          </ul>
        )}

        {/* La marge basse suit l'encoche : sur iPhone, la barre système
            mangerait sinon le dernier tiers des onglets. */}
        <ul className="flex pb-[env(safe-area-inset-bottom)]">
          {PRIMARY.map((item) => (
            <li key={item.to} className="flex flex-1">
              <NavLink
                to={item.to}
                end={item.end}
                onClick={() => setOpen(false)}
                className={({ isActive }) =>
                  `${ITEM} ${isActive && !open ? 'text-accent' : 'text-ink-400'}`
                }
              >
                {item.icon}
                <span className="truncate">{item.label}</span>
              </NavLink>
            </li>
          ))}
          <li className="flex flex-1">
            <button
              type="button"
              onClick={() => setOpen((value) => !value)}
              aria-expanded={open}
              className={`${ITEM} ${open || secondaryActive ? 'text-accent' : 'text-ink-400'}`}
            >
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.75"
                strokeLinecap="round"
                aria-hidden
              >
                <path d="M5 8h14M5 12h14M5 16h14" />
              </svg>
              <span>Plus</span>
            </button>
          </li>
        </ul>
      </nav>
    </>
  );
}
