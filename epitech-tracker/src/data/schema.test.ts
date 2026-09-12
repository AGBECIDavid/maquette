import { describe, expect, it } from 'vitest';
import { findOrphans, parseCurriculum, SchemaError, SCHEMA_VERSION } from './schema';
import { mockCurriculum } from './mock';
import { makeCurriculum, makeProject } from '../domain/testFixtures';

describe('lecture d’un document', () => {
  it('relit ce qu’il a écrit', () => {
    const data = mockCurriculum('2026-09-12');
    const round = parseCurriculum(JSON.parse(JSON.stringify(data)));
    expect(round.projects).toHaveLength(data.projects.length);
    expect(round.schemaVersion).toBe(SCHEMA_VERSION);
  });

  it('refuse un document sans version', () => {
    expect(() => parseCurriculum({ years: [] })).toThrow(SchemaError);
  });

  it('refuse un document venu d’une version plus récente', () => {
    expect(() =>
      parseCurriculum({ schemaVersion: SCHEMA_VERSION + 1, years: [], roadblocks: [], modules: [], projects: [] }),
    ).toThrow(SchemaError);
  });

  it('refuse un document amputé plutôt que de deviner', () => {
    expect(() => parseCurriculum({ schemaVersion: 1, years: [] })).toThrow(SchemaError);
  });

  it('complète les réglages absents par leurs valeurs par défaut', () => {
    const parsed = parseCurriculum({
      schemaVersion: 1,
      years: [],
      roadblocks: [],
      modules: [],
      projects: [],
    });
    expect(parsed.settings.deadlineSoonDays).toBe(7);
    expect(parsed.settings.source).toBe('user');
  });
});

describe('cohérence de l’arbre', () => {
  it('ne trouve aucun orphelin dans le jeu d’exemple', () => {
    expect(findOrphans(mockCurriculum('2026-09-12'))).toEqual([]);
  });

  it('signale un projet rattaché à un module inconnu', () => {
    const data = makeCurriculum({ projects: [makeProject({ moduleId: 'inconnu' })] });
    expect(findOrphans(data)).toHaveLength(1);
  });
});
