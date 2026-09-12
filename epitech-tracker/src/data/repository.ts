/**
 * Contrat de persistance.
 *
 * L'application ne connaît que cette interface. Passer de `localStorage` à
 * un fichier, à SQLite ou à une API ne demandera qu'une nouvelle
 * implémentation ici — aucun composant, aucun calcul ne changera.
 */

import type { Curriculum } from '../domain/types';

export interface Repository {
  load(): Curriculum | null;
  save(data: Curriculum): void;
  clear(): void;
}
