import { parseCurriculum, SchemaError } from './schema';
import type { Repository } from './repository';
import type { Curriculum } from '../domain/types';

/** Clé d'avant les profils. Ne sert plus qu'à récupérer d'anciennes données. */
export const LEGACY_STORAGE_KEY = 'epitech-academic-tracker/v1';

/**
 * Persistance dans le navigateur, sous une clé donnée.
 *
 * La clé est un paramètre : chaque profil a son propre tiroir, et deux
 * profils de la même machine ne peuvent pas se marcher dessus.
 *
 * Toute opération peut échouer (navigation privée, quota, données écrites par
 * un autre onglet) : une exception de stockage ne doit jamais casser
 * l'interface. Mais une donnée corrompue n'est pas masquée pour autant —
 * `load()` rend `null`, et l'appelant décide quoi en faire.
 */
export function createLocalStorageRepository(
  storageKey: string,
  storage: Storage = window.localStorage,
): Repository {
  return {
    load(): Curriculum | null {
      let raw: string | null;
      try {
        raw = storage.getItem(storageKey);
      } catch {
        return null;
      }
      if (raw === null) return null;
      try {
        return parseCurriculum(JSON.parse(raw));
      } catch (error) {
        if (error instanceof SchemaError) {
          console.error('Données locales illisibles :', error.message);
        }
        return null;
      }
    },

    save(data: Curriculum): void {
      try {
        storage.setItem(storageKey, JSON.stringify(data));
      } catch (error) {
        console.error('Sauvegarde impossible :', error);
      }
    },

    clear(): void {
      try {
        storage.removeItem(storageKey);
      } catch {
        /* rien à faire : le stockage est déjà indisponible */
      }
    },
  };
}
