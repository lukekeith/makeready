/**
 * Unit tests for the shared enrollment schedule date-walk
 * (server/src/services/enrollment-schedule.ts, monday#12270302158).
 */

import { describe, it, expect } from 'vitest'
import { generateScheduleDates, enabledDayNumbers, validateScheduleDates } from '../enrollment-schedule'

describe('generateScheduleDates', () => {
  it('maps day names to JS weekday numbers (Sun=0…Sat=6)', () => {
    expect(enabledDayNumbers(['Sun', 'Mon', 'Sat'])).toEqual([0, 1, 6])
  })

  it('walks consecutive enabled days from the start date', () => {
    // 2035-01-01 is a Monday; all weekdays enabled ⇒ 3 consecutive days.
    const dates = generateScheduleDates(new Date('2035-01-01T12:00:00.000Z'), ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], 3)
    expect(dates.map((d) => d.toISOString().slice(0, 10))).toEqual(['2035-01-01', '2035-01-02', '2035-01-03'])
  })

  it('skips disabled weekdays (Mondays only)', () => {
    const dates = generateScheduleDates(new Date('2035-01-01T12:00:00.000Z'), ['Mon'], 3)
    expect(dates.map((d) => d.toISOString().slice(0, 10))).toEqual(['2035-01-01', '2035-01-08', '2035-01-15'])
  })

  it('returns an empty array when zero dates are requested', () => {
    expect(generateScheduleDates(new Date('2035-01-01T12:00:00.000Z'), ['Mon'], 0)).toEqual([])
  })

  it('throws on an empty enabled-day set (would loop forever)', () => {
    expect(() => generateScheduleDates(new Date('2035-01-01T12:00:00.000Z'), [], 3)).toThrow(/must not be empty/)
  })
})

describe('validateScheduleDates (D3, D16)', () => {
  const now = new Date('2035-01-08T15:00:00Z') // Jan 8, 09:00 in Chicago
  const tz = 'America/Chicago'

  it('accepts one ascending date per lesson from today and stores 00:00 local', () => {
    const r = validateScheduleDates(['2035-01-08', '2035-01-10', '2035-01-15'], 3, tz, now)
    expect(r.ok).toBe(true)
    if (r.ok) expect(r.dates.map((d) => d.toISOString())).toEqual([
      '2035-01-08T06:00:00.000Z', '2035-01-10T06:00:00.000Z', '2035-01-15T06:00:00.000Z',
    ])
  })

  it('ignores weekdays — an override may fall on any day', () => {
    expect(validateScheduleDates(['2035-01-13', '2035-01-14'], 2, tz, now).ok).toBe(true) // Sat, Sun
  })

  it('names the expected count on a mismatch (A2)', () => {
    expect(validateScheduleDates(['2035-01-08'], 3, tz, now)).toEqual({
      ok: false, error: "Schedule doesn't match the program: expected 3 dates, got 1",
    })
  })

  it('refuses unsorted or repeated dates', () => {
    expect(validateScheduleDates(['2035-01-10', '2035-01-09'], 2, tz, now).ok).toBe(false)
    expect(validateScheduleDates(['2035-01-10', '2035-01-10'], 2, tz, now).ok).toBe(false)
  })

  it('refuses a first date before today in the request zone', () => {
    expect(validateScheduleDates(['2035-01-07', '2035-01-09'], 2, tz, now)).toEqual({
      ok: false, error: "Schedule doesn't match the program: the first date is before today",
    })
  })

  it('refuses a malformed or impossible date', () => {
    expect(validateScheduleDates(['2035-02-30', '2035-03-01'], 2, tz, now).ok).toBe(false)
    expect(validateScheduleDates(['soon', '2035-03-01'], 2, tz, now).ok).toBe(false)
  })

  it('accepts an empty schedule for a zero-lesson program', () => {
    expect(validateScheduleDates([], 0, tz, now)).toEqual({ ok: true, dates: [] })
  })
})
