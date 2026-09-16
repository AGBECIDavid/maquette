/**
 * Icônes de navigation, au trait.
 *
 * Dessinées ici plutôt qu'importées d'une librairie : sept icônes ne
 * justifient pas une dépendance, et `currentColor` les fait suivre l'état
 * actif du lien sans règle supplémentaire.
 *
 * Toutes sur une grille de 24, trait de 1,75 — assez fin pour rester calme à
 * côté du texte, assez épais pour ne pas disparaître sur le fond sombre.
 */

import type { ReactNode } from 'react';

function Icon({ children }: { children: ReactNode }) {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className="shrink-0"
    >
      {children}
    </svg>
  );
}

export const NAV_ICONS = {
  /** Dashboard : un toit, l'écran d'accueil. */
  dashboard: (
    <Icon>
      <path d="M3 10.5 12 3l9 7.5" />
      <path d="M5.5 9.5V20h13V9.5" />
      <path d="M9.5 20v-6h5v6" />
    </Icon>
  ),
  /** Roadblocks : un jalon planté sur le parcours. */
  roadblocks: (
    <Icon>
      <path d="M6 21V3" />
      <path d="M6 4h11l-2.2 3.5L17 11H6" />
      <circle cx="6" cy="21" r="0.6" fill="currentColor" />
    </Icon>
  ),
  /** Modules : des strates empilées. */
  modules: (
    <Icon>
      <path d="m12 3 8.5 4.5L12 12 3.5 7.5 12 3Z" />
      <path d="m3.5 12 8.5 4.5 8.5-4.5" />
      <path d="m3.5 16.5 8.5 4.5 8.5-4.5" />
    </Icon>
  ),
  /** Projets : une liste de tâches. */
  projects: (
    <Icon>
      <path d="M4 5h4v4H4z" />
      <path d="M4 15h4v4H4z" />
      <path d="M11 7h9" />
      <path d="M11 17h9" />
    </Icon>
  ),
  /** Calendrier. */
  calendar: (
    <Icon>
      <rect x="3.5" y="5" width="17" height="15.5" rx="2.5" />
      <path d="M3.5 10h17" />
      <path d="M8 3v4" />
      <path d="M16 3v4" />
    </Icon>
  ),
  /** Statistiques : des barres ascendantes, comme dans la marque. */
  stats: (
    <Icon>
      <path d="M4 20h16" />
      <path d="M7 20v-5" />
      <path d="M12 20V8" />
      <path d="M17 20v-8" />
    </Icon>
  ),
  /**
   * Paramètres : des curseurs de réglage.
   *
   * Un engrenage au trait se dessine mal à 18 px, et un cercle entouré de
   * rayons — l'approximation habituelle — lit « soleil » ou « luminosité »,
   * pas « réglages ».
   */
  settings: (
    <Icon>
      <path d="M4 7h16M4 12h16M4 17h16" />
      <circle cx="9" cy="7" r="2" />
      <circle cx="15" cy="12" r="2" />
      <circle cx="8" cy="17" r="2" />
    </Icon>
  ),
} as const;
