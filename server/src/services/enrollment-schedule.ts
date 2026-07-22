/**
 * Enrollment schedule date math.
 *
 * Extracted from the inline date-walk in POST /enrollments so the same logic
 * is reused by enrollment CREATE and the edit/reschedule + study-swap paths
 * (monday#12270302158). Keeping one implementation guarantees a rescheduled
 * enrollment lands its lessons on exactly the dates a fresh enrollment would.
 */

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
