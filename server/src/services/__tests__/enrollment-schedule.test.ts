/**
 * Unit tests for the shared enrollment schedule date-walk
 * (server/src/services/enrollment-schedule.ts, monday#12270302158).
 */

import { describe, it, expect } from 'vitest'
import { generateScheduleDates, enabledDayNumbers } from '../enrollment-schedule'

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
