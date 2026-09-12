import { describe, expect, it } from 'vitest';
import {
  cleanName,
  createProfileStore,
  dataKeyFor,
  EMPTY_SESSION,
  isNameTaken,
  parseSession,
  type Profile,
} from './profiles';

/** Stockage en mémoire : les tests ne dépendent d'aucun navigateur. */
function fakeStorage(initial: Record<string, string> = {}): Storage {
  const map = new Map(Object.entries(initial));
  return {
    get length() {
      return map.size;
    },
    clear: () => map.clear(),
    getItem: (key: string) => map.get(key) ?? null,
    key: (index: number) => [...map.keys()][index] ?? null,
    removeItem: (key: string) => void map.delete(key),
    setItem: (key: string, value: string) => void map.set(key, value),
  };
}

const profile = (over: Partial<Profile> = {}): Profile => ({
  id: 'p1',
  name: 'David',
  email: null,
  createdAt: '2026-09-01',
  lastSeenAt: '2026-09-12',
  ...over,
});

describe('lecture d’une session', () => {
  it('rend une session vide pour un document illisible', () => {
    expect(parseSession(null)).toEqual(EMPTY_SESSION);
    expect(parseSession('bonjour')).toEqual(EMPTY_SESSION);
    expect(parseSession({})).toEqual(EMPTY_SESSION);
  });

  it('écarte les entrées qui ne sont pas des profils', () => {
    const session = parseSession({ profiles: [profile(), { nom: 'raté' }, 42] });
    expect(session.profiles).toHaveLength(1);
  });

  it('oublie un profil actif qui n’existe plus', () => {
    const session = parseSession({ profiles: [profile()], activeProfileId: 'disparu' });
    expect(session.activeProfileId).toBeNull();
  });

  it('conserve un profil actif valide', () => {
    const session = parseSession({ profiles: [profile()], activeProfileId: 'p1' });
    expect(session.activeProfileId).toBe('p1');
  });

  it('normalise un email vide en « inconnu »', () => {
    expect(parseSession({ profiles: [profile({ email: '' })] }).profiles[0]?.email).toBeNull();
  });
});

describe('stockage', () => {
  it('relit ce qu’il a écrit', () => {
    const store = createProfileStore(fakeStorage());
    store.write({ profiles: [profile()], activeProfileId: 'p1' });
    expect(store.read()).toEqual({ profiles: [profile()], activeProfileId: 'p1' });
  });

  it('survit à un contenu corrompu', () => {
    const store = createProfileStore(
      fakeStorage({ 'epitech-tracker/v1/session': '{ ceci n’est pas du JSON' }),
    );
    expect(store.read()).toEqual(EMPTY_SESSION);
  });

  it('donne à chaque profil son propre tiroir de données', () => {
    expect(dataKeyFor('a')).not.toBe(dataKeyFor('b'));
    expect(dataKeyFor('a')).toContain('a');
  });
});

describe('noms de profil', () => {
  it('nettoie les espaces superflus', () => {
    expect(cleanName('  David   Agbeci  ')).toBe('David Agbeci');
  });

  it('borne la longueur', () => {
    expect(cleanName('x'.repeat(100))).toHaveLength(60);
  });

  it('repère un nom déjà pris, sans tenir compte de la casse', () => {
    const profiles = [profile({ name: 'David' })];
    expect(isNameTaken(profiles, 'david')).toBe(true);
    expect(isNameTaken(profiles, 'Autre')).toBe(false);
  });

  it('ne se signale pas lui-même lors d’un renommage', () => {
    const profiles = [profile({ id: 'p1', name: 'David' })];
    expect(isNameTaken(profiles, 'David', 'p1')).toBe(false);
  });
});
