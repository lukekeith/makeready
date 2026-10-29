/**
 * IANA-timezone date helpers shared by analytics and enrollments (ui2-enrollment-create D16).
 * Calendar dates travel as 'yyyy-MM-dd' strings; instants as Date.
 */

export function isValidTimezone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz })
    return true
  } catch {
    return false
  }
}

/** The calendar date (yyyy-MM-dd) `instant` falls on in `tz`. */
export function localDate(instant: Date, tz: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(instant)
}

/** Today's calendar date (yyyy-MM-dd) in `tz`. */
export function todayInTimezone(tz: string, now: Date = new Date()): string {
  return localDate(now, tz)
}

/** Milliseconds `tz` is ahead of UTC at `instant`. */
function tzOffsetMs(instant: Date, tz: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    hour12: false,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(instant)
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? '0')
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour') % 24, get('minute'), get('second'))
  return asUtc - (instant.getTime() - instant.getUTCMilliseconds())
}

/** The UTC instant of 00:00 on `date` (yyyy-MM-dd) in `tz` — DST-safe (two-pass offset). */
export function zonedMidnight(date: string, tz: string): Date {
  const [y, m, d] = date.split('-').map(Number)
  const wall = Date.UTC(y, m - 1, d)
  const first = wall - tzOffsetMs(new Date(wall), tz)
  return new Date(wall - tzOffsetMs(new Date(first), tz))
}

/** "Monday, November 3" — `instant`'s day in `tz` (D4's not-yet message). */
export function formatLongDay(instant: Date, tz: string): string {
  return new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'long', month: 'long', day: 'numeric' }).format(instant)
}
