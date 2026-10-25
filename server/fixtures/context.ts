/**
 * FixtureContext and the helpers every fixture layer uses (SPEC ui2-fixtures
 * D2, D9, D11, D15). Every timestamp is computed from `now`; fixture days are
 * America/Chicago calendar days, so completions placed 07:00–21:00 Chicago
 * fall on the same calendar day on any US-timezone device.
 */
import type {
  Enrollment,
  Group,
  GroupMember,
  Lesson,
  LessonActivity,
  LessonSchedule,
  Member,
  Organization,
  PrismaClient,
  StudyProgram,
  User,
} from '../src/generated/prisma/index.js'
import { FIXTURE_IDS } from './ids.js'

export const FIXTURE_TZ = 'America/Chicago'
export const FIXTURE_SEED = 0xf1f1f1f1

export class FixtureError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'FixtureError'
  }
}

// ── Seeded PRNG (mulberry32) — identical sequences across resets ─────────────

export interface Prng {
  next(): number
  int(min: number, maxInclusive: number): number
  shuffle<T>(items: readonly T[]): T[]
}

export function createPrng(seed: number = FIXTURE_SEED): Prng {
  let state = seed >>> 0
  const next = (): number => {
    state = (state + 0x6d2b79f5) >>> 0
    let t = state
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
  return {
    next,
    int: (min, maxInclusive) => min + Math.floor(next() * (maxInclusive - min + 1)),
    shuffle<T>(items: readonly T[]): T[] {
      const out = items.slice()
      for (let i = out.length - 1; i > 0; i--) {
        const j = Math.floor(next() * (i + 1))
        const tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
      return out
    },
  }
}

// ── Dates (America/Chicago calendar days) ───────────────────────────────────

/** The calendar date (YYYY-MM-DD) of an instant in `tz`. */
export function localDate(instant: Date, tz: string = FIXTURE_TZ): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(instant)
}

/** Date-only arithmetic on YYYY-MM-DD (UTC-noon anchor avoids DST edges). */
export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

/** Day of week of a calendar date: 0 = Sunday … 6 = Saturday. */
export function weekdayOf(date: string): number {
  return new Date(`${date}T12:00:00Z`).getUTCDay()
}

/** Milliseconds `tz` is ahead of UTC at `instant` (negative west of Greenwich). */
function tzOffsetMs(instant: Date, tz: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(instant)
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? '0')
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour') % 24, get('minute'), get('second'))
  return asUtc - (instant.getTime() - instant.getUTCMilliseconds())
}

/** The UTC instant of wall-clock `hour` (fractional allowed) on `date` in `tz`. */
export function zonedTime(date: string, hour: number, tz: string = FIXTURE_TZ): Date {
  const [y, m, d] = date.split('-').map(Number)
  const wall = Date.UTC(y, m - 1, d) + Math.round(hour * 3_600_000)
  const first = wall - tzOffsetMs(new Date(wall), tz)
  return new Date(wall - tzOffsetMs(new Date(first), tz))
}

/** Wall-clock `hour` on the `tz` calendar date that contains `date`. */
export function atLocalHour(date: Date, hour: number, tz: string = FIXTURE_TZ): Date {
  return zonedTime(localDate(date, tz), hour, tz)
}

/** Local noon `n` calendar days before `now`'s local date (negative n = the future). */
export function daysAgo(now: Date, n: number, tz: string = FIXTURE_TZ): Date {
  return zonedTime(addDays(localDate(now, tz), -n), 12, tz)
}

// ── Layers ───────────────────────────────────────────────────────────────────

export interface FixtureCreated {
  user: User | null
  org: Organization | null
  groups: Group[]
  members: Member[]
  groupMembers: GroupMember[]
  programs: StudyProgram[]
  lessons: Lesson[]
  activities: LessonActivity[]
  enrollments: Enrollment[]
  schedules: LessonSchedule[]
}

export interface FixtureContext {
  readonly now: Date
  /** `now`'s America/Chicago calendar date. */
  readonly today: string
  readonly prisma: PrismaClient
  readonly ids: typeof FIXTURE_IDS
  readonly rand: Prng
  /** What the base layer created — screen layers read it, never re-create it (D2). */
  readonly created: FixtureCreated
  daysAgo(n: number): Date
  atLocalHour(date: Date, hour: number): Date
  /** The Chicago calendar date `dayOffset` days from today (−1 = yesterday). */
  dateOf(dayOffset: number): string
  /** Wall-clock `hour` (Chicago) on the day `dayOffset` days from today. */
  at(dayOffset: number, hour: number): Date
}

export type ScenarioFn = (ctx: FixtureContext) => Promise<void>
export type LayerScenario = 'full' | 'sparse' | 'extreme'
export const LAYER_SCENARIOS: readonly LayerScenario[] = ['full', 'sparse', 'extreme']
export type ScreenLayer = Partial<Record<LayerScenario, ScenarioFn>>

export function createContext(prisma: PrismaClient, now: Date, seed: number = FIXTURE_SEED): FixtureContext {
  const today = localDate(now)
  return {
    now,
    today,
    prisma,
    ids: FIXTURE_IDS,
    rand: createPrng(seed),
    created: {
      user: null,
      org: null,
      groups: [],
      members: [],
      groupMembers: [],
      programs: [],
      lessons: [],
      activities: [],
      enrollments: [],
      schedules: [],
    },
    daysAgo: (n) => daysAgo(now, n),
    atLocalHour: (date, hour) => atLocalHour(date, hour),
    dateOf: (dayOffset) => addDays(today, dayOffset),
    at: (dayOffset, hour) => zonedTime(addDays(today, dayOffset), hour),
  }
}
