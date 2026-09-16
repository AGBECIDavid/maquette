import { useSession } from '../../store/SessionContext';
import { AuthShell } from '../components/AuthShell';

/**
 * Reprendre un profil existant sur cet appareil.
 *
 * L'équivalent d'une page de connexion — sans mot de passe, parce qu'il n'y a
 * pas de serveur derrière pour en vérifier un. L'encadré de `AuthShell` le dit
 * à l'utilisateur plutôt que de le laisser croire à une protection.
 */
export function SignInPage({ onBack, onSignUp }: { onBack: () => void; onSignUp: () => void }) {
  const { profiles, selectProfile, deleteProfile } = useSession();

  return (
    <AuthShell
      title="Reprendre un profil"
      subtitle="Choisis le profil enregistré sur cet appareil."
      onBack={onBack}
      footer={
        <p className="text-center text-sm text-ink-400">
          Pas encore de profil ?{' '}
          <button type="button" onClick={onSignUp} className="text-accent hover:underline">
            Créer un profil
          </button>
        </p>
      }
    >
      {profiles.length === 0 ? (
        <p className="text-sm text-ink-400">
          Aucun profil sur cet appareil. Crée-en un pour commencer.
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {profiles.map((profile) => (
            <li
              key={profile.id}
              className="flex items-center gap-2 rounded-xl border border-ink-800 bg-ink-850 pr-2"
            >
              <button
                type="button"
                onClick={() => selectProfile(profile.id)}
                className="flex min-w-0 flex-1 items-center gap-3 px-4 py-3 text-left"
              >
                <span className="grid size-9 shrink-0 place-items-center rounded-full bg-accent/15 text-sm font-semibold text-accent">
                  {profile.name.slice(0, 1).toLocaleUpperCase()}
                </span>
                <span className="min-w-0">
                  <span className="block truncate text-sm text-ink-100">{profile.name}</span>
                  <span className="block truncate text-xs text-ink-400">
                    {profile.email ?? 'Profil local'}
                  </span>
                </span>
              </button>
              <button
                type="button"
                aria-label={`Supprimer le profil ${profile.name}`}
                className="rounded-md px-2 py-1 text-xs text-ink-600 hover:text-bad"
                onClick={() => {
                  if (
                    window.confirm(`Supprimer le profil « ${profile.name} » et toutes ses données ?`)
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
      )}
    </AuthShell>
  );
}
