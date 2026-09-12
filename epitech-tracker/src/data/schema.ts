/**
 * Schéma persisté et migrations.
 *
 * Le numéro de version est écrit dans chaque export : quand le modèle
 * évoluera, `migrate()` saura remonter un ancien fichier plutôt que de le
 * rejeter. Un fichier illisible n'écrase jamais les données en place — il
 * remonte une erreur.
 */

import type { AcademicYear, Curriculum, Settings, TekLevel } from '../domain/types';

/**
 * 1 → 2 : les années portent un niveau TEK, et les réglages désignent
 * explicitement l'année courante.
 */
export const SCHEMA_VERSION = 2;

export const DEFAULT_SETTINGS: Settings = {
  currentYearId: null,
  deadlineSoonDays: 7,
  roadblockAlmostDoneRatio: 0.8,
  source: 'user',
};

/** Un cursus neuf : vide, avec une année ouverte au niveau annoncé. */
export function newCurriculum(level: TekLevel | null, id: string): Curriculum {
  const fresh = emptyCurriculum();
  const start = new Date().getFullYear();
  fresh.years = [
    { id, label: `${start}-${start + 1}`, level, order: 1, startDate: null, endDate: null },
  ];
  fresh.settings.currentYearId = id;
  return fresh;
}

export function emptyCurriculum(): Curriculum {
  return {
    schemaVersion: SCHEMA_VERSION,
    years: [],
    roadblocks: [],
    modules: [],
    projects: [],
    settings: { ...DEFAULT_SETTINGS },
  };
}

export class SchemaError extends Error {}

/** L'année de rang le plus élevé : la plus récente du cursus. */
function lastYear(years: readonly AcademicYear[]): AcademicYear | undefined {
  return [...years].sort((a, b) => a.order - b.order).pop();
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function requireArray(source: Record<string, unknown>, key: string): unknown[] {
  const value = source[key];
  if (!Array.isArray(value)) {
    throw new SchemaError(`Champ « ${key} » absent ou invalide`);
  }
  return value;
}

/**
 * Relit un document quelconque et le remonte au schéma courant.
 * Lève `SchemaError` si le document n'est pas exploitable.
 */
export function parseCurriculum(raw: unknown): Curriculum {
  if (!isObject(raw)) throw new SchemaError('Le document n’est pas un objet JSON');

  const version = raw['schemaVersion'];
  if (typeof version !== 'number') {
    throw new SchemaError('Version de schéma absente');
  }
  if (version > SCHEMA_VERSION) {
    throw new SchemaError(
      `Document en version ${version}, cette application lit jusqu’à ${SCHEMA_VERSION}`,
    );
  }

  const settings = isObject(raw['settings']) ? raw['settings'] : {};

  // Migration 1 → 2 : une année d'avant la v2 n'a pas de niveau, et aucune
  // année n'était désignée comme courante. On ne devine pas le niveau — il
  // reste inconnu tant que l'utilisateur ne l'a pas dit — mais on désigne la
  // dernière année comme courante, faute de quoi l'application n'aurait
  // aucune année à afficher.
  const years = (requireArray(raw, 'years') as AcademicYear[]).map((year) => ({
    ...year,
    level: year.level ?? null,
  }));

  const declaredCurrent = settings['currentYearId'];
  const currentYearId =
    typeof declaredCurrent === 'string' && years.some((y) => y.id === declaredCurrent)
      ? declaredCurrent
      : (lastYear(years)?.id ?? null);

  return {
    schemaVersion: SCHEMA_VERSION,
    years,
    roadblocks: requireArray(raw, 'roadblocks') as Curriculum['roadblocks'],
    modules: requireArray(raw, 'modules') as Curriculum['modules'],
    projects: requireArray(raw, 'projects') as Curriculum['projects'],
    settings: {
      currentYearId,
      deadlineSoonDays:
        typeof settings['deadlineSoonDays'] === 'number'
          ? settings['deadlineSoonDays']
          : DEFAULT_SETTINGS.deadlineSoonDays,
      roadblockAlmostDoneRatio:
        typeof settings['roadblockAlmostDoneRatio'] === 'number'
          ? settings['roadblockAlmostDoneRatio']
          : DEFAULT_SETTINGS.roadblockAlmostDoneRatio,
      source: settings['source'] === 'mock' ? 'mock' : 'user',
    },
  };
}

/** Vérifie que l'arbre est cohérent : aucun orphelin. */
export function findOrphans(data: Curriculum): string[] {
  const problems: string[] = [];
  const years = new Set(data.years.map((y) => y.id));
  const roadblocks = new Set(data.roadblocks.map((r) => r.id));
  const modules = new Set(data.modules.map((m) => m.id));

  for (const r of data.roadblocks) {
    if (!years.has(r.yearId)) problems.push(`Roadblock « ${r.name} » : année inconnue`);
  }
  for (const m of data.modules) {
    if (!roadblocks.has(m.roadblockId)) problems.push(`Module « ${m.name} » : Roadblock inconnu`);
  }
  for (const p of data.projects) {
    if (!modules.has(p.moduleId)) problems.push(`Projet « ${p.name} » : module inconnu`);
  }
  return problems;
}
