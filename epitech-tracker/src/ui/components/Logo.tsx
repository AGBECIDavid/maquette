import { useId } from 'react';

/**
 * Marque Epitech Tracker, d'après la charte.
 *
 * Cinq pièces : le chapeau de diplômé et sa houppe, la barre et le fût du T,
 * la diagonale de progression, les trois barres de suivi.
 *
 * Redessinée en SVG plutôt qu'importée en PNG : nette à toutes les tailles,
 * quelques centaines d'octets, lisible sur fond sombre comme sur fond clair.
 * Le tracé a été comparé à 104, 48, 24 et 16 px avant d'être retenu — un logo
 * qui ne survit pas à la taille d'un favicon n'est pas un logo d'application.
 *
 * Les identifiants de dégradé viennent de `useId` : deux marques sur la même
 * page partageraient sinon le même `id`, et la seconde irait chercher le
 * dégradé de la première.
 */
export function LogoMark({
  size = 32,
  className = '',
  animated = false,
}: {
  size?: number;
  className?: string;
  /** Anime l'apparition des pièces. Voir les keyframes dans index.css. */
  animated?: boolean;
}) {
  const id = useId();
  const blue = `${id}-blue`;
  const light = `${id}-light`;

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      className={`${animated ? 'logo-animate' : ''} ${className}`}
      role="img"
      aria-label="Epitech Tracker"
    >
      <defs>
        <linearGradient id={blue} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#1B3A6B" />
          <stop offset="1" stopColor="#3B82F6" />
        </linearGradient>
        <linearGradient id={light} x1="0" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#F8FAFC" />
          <stop offset="1" stopColor="#B9C6DA" />
        </linearGradient>
      </defs>

      {/* La barre du T, cisaillée comme dans la charte. */}
      <path className="logo-bar" d="M10 16 H54 L46 28 H2 Z" fill={`url(#${light})`} />
      {/* Le fût, arrondi au pied. */}
      <path
        className="logo-stem"
        d="M18 28 H30 V54 a4 4 0 0 1 -4 4 H18 Z"
        fill={`url(#${light})`}
      />
      {/* La diagonale de progression. */}
      <path className="logo-diagonal" d="M44 28 H54 L34 58 H24 Z" fill={`url(#${blue})`} />
      {/* Trois barres ascendantes : le suivi. */}
      <rect className="logo-bar1" x="38" y="44" width="7" height="14" rx="2" fill="#3B82F6" />
      <rect className="logo-bar2" x="48" y="37" width="7" height="21" rx="2" fill="#3B82F6" />
      <rect className="logo-bar3" x="58" y="30" width="6" height="28" rx="2" fill="#3B82F6" />
      {/* Le chapeau : planche, bandeau, houppe. */}
      <g className="logo-cap">
        <path d="M32 3 L56 11 L32 19 L8 11 Z" fill={`url(#${blue})`} />
        <path d="M32 19 L21 15.4 V20 a11 4.5 0 0 0 22 0 v-4.6 Z" fill="#1B3A6B" />
        <path d="M56 11 v8" stroke="#3B82F6" strokeWidth="2" fill="none" />
        <circle cx="56" cy="20" r="2.2" fill="#3B82F6" />
      </g>
    </svg>
  );
}

/**
 * Marque + typographie. Le nom s'écrit `Epitech Tracker`, en casse normale :
 * les capitales de la première version ne venaient pas de la charte.
 */
export function Logo({ size = 40 }: { size?: number }) {
  return (
    <div className="flex items-center gap-3">
      <LogoMark size={size} className="shrink-0" />
      <div className="min-w-0 leading-none">
        <span className="block text-lg font-bold tracking-tight text-ink-100">Epitech</span>
        <span className="block text-lg font-bold tracking-tight text-accent">Tracker</span>
      </div>
    </div>
  );
}

export const TAGLINE = 'Suivre · Planifier · Réussir';
