import { useEffect, useState } from 'react';
import { LogoMark, TAGLINE } from '../components/Logo';

/** Durée de l'animation complète, keyframes de `index.css` comprises. */
const FULL_DURATION_MS = 2300;
/** Durée quand l'utilisateur a demandé moins de mouvement. */
const REDUCED_DURATION_MS = 700;
const FADE_OUT_MS = 280;

export const SPLASH_SESSION_KEY = 'epitech-tracker/splash-seen';

function prefersReducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/**
 * Écran d'ouverture.
 *
 * Trois règles, parce qu'une animation qu'on ne peut pas éviter devient vite
 * une corvée :
 *
 *   1. Elle se passe au clic, à la touche, ou par le bouton « Passer ».
 *   2. Elle ne se joue qu'une fois par session, pas à chaque navigation.
 *   3. `prefers-reduced-motion` la réduit à un affichage bref et fixe.
 */
export function SplashScreen({ onDone }: { onDone: () => void }) {
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    const reduced = prefersReducedMotion();
    let fade: number;

    const finish = () => {
      setLeaving(true);
      fade = window.setTimeout(onDone, FADE_OUT_MS);
    };

    const hold = window.setTimeout(
      finish,
      reduced ? REDUCED_DURATION_MS : FULL_DURATION_MS,
    );

    // Passer : n'importe quelle touche, n'importe quel clic.
    const skip = () => {
      window.clearTimeout(hold);
      finish();
    };
    window.addEventListener('keydown', skip, { once: true });
    window.addEventListener('pointerdown', skip, { once: true });

    return () => {
      window.clearTimeout(hold);
      window.clearTimeout(fade);
      window.removeEventListener('keydown', skip);
      window.removeEventListener('pointerdown', skip);
    };
  }, [onDone]);

  return (
    <div
      className={`fixed inset-0 z-50 flex flex-col items-center justify-center bg-ink-950 ${leaving ? 'splash-leaving' : ''}`}
    >
      <LogoMark size={148} animated />

      <p className="splash-word mt-6 text-center text-3xl font-bold tracking-tight text-ink-100">
        Epitech <span className="text-accent">Tracker</span>
      </p>
      <p className="splash-tagline mt-3 text-sm text-ink-400">{TAGLINE}</p>

      <button
        type="button"
        onClick={onDone}
        className="splash-hint absolute bottom-10 rounded-lg px-4 py-2 text-xs text-ink-400 hover:text-ink-100"
      >
        Passer
      </button>
    </div>
  );
}
