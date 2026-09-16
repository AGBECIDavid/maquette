import { useState } from 'react';
import { useSession } from '../../store/SessionContext';
import { AuthShell } from '../components/AuthShell';
import { Field, Select, TextInput } from '../components/Form';
import { TEK_LEVELS, type TekLevel } from '../../domain/types';

/**
 * Création d'un profil local.
 *
 * Le niveau demandé ici ouvre la première année du cursus ; il n'est pas
 * stocké sur le profil (voir `domain/types.ts`), pour n'avoir qu'une seule
 * source de vérité le jour d'un passage de niveau ou d'un redoublement.
 */
export function SignUpPage({ onBack, onSignIn }: { onBack: () => void; onSignIn: () => void }) {
  const { profiles, createProfile, nameTaken } = useSession();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [withSample, setWithSample] = useState(true);
  const [level, setLevel] = useState<TekLevel | 'unknown'>('TEK1');

  const cleaned = name.trim();
  const taken = cleaned !== '' && nameTaken(cleaned);
  const canCreate = cleaned !== '' && !taken;

  return (
    <AuthShell
      title="Créer un profil"
      subtitle="Quelques secondes, et rien à retenir."
      onBack={onBack}
      footer={
        profiles.length === 0 ? undefined : (
          <p className="text-center text-sm text-ink-400">
            Déjà un profil ?{' '}
            <button type="button" onClick={onSignIn} className="text-accent hover:underline">
              Le reprendre
            </button>
          </p>
        )
      }
    >
      <form
        className="flex flex-col gap-4"
        onSubmit={(event) => {
          event.preventDefault();
          if (canCreate) {
            createProfile({ name, email, withSample, level: level === 'unknown' ? null : level });
          }
        }}
      >
        <Field label="Nom">
          <TextInput value={name} onChange={setName} autoFocus placeholder="David" />
        </Field>
        {taken && <p className="-mt-2 text-xs text-bad">Ce nom est déjà pris sur cet appareil.</p>}

        <Field label="Email (facultatif)" hint="Sert d’aide-mémoire, jamais de moyen de connexion">
          <TextInput value={email} onChange={setEmail} placeholder="david@epitech.eu" />
        </Field>

        <Field
          label="Niveau actuel"
          hint="Il ouvre ta première année. Au passage au niveau suivant, cette année sera conservée."
        >
          <Select
            value={level}
            onChange={setLevel}
            options={[
              ...TEK_LEVELS.map((value) => ({ value, label: value })),
              { value: 'unknown' as const, label: 'Je préfère ne pas préciser' },
            ]}
          />
        </Field>

        <label className="flex items-start gap-3 text-sm text-ink-300">
          <input
            type="checkbox"
            checked={withSample}
            onChange={(event) => setWithSample(event.target.checked)}
            className="mt-0.5 size-4 accent-[var(--color-accent)]"
          />
          <span>
            Démarrer avec des données d’exemple
            <span className="block text-xs text-ink-400">
              Un cursus fictif pour explorer l’application. Remplaçable à tout moment.
            </span>
          </span>
        </label>

        <button
          type="submit"
          disabled={!canCreate}
          className="mt-1 w-full rounded-xl bg-accent px-5 py-3 text-sm font-semibold text-white transition-colors hover:bg-accent-soft disabled:cursor-not-allowed disabled:opacity-40"
        >
          Créer mon profil
        </button>
      </form>
    </AuthShell>
  );
}
