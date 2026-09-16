import { Logo, TAGLINE } from '../components/Logo';
import { NAV_ICONS } from '../components/NavIcons';

/**
 * Écran d'arrivée.
 *
 * Il ne demande rien : il dit à quoi sert l'application, puis laisse choisir
 * entre créer un profil et en reprendre un. Poser un formulaire à quelqu'un
 * qui ne sait pas encore ce qu'il regarde est le meilleur moyen de le perdre.
 */
export function LandingPage({
  onSignUp,
  onSignIn,
  hasProfiles,
}: {
  onSignUp: () => void;
  onSignIn: () => void;
  /** Sans profil sur l'appareil, « Connexion » n'aurait rien à proposer. */
  hasProfiles: boolean;
}) {
  const features = [
    { icon: NAV_ICONS.stats, label: 'Suivi des crédits' },
    { icon: NAV_ICONS.roadblocks, label: 'Roadblocks' },
    { icon: NAV_ICONS.projects, label: 'Projets' },
    { icon: NAV_ICONS.calendar, label: 'Calendrier' },
  ];

  return (
    <div className="landing-grid flex min-h-full items-center justify-center px-4 py-10 sm:px-6">
      <div className="w-full max-w-lg text-center">
        <div className="flex justify-center">
          <Logo size={60} />
        </div>
        <p className="mt-3 text-sm text-ink-400">{TAGLINE}</p>

        <h1 className="mt-10 text-3xl leading-tight font-bold text-ink-100 sm:text-4xl">
          Optimisez votre
          <br />
          parcours Epitech
        </h1>
        <p className="mx-auto mt-4 max-w-md text-sm text-ink-300 sm:text-base">
          Roadblocks, modules, projets et crédits au même endroit. Vous voyez où vous en êtes, ce
          qu’il vous reste, et ce qui est urgent.
        </p>

        <div className="mt-8 flex flex-col gap-3">
          <button
            type="button"
            onClick={onSignUp}
            className="w-full rounded-xl bg-accent px-5 py-3.5 text-sm font-semibold text-white transition-colors hover:bg-accent-soft"
          >
            Commencer — créer un profil
          </button>
          <button
            type="button"
            onClick={onSignIn}
            disabled={!hasProfiles}
            className="w-full rounded-xl border border-accent/60 px-5 py-3.5 text-sm font-semibold text-accent transition-colors hover:border-accent hover:bg-accent/10 disabled:cursor-not-allowed disabled:border-ink-800 disabled:text-ink-600 disabled:hover:bg-transparent"
          >
            {hasProfiles ? 'Reprendre un profil' : 'Aucun profil sur cet appareil'}
          </button>
        </div>

        <ul className="mt-10 grid grid-cols-2 gap-3 sm:grid-cols-4">
          {features.map((feature) => (
            <li
              key={feature.label}
              className="flex flex-col items-center gap-2 rounded-xl border border-ink-800 bg-ink-900/60 px-2 py-4 text-ink-400"
            >
              <span className="text-accent">{feature.icon}</span>
              <span className="text-[11px] leading-tight text-ink-300">{feature.label}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
