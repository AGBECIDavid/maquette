/**
 * Profils locaux.
 *
 * ─────────────────────────────────────────────────────────────────────────
 *  CE N'EST PAS UNE AUTHENTIFICATION. Un profil n'est pas un compte : il
 *  n'y a ni mot de passe, ni serveur, ni vérification. C'est un tiroir dans
 *  le navigateur, pour que deux personnes sur la même machine ne mélangent
 *  pas leurs cursus.
 *
 *  L'interface le dit à l'utilisateur, en toutes lettres, au moment où il
 *  crée son profil. Un mot de passe stocké dans un navigateur ne protège
 *  rien, et laisser croire le contraire serait pire que de ne rien offrir.
 *
 *  Cette couche est volontairement isolée derrière `ProfileStore` : brancher
 *  une vraie authentification en production reviendra à écrire une autre
 *  implémentation, sans toucher aux écrans.
 * ─────────────────────────────────────────────────────────────────────────
 */

export interface Profile {
  id: string;
  name: string;
  /** Facultatif : sert d'aide-mémoire, jamais de moyen de connexion. */
  email: string | null;
  createdAt: string;
  lastSeenAt: string;
}

export interface Session {
  profiles: Profile[];
  activeProfileId: string | null;
}

export interface ProfileStore {
  read(): Session;
  write(session: Session): void;
}

const SESSION_KEY = 'epitech-tracker/v1/session';

/** Clé de stockage des données d'un profil : un tiroir par profil. */
export function dataKeyFor(profileId: string): string {
  return `epitech-tracker/v1/data/${profileId}`;
}

export const EMPTY_SESSION: Session = { profiles: [], activeProfileId: null };

function isProfile(value: unknown): value is Profile {
  if (typeof value !== 'object' || value === null) return false;
  const record = value as Record<string, unknown>;
  return typeof record['id'] === 'string' && typeof record['name'] === 'string';
}

/**
 * Relit une session stockée. Un document illisible rend une session vide
 * plutôt que de lever : on ne bloque pas l'accès à l'application parce
 * qu'une clé de stockage a été corrompue.
 */
export function parseSession(raw: unknown): Session {
  if (typeof raw !== 'object' || raw === null) return EMPTY_SESSION;
  const record = raw as Record<string, unknown>;
  const list = Array.isArray(record['profiles']) ? record['profiles'] : [];

  const profiles = list.filter(isProfile).map((profile) => ({
    ...profile,
    email: typeof profile.email === 'string' && profile.email !== '' ? profile.email : null,
    createdAt: typeof profile.createdAt === 'string' ? profile.createdAt : '',
    lastSeenAt: typeof profile.lastSeenAt === 'string' ? profile.lastSeenAt : '',
  }));

  const active = record['activeProfileId'];
  // Un profil actif qui n'existe plus ne doit pas laisser l'application
  // afficher les données de personne.
  const activeProfileId =
    typeof active === 'string' && profiles.some((p) => p.id === active) ? active : null;

  return { profiles, activeProfileId };
}

export function createProfileStore(storage: Storage = window.localStorage): ProfileStore {
  return {
    read(): Session {
      try {
        const raw = storage.getItem(SESSION_KEY);
        return raw === null ? EMPTY_SESSION : parseSession(JSON.parse(raw));
      } catch {
        return EMPTY_SESSION;
      }
    },
    write(session: Session): void {
      try {
        storage.setItem(SESSION_KEY, JSON.stringify(session));
      } catch (error) {
        console.error('Session non enregistrée :', error);
      }
    },
  };
}

/** Nettoie un nom saisi : espaces en trop, longueur bornée. */
export function cleanName(name: string): string {
  return name.trim().replace(/\s+/g, ' ').slice(0, 60);
}

export function isNameTaken(profiles: readonly Profile[], name: string, exceptId?: string): boolean {
  const target = cleanName(name).toLocaleLowerCase();
  return profiles.some(
    (p) => p.id !== exceptId && p.name.toLocaleLowerCase() === target,
  );
}
