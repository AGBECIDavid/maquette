import { parseCurriculum, SchemaError } from './schema';
import type { Repository } from './repository';
import type { Curriculum } from '../domain/types';

const STORAGE_KEY = 'epitech-academic-tracker/v1';

/**
 * Persistance dans le navigateur.
 *
 * Toute opération peut échouer (navigation privée, quota, données d'un autre
 * onglet) : on ne laisse jamais une exception de stockage casser l'interface,
 * mais on ne masque pas non plus une donnée corrompue — `load()` rend `null`
 * et l'appelant décide.
 */
export function createLocalStorageRepository(
  storage: Storage = window.localStorage,
): Repository {
  return {
    load(): Curriculum | null {
      let raw: string | null;
      try {
        raw = storage.getItem(STORAGE_KEY);
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
        storage.setItem(STORAGE_KEY, JSON.stringify(data));
      } catch (error) {
        console.error('Sauvegarde impossible :', error);
      }
    },

    clear(): void {
      try {
        storage.removeItem(STORAGE_KEY);
      } catch {
        /* rien à faire : le stockage est déjà indisponible */
      }
    },
  };
}
