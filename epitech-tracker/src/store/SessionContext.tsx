/**
 * Session locale : quel profil utilise l'application.
 *
 * Ce n'est pas une authentification (voir `data/profiles.ts`). C'est
 * l'aiguillage qui décide quel tiroir de données l'application ouvre.
 */

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {
  cleanName,
  createProfileStore,
  dataKeyFor,
  isNameTaken,
  type Profile,
  type Session,
} from '../data/profiles';
import {
  createLocalStorageRepository,
  LEGACY_STORAGE_KEY,
} from '../data/localStorageRepository';
import { mockCurriculum } from '../data/mock';
import { today } from '../domain/dates';

interface SessionStore {
  profiles: Profile[];
  activeProfile: Profile | null;
  createProfile: (input: { name: string; email: string; withSample: boolean }) => void;
  selectProfile: (id: string) => void;
  renameProfile: (id: string, name: string) => void;
  deleteProfile: (id: string) => void;
  signOut: () => void;
  nameTaken: (name: string, exceptId?: string) => boolean;
}

const Context = createContext<SessionStore | null>(null);

/**
 * Reprise des données d'avant les profils : elles sont rattachées à un
 * premier profil plutôt que laissées orphelines dans le stockage.
 */
function adoptLegacyData(): Session | null {
  try {
    const legacy = window.localStorage.getItem(LEGACY_STORAGE_KEY);
    if (legacy === null) return null;

    const id = crypto.randomUUID();
    window.localStorage.setItem(dataKeyFor(id), legacy);
    window.localStorage.removeItem(LEGACY_STORAGE_KEY);

    const now = today();
    return {
      profiles: [
        { id, name: 'Mon cursus', email: null, createdAt: now, lastSeenAt: now },
      ],
      activeProfileId: id,
    };
  } catch {
    return null;
  }
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const store = useRef(createProfileStore()).current;

  const [session, setSession] = useState<Session>(() => {
    const existing = store.read();
    if (existing.profiles.length > 0) return existing;
    const adopted = adoptLegacyData();
    if (adopted !== null) {
      store.write(adopted);
      return adopted;
    }
    return existing;
  });

  const commit = useCallback(
    (next: Session) => {
      store.write(next);
      setSession(next);
    },
    [store],
  );

  const activeProfile = useMemo(
    () => session.profiles.find((p) => p.id === session.activeProfileId) ?? null,
    [session],
  );

  const value: SessionStore = {
    profiles: session.profiles,
    activeProfile,

    createProfile: useCallback(
      ({ name, email, withSample }) => {
        const id = crypto.randomUUID();
        const now = today();

        // Le jeu d'exemple est écrit dans le tiroir du profil au moment de sa
        // création : l'application n'a ensuite qu'à lire ce qui s'y trouve,
        // sans règle cachée sur « le premier lancement ».
        if (withSample) {
          createLocalStorageRepository(dataKeyFor(id)).save(mockCurriculum());
        }

        commit({
          profiles: [
            ...session.profiles,
            { id, name: cleanName(name), email: email.trim() === '' ? null : email.trim(), createdAt: now, lastSeenAt: now },
          ],
          activeProfileId: id,
        });
      },
      [commit, session.profiles],
    ),

    selectProfile: useCallback(
      (id) => {
        commit({
          profiles: session.profiles.map((p) =>
            p.id === id ? { ...p, lastSeenAt: today() } : p,
          ),
          activeProfileId: id,
        });
      },
      [commit, session.profiles],
    ),

    renameProfile: useCallback(
      (id, name) => {
        commit({
          ...session,
          profiles: session.profiles.map((p) =>
            p.id === id ? { ...p, name: cleanName(name) } : p,
          ),
        });
      },
      [commit, session],
    ),

    deleteProfile: useCallback(
      (id) => {
        // Le tiroir de données part avec le profil : le laisser derrière
        // encombrerait le stockage sans que rien ne puisse plus le lire.
        createLocalStorageRepository(dataKeyFor(id)).clear();
        const profiles = session.profiles.filter((p) => p.id !== id);
        commit({
          profiles,
          activeProfileId: session.activeProfileId === id ? null : session.activeProfileId,
        });
      },
      [commit, session],
    ),

    signOut: useCallback(() => {
      commit({ ...session, activeProfileId: null });
    }, [commit, session]),

    nameTaken: useCallback(
      (name, exceptId) => isNameTaken(session.profiles, name, exceptId),
      [session.profiles],
    ),
  };

  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function useSession(): SessionStore {
  const store = useContext(Context);
  if (store === null) {
    throw new Error('useSession doit être utilisé dans <SessionProvider>');
  }
  return store;
}
