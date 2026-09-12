/**
 * Modèle de données du cursus.
 *
 * Un arbre strict : Année → Roadblock → Module → Projet.
 * Chaque niveau ne connaît que son parent, par identifiant.
 *
 * Toutes les dates sont des dates civiles ISO ("2026-09-12"), sans heure ni
 * fuseau : une deadline de projet n'a pas d'heure, et comparer des dates
 * locales à des instants UTC est la première source de bugs de calendrier.
 *
 * `null` veut dire « inconnu », jamais « zéro ». L'interface affiche « — »
 * pour un `null` et ne fabrique aucune valeur de remplacement.
 */

export type Id = string;

/** Date civile ISO, sans heure : "2026-09-12". */
export type IsoDate = string;

/** Statuts d'un projet — confirmés : seul `validated` rapporte des crédits. */
export type ProjectStatus =
  | 'todo' // à faire
  | 'in_progress' // en cours
  | 'done' // terminé : rendu, en attente de correction
  | 'validated'; // validé par l'école

/** Statuts dérivés d'un module ou d'un Roadblock. */
export type ProgressStatus =
  | 'upcoming' // à venir
  | 'in_progress' // en cours
  | 'validated' // validé
  | 'failed'; // non validé

export type Priority = 'critical' | 'high' | 'normal' | 'low';

export interface AcademicYear {
  id: Id;
  label: string; // "2026-2027"
  order: number;
  startDate: IsoDate | null;
  endDate: IsoDate | null;
}

export interface Roadblock {
  id: Id;
  yearId: Id;
  name: string;
  description: string;
  order: number;
  /** Seuil de crédits à atteindre pour valider le Roadblock. */
  requiredCredits: number;
  startDate: IsoDate | null;
  endDate: IsoDate | null;
  /** Force le statut à la main ; sinon il est dérivé des crédits obtenus. */
  statusOverride: ProgressStatus | null;
}

export interface Module {
  id: Id;
  roadblockId: Id;
  name: string;
  description: string;
  order: number;
  /** Crédits que le module rapporte une fois tous ses projets validés. */
  credits: number;
  startDate: IsoDate | null;
  endDate: IsoDate | null;
  statusOverride: ProgressStatus | null;
  grade: string | null;
  notes: string;
}

export interface Project {
  id: Id;
  moduleId: Id;
  name: string;
  description: string;
  order: number;
  /**
   * Poids en crédits du projet. `null` = partage à parts égales des crédits
   * du module entre ses projets. Un projet qui pèse plus que les autres se
   * déclare ici, sans toucher au total du module.
   */
  creditsOverride: number | null;
  startDate: IsoDate | null;
  deadline: IsoDate | null;
  completedAt: IsoDate | null;
  status: ProjectStatus;
  priority: Priority;
  grade: string | null;
  repoUrl: string | null;
  notes: string;
}

export interface Settings {
  /** En deçà de ce nombre de jours, une deadline est « proche ». */
  deadlineSoonDays: number;
  /** À partir de cette part des crédits requis, un Roadblock est « bientôt validé ». */
  roadblockAlmostDoneRatio: number;
  /** `mock` tant que les vraies données n'ont pas remplacé le jeu d'exemple. */
  source: 'mock' | 'user';
}

export interface Curriculum {
  schemaVersion: number;
  years: AcademicYear[];
  roadblocks: Roadblock[];
  modules: Module[];
  projects: Project[];
  settings: Settings;
}
