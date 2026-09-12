import { describe, expect, it } from 'vitest';
import { addDays, daysBetween, formatDate, isValidIsoDate, isWithin } from './dates';

describe('dates', () => {
  it('compte les jours entre deux dates', () => {
    expect(daysBetween('2026-09-12', '2026-09-20')).toBe(8);
    expect(daysBetween('2026-09-12', '2026-09-05')).toBe(-7);
    expect(daysBetween('2026-09-12', '2026-09-12')).toBe(0);
  });

  it('traverse un changement d’heure sans perdre de jour', () => {
    // Passage à l'heure d'hiver en Europe fin octobre.
    expect(daysBetween('2026-10-24', '2026-10-26')).toBe(2);
    expect(daysBetween('2026-12-31', '2027-01-01')).toBe(1);
  });

  it('gère les années bissextiles', () => {
    expect(daysBetween('2028-02-28', '2028-03-01')).toBe(2);
    expect(addDays('2028-02-28', 1)).toBe('2028-02-29');
  });

  it('rejette une date impossible', () => {
    expect(isValidIsoDate('2026-02-30')).toBe(false);
    expect(isValidIsoDate('12/09/2026')).toBe(false);
    expect(isValidIsoDate('2026-09-12')).toBe(true);
  });

  it('accepte une période à borne ouverte', () => {
    expect(isWithin('2026-09-12', '2026-09-01', null)).toBe(true);
    expect(isWithin('2026-09-12', null, '2026-09-01')).toBe(false);
  });

  it('affiche « — » pour une date inconnue', () => {
    expect(formatDate(null)).toBe('—');
    expect(formatDate('2026-09-12')).toBe('12/09/2026');
  });
});
