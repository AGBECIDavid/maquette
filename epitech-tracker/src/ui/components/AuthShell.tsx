import type { ReactNode } from 'react';
import { Logo, TAGLINE } from './Logo';

/**
 * Cadre commun aux écrans d'authentification.
 *
 * Le rappel du bas est volontairement dans le cadre plutôt que dans une page :
 * il doit être sous les yeux au moment où l'on saisit quelque chose, pas dans
 * une aide que personne n'ouvre.
 */
export function AuthShell({
  title,
  subtitle,
  onBack,
  children,
  footer,
}: {
  title: string;
  subtitle: string;
  onBack: () => void;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <div className="landing-grid flex min-h-full items-start justify-center px-4 py-8 sm:items-center sm:px-6 sm:py-10">
      <div className="w-full max-w-md">
        <button
          type="button"
          onClick={onBack}
          className="mb-5 text-xs text-ink-400 hover:text-ink-100"
        >
          ← Retour
        </button>

        <div className="mb-6 flex flex-col items-center text-center">
          <Logo size={48} />
          <p className="mt-2 text-xs text-ink-400">{TAGLINE}</p>
        </div>

        <div className="rounded-2xl border border-ink-800 bg-ink-900 p-5 sm:p-6">
          <h1 className="text-lg font-semibold text-ink-100">{title}</h1>
          <p className="mt-1 mb-5 text-sm text-ink-400">{subtitle}</p>
          {children}
        </div>

        {footer !== undefined && <div className="mt-5">{footer}</div>}

        <p className="mt-5 rounded-xl border border-ink-800 px-4 py-3 text-xs leading-relaxed text-ink-400">
          <strong className="text-ink-300">Pas de mot de passe, et c’est volontaire.</strong> Un
          profil est un tiroir sur cet appareil, pas un compte en ligne : tes données restent dans
          ce navigateur, ne partent sur aucun serveur, et ne sont pas protégées de quelqu’un qui
          aurait accès à la machine. Pense à exporter ton cursus depuis les Paramètres.
        </p>
      </div>
    </div>
  );
}
