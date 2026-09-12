import { useId } from 'react';

/**
 * Marque Epitech Tracker.
 *
 * Redessinée en SVG plutôt qu'importée en PNG : nette à toutes les tailles,
 * quelques centaines d'octets, et lisible sur fond sombre comme sur fond
 * clair — un PNG sur fond blanc ferait une tache sur l'interface.
 *
 * Les identifiants de dégradé sont générés par `useId` : deux marques sur la
 * même page partageraient sinon le même `id`, et la seconde irait chercher le
 * dégradé de la première.
 */
export function LogoMark({ size = 32, className = '' }: { size?: number; className?: string }) {
  const id = useId();
  const blue = `${id}-blue`;
  const steel = `${id}-steel`;

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      className={className}
      role="img"
      aria-label="Epitech Tracker"
    >
      <defs>
        <linearGradient id={blue} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#1d4ed8" />
          <stop offset="1" stopColor="#3b82f6" />
        </linearGradient>
        <linearGradient id={steel} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#cbd5e1" />
          <stop offset="1" stopColor="#7c93b8" />
        </linearGradient>
      </defs>

      {/* La barre du T, cisaillée comme dans la marque d'origine. */}
      <path d="M12 5 H58 L49 19 H3 Z" fill={`url(#${blue})`} />
      {/* Le fût, arrondi au pied. */}
      <path d="M19 19 H31 V51 a4 4 0 0 1 -4 4 H19 Z" fill={`url(#${steel})`} />
      {/* La diagonale de progression. */}
      <path d="M44 19 H54 L33 55 H23 Z" fill={`url(#${blue})`} />
      {/* Trois barres ascendantes : le suivi. */}
      <rect x="38" y="40" width="7" height="15" rx="2" fill="#3b82f6" />
      <rect x="48" y="32" width="7" height="23" rx="2" fill="#3b82f6" />
      <rect x="58" y="24" width="6" height="31" rx="2" fill="#3b82f6" />
    </svg>
  );
}

/** Marque + typographie, pour l'en-tête de la barre latérale. */
export function Logo() {
  return (
    <div className="flex items-center gap-3">
      <LogoMark size={36} className="shrink-0" />
      <div className="min-w-0">
        <p className="text-sm leading-tight font-semibold tracking-[0.12em] text-ink-100">
          EPITECH
        </p>
        <p className="text-sm leading-tight font-semibold tracking-[0.12em] text-accent-soft">
          TRACKER
        </p>
      </div>
    </div>
  );
}

export const TAGLINE = 'Planifier · Suivre · Réussir';
