/**
 * ui2-members-edit D4, D7, D9, D18, D19: normalization and validation of the member fields
 * PATCH /api/members/:memberId writes. Pure functions — no Prisma, no Express.
 */

/** E.164 — the only shape a Member.phoneNumber may hold; SMS sign-in accepts nothing else. */
export const E164 = /^\+[1-9]\d{1,14}$/

/**
 * D4 + D18: strip spaces, `-`, `.`, `(`, `)`; exactly 10 digits → `+1` + digits; exactly 11 digits
 * starting `1` → `+` + digits; a leading `+` is kept. The result must match E164, else null.
 */
export function normalizePhone(raw: string): string | null {
  const stripped = raw.replace(/[\s\-.()]/g, '')
  let candidate = stripped
  if (/^\d{10}$/.test(stripped)) candidate = `+1${stripped}`
  else if (/^1\d{10}$/.test(stripped)) candidate = `+${stripped}`
  return E164.test(candidate) ? candidate : null
}

/** D7: digits and phone punctuation, an optional `ext`/`ext.`/`x` extension, ≥ 7 digits before it. */
const CONTACT_PHONE = /^[\d\s().+-]+(?:\s*(?:ext\.?|x)\s*\d+)?$/i
const CONTACT_EXTENSION = /\s*(?:ext\.?|x)\s*\d+$/i

export function isValidContactPhone(raw: string): boolean {
  const value = raw.trim()
  if (!CONTACT_PHONE.test(value)) return false
  const main = value.replace(CONTACT_EXTENSION, '')
  return (main.match(/\d/g) ?? []).length >= 7
}

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/
const ISO_DATE_TIME = /^(\d{4}-\d{2}-\d{2})T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$/

/**
 * D19: `YYYY-MM-DD` or an ISO date-time; returns its UTC calendar date at 00:00Z (time and offset
 * dropped after converting to UTC). An ISO string without an offset is read as UTC, never as the
 * server's local time. Anything else — including impossible dates like 2026-02-30 — is null.
 */
export function parseBirthday(raw: string): Date | null {
  const value = raw.trim()
  let utcDay: string
  if (DATE_ONLY.test(value)) {
    utcDay = value
  } else {
    const match = ISO_DATE_TIME.exec(value)
    if (!match) return null
    const instant = new Date(match[2] ? value : `${value}Z`)
    if (Number.isNaN(instant.getTime())) return null
    // The written date must exist (rejects 2026-02-30T…, which Date would roll forward).
    const written = new Date(`${match[1]}T00:00:00Z`)
    if (Number.isNaN(written.getTime()) || written.toISOString().slice(0, 10) !== match[1]) return null
    utcDay = instant.toISOString().slice(0, 10)
  }
  const date = new Date(`${utcDay}T00:00:00Z`)
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== utcDay) return null
  return date
}

const MIN_BIRTHDAY_MS = Date.UTC(1900, 0, 1)
const DAY_MS = 86_400_000

/** D9: 1900-01-01 ≤ d ≤ (UTC today + 1 day), so UTC tomorrow is accepted for UTC+14 devices. */
export function birthdayInRange(d: Date, now: Date): boolean {
  const todayUtcMs = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
  const t = d.getTime()
  return t >= MIN_BIRTHDAY_MS && t <= todayUtcMs + DAY_MS
}
