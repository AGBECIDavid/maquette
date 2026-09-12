import { describe, expect, it } from 'vitest';
import { buildDiagnostics, type DiagnosticInput } from './diagnostics';
import { makeCurriculum, makeModule, makeProject } from '../domain/testFixtures';

const input = (over: Partial<DiagnosticInput> = {}): DiagnosticInput => ({
  curriculum: makeCurriculum({
    modules: [makeModule({ credits: 6 })],
    projects: [
      makeProject({ id: 'a', status: 'validated' }),
      makeProject({ id: 'b', deadline: '2026-09-01', order: 2 }),
    ],
  }),
  profileName: 'David',
  version: '0.4.0',
  stage: 'bêta',
  today: '2026-09-12',
  generatedAt: '2026-09-12T10:00:00.000Z',
  environment: { userAgent: 'test', language: 'fr', screen: '1280x800' },
  ...over,
});

describe('rapport de diagnostic', () => {
  it('porte la version et le moment de génération', () => {
    const report = buildDiagnostics(input());
    expect(report).toMatchObject({
      kind: 'epitech-tracker-diagnostic',
      version: '0.4.0',
      generatedAt: '2026-09-12T10:00:00.000Z',
    });
  });

  it('compte ce qu’il faut pour situer le cas sans ouvrir les données', () => {
    const report = buildDiagnostics(input());
    expect(report.counts).toMatchObject({ modules: 1, projects: 2, lateProjects: 1 });
    expect(report.credits).toEqual({ obtained: 3, total: 12 });
  });

  it('signale les incohérences de structure', () => {
    const broken = makeCurriculum({ projects: [makeProject({ moduleId: 'inconnu' })] });
    expect(buildDiagnostics(input({ curriculum: broken })).integrity).toHaveLength(1);
  });

  it('joint le cursus complet, pour que le cas soit reproductible', () => {
    const report = buildDiagnostics(input());
    expect(report.curriculum.projects).toHaveLength(2);
  });

  it('se relit en JSON sans perte', () => {
    const report = buildDiagnostics(input());
    expect(JSON.parse(JSON.stringify(report))).toEqual(report);
  });
});
