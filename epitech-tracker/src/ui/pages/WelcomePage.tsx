import { useState } from 'react';
import { useSession } from '../../store/SessionContext';
import { Logo, TAGLINE } from '../components/Logo';
import { Button } from '../components/Primitives';
import { Field, Select, TextInput } from '../components/Form';
import { TEK_LEVELS, type TekLevel } from '../../domain/types';

/**
 * Accueil : choisir un profil ou en créer un.
 *
 * Aucun mot de passe, et l'écran le dit. Un profil est un tiroir local, pas
 * un compte en ligne : promettre l'inverse mettrait les bêta-testeurs en
 * confiance sur une protection qui n'existe pas.
 */
export function WelcomePage() {
  const { profiles, createProfile, selectProfile, deleteProfile, nameTaken } = useSession();
  const [creating, setCreating] = useState(profiles.length === 0);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [withSample, setWithSample] = useState(true);
  const [level, setLevel] = useState<TekLevel | 'unknown'>('TEK1');

  const cleaned = name.trim();
  const taken = cleaned !== '' && nameTaken(cleaned);
  const canCreate = cleaned !== '' && !taken;

  return (
    <div className="flex min-h-full items-center justify-center px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-8 flex flex-col items-center text-center">
          <Logo size={52} />
          <p className="mt-3 text-sm text-ink-400">{TAGLINE}</p>
        </div>

        {profiles.length > 0 && !creating && (
          <div className="mb-6">
            <h1 className="mb-3 text-sm font-medium text-ink-300">Reprendre un profil</h1>
            <ul className="flex flex-col gap-2">
              {profiles.map((profile) => (
                <li
                  key={profile.id}
                  className="flex items-center gap-2 rounded-xl border border-ink-800 bg-ink-900 pr-2"
                >
                  <button
                    type="button"
                    onClick={() => selectProfile(profile.id)}
                    className="flex-1 px-4 py-3 text-left"
                  >
                    <span className="block text-sm text-ink-100">{profile.name}</span>
                    <span className="block text-xs text-ink-400">
                      {profile.email ?? 'Profil local'}
                    </span>
                  </button>
                  <button
                    type="button"
                    aria-label={`Supprimer le profil ${profile.name}`}
                    className="rounded-md px-2 py-1 text-xs text-ink-600 hover:text-bad"
                    onClick={() => {
                      if (
                        window.confirm(
                          `Supprimer le profil « ${profile.name} » et toutes ses données ?`,
                        )
                      ) {
                        deleteProfile(profile.id);
                      }
                    }}
                  >
                    Supprimer
                  </button>
                </li>
              ))}
            </ul>
            <Button className="mt-4 w-full" onClick={() => setCreating(true)}>
              + Nouveau profil
            </Button>
          </div>
        )}

        {creating && (
          <form
            className="flex flex-col gap-4 rounded-xl border border-ink-800 bg-ink-900 p-6"
            onSubmit={(event) => {
              event.preventDefault();
              if (canCreate) {
                createProfile({
                  name,
                  email,
                  withSample,
                  level: level === 'unknown' ? null : level,
                });
              }
            }}
          >
            <h1 className="text-base font-semibold text-ink-100">Créer un profil</h1>

            <Field label="Nom">
              <TextInput value={name} onChange={setName} autoFocus placeholder="David" />
            </Field>
            {taken && <p className="-mt-2 text-xs text-bad">Ce nom est déjà pris sur cet appareil.</p>}

            <Field label="Email (facultatif)" hint="Sert d’aide-mémoire, jamais de moyen de connexion">
              <TextInput value={email} onChange={setEmail} placeholder="david@exemple.fr" />
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

            <div className="flex gap-2">
              {profiles.length > 0 && (
                <Button type="button" onClick={() => setCreating(false)}>
                  Annuler
                </Button>
              )}
              <Button type="submit" variant="primary" disabled={!canCreate} className="flex-1">
                Commencer
              </Button>
            </div>
          </form>
        )}

        <p className="mt-6 rounded-lg border border-ink-800 px-4 py-3 text-xs leading-relaxed text-ink-400">
          <strong className="text-ink-300">Pas de mot de passe, et c’est volontaire.</strong> Un
          profil est un tiroir sur cet appareil, pas un compte en ligne : tes données restent dans
          ce navigateur, ne partent sur aucun serveur, et ne sont pas protégées de quelqu’un qui
          aurait accès à la machine. Pense à exporter ton cursus depuis les Paramètres.
        </p>
      </div>
    </div>
  );
}
