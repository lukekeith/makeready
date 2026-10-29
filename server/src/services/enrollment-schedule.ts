/**
 * Enrollment schedule date math.
 *
 * Extracted from the inline date-walk in POST /enrollments so the same logic
 * is reused by enrollment CREATE and the edit/reschedule + study-swap paths
 * (monday#12270302158). Keeping one implementation guarantees a rescheduled
 * enrollment lands its lessons on exactly the dates a fresh enrollment would.
 */

import { localDate, todayInTimezone, zonedMidnight } from '../utils/timezone.js'

export type EnabledDayName = 'Sun' | 'Mon' | 'Tue' | 'Wed' | 'Thu' | 'Fri' | 'Sat'

const DAY_NAME_TO_NUMBER: Record<EnabledDayName, number> = {
  Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
}

/** Map the enabled day-of-week names to JS `Date.getDay()` numbers (Sun=0…Sat=6). */
export function enabledDayNumbers(days: EnabledDayName[]): number[] {
  return days.map((d) => DAY_NAME_TO_NUMBER[d])
}

/**
 * Walk forward from `startDate`, collecting one date per lesson on the enabled
 * weekdays, until `count` dates are gathered. The first date is `startDate`
 * itself when it falls on an enabled day.
 *
 * Throws if `days` is empty (an empty enabled-day set would loop forever) — the
 * route zod schema already enforces `.min(1)`, this is the defensive backstop.
 */
export function generateScheduleDates(
  startDate: Date,
  days: EnabledDayName[],
  count: number
): Date[] {
  if (days.length === 0) {
    throw new Error('generateScheduleDates: enabledDays must not be empty')
  }
  const enabled = new Set(enabledDayNumbers(days))
  const dates: Date[] = []
  const cursor = new Date(startDate)
  while (dates.length < count) {
    if (enabled.has(cursor.getDay())) {
      dates.push(new Date(cursor))
    }
    cursor.setDate(cursor.getDate() + 1)
  }
  return dates
}

const YMD = /^\d{4}-\d{2}-\d{2}$/
const MISMATCH = "Schedule doesn't match the program"

/**
 * ui2-enrollment-create D3/D16: the app's exact lesson dates. One per lesson, strictly ascending,
 * the first not before today in `tz`; weekdays are NOT checked (an override may fall on any day).
 * Each is stored as 00:00 in `tz` — never `new Date('yyyy-MM-dd')`, which is UTC midnight.
 */
export function validateScheduleDates(
  dates: string[],
  lessonCount: number,
  tz: string,
  now: Date,
): { ok: true; dates: Date[] } | { ok: false; error: string } {
  if (dates.length !== lessonCount) {
    return { ok: false, error: `${MISMATCH}: expected ${lessonCount} dates, got ${dates.length}` }
  }
  for (const d of dates) {
    // round-trips only when the date exists on the calendar (rejects 2035-02-30)
    if (!YMD.test(d) || localDate(zonedMidnight(d, 'UTC'), 'UTC') !== d) {
      return { ok: false, error: `${MISMATCH}: ${d} is not a date` }
    }
  }
  for (let i = 1; i < dates.length; i++) {
    if (dates[i] <= dates[i - 1]) return { ok: false, error: `${MISMATCH}: dates must be strictly ascending` }
  }
  if (dates.length > 0 && dates[0] < todayInTimezone(tz, now)) {
    return { ok: false, error: `${MISMATCH}: the first date is before today` }
  }
  return { ok: true, dates: dates.map((d) => zonedMidnight(d, tz)) }
}
