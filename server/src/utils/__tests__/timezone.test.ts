import { describe, expect, it } from 'vitest'
import { formatLongDay, isValidTimezone, localDate, todayInTimezone, zonedMidnight } from '../timezone'

describe('timezone util (ui2-enrollment-create D16)', () => {
  it('validates IANA zones', () => {
    expect(isValidTimezone('America/Chicago')).toBe(true)
    expect(isValidTimezone('UTC')).toBe(true)
    expect(isValidTimezone('Mars/Olympus')).toBe(false)
  })

  it('reads the local calendar date of an instant', () => {
    // 2035-01-02T03:00Z is still Jan 1 in Chicago (UTC−6)
    expect(localDate(new Date('2035-01-02T03:00:00Z'), 'America/Chicago')).toBe('2035-01-01')
    expect(localDate(new Date('2035-01-02T03:00:00Z'), 'UTC')).toBe('2035-01-02')
  })

  it('today follows the given now', () => {
    expect(todayInTimezone('America/Chicago', new Date('2035-01-02T03:00:00Z'))).toBe('2035-01-01')
  })

  it('today defaults to the real clock', () => {
    expect(todayInTimezone('UTC')).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  it('zonedMidnight is 00:00 local, not UTC midnight', () => {
    expect(zonedMidnight('2035-01-08', 'America/Chicago').toISOString()).toBe('2035-01-08T06:00:00.000Z')
    expect(zonedMidnight('2035-07-08', 'America/Chicago').toISOString()).toBe('2035-07-08T05:00:00.000Z') // CDT
    expect(zonedMidnight('2035-01-08', 'UTC').toISOString()).toBe('2035-01-08T00:00:00.000Z')
    expect(localDate(zonedMidnight('2035-01-08', 'America/Chicago'), 'America/Chicago')).toBe('2035-01-08')
  })

  it('formats the long day in the zone', () => {
    expect(formatLongDay(zonedMidnight('2035-01-08', 'America/Chicago'), 'America/Chicago')).toBe('Monday, January 8')
  })
})
