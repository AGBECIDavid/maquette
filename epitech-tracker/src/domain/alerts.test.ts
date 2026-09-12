import { describe, expect, it } from 'vitest';
import { buildAlerts } from './alerts';
import { buildView } from './selectors';
import { makeCurriculum, makeModule, makeProject, makeRoadblock } from './testFixtures';
import { DEFAULT_SETTINGS } from '../data/schema';

const TODAY = '2026-09-12';
const settings = { ...DEFAULT_SETTINGS };

function alertsFor(data: Parameters<typeof buildView>[0]) {
  return buildAlerts(buildView(data, TODAY), settings);
}

describe('alertes', () => {
  it('signale un projet en retard', () => {
    const alerts = alertsFor(
      makeCurriculum({ projects: [makeProject({ deadline: '2026-09-05' })] }),
    );
    expect(alerts.some((a) => a.id === 'late:p1' && a.level === 'danger')).toBe(true);
  });

  it('signale une deadline proche sans doublon avec le retard', () => {
    const alerts = alertsFor(
      makeCurriculum({ projects: [makeProject({ deadline: '2026-09-14' })] }),
    );
    expect(alerts.map((a) => a.id)).toContain('soon:p1');
    expect(alerts.map((a) => a.id)).not.toContain('late:p1');
  });

  it('signale un module qui se termine avec des crédits à obtenir', () => {
    const data = makeCurriculum({
      modules: [makeModule({ endDate: '2026-09-16' })],
      projects: [makeProject({ status: 'todo' })],
    });
    expect(alertsFor(data).map((a) => a.id)).toContain('module-ending:m1');
  });

  it('ne signale pas un module terminé et validé', () => {
    const data = makeCurriculum({
      modules: [makeModule({ endDate: '2026-09-16' })],
      projects: [makeProject({ status: 'validated' })],
    });
    expect(alertsFor(data).map((a) => a.id)).not.toContain('module-ending:m1');
  });

  it('signale un Roadblock dont les crédits restants ne suffisent plus', () => {
    const data = makeCurriculum({
      roadblocks: [makeRoadblock({ requiredCredits: 20 })],
      modules: [makeModule({ credits: 6 })],
      projects: [makeProject({ status: 'validated' })],
    });
    const alert = alertsFor(data).find((a) => a.id === 'rb-unreachable:rb1');
    expect(alert?.level).toBe('danger');
  });

  it('signale un Roadblock bientôt validé', () => {
    const data = makeCurriculum({
      roadblocks: [makeRoadblock({ requiredCredits: 10 })],
      modules: [makeModule({ credits: 10 })],
      projects: [
        makeProject({ id: 'a', status: 'validated' }),
        makeProject({ id: 'b', status: 'validated', order: 2 }),
        makeProject({ id: 'c', status: 'validated', order: 3 }),
        makeProject({ id: 'd', status: 'validated', order: 4 }),
        makeProject({ id: 'e', status: 'todo', order: 5 }),
      ],
    });
    expect(alertsFor(data).map((a) => a.id)).toContain('rb-almost:rb1');
  });

  it('signale un Roadblock validé', () => {
    const data = makeCurriculum({
      roadblocks: [makeRoadblock({ requiredCredits: 6 })],
      modules: [makeModule({ credits: 6 })],
      projects: [makeProject({ status: 'validated' })],
    });
    const alert = alertsFor(data).find((a) => a.id === 'rb-ok:rb1');
    expect(alert?.level).toBe('success');
  });

  it('classe les alertes les plus graves en premier', () => {
    const data = makeCurriculum({
      roadblocks: [makeRoadblock({ requiredCredits: 6 })],
      modules: [makeModule({ credits: 6 })],
      projects: [
        makeProject({ id: 'a', status: 'validated' }),
        makeProject({ id: 'b', deadline: '2026-09-01', order: 2 }),
      ],
    });
    const levels = alertsFor(data).map((a) => a.level);
    expect(levels[0]).toBe('danger');
  });
});
