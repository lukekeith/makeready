# ui2-fixtures — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** A resettable local fixture world (one fixture org owned by `fixtures@makeready.local`, built from a base layer plus one layer per UI 2.0 screen, Home first) and a dev-only "Local identity" picker on the iPhone Profile stopgap that signs in as it.

**Architecture:** `server/fixtures/` is a standalone tsx CLI (`npm run fixtures:reset|seed [-- scenario]`) that guards the environment, wipes the fixture graph by fixed IDs, runs `base.ts` then every `screens/*.ts` layer's scenario function against one shared `FixtureContext`, then refreshes the analytics materialized view with a lock-held retry. Home's numbers are produced by construction (a target curve apportioned exactly per comparison window, then assigned to member × schedule pairs) from a fixed-seed PRNG. The iPhone side adds a `DevLoginIdentity` (You / Fixtures) read by both dev-login callers, a typed `fixturesNotSeeded` error, and `EnvironmentActions.switchIdentity` (sign out → sign in as the new identity, revert to You on failure, message handed to Login).

**Tech Stack:** server — TypeScript (ESM), tsx, Prisma 6 generated client, `pg` (via `analytics.service`), vitest 2; iphone — Swift 5 / SwiftUI (iOS 17), `@Observable` + Actions, XCTest in `MakeReadyCaptureTests`; repo — root `docker-compose.yml`, `.claude/builder.md`.

**Spec:** docs/features/ui2-fixtures/SPEC.md

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-fixtures): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–2 | The fixture runner core exists: fixed IDs, `FixtureContext` + date/PRNG helpers, the D8 guard, D7 wipe, row counts, D10 refresh retry, the CLI with D6 scenario parsing, its own tsconfig, the npm scripts and the container volumes | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` |
| 2 | server | 3–5 | `fixtures:reset` builds the base world and the `home-dashboard` layer with D11's numbers, proven against a throwaway database; authoring guide + builder house rule; contract frozen | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` |
| 3 | iphone | 6–7 | Both dev-login callers sign in as the selected `DevLoginIdentity`, an unseeded fixture user surfaces as `AuthError.fixturesNotSeeded` with the D14 message on Login, and the Profile stopgap's "Local identity" group switches identity through `EnvironmentActions.switchIdentity`, reverting to You on failure | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: Fixed IDs, FixtureContext and the date/PRNG helpers
App: server
Phase: 1
Recipe: REFERENCE §Global constraints (server) · server/.claude/CLAUDE.md

**Files:**
- Create: `server/fixtures/ids.ts`
- Create: `server/fixtures/context.ts`
- Create: `server/fixtures/tsconfig.json`
- Test: `server/fixtures/__tests__/context.test.ts`

**Interfaces:**
- Consumes: `PrismaClient` and model types (`User`, `Organization`, `Group`, `GroupMember`, `Member`, `StudyProgram`, `Lesson`, `LessonActivity`, `Enrollment`, `LessonSchedule`) from `server/src/generated/prisma/index.js` (type-only).
- Produces (`ids.ts`):
  - `FIXTURE_KIND: { user:'0001', organization:'0002', group:'0003', member:'0004', program:'0005', lesson:'0006', activity:'0007', enrollment:'0008', schedule:'0009', lessonProgress:'000a', videoProgress:'000b', membershipEvent:'000c', clientEvent:'000d', userRole:'000e', groupMember:'000f', memberOrganization:'0010' }`, `type FixtureKind = keyof typeof FIXTURE_KIND`
  - `fixtureId(kind: FixtureKind, n: number): string` → `f1f1f1f1-<kind>-4000-8000-<n as 12 hex digits>`
  - `FIXTURE_USER_EMAIL = 'fixtures@makeready.local'`, `FIXTURE_USER_ID: string`, `FIXTURE_ORG_ID: string`, `FIXTURE_GROUP_IDS: string[]` (3), `FIXTURE_MEMBER_IDS: string[]` (24), `FIXTURE_PROGRAM_IDS: { days21: string; days30: string }`, `FIXTURE_ENROLLMENT_IDS: string[]` (4), `FIXTURE_IDS` (all of these in one object)
- Produces (`context.ts`):
  - `FIXTURE_TZ = 'America/Chicago'`, `FIXTURE_SEED = 0xf1f1f1f1`, `class FixtureError extends Error`
  - `interface Prng { next(): number; int(min: number, maxInclusive: number): number; shuffle<T>(items: readonly T[]): T[] }`, `createPrng(seed?: number): Prng`
  - `localDate(instant: Date, tz?: string): string` (YYYY-MM-DD), `addDays(date: string, days: number): string`, `weekdayOf(date: string): number` (0 = Sun), `zonedTime(date: string, hour: number, tz?: string): Date` (fractional hours allowed), `atLocalHour(date: Date, hour: number, tz?: string): Date`, `daysAgo(now: Date, n: number, tz?: string): Date` (Chicago-local noon, n days before today)
  - `interface FixtureCreated { user: User | null; org: Organization | null; groups: Group[]; members: Member[]; groupMembers: GroupMember[]; programs: StudyProgram[]; lessons: Lesson[]; activities: LessonActivity[]; enrollments: Enrollment[]; schedules: LessonSchedule[] }`
  - `interface FixtureContext { readonly now: Date; readonly today: string; readonly prisma: PrismaClient; readonly ids: typeof FIXTURE_IDS; readonly rand: Prng; readonly created: FixtureCreated; daysAgo(n: number): Date; atLocalHour(date: Date, hour: number): Date; dateOf(dayOffset: number): string; at(dayOffset: number, hour: number): Date }`
  - `type ScenarioFn = (ctx: FixtureContext) => Promise<void>`, `type LayerScenario = 'full' | 'sparse' | 'extreme'`, `LAYER_SCENARIOS: readonly LayerScenario[]`, `type ScreenLayer = Partial<Record<LayerScenario, ScenarioFn>>`
  - `createContext(prisma: PrismaClient, now: Date, seed?: number): FixtureContext`

- [ ] **Step 1: Write the failing test** — `server/fixtures/__tests__/context.test.ts`

```ts
import { describe, expect, it } from 'vitest'
import type { PrismaClient } from '../../src/generated/prisma/index.js'
import {
  FIXTURE_ENROLLMENT_IDS,
  FIXTURE_GROUP_IDS,
  FIXTURE_IDS,
  FIXTURE_MEMBER_IDS,
  FIXTURE_ORG_ID,
  FIXTURE_USER_ID,
  fixtureId,
} from '../ids.js'
import {
  addDays,
  atLocalHour,
  createContext,
  createPrng,
  daysAgo,
  localDate,
  weekdayOf,
  zonedTime,
} from '../context.js'

const UUID = /^f1f1f1f1-[0-9a-f]{4}-4000-8000-[0-9a-f]{12}$/

describe('fixture ids (D15)', () => {
  it('builds valid f1f1f1f1-prefixed UUIDs with the kind in the second group', () => {
    expect(fixtureId('group', 1)).toBe('f1f1f1f1-0003-4000-8000-000000000001')
    expect(fixtureId('schedule', 4021)).toBe('f1f1f1f1-0009-4000-8000-000000000fb5')
    expect(() => fixtureId('member', -1)).toThrow(RangeError)
    expect(() => fixtureId('member', 1.5)).toThrow(RangeError)
  })

  it('fixes every base identity, all distinct and well-formed', () => {
    expect(FIXTURE_GROUP_IDS).toHaveLength(3)
    expect(FIXTURE_MEMBER_IDS).toHaveLength(24)
    expect(FIXTURE_ENROLLMENT_IDS).toHaveLength(4)
    const all = [
      FIXTURE_USER_ID,
      FIXTURE_ORG_ID,
      ...FIXTURE_GROUP_IDS,
      ...FIXTURE_MEMBER_IDS,
      FIXTURE_IDS.programs.days21,
      FIXTURE_IDS.programs.days30,
      ...FIXTURE_ENROLLMENT_IDS,
    ]
    for (const id of all) expect(id).toMatch(UUID)
    expect(new Set(all).size).toBe(all.length)
  })
})

describe('seeded PRNG', () => {
  it('is deterministic for a seed and stays in [0, 1)', () => {
    const a = createPrng()
    const b = createPrng()
    const xs = Array.from({ length: 50 }, () => a.next())
    const ys = Array.from({ length: 50 }, () => b.next())
    expect(xs).toEqual(ys)
    for (const x of xs) {
      expect(x).toBeGreaterThanOrEqual(0)
      expect(x).toBeLessThan(1)
    }
    expect(createPrng(7).next()).not.toBe(createPrng(8).next())
  })

  it('shuffles deterministically without losing items', () => {
    const items = Array.from({ length: 20 }, (_, i) => i)
    const s1 = createPrng().shuffle(items)
    const s2 = createPrng().shuffle(items)
    expect(s1).toEqual(s2)
    expect([...s1].sort((x, y) => x - y)).toEqual(items)
    expect(items[0]).toBe(0) // input untouched
  })

  it('int() stays inside its inclusive bounds', () => {
    const r = createPrng()
    for (let i = 0; i < 200; i++) {
      const n = r.int(7, 9)
      expect(n).toBeGreaterThanOrEqual(7)
      expect(n).toBeLessThanOrEqual(9)
    }
  })
})

describe('America/Chicago date helpers (D9, D11)', () => {
  it('converts Chicago wall time to UTC across both offsets and DST', () => {
    expect(zonedTime('2026-07-01', 7).toISOString()).toBe('2026-07-01T12:00:00.000Z') // CDT −5
    expect(zonedTime('2026-07-01', 13.5).toISOString()).toBe('2026-07-01T18:30:00.000Z')
    expect(zonedTime('2026-01-15', 21).toISOString()).toBe('2026-01-16T03:00:00.000Z') // CST −6
    expect(zonedTime('2026-03-08', 12).toISOString()).toBe('2026-03-08T17:00:00.000Z') // DST-start day
  })

  it('reads the Chicago calendar date of an instant', () => {
    expect(localDate(new Date('2026-01-16T03:00:00.000Z'))).toBe('2026-01-15')
    expect(localDate(new Date('2026-07-01T05:30:00.000Z'))).toBe('2026-07-01')
  })

  it('anchors daysAgo at Chicago noon and atLocalHour on the instant’s Chicago date', () => {
    const now = new Date('2026-07-10T15:00:00.000Z') // 10:00 CDT
    expect(daysAgo(now, 3).toISOString()).toBe('2026-07-07T17:00:00.000Z')
    expect(atLocalHour(new Date('2026-01-16T03:30:00.000Z'), 9).toISOString()).toBe('2026-01-15T15:00:00.000Z')
  })

  it('does date-only arithmetic and weekday lookup', () => {
    expect(addDays('2026-02-28', 1)).toBe('2026-03-01')
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28')
    expect(weekdayOf('2026-10-25')).toBe(0) // Sunday
    expect(weekdayOf('2026-10-31')).toBe(6) // Saturday
  })
})

describe('createContext', () => {
  it('derives today and the day-offset helpers from now', () => {
    const now = new Date('2026-10-25T20:00:00.000Z') // 15:00 CDT, Sunday
    const ctx = createContext({} as PrismaClient, now)
    expect(ctx.today).toBe('2026-10-25')
    expect(ctx.dateOf(-1)).toBe('2026-10-24')
    expect(ctx.at(-1, 7).toISOString()).toBe('2026-10-24T12:00:00.000Z')
    expect(ctx.daysAgo(2).toISOString()).toBe('2026-10-23T17:00:00.000Z')
    expect(ctx.ids.user).toBe(FIXTURE_USER_ID)
    expect(ctx.created.groups).toEqual([])
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run fixtures/__tests__/context.test.ts` → FAIL, `Failed to resolve import "../ids.js"`

- [ ] **Step 3: Write the minimal implementation** — `server/fixtures/ids.ts`

```ts
/**
 * Every fixed ID of the fixture world (SPEC ui2-fixtures D3, D7, D15).
 *
 * Scheme: valid UUIDs `f1f1f1f1-<kind>-4000-8000-<n, 12 hex digits>`, where
 * <kind> is a per-model 4-hex group (`0003` = groups, …). Reset deletes by
 * these IDs, so nothing outside the fixture graph can ever be touched.
 */

export const FIXTURE_KIND = {
  user: '0001',
  organization: '0002',
  group: '0003',
  member: '0004',
  program: '0005',
  lesson: '0006',
  activity: '0007',
  enrollment: '0008',
  schedule: '0009',
  lessonProgress: '000a',
  videoProgress: '000b',
  membershipEvent: '000c',
  clientEvent: '000d',
  userRole: '000e',
  groupMember: '000f',
  memberOrganization: '0010',
} as const

export type FixtureKind = keyof typeof FIXTURE_KIND

const MAX_N = 0xffffffffffff

export function fixtureId(kind: FixtureKind, n: number): string {
  if (!Number.isInteger(n) || n < 0 || n > MAX_N) {
    throw new RangeError(`fixtureId: n must be an integer in [0, ${MAX_N}], got ${n}`)
  }
  return `f1f1f1f1-${FIXTURE_KIND[kind]}-4000-8000-${n.toString(16).padStart(12, '0')}`
}

export const FIXTURE_USER_EMAIL = 'fixtures@makeready.local'
export const FIXTURE_USER_ID = fixtureId('user', 1)
export const FIXTURE_ORG_ID = fixtureId('organization', 1)
export const FIXTURE_GROUP_IDS: string[] = [1, 2, 3].map((n) => fixtureId('group', n))
export const FIXTURE_MEMBER_IDS: string[] = Array.from({ length: 24 }, (_, i) => fixtureId('member', i + 1))
export const FIXTURE_PROGRAM_IDS = {
  days21: fixtureId('program', 1),
  days30: fixtureId('program', 2),
}
export const FIXTURE_ENROLLMENT_IDS: string[] = [1, 2, 3, 4].map((n) => fixtureId('enrollment', n))

export const FIXTURE_IDS = {
  user: FIXTURE_USER_ID,
  org: FIXTURE_ORG_ID,
  groups: FIXTURE_GROUP_IDS,
  members: FIXTURE_MEMBER_IDS,
  programs: FIXTURE_PROGRAM_IDS,
  enrollments: FIXTURE_ENROLLMENT_IDS,
}
```

`server/fixtures/context.ts`

```ts
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
```

`server/fixtures/tsconfig.json` (D17 — the root tsconfig only sees `src/`):

```json
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "rootDir": "..",
    "noEmit": true,
    "composite": false,
    "incremental": false
  },
  "include": ["./**/*.ts", "../src/**/*.ts"],
  "exclude": ["../node_modules", "../dist"]
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run fixtures/__tests__/context.test.ts` → PASS (10 tests); then `cd server && npx tsc --noEmit -p fixtures` → exit 0 and `cd server && npx tsc --noEmit` → exit 0

- [ ] **Step 5: Commit** — `feat(ui2-fixtures): fixture ids, FixtureContext and Chicago date/PRNG helpers`

### Task 2: Guard, wipe, row counts, refresh retry and the fixtures CLI
App: server
Phase: 1
Recipe: REFERENCE §Global constraints (server) · server/.claude/CLAUDE.md

**Files:**
- Create: `server/fixtures/guard.ts`
- Create: `server/fixtures/wipe.ts`
- Create: `server/fixtures/counts.ts`
- Create: `server/fixtures/runner.ts`
- Create: `server/fixtures/index.ts`
- Modify: `server/package.json` (scripts, after `"db:seed:dev"`)
- Modify: `docker-compose.yml:26-30` (root — the `server` service volumes, D16)
- Test: `server/fixtures/__tests__/guard.test.ts`, `server/fixtures/__tests__/wipe.test.ts`, `server/fixtures/__tests__/runner.test.ts`

**Interfaces:**
- Consumes (Task 1): `FixtureError`, `createContext(prisma, now)`, `LAYER_SCENARIOS`, `LayerScenario`, `ScenarioFn`, `ScreenLayer` from `../context.js`; `FIXTURE_USER_ID`, `FIXTURE_USER_EMAIL`, `FIXTURE_ORG_ID`, `FIXTURE_MEMBER_IDS` from `../ids.js`; `RefreshResult` (type) and `refreshAnalytics(): Promise<RefreshResult>` from `server/src/services/analytics.service.ts` (`RefreshResult = { refreshed: boolean; skippedLockHeld?: boolean; durationMs?: number; error?: string }`, never throws).
- Produces:
  - `guard.ts`: `ALLOWED_NODE_ENVS`, `ALLOWED_DB_HOSTS`, `type GuardResult = { ok: true } | { ok: false; reason: string }`, `checkGuard(env: Record<string, string | undefined>): GuardResult`
  - `wipe.ts`: `type WipeClient = Pick<PrismaClient, 'clientEvent' | 'member' | 'group' | 'studyProgram' | 'user'>`, `FIXTURE_CLIENT_EVENT_WHERE`, `wipeFixtures(prisma: WipeClient): Promise<void>`, `fixtureUserExists(prisma: Pick<PrismaClient, 'user'>): Promise<boolean>`
  - `counts.ts`: `FIXTURE_TABLES` (16 snake_case table names), `type FixtureTable`, `type RowCounts = Record<FixtureTable, number>`, `countFixtureRows(prisma: PrismaClient): Promise<RowCounts>`, `formatCounts(counts: RowCounts): string`
  - `runner.ts`: `FIXTURES_DIR: string`, `type Command = 'reset' | 'seed'`, `type Scenario = LayerScenario | 'empty'`, `interface NamedLayer { name: string; module: ScreenLayer }`, `interface LoadedLayers { base: ScenarioFn; screens: NamedLayer[] }`, `parseCommand(argv: readonly string[]): { command: Command; scenario: string } | { error: string }`, `availableScenarios(screens: readonly NamedLayer[]): Scenario[]`, `REFRESH_RETRY_MS = 2000`, `REFRESH_MAX_WAIT_MS = 30000`, `refreshUntilRan(refresh: () => Promise<RefreshResult>, sleep: (ms: number) => Promise<void>): Promise<RefreshResult>`, `loadLayers(dir: string): Promise<LoadedLayers>` (imports `<dir>/base.ts` → its `seedBase` export, then every `<dir>/screens/*.ts` in filename order → their `full`/`sparse`/`extreme` exports), `interface RunOptions { command: Command; scenario: Scenario; prisma: PrismaClient; layers: LoadedLayers; now: Date; refresh: () => Promise<RefreshResult>; sleep: (ms: number) => Promise<void>; log: (line: string) => void }`, `runFixtures(o: RunOptions): Promise<RowCounts>`, `interface MainDeps { loadLayers(): Promise<LoadedLayers>; createPrisma(url: string): PrismaClient; refresh(): Promise<RefreshResult>; sleep(ms: number): Promise<void>; now(): Date; log(line: string): void; error(line: string): void }`, `main(argv: readonly string[], env: Record<string, string | undefined>, deps: MainDeps): Promise<number>`, `liveDeps(): MainDeps`
  - Base layer contract for Task 3: `server/fixtures/base.ts` must `export const seedBase: ScenarioFn`. Screen layer contract for Task 4: `server/fixtures/screens/<screen-id>.ts` exports any of `full`, `sparse`, `extreme` as `ScenarioFn`.
  - npm scripts `fixtures:reset` = `tsx fixtures/index.ts reset`, `fixtures:seed` = `tsx fixtures/index.ts seed`.

- [ ] **Step 1: Write the failing tests**

`server/fixtures/__tests__/guard.test.ts` — §Testing (a)

```ts
import { describe, expect, it } from 'vitest'
import { checkGuard } from '../guard.js'

const LOCAL = 'postgresql://postgres:postgres@localhost:5434/makeready_dev'

describe('fixtures guard (D8, §Testing a)', () => {
  it('admits development and test against a local host', () => {
    expect(checkGuard({ NODE_ENV: 'development', DATABASE_URL: LOCAL })).toEqual({ ok: true })
    expect(checkGuard({ NODE_ENV: 'test', DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5434/x' })).toEqual({ ok: true })
    expect(
      checkGuard({
        NODE_ENV: 'development',
        DATABASE_URL: 'postgresql://postgres:postgres@postgres:5432/makeready_dev',
        DIRECT_URL: 'postgresql://postgres:postgres@postgres:5432/makeready_dev',
      })
    ).toEqual({ ok: true })
  })

  it('refuses NODE_ENV=production even on a local database', () => {
    const r = checkGuard({ NODE_ENV: 'production', DATABASE_URL: LOCAL })
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.reason).toContain('NODE_ENV')
  })

  it('refuses a missing NODE_ENV', () => {
    expect(checkGuard({ DATABASE_URL: LOCAL }).ok).toBe(false)
  })

  it('refuses a non-local DATABASE_URL host', () => {
    const r = checkGuard({ NODE_ENV: 'development', DATABASE_URL: 'postgresql://u:p@hopper.proxy.rlwy.net:33058/railway' })
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.reason).toContain('hopper.proxy.rlwy.net')
  })

  it('refuses a non-local DIRECT_URL even when DATABASE_URL is local', () => {
    const r = checkGuard({ NODE_ENV: 'development', DATABASE_URL: LOCAL, DIRECT_URL: 'postgresql://u:p@db.example.com:5432/x' })
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.reason).toContain('DIRECT_URL')
  })

  it('refuses a missing or unparsable DATABASE_URL', () => {
    expect(checkGuard({ NODE_ENV: 'development' }).ok).toBe(false)
    expect(checkGuard({ NODE_ENV: 'development', DATABASE_URL: 'not a url' }).ok).toBe(false)
  })
})
```

`server/fixtures/__tests__/wipe.test.ts` — D7 order, against a recording fake (no database)

```ts
import { describe, expect, it } from 'vitest'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { type WipeClient, wipeFixtures } from '../wipe.js'

describe('wipeFixtures (D7)', () => {
  it('deletes exactly the fixture graph, in the D7 order', async () => {
    const calls: Array<{ model: string; args: unknown }> = []
    const model = (name: string) => ({
      deleteMany: async (args: unknown) => {
        calls.push({ model: name, args })
        return { count: 0 }
      },
    })
    const fake = {
      clientEvent: model('clientEvent'),
      member: model('member'),
      group: model('group'),
      studyProgram: model('studyProgram'),
      user: model('user'),
    } as unknown as WipeClient

    await wipeFixtures(fake)

    expect(calls).toEqual([
      {
        model: 'clientEvent',
        args: { where: { OR: [{ organizationId: FIXTURE_ORG_ID }, { memberId: { in: FIXTURE_MEMBER_IDS } }] } },
      },
      { model: 'member', args: { where: { id: { in: FIXTURE_MEMBER_IDS } } } },
      { model: 'group', args: { where: { organizationId: FIXTURE_ORG_ID } } },
      { model: 'studyProgram', args: { where: { organizationId: FIXTURE_ORG_ID } } },
      { model: 'user', args: { where: { id: FIXTURE_USER_ID } } },
    ])
  })
})
```

`server/fixtures/__tests__/runner.test.ts` — §Testing (f), D6 parsing, D10 retry

```ts
import { describe, expect, it, vi } from 'vitest'
import {
  type MainDeps,
  REFRESH_RETRY_MS,
  availableScenarios,
  main,
  parseCommand,
  refreshUntilRan,
} from '../runner.js'

const LOCAL_ENV = {
  NODE_ENV: 'development',
  DATABASE_URL: 'postgresql://postgres:postgres@localhost:5434/makeready_dev',
}

function stubDeps(overrides: Partial<MainDeps> = {}) {
  const errors: string[] = []
  const createPrisma = vi.fn(() => {
    throw new Error('main must not open a database on this path')
  })
  const deps: MainDeps = {
    loadLayers: async () => ({
      base: async () => undefined,
      screens: [{ name: 'home-dashboard', module: { full: async () => undefined } }],
    }),
    createPrisma,
    refresh: async () => ({ refreshed: true }),
    sleep: async () => undefined,
    now: () => new Date('2026-10-25T15:00:00Z'),
    log: () => undefined,
    error: (line) => {
      errors.push(line)
    },
    ...overrides,
  }
  return { deps, errors, createPrisma }
}

describe('parseCommand (D4, D6)', () => {
  it('defaults the scenario to full', () => {
    expect(parseCommand(['reset'])).toEqual({ command: 'reset', scenario: 'full' })
    expect(parseCommand(['seed', 'empty'])).toEqual({ command: 'seed', scenario: 'empty' })
  })

  it('rejects an unknown command or extra arguments', () => {
    expect('error' in parseCommand(['wipe'])).toBe(true)
    expect('error' in parseCommand([])).toBe(true)
    expect('error' in parseCommand(['reset', 'full', 'extra'])).toBe(true)
  })
})

describe('availableScenarios (D6)', () => {
  it('lists what screen layers implement, plus empty', () => {
    expect(availableScenarios([{ name: 'home-dashboard', module: { full: async () => undefined } }])).toEqual([
      'full',
      'empty',
    ])
    expect(availableScenarios([])).toEqual(['empty'])
  })
})

describe('main (§Testing f)', () => {
  it('exits 1 on an unknown scenario, lists the available ones, and never opens a database', async () => {
    const { deps, errors, createPrisma } = stubDeps()
    expect(await main(['reset', 'bogus'], LOCAL_ENV, deps)).toBe(1)
    expect(errors.join('\n')).toContain('unknown scenario "bogus"')
    expect(errors.join('\n')).toContain('Available scenarios: full, empty')
    expect(createPrisma).not.toHaveBeenCalled()
  })

  it('exits 1 on a scenario no layer implements beyond base', async () => {
    const { deps, errors } = stubDeps()
    expect(await main(['reset', 'sparse'], LOCAL_ENV, deps)).toBe(1)
    expect(errors.join('\n')).toContain('Available scenarios: full, empty')
  })

  it('exits 1 on an unknown command', async () => {
    const { deps, createPrisma } = stubDeps()
    expect(await main(['nuke'], LOCAL_ENV, deps)).toBe(1)
    expect(createPrisma).not.toHaveBeenCalled()
  })

  it('exits 1 when the guard refuses, before opening a database', async () => {
    const { deps, errors, createPrisma } = stubDeps()
    expect(await main(['reset'], { ...LOCAL_ENV, NODE_ENV: 'production' }, deps)).toBe(1)
    expect(errors.join('\n')).toContain('refused')
    expect(createPrisma).not.toHaveBeenCalled()
  })

  it('exits 1 when the layers cannot be loaded', async () => {
    const { deps, errors } = stubDeps({
      loadLayers: async () => {
        throw new Error('base layer not found')
      },
    })
    expect(await main(['reset'], LOCAL_ENV, deps)).toBe(1)
    expect(errors.join('\n')).toContain('base layer not found')
  })
})

describe('refreshUntilRan (D10)', () => {
  it('retries every 2 s while the advisory lock is held', async () => {
    const refresh = vi
      .fn()
      .mockResolvedValueOnce({ refreshed: false, skippedLockHeld: true })
      .mockResolvedValueOnce({ refreshed: false, skippedLockHeld: true })
      .mockResolvedValueOnce({ refreshed: true, durationMs: 12 })
    const sleep = vi.fn(async () => undefined)
    await expect(refreshUntilRan(refresh, sleep)).resolves.toEqual({ refreshed: true, durationMs: 12 })
    expect(refresh).toHaveBeenCalledTimes(3)
    expect(sleep).toHaveBeenCalledTimes(2)
    expect(sleep).toHaveBeenCalledWith(REFRESH_RETRY_MS)
  })

  it('fails immediately with the error when the refresh itself failed', async () => {
    const refresh = vi.fn().mockResolvedValue({ refreshed: false, error: 'relation "analytics_events" does not exist' })
    const sleep = vi.fn(async () => undefined)
    await expect(refreshUntilRan(refresh, sleep)).rejects.toThrow('relation "analytics_events" does not exist')
    expect(sleep).not.toHaveBeenCalled()
  })

  it('gives up after 30 s of a held lock', async () => {
    const refresh = vi.fn().mockResolvedValue({ refreshed: false, skippedLockHeld: true })
    const sleep = vi.fn(async () => undefined)
    await expect(refreshUntilRan(refresh, sleep)).rejects.toThrow('advisory lock')
    expect(refresh).toHaveBeenCalledTimes(16)
    expect(sleep).toHaveBeenCalledTimes(15)
  })
})
```

- [ ] **Step 2: Run them and watch them fail** — `cd server && npx vitest run fixtures/__tests__/guard.test.ts fixtures/__tests__/wipe.test.ts fixtures/__tests__/runner.test.ts` → FAIL, `Failed to resolve import "../guard.js"` (and `../wipe.js`, `../runner.js`)

- [ ] **Step 3: Write the minimal implementation**

`server/fixtures/guard.ts`

```ts
/**
 * Safety guard (SPEC ui2-fixtures D8): the runner deletes rows, so it refuses
 * unless NODE_ENV is development or test AND every database URL it will use
 * (DATABASE_URL, and DIRECT_URL when set — Prisma and the analytics pool
 * prefer it) points at a local host. Pure: the env is passed in.
 */

export const ALLOWED_NODE_ENVS: readonly string[] = ['development', 'test']
export const ALLOWED_DB_HOSTS: readonly string[] = ['postgres', 'localhost', '127.0.0.1']

export type GuardResult = { ok: true } | { ok: false; reason: string }

export function checkGuard(env: Record<string, string | undefined>): GuardResult {
  const nodeEnv = env.NODE_ENV
  if (!nodeEnv || !ALLOWED_NODE_ENVS.includes(nodeEnv)) {
    return { ok: false, reason: `NODE_ENV is "${nodeEnv ?? ''}" — fixtures run only when NODE_ENV is development or test` }
  }
  if (!env.DATABASE_URL) {
    return { ok: false, reason: 'DATABASE_URL is not set' }
  }
  for (const name of ['DATABASE_URL', 'DIRECT_URL']) {
    const value = env[name]
    if (!value) continue
    let host: string
    try {
      host = new URL(value).hostname
    } catch {
      return { ok: false, reason: `${name} is not a valid URL` }
    }
    if (!ALLOWED_DB_HOSTS.includes(host)) {
      return { ok: false, reason: `${name} host "${host}" is not local (allowed: ${ALLOWED_DB_HOSTS.join(', ')})` }
    }
  }
  return { ok: true }
}
```

`server/fixtures/wipe.ts`

```ts
/**
 * Reset's delete step (SPEC ui2-fixtures D7) — exactly, in this order:
 *  1. client_events of the fixture org or a fixture member (no FKs, so explicit);
 *  2. the fixture members (cascades group_members, member_organizations, the
 *     three progress tables and membership_events);
 *  3. groups and study_programs whose organizationId is the fixture org (a
 *     backstop: organizationId has no FK);
 *  4. the fixture user (cascades the owned org, and through creatorId its
 *     groups, programs, lessons, activities, enrollments, schedules,
 *     user_roles and member_organizations).
 * The system Owner role is never deleted. Nothing else is.
 */
import type { PrismaClient } from '../src/generated/prisma/index.js'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_EMAIL, FIXTURE_USER_ID } from './ids.js'

export type WipeClient = Pick<PrismaClient, 'clientEvent' | 'member' | 'group' | 'studyProgram' | 'user'>

export const FIXTURE_CLIENT_EVENT_WHERE = {
  OR: [{ organizationId: FIXTURE_ORG_ID }, { memberId: { in: FIXTURE_MEMBER_IDS } }],
}

export async function wipeFixtures(prisma: WipeClient): Promise<void> {
  await prisma.clientEvent.deleteMany({ where: FIXTURE_CLIENT_EVENT_WHERE })
  await prisma.member.deleteMany({ where: { id: { in: FIXTURE_MEMBER_IDS } } })
  await prisma.group.deleteMany({ where: { organizationId: FIXTURE_ORG_ID } })
  await prisma.studyProgram.deleteMany({ where: { organizationId: FIXTURE_ORG_ID } })
  await prisma.user.deleteMany({ where: { id: FIXTURE_USER_ID } })
}

/** `fixtures:seed` refuses when this is true (D4). */
export async function fixtureUserExists(prisma: Pick<PrismaClient, 'user'>): Promise<boolean> {
  const user = await prisma.user.findFirst({
    where: { OR: [{ id: FIXTURE_USER_ID }, { email: FIXTURE_USER_EMAIL }] },
    select: { id: true },
  })
  return user !== null
}
```

`server/fixtures/counts.ts`

```ts
/**
 * Row counts of the fixture graph per table — the runner's summary table
 * (SPEC §Contract) and the idempotence/isolation evidence (§Testing b, c, e).
 */
import type { PrismaClient } from '../src/generated/prisma/index.js'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from './ids.js'
import { FIXTURE_CLIENT_EVENT_WHERE } from './wipe.js'

export const FIXTURE_TABLES = [
  'users',
  'organizations',
  'user_roles',
  'groups',
  'members',
  'group_members',
  'member_organizations',
  'study_programs',
  'lessons',
  'lesson_activities',
  'enrollments',
  'lesson_schedules',
  'member_lesson_progress',
  'member_video_progress',
  'membership_events',
  'client_events',
] as const

export type FixtureTable = (typeof FIXTURE_TABLES)[number]
export type RowCounts = Record<FixtureTable, number>

export async function countFixtureRows(prisma: PrismaClient): Promise<RowCounts> {
  const org = FIXTURE_ORG_ID
  const members = { in: FIXTURE_MEMBER_IDS }
  return {
    users: await prisma.user.count({ where: { id: FIXTURE_USER_ID } }),
    organizations: await prisma.organization.count({ where: { id: org } }),
    user_roles: await prisma.userRole.count({ where: { userId: FIXTURE_USER_ID } }),
    groups: await prisma.group.count({ where: { organizationId: org } }),
    members: await prisma.member.count({ where: { id: members } }),
    group_members: await prisma.groupMember.count({ where: { group: { organizationId: org } } }),
    member_organizations: await prisma.memberOrganization.count({ where: { organizationId: org } }),
    study_programs: await prisma.studyProgram.count({ where: { organizationId: org } }),
    lessons: await prisma.lesson.count({ where: { studyProgram: { organizationId: org } } }),
    lesson_activities: await prisma.lessonActivity.count({ where: { lesson: { studyProgram: { organizationId: org } } } }),
    enrollments: await prisma.enrollment.count({ where: { group: { organizationId: org } } }),
    lesson_schedules: await prisma.lessonSchedule.count({ where: { enrollment: { group: { organizationId: org } } } }),
    member_lesson_progress: await prisma.memberLessonProgress.count({ where: { memberId: members } }),
    member_video_progress: await prisma.memberVideoProgress.count({ where: { memberId: members } }),
    membership_events: await prisma.membershipEvent.count({ where: { memberId: members } }),
    client_events: await prisma.clientEvent.count({ where: FIXTURE_CLIENT_EVENT_WHERE }),
  }
}

export function formatCounts(counts: RowCounts): string {
  const lines = FIXTURE_TABLES.map((table) => `  ${table.padEnd(24)} ${counts[table]}`)
  return ['fixtures: rows in the fixture graph', ...lines].join('\n')
}
```

`server/fixtures/runner.ts`

```ts
/**
 * Fixture runner (SPEC ui2-fixtures D2, D4, D6, D8, D10): argument parsing,
 * layer discovery, the reset/seed pipeline and the CLI's exit codes.
 * `index.ts` is the process entry; everything here is injectable for tests.
 */
import { existsSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { PrismaClient } from '../src/generated/prisma/index.js'
import type { RefreshResult } from '../src/services/analytics.service.js'
import {
  FixtureError,
  LAYER_SCENARIOS,
  type LayerScenario,
  type ScenarioFn,
  type ScreenLayer,
  createContext,
} from './context.js'
import { type RowCounts, countFixtureRows, formatCounts } from './counts.js'
import { checkGuard } from './guard.js'
import { fixtureUserExists, wipeFixtures } from './wipe.js'

export const FIXTURES_DIR = dirname(fileURLToPath(import.meta.url))

export type Command = 'reset' | 'seed'
export type Scenario = LayerScenario | 'empty'

export interface NamedLayer {
  name: string
  module: ScreenLayer
}

export interface LoadedLayers {
  base: ScenarioFn
  screens: NamedLayer[]
}

const USAGE = 'usage: npm run fixtures:reset [-- <scenario>] | npm run fixtures:seed [-- <scenario>]'

export function parseCommand(argv: readonly string[]): { command: Command; scenario: string } | { error: string } {
  const [command, scenario = 'full', ...rest] = argv
  if (command !== 'reset' && command !== 'seed') {
    return { error: `fixtures: unknown command "${command ?? ''}" — ${USAGE}` }
  }
  if (rest.length > 0) {
    return { error: `fixtures: unexpected arguments "${rest.join(' ')}" — ${USAGE}` }
  }
  return { command, scenario }
}

/** D6: scenarios some screen layer implements, plus `empty` (base only). */
export function availableScenarios(screens: readonly NamedLayer[]): Scenario[] {
  const implemented = LAYER_SCENARIOS.filter((s) => screens.some((layer) => typeof layer.module[s] === 'function'))
  return [...implemented, 'empty']
}

// ── D10: refresh the analytics view, retrying while another instance holds the lock ──

export const REFRESH_RETRY_MS = 2_000
export const REFRESH_MAX_WAIT_MS = 30_000

export async function refreshUntilRan(
  refresh: () => Promise<RefreshResult>,
  sleep: (ms: number) => Promise<void>
): Promise<RefreshResult> {
  const maxAttempts = 1 + Math.floor(REFRESH_MAX_WAIT_MS / REFRESH_RETRY_MS)
  for (let attempt = 1; ; attempt++) {
    const result = await refresh()
    if (result.refreshed) return result
    if (!result.skippedLockHeld) {
      throw new FixtureError(`analytics refresh did not run: ${result.error ?? 'unknown error'}`)
    }
    if (attempt >= maxAttempts) {
      throw new FixtureError(
        `analytics refresh did not run: the advisory lock was held for ${REFRESH_MAX_WAIT_MS / 1000} s`
      )
    }
    await sleep(REFRESH_RETRY_MS)
  }
}

// ── D2: layer discovery — base.ts, then screens/*.ts in filename order ──

export async function loadLayers(dir: string): Promise<LoadedLayers> {
  const basePath = join(dir, 'base.ts')
  if (!existsSync(basePath)) throw new FixtureError(`base layer not found at ${basePath}`)
  const baseModule = (await import(pathToFileURL(basePath).href)) as Record<string, unknown>
  const seedBase = baseModule.seedBase
  if (typeof seedBase !== 'function') throw new FixtureError('base.ts must export seedBase(ctx)')

  const screensDir = join(dir, 'screens')
  const files = existsSync(screensDir)
    ? readdirSync(screensDir)
        .filter((f) => f.endsWith('.ts') && !f.endsWith('.d.ts') && !f.endsWith('.test.ts'))
        .sort()
    : []
  const screens: NamedLayer[] = []
  for (const file of files) {
    const mod = (await import(pathToFileURL(join(screensDir, file)).href)) as Record<string, unknown>
    const layer: ScreenLayer = {}
    for (const scenario of LAYER_SCENARIOS) {
      const fn = mod[scenario]
      if (fn === undefined) continue
      if (typeof fn !== 'function') throw new FixtureError(`screens/${file}: export "${scenario}" must be a function`)
      layer[scenario] = fn as ScenarioFn
    }
    screens.push({ name: file.replace(/\.ts$/, ''), module: layer })
  }
  return { base: seedBase as ScenarioFn, screens }
}

// ── The pipeline ──

export interface RunOptions {
  command: Command
  scenario: Scenario
  prisma: PrismaClient
  layers: LoadedLayers
  now: Date
  refresh: () => Promise<RefreshResult>
  sleep: (ms: number) => Promise<void>
  log: (line: string) => void
}

export async function runFixtures(o: RunOptions): Promise<RowCounts> {
  if (o.command === 'seed' && (await fixtureUserExists(o.prisma))) {
    throw new FixtureError('the fixture user already exists — run fixtures:reset instead')
  }
  if (o.command === 'reset') {
    o.log('fixtures: wiping the fixture graph')
    await wipeFixtures(o.prisma)
  }
  const ctx = createContext(o.prisma, o.now)
  o.log('fixtures: base')
  await o.layers.base(ctx)
  const scenario = o.scenario
  if (scenario !== 'empty') {
    for (const layer of o.layers.screens) {
      const fn = layer.module[scenario]
      if (!fn) continue
      o.log(`fixtures: ${layer.name} (${scenario})`)
      await fn(ctx)
    }
  }
  o.log('fixtures: refreshing analytics')
  await refreshUntilRan(o.refresh, o.sleep)
  return countFixtureRows(o.prisma)
}

// ── CLI ──

export interface MainDeps {
  loadLayers(): Promise<LoadedLayers>
  createPrisma(url: string): PrismaClient
  refresh(): Promise<RefreshResult>
  sleep(ms: number): Promise<void>
  now(): Date
  log(line: string): void
  error(line: string): void
}

const messageOf = (err: unknown) => (err instanceof Error ? err.message : String(err))

export async function main(
  argv: readonly string[],
  env: Record<string, string | undefined>,
  deps: MainDeps
): Promise<number> {
  const parsed = parseCommand(argv)
  if ('error' in parsed) {
    deps.error(parsed.error)
    return 1
  }

  let layers: LoadedLayers
  try {
    layers = await deps.loadLayers()
  } catch (err) {
    deps.error(`fixtures: ${messageOf(err)}`)
    return 1
  }

  const available = availableScenarios(layers.screens)
  const scenario = available.find((s) => s === parsed.scenario)
  if (!scenario) {
    deps.error(`fixtures: unknown scenario "${parsed.scenario}". Available scenarios: ${available.join(', ')}`)
    return 1
  }

  const guard = checkGuard(env)
  if (!guard.ok) {
    deps.error(`fixtures: refused — ${guard.reason}`)
    return 1
  }

  const prisma = deps.createPrisma(env.DIRECT_URL || env.DATABASE_URL || '')
  try {
    const counts = await runFixtures({
      command: parsed.command,
      scenario,
      prisma,
      layers,
      now: deps.now(),
      refresh: () => deps.refresh(),
      sleep: (ms) => deps.sleep(ms),
      log: (line) => deps.log(line),
    })
    deps.log(formatCounts(counts))
    return 0
  } catch (err) {
    deps.error(`fixtures: ${messageOf(err)}`)
    return 1
  } finally {
    await prisma.$disconnect()
  }
}

export function liveDeps(): MainDeps {
  return {
    loadLayers: () => loadLayers(FIXTURES_DIR),
    createPrisma: (url) => new PrismaClient({ datasourceUrl: url }),
    // Imported lazily: the analytics service opens its pg pool from env on first use.
    refresh: async () => (await import('../src/services/analytics.service.js')).refreshAnalytics(),
    sleep: (ms) => new Promise<void>((resolve) => setTimeout(resolve, ms)),
    now: () => new Date(),
    log: (line) => console.log(line),
    error: (line) => console.error(line),
  }
}
```

`server/fixtures/index.ts`

```ts
/**
 * Process entry for `npm run fixtures:reset [-- <scenario>]` and
 * `npm run fixtures:seed [-- <scenario>]` (SPEC ui2-fixtures D4).
 * Ends with process.exit: the analytics service's pg pool has no exported
 * close, so the process would otherwise never exit (D10).
 */
import { liveDeps, main } from './runner.js'

main(process.argv.slice(2), process.env, liveDeps()).then(
  (code) => process.exit(code),
  (err: unknown) => {
    console.error('fixtures: unexpected failure —', err)
    process.exit(1)
  }
)
```

`server/package.json` — add the two scripts directly after the existing `"db:seed:dev"` line:

```json
    "db:seed:dev": "npx tsx prisma/seed-dev.ts",
    "fixtures:reset": "tsx fixtures/index.ts reset",
    "fixtures:seed": "tsx fixtures/index.ts seed",
```

Root `docker-compose.yml` — the `server` service volumes (D16) become:

```yaml
    volumes:
      - ./server/src:/app/src
      - ./server/prisma:/app/prisma
      - ./server/atlas:/app/atlas
      - ./server/fixtures:/app/fixtures
      - ./server/package.json:/app/package.json
      - /app/src/generated/prisma
```

- [ ] **Step 4: Run them and watch them pass** — `cd server && npx vitest run fixtures/__tests__/guard.test.ts fixtures/__tests__/wipe.test.ts fixtures/__tests__/runner.test.ts` → PASS (18 tests); then `cd server && npx tsc --noEmit -p fixtures` → exit 0, `cd server && npx tsc --noEmit` → exit 0, `grep -n 'server/fixtures:/app/fixtures\|server/package.json:/app/package.json' docker-compose.yml` (repo root) → both lines (do not run `docker compose config`: it reads `server/.env`, a 1Password named pipe). Do NOT run `fixtures:reset` against any database in this task (base.ts arrives in Task 3; the CLI would correctly exit 1 with `base layer not found`).

- [ ] **Step 5: Commit** — `feat(ui2-fixtures): fixtures runner — guard, wipe, counts, refresh retry, CLI, npm scripts and container volumes`

### Task 3: Base layer and the DB-backed isolation + empty-scenario tests
App: server
Phase: 2
Recipe: REFERENCE §Global constraints (server) · server/.claude/CLAUDE.md

**Files:**
- Create: `server/fixtures/base.ts`
- Create: `server/fixtures/__tests__/db-harness.ts`
- Test: `server/fixtures/__tests__/base.db.test.ts`

**Interfaces:**
- Consumes (Task 1): `ScenarioFn`, `FixtureError`, `FIXTURE_TZ`, `localDate`, `addDays` from `../context.js`; `fixtureId`, `FIXTURE_USER_ID`, `FIXTURE_USER_EMAIL`, `FIXTURE_ORG_ID`, `FIXTURE_GROUP_IDS`, `FIXTURE_MEMBER_IDS`, `FIXTURE_PROGRAM_IDS`, `FIXTURE_ENROLLMENT_IDS` from `../ids.js`. (Task 2): `checkGuard(env)` from `../guard.js`; `FIXTURE_TABLES`, `RowCounts`, `countFixtureRows(prisma)` from `../counts.js`; `FIXTURES_DIR`, `loadLayers(dir)`, `runFixtures(o: RunOptions)` from `../runner.js`; `refreshAnalytics()` from `server/src/services/analytics.service.ts`.
- Produces:
  - `base.ts`: `export const seedBase: ScenarioFn`; constants `FIXTURE_USER_NAME = 'Fixture Leader'`, `FIXTURE_ORG_NAME = 'MakeReady Fixtures'`, `GROUP_NAMES`, `MEMBERS_PER_GROUP = 8`, `ALL_DAYS`, `VIDEO_SECONDS = 1200`, `PROGRAMS`, `ENROLLMENT_PLAN` (`{ index, groupIndex, program: 'days21'|'days30', startOffset }` — E1 −48, E2 −29, E3 −20, E4 −13), helpers `lessonId(programIndex, day)`, `activityId(programIndex, day, order)`, `scheduleId(enrollmentIndex, day)`. After `seedBase`, `ctx.created` holds `user`, `org`, `groups` (3), `members` (24), `groupMembers` (24, `memberId` set), `programs` (2), `lessons` (51), `activities` (153; order 2 of every lesson is `VIDEO`), `enrollments` (4), `schedules` (102), each list ordered by id.
  - `db-harness.ts`: `TEST_DB_URL: string | undefined`, `SKIP_LINE`, `interface FixturesDb { prisma: PrismaClient; run(command: 'reset' | 'seed', scenario: 'full' | 'empty'): Promise<RowCounts>; countAll(): Promise<RowCounts>; close(): Promise<void> }`, `openFixturesDb(): Promise<FixturesDb>`, `subtractCounts(all: RowCounts, fixture: RowCounts): RowCounts`

**The throwaway test database (D18) — used by Steps 2 and 4 of this task and of Task 4.** Never point these tests at `makeready_dev`. `migrate:apply`'s `dotenv` wrapper would read `server/.env` (a 1Password named pipe), so Atlas is called directly:

```bash
export FX_DB=postgresql://postgres:postgres@localhost:5434/makeready_fixtures_test
docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_fixtures_test
docker exec makeready-postgres createdb -U postgres makeready_fixtures_test
(cd server/atlas && DATABASE_URL=$FX_DB atlas migrate apply --env local)
(cd server && DATABASE_URL=$FX_DB DIRECT_URL=$FX_DB npm run db:seed)   # the system Owner role (D12) comes from the versioned seeds, not the migrations
```

and after the task's last run: `docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_fixtures_test`. Quote the vitest output in your report.

- [ ] **Step 1: Write the failing test**

`server/fixtures/__tests__/db-harness.ts`

```ts
/**
 * DB harness for the fixture tests (SPEC ui2-fixtures D18). Reads
 * FIXTURES_TEST_DATABASE_URL; absent, every DB suite is skipped and this line
 * is printed — never silently. Env is set BEFORE the Prisma client and the
 * analytics service are imported, so both talk to the throwaway database.
 */
import type { PrismaClient } from '../../src/generated/prisma/index.js'
import { FIXTURE_TABLES, type RowCounts } from '../counts.js'
import { checkGuard } from '../guard.js'

export const TEST_DB_URL = process.env.FIXTURES_TEST_DATABASE_URL
export const SKIP_LINE = 'fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL'

if (!TEST_DB_URL) console.log(SKIP_LINE)

export interface FixturesDb {
  prisma: PrismaClient
  run(command: 'reset' | 'seed', scenario: 'full' | 'empty'): Promise<RowCounts>
  countAll(): Promise<RowCounts>
  close(): Promise<void>
}

export function subtractCounts(all: RowCounts, fixture: RowCounts): RowCounts {
  const out = { ...all }
  for (const table of FIXTURE_TABLES) out[table] = all[table] - fixture[table]
  return out
}

export async function openFixturesDb(): Promise<FixturesDb> {
  const url = TEST_DB_URL
  if (!url) throw new Error(SKIP_LINE)
  if (new URL(url).pathname.replace(/^\//, '') === 'makeready_dev') {
    throw new Error('FIXTURES_TEST_DATABASE_URL must be a throwaway database, never makeready_dev')
  }
  process.env.DATABASE_URL = url
  process.env.DIRECT_URL = url
  const guard = checkGuard(process.env)
  if (!guard.ok) throw new Error(`fixtures guard refused the test database: ${guard.reason}`)

  const { PrismaClient: Client } = await import('../../src/generated/prisma/index.js')
  const { refreshAnalytics } = await import('../../src/services/analytics.service.js')
  const { FIXTURES_DIR, loadLayers, runFixtures } = await import('../runner.js')

  const prisma = new Client({ datasourceUrl: url })
  const layers = await loadLayers(FIXTURES_DIR)

  return {
    prisma,
    run: (command, scenario) =>
      runFixtures({
        command,
        scenario,
        prisma,
        layers,
        now: new Date(),
        refresh: refreshAnalytics,
        sleep: (ms) => new Promise<void>((resolve) => setTimeout(resolve, ms)),
        log: () => undefined,
      }),
    countAll: async () => ({
      users: await prisma.user.count(),
      organizations: await prisma.organization.count(),
      user_roles: await prisma.userRole.count(),
      groups: await prisma.group.count(),
      members: await prisma.member.count(),
      group_members: await prisma.groupMember.count(),
      member_organizations: await prisma.memberOrganization.count(),
      study_programs: await prisma.studyProgram.count(),
      lessons: await prisma.lesson.count(),
      lesson_activities: await prisma.lessonActivity.count(),
      enrollments: await prisma.enrollment.count(),
      lesson_schedules: await prisma.lessonSchedule.count(),
      member_lesson_progress: await prisma.memberLessonProgress.count(),
      member_video_progress: await prisma.memberVideoProgress.count(),
      membership_events: await prisma.membershipEvent.count(),
      client_events: await prisma.clientEvent.count(),
    }),
    close: () => prisma.$disconnect(),
  }
}
```

`server/fixtures/__tests__/base.db.test.ts` — §Testing (c), (e), D3, D4, D11 base, D12

```ts
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate } from '../context.js'
import { countFixtureRows } from '../counts.js'
import {
  FIXTURE_ENROLLMENT_IDS,
  FIXTURE_GROUP_IDS,
  FIXTURE_MEMBER_IDS,
  FIXTURE_ORG_ID,
  FIXTURE_USER_EMAIL,
  FIXTURE_USER_ID,
} from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb, subtractCounts } from './db-harness.js'

// A non-fixture graph the reset must never touch (§Testing c).
const SENTINEL = {
  user: '0b0b0b0b-0000-4000-8000-000000000001',
  org: '0b0b0b0b-0000-4000-8000-000000000002',
  group: '0b0b0b0b-0000-4000-8000-000000000003',
  member: '0b0b0b0b-0000-4000-8000-000000000004',
  groupMember: '0b0b0b0b-0000-4000-8000-000000000005',
  event: '0b0b0b0b-0000-4000-8000-000000000006',
}

describe.skipIf(!TEST_DB_URL)('fixtures base layer against the test database (D18)', () => {
  let db: FixturesDb

  async function removeSentinel() {
    await db.prisma.clientEvent.deleteMany({ where: { id: SENTINEL.event } })
    await db.prisma.member.deleteMany({ where: { id: SENTINEL.member } })
    await db.prisma.user.deleteMany({ where: { id: SENTINEL.user } })
  }

  beforeAll(async () => {
    db = await openFixturesDb()
    await removeSentinel()
    await db.prisma.user.create({ data: { id: SENTINEL.user, email: 'sentinel@fixtures-test.local', name: 'Sentinel' } })
    await db.prisma.organization.create({ data: { id: SENTINEL.org, name: 'Sentinel Org', ownerId: SENTINEL.user } })
    await db.prisma.group.create({
      data: { id: SENTINEL.group, name: 'Sentinel Group', creatorId: SENTINEL.user, organizationId: SENTINEL.org },
    })
    await db.prisma.member.create({ data: { id: SENTINEL.member, phoneNumber: '+15559990001' } })
    await db.prisma.groupMember.create({
      data: { id: SENTINEL.groupMember, groupId: SENTINEL.group, memberId: SENTINEL.member },
    })
    await db.prisma.clientEvent.create({
      data: {
        id: SENTINEL.event,
        eventType: 'LESSON_OPENED',
        occurredAt: new Date(),
        memberId: SENTINEL.member,
        organizationId: SENTINEL.org,
      },
    })
  }, 60_000)

  afterAll(async () => {
    if (!db) return
    await removeSentinel()
    await db.close()
  })

  it('(e) reset empty builds exactly the base world and no progress rows', async () => {
    const counts = await db.run('reset', 'empty')
    expect(counts).toEqual({
      users: 1,
      organizations: 1,
      user_roles: 1,
      groups: 3,
      members: 24,
      group_members: 24,
      member_organizations: 24,
      study_programs: 2,
      lessons: 51,
      lesson_activities: 153,
      enrollments: 4,
      lesson_schedules: 102,
      member_lesson_progress: 0,
      member_video_progress: 0,
      membership_events: 0,
      client_events: 0,
    })
  }, 120_000)

  it('builds the D3/D11/D12 identity, groups, members and programs', async () => {
    await db.run('reset', 'empty')
    const user = await db.prisma.user.findUniqueOrThrow({ where: { id: FIXTURE_USER_ID } })
    expect(user).toMatchObject({ email: FIXTURE_USER_EMAIL, name: 'Fixture Leader', googleId: null })
    const org = await db.prisma.organization.findUniqueOrThrow({ where: { id: FIXTURE_ORG_ID } })
    expect(org).toMatchObject({ name: 'MakeReady Fixtures', ownerId: FIXTURE_USER_ID })

    const role = await db.prisma.userRole.findFirstOrThrow({ where: { userId: FIXTURE_USER_ID }, include: { role: true } })
    expect(role.organizationId).toBe(FIXTURE_ORG_ID)
    expect(role.role).toMatchObject({ name: 'Owner', isSystem: true, organizationId: null })

    const groups = await db.prisma.group.findMany({ where: { id: { in: FIXTURE_GROUP_IDS } }, orderBy: { id: 'asc' } })
    expect(groups.map((g) => g.name)).toEqual(["Tuesday Men's Group", 'Young Adults', "Women's Bible Study"])

    const members = await db.prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS } } })
    for (const m of members) {
      expect(m.phoneNumber).toMatch(/^\+1555010\d{4}$/)
      expect(m.phoneVerified).toBe(true)
    }
    for (const groupId of FIXTURE_GROUP_IDS) {
      expect(await db.prisma.groupMember.count({ where: { groupId } })).toBe(8)
    }

    const programs = await db.prisma.studyProgram.findMany({ where: { organizationId: FIXTURE_ORG_ID }, orderBy: { days: 'asc' } })
    expect(programs.map((p) => p.days)).toEqual([21, 30])
    for (const p of programs) {
      expect(p.isPublished).toBe(true)
      expect(p.publishedAt).not.toBeNull()
      expect(p.creatorId).toBe(FIXTURE_USER_ID)
    }
    const videoActivities = await db.prisma.lessonActivity.count({
      where: { activityType: 'VIDEO', lesson: { studyProgram: { organizationId: FIXTURE_ORG_ID } } },
    })
    expect(videoActivities).toBe(51)
  }, 120_000)

  it('staggers E1–E4 over now−48 … now+7 (D11), every day enabled, America/Chicago', async () => {
    await db.run('reset', 'empty')
    const today = localDate(new Date())
    const windows: Array<[number, number]> = [[-48, -19], [-29, 0], [-20, 0], [-13, 7]]
    const enrollments = await db.prisma.enrollment.findMany({ where: { id: { in: FIXTURE_ENROLLMENT_IDS } }, orderBy: { id: 'asc' } })
    expect(enrollments).toHaveLength(4)
    for (const [i, enrollment] of enrollments.entries()) {
      expect(JSON.parse(enrollment.enabledDays)).toEqual(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
      expect(enrollment.timezone).toBe('America/Chicago')
      expect(enrollment.createdById).toBe(FIXTURE_USER_ID)
      const schedules = await db.prisma.lessonSchedule.findMany({ where: { enrollmentId: enrollment.id } })
      const dates = schedules.map((s) => localDate(s.scheduledDate)).sort()
      expect(dates[0]).toBe(addDays(today, windows[i][0]))
      expect(dates[dates.length - 1]).toBe(addDays(today, windows[i][1]))
      expect(new Set(dates).size).toBe(dates.length)
    }
    const covered = new Set(
      (await db.prisma.lessonSchedule.findMany({ where: { enrollmentId: { in: FIXTURE_ENROLLMENT_IDS } } })).map((s) =>
        localDate(s.scheduledDate)
      )
    )
    for (let offset = -48; offset <= 7; offset++) expect(covered.has(addDays(today, offset))).toBe(true)
  }, 120_000)

  it('(c) leaves every non-fixture row untouched', async () => {
    const before = subtractCounts(await db.countAll(), await countFixtureRows(db.prisma))
    await db.run('reset', 'full')
    await db.run('reset', 'full')
    const after = subtractCounts(await db.countAll(), await countFixtureRows(db.prisma))
    expect(after).toEqual(before)
    expect(await db.prisma.clientEvent.count({ where: { id: SENTINEL.event } })).toBe(1)
    expect(await db.prisma.groupMember.count({ where: { id: SENTINEL.groupMember } })).toBe(1)
    expect(await db.prisma.organization.count({ where: { id: SENTINEL.org } })).toBe(1)
  }, 180_000)

  it('(D4) seed refuses when the fixture user already exists', async () => {
    await db.run('reset', 'empty')
    await expect(db.run('seed', 'empty')).rejects.toThrow('already exists')
  }, 120_000)
})
```

- [ ] **Step 2: Run it and watch it fail** — create and migrate the test database (block above), then `cd server && FIXTURES_TEST_DATABASE_URL=$FX_DB DATABASE_URL=$FX_DB DIRECT_URL=$FX_DB npx vitest run fixtures/__tests__/base.db.test.ts` → FAIL, `base layer not found at …/server/fixtures/base.ts`. Also confirm the skip path: `cd server && npx vitest run fixtures/__tests__/base.db.test.ts` (no FIXTURES_TEST_DATABASE_URL) → prints `fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL`, suite skipped.

- [ ] **Step 3: Write the minimal implementation** — `server/fixtures/base.ts`

```ts
/**
 * Base layer (SPEC ui2-fixtures D3, D11, D12): the fixture owner, org, groups,
 * members, programs, enrollments and lesson schedules every screen layer
 * reads. Runs for every scenario, `empty` included. Every row has a fixed ID;
 * every date comes from ctx (D9). Every group's and program's creatorId is the
 * fixture user, so deleting that user cascades the graph (D7).
 */
import { FIXTURE_TZ, FixtureError, type ScenarioFn } from './context.js'
import {
  FIXTURE_ENROLLMENT_IDS,
  FIXTURE_GROUP_IDS,
  FIXTURE_MEMBER_IDS,
  FIXTURE_ORG_ID,
  FIXTURE_PROGRAM_IDS,
  FIXTURE_USER_EMAIL,
  FIXTURE_USER_ID,
  fixtureId,
} from './ids.js'

export const FIXTURE_USER_NAME = 'Fixture Leader'
export const FIXTURE_ORG_NAME = 'MakeReady Fixtures'
export const GROUP_NAMES = ["Tuesday Men's Group", 'Young Adults', "Women's Bible Study"] as const
export const MEMBERS_PER_GROUP = 8
export const ALL_DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const
/** Every lesson's VIDEO activity runs 20 minutes. */
export const VIDEO_SECONDS = 1200

const FIRST_NAMES = [
  'James', 'Michael', 'David', 'Daniel', 'Matthew', 'Andrew', 'Joshua', 'Nathan',
  'Emily', 'Grace', 'Hannah', 'Olivia', 'Sophia', 'Abigail', 'Chloe', 'Lydia',
  'Sarah', 'Rachel', 'Rebecca', 'Naomi', 'Ruth', 'Esther', 'Leah', 'Miriam',
]
const LAST_NAMES = [
  'Carter', 'Brooks', 'Hayes', 'Morgan', 'Reed', 'Foster', 'Bennett', 'Hughes',
  'Price', 'Coleman', 'Jenkins', 'Perry', 'Powell', 'Long', 'Patterson', 'Russell',
  'Griffin', 'Diaz', 'Myers', 'Ford', 'Hamilton', 'Graham', 'Sullivan', 'Wallace',
]

export const PROGRAMS = [
  { key: 'days21', id: FIXTURE_PROGRAM_IDS.days21, index: 1, name: 'Foundations of Faith', days: 21 },
  { key: 'days30', id: FIXTURE_PROGRAM_IDS.days30, index: 2, name: 'Walking Through John', days: 30 },
] as const

const PROGRAM_BY_KEY = { days21: PROGRAMS[0], days30: PROGRAMS[1] }

/** D11 stagger: day k of enrollment e is scheduled on today + startOffset + (k − 1). */
export const ENROLLMENT_PLAN = [
  { index: 1, groupIndex: 0, program: 'days30', startOffset: -48 }, // −48 … −19
  { index: 2, groupIndex: 1, program: 'days30', startOffset: -29 }, // −29 … 0
  { index: 3, groupIndex: 2, program: 'days21', startOffset: -20 }, // −20 … 0
  { index: 4, groupIndex: 0, program: 'days21', startOffset: -13 }, // −13 … +7
] as const

export const lessonId = (programIndex: number, day: number) => fixtureId('lesson', programIndex * 1000 + day)
export const activityId = (programIndex: number, day: number, order: number) =>
  fixtureId('activity', (programIndex * 1000 + day) * 10 + order)
export const scheduleId = (enrollmentIndex: number, day: number) => fixtureId('schedule', enrollmentIndex * 1000 + day)

const dayNumbers = (n: number) => Array.from({ length: n }, (_, i) => i + 1)

export const seedBase: ScenarioFn = async (ctx) => {
  const { prisma, created } = ctx

  // D12: the system Owner role is looked up, never created.
  const ownerRole = await prisma.role.findFirst({ where: { name: 'Owner', isSystem: true, organizationId: null } })
  if (!ownerRole) throw new FixtureError('the system Owner role is missing — run `npm run db:seed` first')

  const seededAt = ctx.daysAgo(75)
  created.user = await prisma.user.create({
    data: { id: FIXTURE_USER_ID, email: FIXTURE_USER_EMAIL, name: FIXTURE_USER_NAME, createdAt: seededAt },
  })
  created.org = await prisma.organization.create({
    data: { id: FIXTURE_ORG_ID, name: FIXTURE_ORG_NAME, ownerId: FIXTURE_USER_ID, createdAt: seededAt },
  })
  await prisma.userRole.create({
    data: {
      id: fixtureId('userRole', 1),
      userId: FIXTURE_USER_ID,
      roleId: ownerRole.id,
      organizationId: FIXTURE_ORG_ID,
      assignedAt: seededAt,
    },
  })

  await prisma.group.createMany({
    data: GROUP_NAMES.map((name, i) => ({
      id: FIXTURE_GROUP_IDS[i],
      name,
      creatorId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: seededAt,
    })),
  })
  created.groups = await prisma.group.findMany({ where: { id: { in: FIXTURE_GROUP_IDS } }, orderBy: { id: 'asc' } })

  // Members join on −62 … −51, two a day, before the first schedule (−48).
  const joinedAt = (i: number) => ctx.at(-62 + Math.floor(i / 2), 10)
  await prisma.member.createMany({
    data: FIXTURE_MEMBER_IDS.map((id, i) => ({
      id,
      phoneNumber: `+1555010${String(i + 1).padStart(4, '0')}`,
      phoneVerified: true,
      firstName: FIRST_NAMES[i],
      lastName: LAST_NAMES[i],
      createdAt: joinedAt(i),
    })),
  })
  created.members = await prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS } }, orderBy: { id: 'asc' } })
  await prisma.groupMember.createMany({
    data: FIXTURE_MEMBER_IDS.map((memberId, i) => ({
      id: fixtureId('groupMember', i + 1),
      groupId: FIXTURE_GROUP_IDS[Math.floor(i / MEMBERS_PER_GROUP)],
      memberId,
      joinedAt: joinedAt(i),
    })),
  })
  created.groupMembers = await prisma.groupMember.findMany({
    where: { memberId: { in: FIXTURE_MEMBER_IDS } },
    orderBy: { id: 'asc' },
  })
  await prisma.memberOrganization.createMany({
    data: FIXTURE_MEMBER_IDS.map((memberId, i) => ({
      id: fixtureId('memberOrganization', i + 1),
      memberId,
      organizationId: FIXTURE_ORG_ID,
      joinedAt: joinedAt(i),
    })),
  })

  await prisma.studyProgram.createMany({
    data: PROGRAMS.map((p) => ({
      id: p.id,
      name: p.name,
      days: p.days,
      creatorId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      isPublished: true,
      publishedAt: ctx.daysAgo(70),
      createdAt: seededAt,
    })),
  })
  await prisma.lesson.createMany({
    data: PROGRAMS.flatMap((p) =>
      dayNumbers(p.days).map((day) => ({
        id: lessonId(p.index, day),
        studyProgramId: p.id,
        dayNumber: day,
        title: `Day ${day}`,
        estimatedMinutes: 25,
      }))
    ),
  })
  await prisma.lessonActivity.createMany({
    data: PROGRAMS.flatMap((p) =>
      dayNumbers(p.days).flatMap((day) => [
        {
          id: activityId(p.index, day, 1),
          lessonId: lessonId(p.index, day),
          activityType: 'READ' as const,
          orderNumber: 1,
          title: 'Read',
          referenceTitle: `John ${day}`,
          readContent: `Read John ${day} slowly, twice.`,
        },
        {
          id: activityId(p.index, day, 2),
          lessonId: lessonId(p.index, day),
          activityType: 'VIDEO' as const,
          orderNumber: 2,
          title: 'Watch',
          estimatedSeconds: VIDEO_SECONDS,
        },
        {
          id: activityId(p.index, day, 3),
          lessonId: lessonId(p.index, day),
          activityType: 'USER_INPUT' as const,
          orderNumber: 3,
          title: 'Reflect',
          placeholder: 'What stood out to you today?',
        },
      ])
    ),
  })
  created.programs = await prisma.studyProgram.findMany({ where: { organizationId: FIXTURE_ORG_ID }, orderBy: { id: 'asc' } })
  created.lessons = await prisma.lesson.findMany({
    where: { studyProgramId: { in: PROGRAMS.map((p) => p.id) } },
    orderBy: { id: 'asc' },
  })
  created.activities = await prisma.lessonActivity.findMany({
    where: { lessonId: { in: created.lessons.map((l) => l.id) } },
    orderBy: { id: 'asc' },
  })

  const enabledDays = JSON.stringify(ALL_DAYS)
  await prisma.enrollment.createMany({
    data: ENROLLMENT_PLAN.map((e) => {
      const p = PROGRAM_BY_KEY[e.program]
      return {
        id: FIXTURE_ENROLLMENT_IDS[e.index - 1],
        groupId: FIXTURE_GROUP_IDS[e.groupIndex],
        studyProgramId: p.id,
        startDate: ctx.at(e.startOffset, 12),
        endDate: ctx.at(e.startOffset + p.days - 1, 12),
        enabledDays,
        smsTime: '08:00',
        timezone: FIXTURE_TZ,
        createdById: FIXTURE_USER_ID,
        createdAt: ctx.daysAgo(3 - e.startOffset),
      }
    }),
  })
  await prisma.lessonSchedule.createMany({
    data: ENROLLMENT_PLAN.flatMap((e) => {
      const p = PROGRAM_BY_KEY[e.program]
      return dayNumbers(p.days).map((day) => ({
        id: scheduleId(e.index, day),
        enrollmentId: FIXTURE_ENROLLMENT_IDS[e.index - 1],
        lessonId: lessonId(p.index, day),
        scheduledDate: ctx.at(e.startOffset + day - 1, 12),
        title: `Day ${day}`,
        estimatedMinutes: 25,
      }))
    }),
  })
  created.enrollments = await prisma.enrollment.findMany({ where: { id: { in: FIXTURE_ENROLLMENT_IDS } }, orderBy: { id: 'asc' } })
  created.schedules = await prisma.lessonSchedule.findMany({
    where: { enrollmentId: { in: FIXTURE_ENROLLMENT_IDS } },
    orderBy: { id: 'asc' },
  })
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && FIXTURES_TEST_DATABASE_URL=$FX_DB DATABASE_URL=$FX_DB DIRECT_URL=$FX_DB npx vitest run fixtures/__tests__/base.db.test.ts` → PASS (5 tests); `cd server && npx tsc --noEmit -p fixtures` → exit 0; `cd server && npx tsc --noEmit` → exit 0; then drop the test database.

- [ ] **Step 5: Commit** — `feat(ui2-fixtures): base fixture layer — owner, org, groups, members, programs, staggered enrollments`

### Task 4: The home-dashboard layer and the analytics-level tests
App: server
Phase: 2
Recipe: REFERENCE §Global constraints (server) · server/.claude/CLAUDE.md
> build-time risk (F15): Prisma may override an explicit `lastWatchedAt` on create (`@updatedAt`) — test (d) asserts every `member_video_progress.lastWatchedAt` lies before today's Chicago midnight; if it fails, STOP and report rather than patching around it.
> build-time risk (F16): the +15% (±3%) trend and ≥ 18 non-empty days depend on the curve against the D11 stagger — `dailyCompletionCounts` hits them by construction and both the unit test and test (d) settle it.

**Files:**
- Create: `server/fixtures/screens/home-dashboard.ts`
- Test: `server/fixtures/__tests__/home-dashboard.test.ts` (no database)
- Test: `server/fixtures/__tests__/home-dashboard.db.test.ts`

**Interfaces:**
- Consumes (Task 1): `FixtureContext`, `Prng`, `createPrng`, `FixtureError`, `addDays`, `localDate`, `weekdayOf`, `zonedTime` from `../context.js`; `fixtureId`, `FIXTURE_ORG_ID`, `FIXTURE_USER_ID`, `FIXTURE_MEMBER_IDS` from `../ids.js`. (Task 2): `availableScenarios(screens)`, `loadLayers(dir)`, `FIXTURES_DIR` from `../runner.js`. (Task 3): `VIDEO_SECONDS` from `../base.js`; `ctx.created.{groupMembers, lessons, activities, enrollments, schedules}`; `openFixturesDb()`, `TEST_DB_URL` from `./db-harness.js`. From `server/src/services/analytics.service.ts`: `runAnalyticsQuery(input: AnalyticsQueryInput, scope: AnalyticsScope): Promise<AnalyticsQueryResult>` and `todayInTimezone(tz: string): string`.
- Produces: `screens/home-dashboard.ts` exports `full(ctx: FixtureContext): Promise<void>` (the only scenario, D6), and the pure helpers `HISTORY_DAYS = 48`, `WINDOW_DAYS = 24`, `TREND = 1.15`, `WEEKEND_FACTOR = 0.4`, `VIDEO_TOTAL_SECONDS = 144000`, `apportion(total: number, weights: readonly number[], caps: readonly number[]): number[]`, `dailyWeight(offset: number, date: string, jitter: number): number`, `dailyCompletionCounts(today: string, rand: Prng, capacity: (offset: number) => number): Map<number, number>`.

**The throwaway test database (D18) — used by Steps 2 and 4.** Never point these tests at `makeready_dev`. `migrate:apply`'s `dotenv` wrapper would read `server/.env` (a 1Password named pipe), so Atlas is called directly:

```bash
export FX_DB=postgresql://postgres:postgres@localhost:5434/makeready_fixtures_test
docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_fixtures_test
docker exec makeready-postgres createdb -U postgres makeready_fixtures_test
(cd server/atlas && DATABASE_URL=$FX_DB atlas migrate apply --env local)
(cd server && DATABASE_URL=$FX_DB DIRECT_URL=$FX_DB npm run db:seed)   # the system Owner role (D12) comes from the versioned seeds, not the migrations
```

and after the task's last run: `docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_fixtures_test`. Quote the vitest output in your report.

- [ ] **Step 1: Write the failing tests**

`server/fixtures/__tests__/home-dashboard.test.ts` — the by-construction targets, no database

```ts
import { describe, expect, it } from 'vitest'
import { addDays, createPrng, weekdayOf } from '../context.js'
import { FIXTURES_DIR, availableScenarios, loadLayers } from '../runner.js'
import { apportion, dailyCompletionCounts } from '../screens/home-dashboard.js'

const TODAY = '2026-10-25'
// Member × schedule pairs per day under the D11 stagger (8 members per group).
const capacity = (o: number) => (o <= -30 ? 8 : o <= -21 ? 16 : o <= -19 ? 24 : o <= -14 ? 16 : 24)

function sum(counts: Map<number, number>, from: number, to: number): number {
  let total = 0
  for (let o = from; o <= to; o++) total += counts.get(o) ?? 0
  return total
}

describe('apportion', () => {
  it('splits a total exactly, at least one per slot, within caps', () => {
    const out = apportion(100, [1, 2, 3, 4], [50, 50, 50, 20])
    expect(out.reduce((a, b) => a + b, 0)).toBe(100)
    expect(out[3]).toBeLessThanOrEqual(20)
    for (const n of out) expect(n).toBeGreaterThanOrEqual(1)
  })

  it('throws when the caps cannot hold the total', () => {
    expect(() => apportion(10, [1, 1], [3, 3])).toThrow('capacity')
  })
})

describe('dailyCompletionCounts (D11, F16)', () => {
  const counts = dailyCompletionCounts(TODAY, createPrng(), capacity)

  it('covers exactly days −48 … −1, each non-empty and within capacity', () => {
    expect([...counts.keys()].sort((a, b) => a - b)).toEqual(Array.from({ length: 48 }, (_, i) => i - 48))
    for (const [o, n] of counts) {
      expect(n).toBeGreaterThanOrEqual(1)
      expect(n).toBeLessThanOrEqual(capacity(o))
    }
  })

  it('makes the last 24 days 115% (±3%) of the 24 before, with ≥ 18 non-empty days', () => {
    const current = sum(counts, -23, 0)
    const previous = sum(counts, -47, -24)
    expect(current / previous).toBeGreaterThanOrEqual(1.12)
    expect(current / previous).toBeLessThanOrEqual(1.18)
    let nonEmpty = 0
    for (let o = -23; o <= 0; o++) if ((counts.get(o) ?? 0) > 0) nonEmpty++
    expect(nonEmpty).toBeGreaterThanOrEqual(18)
  })

  it('keeps weekends near 40% of weekdays', () => {
    const weekend: number[] = []
    const weekday: number[] = []
    for (const [o, n] of counts) {
      const day = weekdayOf(addDays(TODAY, o))
      ;(day === 0 || day === 6 ? weekend : weekday).push(n)
    }
    const avg = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length
    const ratio = avg(weekend) / avg(weekday)
    expect(ratio).toBeGreaterThanOrEqual(0.3)
    expect(ratio).toBeLessThanOrEqual(0.55)
  })

  it('is identical across runs (fixed seed)', () => {
    expect(dailyCompletionCounts(TODAY, createPrng(), capacity)).toEqual(counts)
  })
})

describe('layer discovery (D2, D6)', () => {
  it('finds base plus the home-dashboard layer, which offers full only', async () => {
    const layers = await loadLayers(FIXTURES_DIR)
    expect(layers.screens.map((s) => s.name)).toEqual(['home-dashboard'])
    expect(availableScenarios(layers.screens)).toEqual(['full', 'empty'])
  })
})
```

`server/fixtures/__tests__/home-dashboard.db.test.ts` — §Testing (b), (d)

```ts
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate, zonedTime } from '../context.js'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const total = (rows: Record<string, unknown>[] | undefined, key: string) =>
  (rows ?? []).reduce((s, r) => s + Number(r[key] ?? 0), 0)

describe.skipIf(!TEST_DB_URL)('home-dashboard layer against the test database (D18)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
  }, 60_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('(b) reset full twice gives identical row counts', async () => {
    const first = await db.run('reset', 'full')
    const second = await db.run('reset', 'full')
    expect(second).toEqual(first)
    expect(first.member_lesson_progress).toBeGreaterThan(0)
    expect(first.member_video_progress).toBe(first.member_lesson_progress)
    expect(first.client_events).toBe(first.member_lesson_progress)
    expect(first.membership_events).toBe(24)
  }, 180_000)

  it('(d) Home reads ≥ 18 non-empty days, +15% (±3%), and 40 h (±2 h) of video', async () => {
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const today = todayInTimezone(TZ)
    const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }

    // Home's Overview query (DashboardActions.swift: from today−23 to today, compareToPrevious).
    const series = await runAnalyticsQuery(
      {
        metrics: ['lesson_completions'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -23), to: today },
        timezone: TZ,
        compareToPrevious: true,
      },
      scope
    )
    expect(series.rows).toHaveLength(24)
    const nonEmpty = series.rows.filter((r) => Number(r.lesson_completions) > 0).length
    expect(nonEmpty).toBeGreaterThanOrEqual(18)
    const current = total(series.rows, 'lesson_completions')
    const previous = total(series.previousRows, 'lesson_completions')
    expect(previous).toBeGreaterThan(0)
    expect(current / previous).toBeGreaterThanOrEqual(1.12)
    expect(current / previous).toBeLessThanOrEqual(1.18)

    // watch_seconds is a snapshot metric: no range (the service 400s on one), as Home queries it.
    const watch = await runAnalyticsQuery(
      { metrics: ['watch_seconds'], dimensions: [], filters: { organizationId: FIXTURE_ORG_ID }, timezone: TZ },
      scope
    )
    const seconds = Number(watch.rows[0]?.watch_seconds)
    expect(seconds).toBeGreaterThanOrEqual(144_000 - 7_200)
    expect(seconds).toBeLessThanOrEqual(144_000 + 7_200)

    // F15: the explicit lastWatchedAt survived @updatedAt — every watch is before today.
    const watched = await db.prisma.memberVideoProgress.aggregate({
      where: { memberId: { in: FIXTURE_MEMBER_IDS } },
      _max: { lastWatchedAt: true },
    })
    expect(watched._max.lastWatchedAt).not.toBeNull()
    expect(watched._max.lastWatchedAt!.getTime()).toBeLessThan(zonedTime(today, 0).getTime())

    // D11: completions, watches and opens all sit in the 07:00–21:00 Chicago band.
    const progress = await db.prisma.memberLessonProgress.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
    for (const p of progress) {
      const date = localDate(p.completedAt!)
      expect(p.completedAt!.getTime()).toBeGreaterThanOrEqual(zonedTime(date, 7).getTime())
      expect(p.completedAt!.getTime()).toBeLessThanOrEqual(zonedTime(date, 21).getTime())
      expect(p.pinnedVersionId).toBeNull()
    }
    const opens = await db.prisma.clientEvent.findMany({ where: { organizationId: FIXTURE_ORG_ID } })
    for (const e of opens) {
      expect(e.eventType).toBe('LESSON_OPENED')
      const date = localDate(e.occurredAt)
      expect(e.occurredAt.getTime()).toBeGreaterThanOrEqual(zonedTime(date, 7).getTime())
      expect(e.occurredAt.getTime()).toBeLessThanOrEqual(zonedTime(date, 21).getTime())
    }
    const joins = await db.prisma.membershipEvent.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
    expect(joins).toHaveLength(24)
    for (const j of joins) {
      expect(j.action).toBe('ADDED')
      expect(j.organizationId).toBe(FIXTURE_ORG_ID)
    }
  }, 180_000)
})
```

- [ ] **Step 2: Run them and watch them fail** — `cd server && npx vitest run fixtures/__tests__/home-dashboard.test.ts` → FAIL, `Failed to resolve import "../screens/home-dashboard.js"`. Then create and migrate the test database (the D18 block above) and `cd server && FIXTURES_TEST_DATABASE_URL=$FX_DB DATABASE_URL=$FX_DB DIRECT_URL=$FX_DB npx vitest run fixtures/__tests__/home-dashboard.db.test.ts` → FAIL, `expected 0 to be greater than 0` (no progress rows yet).

- [ ] **Step 3: Write the minimal implementation** — `server/fixtures/screens/home-dashboard.ts`

```ts
/**
 * home-dashboard layer (SPEC ui2-fixtures D1, D9, D11): fills every number
 * Home reads — Overview's 24-day completed-lessons sparkline and its trend,
 * total video time, Activity's day cards — plus membership_events and
 * client_events for Sessions / Engagement / Following, whose endpoints land
 * later. `full` only (D6).
 *
 * Targets are hit BY CONSTRUCTION: a per-day target curve (rising, weekends at
 * 40%) is rounded for the previous 24-day window, the current window's total
 * is fixed at 115% of it and apportioned exactly, and each day's count is then
 * assigned to that day's member × schedule pairs. Video seconds are apportioned
 * to exactly 40 h. Everything sits in the 07:00–21:00 America/Chicago band.
 */
import type { LessonSchedule } from '../../src/generated/prisma/index.js'
import { VIDEO_SECONDS } from '../base.js'
import {
  type FixtureContext,
  FixtureError,
  type Prng,
  addDays,
  localDate,
  weekdayOf,
  zonedTime,
} from '../context.js'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

/** Completions on days −48 … −1 (today stays empty: nothing completes in the future). */
export const HISTORY_DAYS = 48
/** Home's window: today−23 … today, compared with the 24 days before. */
export const WINDOW_DAYS = 24
export const TREND = 1.15
export const WEEKEND_FACTOR = 0.4
export const VIDEO_TOTAL_SECONDS = 40 * 3600
const BAND_START_HOUR = 7

/** Largest-remainder apportionment of `total`: at least one per slot (cap permitting), never above its cap. */
export function apportion(total: number, weights: readonly number[], caps: readonly number[]): number[] {
  const out = caps.map((cap) => Math.min(1, cap))
  let remaining = total - out.reduce((s, n) => s + n, 0)
  if (remaining < 0) throw new FixtureError(`apportion: ${total} is less than one per slot`)
  while (remaining > 0) {
    const open = out.map((_, i) => i).filter((i) => out[i] < caps[i])
    if (open.length === 0) throw new FixtureError(`apportion: capacity exhausted with ${remaining} left`)
    const weightSum = open.reduce((s, i) => s + weights[i], 0)
    const shares = open.map((i) => ({
      i,
      exact: weightSum > 0 ? (remaining * weights[i]) / weightSum : remaining / open.length,
    }))
    let given = 0
    for (const s of shares) {
      const add = Math.min(Math.floor(s.exact), caps[s.i] - out[s.i])
      out[s.i] += add
      given += add
    }
    let left = remaining - given
    const byRemainder = shares
      .slice()
      .sort((a, b) => b.exact - Math.floor(b.exact) - (a.exact - Math.floor(a.exact)) || a.i - b.i)
    for (const s of byRemainder) {
      if (left === 0) break
      if (out[s.i] < caps[s.i]) {
        out[s.i] += 1
        left -= 1
      }
    }
    remaining = left
  }
  return out
}

/** The target curve: 4 → 5.75 completions a weekday across the 48 days, weekends at 40%, ±8% jitter. */
export function dailyWeight(offset: number, date: string, jitter: number): number {
  const t = (offset + HISTORY_DAYS) / (HISTORY_DAYS - 1)
  const base = 4 + 1.75 * t
  const day = weekdayOf(date)
  const weekend = day === 0 || day === 6
  return base * (weekend ? WEEKEND_FACTOR : 1) * (0.92 + 0.16 * jitter)
}

/** Per-day completion counts for offsets −48 … −1; the current window totals exactly round(115% × previous). */
export function dailyCompletionCounts(
  today: string,
  rand: Prng,
  capacity: (offset: number) => number
): Map<number, number> {
  const weights = new Map<number, number>()
  for (let o = -HISTORY_DAYS; o <= -1; o++) weights.set(o, dailyWeight(o, addDays(today, o), rand.next()))

  const counts = new Map<number, number>()
  const currentStart = -(WINDOW_DAYS - 1) // −23
  for (let o = -HISTORY_DAYS; o < currentStart; o++) {
    counts.set(o, Math.min(capacity(o), Math.max(1, Math.round(weights.get(o) ?? 0))))
  }
  let previousTotal = 0
  for (let o = -(2 * WINDOW_DAYS - 1); o <= -WINDOW_DAYS; o++) previousTotal += counts.get(o) ?? 0 // −47 … −24

  const current: number[] = []
  for (let o = currentStart; o <= -1; o++) current.push(o)
  const split = apportion(
    Math.round(previousTotal * TREND),
    current.map((o) => weights.get(o) ?? 0),
    current.map(capacity)
  )
  current.forEach((o, i) => counts.set(o, split[i]))
  return counts
}

interface Pair {
  memberId: string
  groupId: string
  enrollmentId: string
  studyProgramId: string
  schedule: LessonSchedule
}

interface Completion {
  pair: Pair
  date: string
  openedHour: number
  doneHour: number
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma, created } = ctx

  const enrollmentById = new Map(created.enrollments.map((e) => [e.id, e]))
  const membersByGroup = new Map<string, string[]>()
  for (const gm of created.groupMembers) {
    if (!gm.memberId) continue
    const list = membersByGroup.get(gm.groupId) ?? []
    list.push(gm.memberId)
    membersByGroup.set(gm.groupId, list)
  }

  // Every member × schedule pair, keyed by the schedule's Chicago date.
  const pairsByDate = new Map<string, Pair[]>()
  for (const schedule of created.schedules) {
    const enrollment = enrollmentById.get(schedule.enrollmentId)
    if (!enrollment) throw new FixtureError(`schedule ${schedule.id} has no base enrollment`)
    const date = localDate(schedule.scheduledDate)
    const list = pairsByDate.get(date) ?? []
    for (const memberId of membersByGroup.get(enrollment.groupId) ?? []) {
      list.push({
        memberId,
        groupId: enrollment.groupId,
        enrollmentId: enrollment.id,
        studyProgramId: enrollment.studyProgramId,
        schedule,
      })
    }
    pairsByDate.set(date, list)
  }
  const pairsOn = (offset: number) => pairsByDate.get(ctx.dateOf(offset)) ?? []

  const counts = dailyCompletionCounts(ctx.today, ctx.rand, (o) => pairsOn(o).length)

  const completions: Completion[] = []
  for (let offset = -HISTORY_DAYS; offset <= -1; offset++) {
    const chosen = ctx.rand.shuffle(pairsOn(offset)).slice(0, counts.get(offset) ?? 0)
    for (const pair of chosen) {
      const openedHour = BAND_START_HOUR + 13 * ctx.rand.next() // 07:00 … 20:00
      const doneHour = openedHour + 0.25 + 0.25 * ctx.rand.next() // ≤ 20:30
      completions.push({ pair, date: ctx.dateOf(offset), openedHour, doneHour })
    }
  }

  const watchWeights = completions.map(() => 0.7 + 0.3 * ctx.rand.next())
  const watched = apportion(
    VIDEO_TOTAL_SECONDS,
    watchWeights,
    completions.map(() => VIDEO_SECONDS)
  )

  const lessonById = new Map(created.lessons.map((l) => [l.id, l]))
  const videoActivityByLesson = new Map(
    created.activities.filter((a) => a.activityType === 'VIDEO').map((a) => [a.lessonId, a.id])
  )

  await prisma.memberLessonProgress.createMany({
    data: completions.map((c, i) => ({
      id: fixtureId('lessonProgress', i + 1),
      memberId: c.pair.memberId,
      lessonScheduleId: c.pair.schedule.id,
      startedAt: zonedTime(c.date, c.openedHour),
      completedAt: zonedTime(c.date, c.doneHour),
      lastUpdatedAt: zonedTime(c.date, c.doneHour),
    })),
  })

  await prisma.memberVideoProgress.createMany({
    data: completions.map((c, i) => {
      const lessonId = c.pair.schedule.lessonId
      const lessonActivityId = lessonId ? videoActivityByLesson.get(lessonId) : undefined
      if (!lessonActivityId) throw new FixtureError(`schedule ${c.pair.schedule.id} has no VIDEO activity`)
      return {
        id: fixtureId('videoProgress', i + 1),
        memberId: c.pair.memberId,
        lessonScheduleId: c.pair.schedule.id,
        lessonActivityId,
        watchedSeconds: watched[i],
        totalDuration: VIDEO_SECONDS,
        watchPercentage: Math.round((watched[i] / VIDEO_SECONDS) * 1000) / 10,
        startedAt: zonedTime(c.date, c.openedHour + 0.05),
        lastWatchedAt: zonedTime(c.date, c.openedHour + 0.25),
        completedAt: null,
      }
    }),
  })

  await prisma.clientEvent.createMany({
    data: completions.map((c, i) => {
      const lesson = c.pair.schedule.lessonId ? lessonById.get(c.pair.schedule.lessonId) : undefined
      const occurredAt = zonedTime(c.date, c.openedHour)
      return {
        id: fixtureId('clientEvent', i + 1),
        eventType: 'LESSON_OPENED',
        occurredAt,
        receivedAt: occurredAt,
        memberId: c.pair.memberId,
        organizationId: FIXTURE_ORG_ID,
        groupId: c.pair.groupId,
        enrollmentId: c.pair.enrollmentId,
        studyProgramId: c.pair.studyProgramId,
        lessonScheduleId: c.pair.schedule.id,
        lessonId: c.pair.schedule.lessonId,
        dayNumber: lesson?.dayNumber ?? null,
        scheduledDate: c.pair.schedule.scheduledDate,
      }
    }),
  })

  await prisma.membershipEvent.createMany({
    data: created.groupMembers.map((gm, i) => {
      if (!gm.memberId) throw new FixtureError(`group member ${gm.id} has no member`)
      return {
        id: fixtureId('membershipEvent', i + 1),
        memberId: gm.memberId,
        groupId: gm.groupId,
        organizationId: FIXTURE_ORG_ID,
        action: 'ADDED' as const,
        actorId: FIXTURE_USER_ID,
        actorType: 'user',
        createdAt: gm.joinedAt,
      }
    }),
  })
}
```

- [ ] **Step 4: Run them and watch them pass** — `cd server && npx vitest run fixtures/__tests__/home-dashboard.test.ts` → PASS (7 tests); `cd server && FIXTURES_TEST_DATABASE_URL=$FX_DB DATABASE_URL=$FX_DB DIRECT_URL=$FX_DB npx vitest run fixtures` → PASS (every fixtures test file, the DB suites included); `cd server && npx tsc --noEmit -p fixtures` → exit 0; `cd server && npx tsc --noEmit` → exit 0; `cd server && npm run test:run` → the fixtures DB suites print `fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL` and skip, everything else as before. Drop the test database.

- [ ] **Step 5: Commit** — `feat(ui2-fixtures): home-dashboard fixture layer — 48 days of completions, +15% trend, 40 h of video`

### Task 5: Authoring guide, the builder house rule, and the contract freeze
App: server
Phase: 2
Recipe: REFERENCE §Global constraints (server) · server/.claude/CLAUDE.md
> build-time risk (F18): the agent walk env runs the server natively on :3110 against `makeready_walk`, so D5's walk-readiness line needs a host form under `agent_walk.env` beside the dev-env `docker exec` form — write both.

**Files:**
- Create: `server/fixtures/README.md`
- Modify: `.claude/builder.md` (§Quality gates › server — fast; §Walk readiness; §House rules)
- Modify: `docs/features/ui2-fixtures/MANIFEST.md` (via `advance.mjs` only — never by hand)

**Interfaces:**
- Consumes: the CLI and npm scripts (Task 2: `fixtures:reset`, `fixtures:seed`, scenarios `full`/`empty`, exit 1 cases); `FixtureContext` (Task 1); `seedBase` and `ctx.created` (Task 3); `screens/home-dashboard.ts` (Task 4).
- Produces: the D5 house rule and walk-readiness lines every later UI 2.0 feature is audited against; the D15 authoring guide; `contract: frozen <date>` on the manifest.

- [ ] **Step 1: Write the failing check**

```bash
grep -q 'fixtures: *docker exec makeready-server npm run fixtures:reset' .claude/builder.md \
  && grep -q 'fixtures_agent_walk:' .claude/builder.md \
  && grep -q 'server/fixtures/screens/<screen-id>.ts' .claude/builder.md \
  && grep -q 'tsc --noEmit -p fixtures' .claude/builder.md \
  && test -f server/fixtures/README.md \
  && grep -q 'export async function full' server/fixtures/README.md; echo "exit $?"
```

- [ ] **Step 2: Run it and watch it fail** — run the check from the repo root → `exit 1`

- [ ] **Step 3: Write the minimal implementation**

`server/fixtures/README.md` (D15):

````markdown
# Local fixtures

A resettable fixture world for walking UI 2.0 screens locally (SPEC:
`docs/features/ui2-fixtures/SPEC.md`). One org, **MakeReady Fixtures**, owned by
**Fixture Leader** (`fixtures@makeready.local`). Your own local org and data are never read
or touched: reset deletes only rows under the fixed IDs below.

## Run it

```bash
docker exec makeready-server npm run fixtures:reset            # wipe + seed, scenario full
docker exec makeready-server npm run fixtures:reset -- empty   # base world only, Home zeroed
docker exec makeready-server npm run fixtures:seed             # seed only; fails if the fixture user exists
```

From the host (the agent walk env does this): `cd server && NODE_ENV=development
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/<db> DIRECT_URL=<same> npm run fixtures:reset`.

The container mounts `server/fixtures/` and `server/package.json` (root `docker-compose.yml`).
After this feature first lands, run `docker compose up -d --build server` once; after that, layer
edits need no restart. A change to `package.json` dependencies still needs that rebuild.

It refuses (exit 1) unless `NODE_ENV` is `development` or `test` **and** `DATABASE_URL` (and
`DIRECT_URL`, when set) points at `postgres`, `localhost` or `127.0.0.1`. It also exits 1 on an
unknown scenario (listing the available ones), when the fixture user already exists under
`fixtures:seed`, and when the analytics refresh never ran. On success it prints row counts per table.

Then, in an iPhone dev build on Local: Profile → Local identity → **Fixtures**.

## Scenarios

`full` (default) runs `base.ts` and every screen layer's `full`. `empty` runs `base.ts` only. A
screen adds `sparse` / `extreme` exports when its spec lists those states; the runner offers a
scenario as soon as one layer implements it.

## Layers

`index.ts` → `base.ts` → every file in `screens/`, in filename order, all sharing one
`FixtureContext`. A screen layer **reads** base entities from `ctx.created` and must not create
orgs, users or groups of its own. Every row it creates takes a fixed ID.

## FixtureContext

| Member | What it is |
|---|---|
| `ctx.now` | the run's `Date`; every timestamp derives from it |
| `ctx.today` | `now`'s America/Chicago date, `YYYY-MM-DD` |
| `ctx.prisma` | the generated Prisma client |
| `ctx.ids` | the base fixed IDs (`user`, `org`, `groups`, `members`, `programs`, `enrollments`) |
| `ctx.rand` | seeded PRNG — `next()`, `int(min, max)`, `shuffle(items)`; same sequence every reset |
| `ctx.created` | what base made: `user`, `org`, `groups`, `members`, `groupMembers`, `programs`, `lessons`, `activities`, `enrollments`, `schedules` |
| `ctx.daysAgo(n)` | Chicago noon `n` days ago (negative = future) |
| `ctx.atLocalHour(date, h)` | wall-clock hour `h` (fractional ok) on `date`'s Chicago day |
| `ctx.dateOf(offset)` | Chicago date `offset` days from today |
| `ctx.at(offset, h)` | wall-clock hour `h` on that day |

**Dates come from `ctx.now`, never literals** — literal dates age out of every window. Put
activity in the 07:00–21:00 Chicago band so it lands on the same calendar day on any US device.

## Fixed IDs

`fixtureId(kind, n)` in `ids.ts` → `f1f1f1f1-<kind>-4000-8000-<n as 12 hex>`. Kinds: `0001` user,
`0002` org, `0003` groups, `0004` members, `0005` programs, `0006` lessons, `0007` activities,
`0008` enrollments, `0009` schedules, `000a` lesson progress, `000b` video progress, `000c`
membership events, `000d` client events, `000e` user roles, `000f` group members, `0010` member
orgs. A new kind gets the next free code. Rows that hang off a fixture member, group, program or
the fixture user are deleted by reset's cascade; anything else needs a line in `wipe.ts`.

## A new screen layer

Every feature that wires a UI 2.0 screen into the iPhone app adds `screens/<screen-id>.ts` (the id
as in `docs/ui2/screens/`), whose `full` makes every section it wires non-empty:

```ts
/** <screen-id> layer: what this screen reads, and which section each block fills. */
import type { FixtureContext } from '../context.js'
import { FIXTURE_ORG_ID, fixtureId } from '../ids.js'

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma, created } = ctx
  // Read base entities from ctx.created; never create orgs, users or groups (D2).
  const members = created.members.slice(0, 5)
  // One fixed-ID row per thing the screen renders, dated from ctx — never a literal date.
  await prisma.clientEvent.createMany({
    data: members.map((member, i) => ({
      id: fixtureId('clientEvent', 100_000 + i), // clear of other layers' n ranges, or add a kind
      eventType: 'LESSON_OPENED',
      occurredAt: ctx.at(-(i + 1), 9),
      memberId: member.id,
      organizationId: FIXTURE_ORG_ID,
    })),
  })
}
// A screen whose spec lists sparse / extreme states also exports `sparse` / `extreme`.
```

Run `cd server && npx tsc --noEmit -p fixtures` and `npm run fixtures:reset`; add a test under
`__tests__/` for the numbers the screen's spec promises.
````

`.claude/builder.md` — four edits:

1. §Quality gates › `### server — fast`: directly after the line `cd server && npx tsc --noEmit          # typecheck; needs \`npx prisma generate\` on a clean checkout` add

```
cd server && npx tsc --noEmit -p fixtures   # typechecks server/fixtures/ (its own tsconfig — ui2-fixtures D17)
```

2. §Walk readiness: in the fenced block, directly after the `smoke:` line add

```
fixtures:   docker exec makeready-server npm run fixtures:reset   # the dev env, before every walk (ui2-fixtures D5)
fixtures_agent_walk: cd server && env NODE_ENV=development DATABASE_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" DIRECT_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" npm run fixtures:reset   # the agent walk env: its server is a native process, so the host form (F18)
```

3. §Walk readiness: after the existing bullet list add the bullet

```
- Run `fixtures:` before every walk of a UI 2.0 screen; under `--agent-walk` run `fixtures_agent_walk:` instead, after the walk env's `reset`. Then sign in as the Fixtures identity (iPhone dev build on Local → Profile → Local identity).
```

4. §House rules: after the `**capture** — …` paragraph add

```
**fixtures** — a feature that wires a UI 2.0 screen into the iPhone app adds
`server/fixtures/screens/<screen-id>.ts` (the screen id as in `docs/ui2/screens/`), whose `full`
scenario makes every section the feature wires non-empty; the audit flags a feature that wires a
screen without one. Layers read base entities and never create orgs, users or groups; dates come
from `ctx.now`. Guide: `server/fixtures/README.md`.
```

- [ ] **Step 4: Run it and watch it pass** — the Step 1 check → `exit 0`; `cd server && npx tsc --noEmit -p fixtures` → exit 0

- [ ] **Step 5: Freeze the contract** — the server phase is complete, so SPEC §Contract freezes: `node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/4.14.7/scripts/advance.mjs docs/features/ui2-fixtures --set "contract=frozen $(date +%F)" --no-commit` → `docs/features/ui2-fixtures/MANIFEST.md` shows `contract: frozen <today>`

- [ ] **Step 6: Commit** — stage `server/fixtures/README.md`, `.claude/builder.md` and `docs/features/ui2-fixtures/MANIFEST.md` together: `docs(ui2-fixtures): fixtures authoring guide, house rule and walk-readiness lines; contract frozen`

### Task 6: DevLoginIdentity, identity-aware dev-login and fixturesNotSeeded
App: iphone
Phase: 3
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/Configuration.swift` (append `DevLoginIdentity` after `AppConfiguration`)
- Modify: `iphone/MakeReady/AuthManager.swift:27-46` (AuthError), `:50-67` (AuthIO), `:127-145` (devLoginEmail → selected identity), `:153-170` (resolveLoginEnvironment), `:464-470` (devLogin non-200), `:523-536` (signInToReachableLocal)
- Modify: `iphone/MakeReady/UI2/Containers/Auth/LoginOutcome.swift`
- Modify: `iphone/MakeReady/Pages/Profile/ProfilePage.swift:390` (legacy caller of the now-throwing `signInToReachableLocal`)
- Test: `iphone/MakeReadyCaptureTests/AuthManagerLaunchTests.swift`, `iphone/MakeReadyCaptureTests/LoginOutcomeTests.swift` (existing files — new test files would need pbxproj entries)

**Interfaces:**
- Consumes: `POST /auth/dev-login` per SPEC §Contract (frozen): 200 `{ success, user, sessionCookie }`; 404 `{"success":false,"error":"User not found"}` when the fixture user is not seeded; 404 `{"error":"Not found"}` when the server is not in development. `LocalPortHealer.Outcome`, `LocalPortHealer.heal()`.
- Produces:
  - `enum DevLoginIdentity: String, CaseIterable { case you, fixtures }` with `var email: String` (`luke@lukekeith.com` / `fixtures@makeready.local`), `var title: String` (`You` / `Fixtures`), `static var current: DevLoginIdentity { get set }` (UserDefaults `devLoginIdentity`, default `.you`)
  - `AuthError.fixturesNotSeeded` (errorDescription = the D14 string)
  - `AuthIO.heal: () async -> LocalPortHealer.Outcome` (defaulted to `LocalPortHealer.heal()`; memberwise init unchanged for existing callers)
  - `AuthManager.devLoginAsSelectedIdentity() async throws` (@MainActor), `static AuthManager.devLoginFailure(status: Int, body: Data, email: String) -> Error`, `AuthManager.signInToReachableLocal() async throws -> Bool` (throws only `fixturesNotSeeded`; other failures return `false`)
  - `LoginOutcome.message(for: AuthError.fixturesNotSeeded)` = `"Fixtures not seeded — run npm run fixtures:reset in the server container."`

- [ ] **Step 1: Write the failing tests**

`iphone/MakeReadyCaptureTests/LoginOutcomeTests.swift` — add inside `LoginOutcomeTests`:

```swift
    func testFixturesNotSeeded() {
        XCTAssertEqual(LoginOutcome.message(for: AuthError.fixturesNotSeeded),
                       "Fixtures not seeded — run npm run fixtures:reset in the server container.")
        XCTAssertEqual(AuthError.fixturesNotSeeded.errorDescription,
                       "Fixtures not seeded — run npm run fixtures:reset in the server container.")
    }
```

`iphone/MakeReadyCaptureTests/AuthManagerLaunchTests.swift` — replace the stored properties, `setUp`, `tearDown` and `io()` with:

```swift
    private let userKey = "makeready_current_user"
    private var savedUser: Data?
    private var savedIdentity: String?
    private var savedEnvironment: String?
    private var credential: String?
    private var responses: [String: Result<(Int, String), Error>] = [:]
    private var sentBodies: [String: [Data]] = [:]
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        savedUser = UserDefaults.standard.data(forKey: userKey)
        savedIdentity = UserDefaults.standard.string(forKey: "devLoginIdentity")
        savedEnvironment = UserDefaults.standard.string(forKey: "selectedEnvironment")
        StatePersistence.shared.clear()
        AppState.shared.clearAllData()
        api = StubAPIClient()
        credential = nil
        responses = [:]
        sentBodies = [:]
    }

    override func tearDown() {
        if let savedUser { UserDefaults.standard.set(savedUser, forKey: userKey) } else { UserDefaults.standard.removeObject(forKey: userKey) }
        restore(savedIdentity, forKey: "devLoginIdentity")
        restore(savedEnvironment, forKey: "selectedEnvironment")
        AppState.shared.clearAllData()
        super.tearDown()
    }

    private func restore(_ value: String?, forKey key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
    }

    private func io() -> AuthIO {
        AuthIO(
            send: { [unowned self] request in
                let path = request.url?.path ?? ""
                if let body = request.httpBody { self.sentBodies[path, default: []].append(body) }
                switch self.responses[path] ?? .success((404, "{}")) {
                case .failure(let error): throw error
                case .success(let (status, body)):
                    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                    return (Data(body.utf8), response)
                }
            },
            api: api,
            credential: { [unowned self] in self.credential },
            storeCredential: { [unowned self] in self.credential = $0 },
            clearCredential: { [unowned self] in self.credential = nil },
            heal: { .healthy(3010) }
        )
    }

    /// The `email` of every `/auth/dev-login` body sent, in order.
    private func devLoginEmails() -> [String] {
        (sentBodies["/auth/dev-login"] ?? []).compactMap { body in
            (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["email"] as? String
        }
    }
```

and append these tests at the end of the class:

```swift
    // MARK: - ui2-fixtures D13/D14: the Local dev-login identity

    func testDevLoginIdentityDefaultsToYouAndPersists() {
        UserDefaults.standard.removeObject(forKey: "devLoginIdentity")
        XCTAssertEqual(DevLoginIdentity.current, .you)
        DevLoginIdentity.current = .fixtures
        XCTAssertEqual(UserDefaults.standard.string(forKey: "devLoginIdentity"), "fixtures")
        XCTAssertEqual(DevLoginIdentity.current, .fixtures)
        XCTAssertEqual(DevLoginIdentity.you.email, "luke@lukekeith.com")
        XCTAssertEqual(DevLoginIdentity.fixtures.email, "fixtures@makeready.local")
        XCTAssertEqual(DevLoginIdentity.allCases.map(\.title), ["You", "Fixtures"])
    }

    func testSignInToReachableLocalDevLogsInAsTheSelectedIdentity() async throws {
        stubDevLogin()
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)
        for identity in DevLoginIdentity.allCases {
            DevLoginIdentity.current = identity
            credential = nil
            let auth = AuthManager(io: io())
            let signedIn = try await auth.signInToReachableLocal()
            XCTAssertTrue(signedIn)
        }
        XCTAssertEqual(devLoginEmails(), ["luke@lukekeith.com", "fixtures@makeready.local"])
    }

    func testSignInDevLogsInAsTheSelectedIdentity() async throws {
        try XCTSkipUnless(AppConfiguration.devMode, "needs the DEV_MODE=YES host build")
        AppConfiguration.selectedEnvironment = .local
        stubDevLogin()
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)
        DevLoginIdentity.current = .fixtures
        let auth = AuthManager(io: io())
        try await auth.signIn()
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(devLoginEmails(), ["fixtures@makeready.local"])
        XCTAssertEqual(AppConfiguration.selectedEnvironment, .local, "a healthy Local must not fall back to Production")
    }

    func testUserNotFoundForFixturesThrowsFixturesNotSeeded() async {
        responses["/auth/dev-login"] = .success((404, #"{"success":false,"error":"User not found"}"#))
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: DevLoginIdentity.fixtures.email)
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(credential)
    }

    func testServerNotInDevelopmentKeepsTodaysError() async {
        responses["/auth/dev-login"] = .success((404, #"{"error":"Not found"}"#))
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: DevLoginIdentity.fixtures.email)
            XCTFail("expected a URLError")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .userAuthenticationRequired)
        }
    }

    func testUserNotFoundForYouKeepsTodaysError() async {
        responses["/auth/dev-login"] = .success((404, #"{"success":false,"error":"User not found"}"#))
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: DevLoginIdentity.you.email)
            XCTFail("expected a URLError")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .userAuthenticationRequired)
        }
    }

    func testSignInToReachableLocalLetsFixturesNotSeededThrough() async {
        DevLoginIdentity.current = .fixtures
        responses["/auth/dev-login"] = .success((404, #"{"success":false,"error":"User not found"}"#))
        let auth = AuthManager(io: io())
        do {
            _ = try await auth.signInToReachableLocal()
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testSignInToReachableLocalReturnsFalseOnOtherFailures() async throws {
        DevLoginIdentity.current = .you
        responses["/auth/dev-login"] = .success((500, #"{"success":false,"error":"Login failed"}"#))
        let auth = AuthManager(io: io())
        let signedIn = try await auth.signInToReachableLocal()
        XCTAssertFalse(signedIn)
    }
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` (repo root) → FAIL to compile: `cannot find 'DevLoginIdentity' in scope`, `extra argument 'heal' in call`, `type 'AuthError' has no member 'fixturesNotSeeded'`

- [ ] **Step 3: Write the minimal implementation**

`iphone/MakeReady/Configuration.swift` — append after the closing brace of `struct AppConfiguration`:

```swift

// MARK: - Local dev-login identity (ui2-fixtures D13)

/// Who a dev build signs in as on Local: the owner's own account, or the seeded fixture
/// owner (`npm run fixtures:reset` in the server container). Persisted in UserDefaults.
/// Only reachable when DEV_MODE is YES (Local is unreachable otherwise).
enum DevLoginIdentity: String, CaseIterable {
    case you
    case fixtures

    var email: String {
        switch self {
        case .you: return "luke@lukekeith.com"
        case .fixtures: return "fixtures@makeready.local"
        }
    }

    var title: String {
        switch self {
        case .you: return "You"
        case .fixtures: return "Fixtures"
        }
    }

    private static let key = "devLoginIdentity"

    static var current: DevLoginIdentity {
        get { UserDefaults.standard.string(forKey: key).flatMap(DevLoginIdentity.init(rawValue:)) ?? .you }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
```

`iphone/MakeReady/AuthManager.swift` — `AuthError` becomes:

```swift
/// Authentication-flow errors surfaced to the user.
///
/// `localServerUnreachable` is thrown by an *explicit* switch to Local that fails;
/// `leaderAccessDenied` by the dev-login leader gate (SPEC D7); `fixturesNotSeeded` by a
/// Local dev-login as the Fixtures identity before `fixtures:reset` ran (ui2-fixtures D14).
enum AuthError: LocalizedError {
    /// The selected Local dev server didn't answer at the configured host/port.
    case localServerUnreachable(host: String, port: String)
    /// The account signed in but is not a leader (SPEC D7).
    case leaderAccessDenied
    /// The Fixtures dev identity has no user on the local server yet (ui2-fixtures D14).
    case fixturesNotSeeded

    var errorDescription: String? {
        switch self {
        case let .localServerUnreachable(host, port):
            return "Can't reach the local server at \(host):\(port). Check the Server IP in your profile."
        case .leaderAccessDenied:
            return "This account doesn't have leader access."
        case .fixturesNotSeeded:
            return "Fixtures not seeded — run npm run fixtures:reset in the server container."
        }
    }
}
```

`AuthIO` — add the healer seam as its last stored property (defaulted, so `.live` and existing callers compile unchanged):

```swift
    var clearCredential: () -> Void
    /// Probes (and heals) the Local API port before a Local login; stubbed in tests.
    var heal: () async -> LocalPortHealer.Outcome = { await LocalPortHealer.heal() }
```

Replace the `devLoginEmail` constant and `signIn()`'s Local branch:

```swift
    // MARK: - Login Entry Point

    /// ui2-fixtures D13: both Local dev-login callers sign in as the selected dev identity.
    @MainActor
    func devLoginAsSelectedIdentity() async throws {
        try await devLogin(email: DevLoginIdentity.current.email)
    }
```

```swift
        if AppConfiguration.isLocalDevelopment {
            try await devLoginAsSelectedIdentity()
        } else {
            try await signInWithGoogle()
        }
```

In `resolveLoginEnvironment()` replace `switch await LocalPortHealer.heal() {` with `switch await io.heal() {`.

In `devLogin(email:)` replace the non-200 guard with:

```swift
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("❌ Dev login failed: HTTP \(statusCode)")
            throw Self.devLoginFailure(status: statusCode, body: data, email: email)
        }
```

and add, directly after `devLogin(email:)`:

```swift
    /// ui2-fixtures D14 / SPEC §Contract: both dev-login 404s look alike, so the body decides.
    /// `User not found` for the Fixtures identity means `fixtures:reset` never ran; a 404
    /// `Not found` (server not in development) and every other failure keep today's error.
    static func devLoginFailure(status: Int, body: Data, email: String) -> Error {
        if status == 404, email == DevLoginIdentity.fixtures.email,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           json["error"] as? String == "User not found" {
            return AuthError.fixturesNotSeeded
        }
        return URLError(.userAuthenticationRequired)
    }
```

`signInToReachableLocal()` becomes:

```swift
    /// Silent, non-interactive sign-in for a **reachable** Local server. Local
    /// uses passwordless dev-login, so this brings the user into the app
    /// without the login screen: it reuses a still-valid Local session, or
    /// dev-logs-in fresh as the selected dev identity. Returns whether the user
    /// ended up authenticated.
    ///
    /// Throws only `AuthError.fixturesNotSeeded` (ui2-fixtures D14), so the caller can say
    /// so instead of "can't reach the local server". Any other failure returns `false`
    /// and the caller recovers (rolls the environment switch back and re-validates).
    @MainActor
    func signInToReachableLocal() async throws -> Bool {
        // Reuse a still-valid Local session if one exists.
        if hasSessionCookie {
            await checkAuthStatus()
            if isAuthenticated { return true }
            // Stale/expired Local session — fall through to a fresh dev-login.
        }
        do {
            try await devLoginAsSelectedIdentity()
            return true
        } catch AuthError.fixturesNotSeeded {
            throw AuthError.fixturesNotSeeded
        } catch {
            Log.auth.error("auto dev-login on switch failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
```

`iphone/MakeReady/UI2/Containers/Auth/LoginOutcome.swift` — `message(for:)` becomes:

```swift
    static func message(for error: Error) -> String? {
        if case AuthError.leaderAccessDenied = error { return "This account doesn't have leader access." }
        // ui2-fixtures D14: the likeliest first-run failure, with what to do about it.
        if case AuthError.fixturesNotSeeded = error {
            return "Fixtures not seeded — run npm run fixtures:reset in the server container."
        }
        let ns = error as NSError
        if ns.domain == ASWebAuthenticationSessionErrorDomain,
           ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return nil }
        return "Authentication failed"
    }
```

`iphone/MakeReady/Pages/Profile/ProfilePage.swift:390` — the legacy page keeps today's behaviour (any failure → its unreachable message):

```swift
            if reachable, (try? await authManager.signInToReachableLocal()) == true {
```

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test` → BUILD + TEST SUCCEEDED (the new `AuthManagerLaunchTests` and `LoginOutcomeTests` cases pass); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Stage, do NOT commit** — `git add iphone/MakeReady/Configuration.swift iphone/MakeReady/AuthManager.swift iphone/MakeReady/UI2/Containers/Auth/LoginOutcome.swift iphone/MakeReady/Pages/Profile/ProfilePage.swift iphone/MakeReadyCaptureTests/AuthManagerLaunchTests.swift iphone/MakeReadyCaptureTests/LoginOutcomeTests.swift` and STOP: the iPhone commit is the human's (commit: manual). Proposed message: `feat(ui2-fixtures): Local dev-login identity and fixturesNotSeeded`

### Task 7: switchIdentity, the Profile identity picker and the Login notice
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md (Actions pattern) · /ios-error-surface
> build-time risk (F17): every identity switch runs `signOut()`, which calls `/auth/logout` and removes the push token, and `StatePersistence`'s debounced save could rewrite the old identity's snapshot after `clear()` — the failure test asserts no snapshot exists 0.8 s after the switch (past the 0.5 s debounce).

**Files:**
- Modify: `iphone/MakeReady/State/Actions/EnvironmentActions.swift` (injectable healer, `switchTo(.local)` lets `fixturesNotSeeded` through, new `switchIdentity`)
- Modify: `iphone/MakeReady/AuthManager.swift` (add `loginNotice` after `isAuthenticated`)
- Modify: `iphone/MakeReady/UI2/Containers/Auth/LoginContainer.swift` (show and clear `loginNotice`)
- Modify: `iphone/MakeReady/UI2/Containers/Profile/ProfileStopgapContainer.swift` (identity group + `showsIdentityPicker`)
- Test: `iphone/MakeReadyCaptureTests/EnvironmentActionsTests.swift`, `iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift`

**Interfaces:**
- Consumes (Task 6): `DevLoginIdentity` (`.you`, `.fixtures`, `email`, `title`, `current`), `AuthError.fixturesNotSeeded`, `AuthIO(send:api:credential:storeCredential:clearCredential:heal:)`, `AuthManager.signIn()`, `AuthManager.signOut()`, `AuthManager.signInToReachableLocal() async throws -> Bool`, `LoginOutcome.message(for:)`. Existing: `RadioOptionRow(title:description:selected:onSelect:)`, `StatePersistence.shared.load()`, `AppState.shared.persist()`.
- Produces: `EnvironmentActions.init(heal: @escaping () async -> LocalPortHealer.Outcome = { await LocalPortHealer.heal() })`, `EnvironmentActions.switchIdentity(_ identity: DevLoginIdentity, auth: AuthManager) async throws` (@MainActor), `AuthManager.loginNotice: String?`, `static ProfileStopgapContainer.showsIdentityPicker(devMode: Bool, env: AppConfiguration.SelectedEnvironment) -> Bool`.

- [ ] **Step 1: Write the failing tests**

`iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift` — add inside `ProfileStopgapTests`:

```swift
    /// ui2-fixtures D13: the "Local identity" group shows only in a dev build pointed at Local.
    func testIdentityPickerOnlyForDevModeOnLocal() {
        XCTAssertTrue(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .local))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .staging))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .production))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: false, env: .local))
    }
```

`iphone/MakeReadyCaptureTests/EnvironmentActionsTests.swift` — append after `EnvironmentActionsTests`:

```swift
/// ui2-fixtures D13/D14, F17: the Local dev-identity switch, driven through the real
/// `AuthManager` `AuthIO` seam — no network, no Keychain.
@MainActor
final class EnvironmentIdentitySwitchTests: XCTestCase {
    private let notSeeded = "Fixtures not seeded — run npm run fixtures:reset in the server container."
    private let userKey = "makeready_current_user"
    private var savedUser: Data?
    private var savedIdentity: String?
    private var savedEnvironment: String?
    private var credential: String?
    private var responses: [String: (Int, String)] = [:]
    private var devLoginEmails: [String] = []
    private var api: StubAPIClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedUser = UserDefaults.standard.data(forKey: userKey)
        savedIdentity = UserDefaults.standard.string(forKey: "devLoginIdentity")
        savedEnvironment = UserDefaults.standard.string(forKey: "selectedEnvironment")
        try XCTSkipUnless(AppConfiguration.devMode, "needs the DEV_MODE=YES host build")
        AppConfiguration.selectedEnvironment = .local
        DevLoginIdentity.current = .you
        StatePersistence.shared.clear()
        AppState.shared.clearAllData()
        api = StubAPIClient()
        credential = nil
        responses = [:]
        devLoginEmails = []
    }

    override func tearDown() {
        if let savedUser { UserDefaults.standard.set(savedUser, forKey: userKey) } else { UserDefaults.standard.removeObject(forKey: userKey) }
        restore(savedIdentity, forKey: "devLoginIdentity")
        restore(savedEnvironment, forKey: "selectedEnvironment")
        AppState.shared.clearAllData()
        super.tearDown()
    }

    private func restore(_ value: String?, forKey key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
    }

    private func io() -> AuthIO {
        AuthIO(
            send: { [unowned self] request in
                let path = request.url?.path ?? ""
                if path == "/auth/dev-login", let body = request.httpBody,
                   let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                   let email = json["email"] as? String {
                    self.devLoginEmails.append(email)
                }
                let (status, text) = self.responses[path] ?? (404, "{}")
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (Data(text.utf8), response)
            },
            api: api,
            credential: { [unowned self] in self.credential },
            storeCredential: { [unowned self] in self.credential = $0 },
            clearCredential: { [unowned self] in self.credential = nil },
            heal: { .healthy(3010) }
        )
    }

    /// Signed in on Local as You, as before the owner picks Fixtures.
    private func signedInAsYou() async -> AuthManager {
        credential = "you-cookie"
        responses["/auth/me"] = (200, #"{"user":{"id":"u-you","name":"You","email":"luke@lukekeith.com"}}"#)
        responses["/auth/logout"] = (200, #"{"success":true}"#)
        let auth = AuthManager(io: io())
        await auth.launchValidation?.value
        return auth
    }

    func testSwitchIdentitySignsInAsTheChosenIdentity() async throws {
        let auth = await signedInAsYou()
        XCTAssertTrue(auth.isAuthenticated)
        responses["/auth/dev-login"] = (200, #"{"success":true,"sessionCookie":"fx-cookie","user":{"id":"u-fx","email":"fixtures@makeready.local","name":"Fixture Leader"}}"#)
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)

        try await EnvironmentActions().switchIdentity(.fixtures, auth: auth)

        XCTAssertEqual(DevLoginIdentity.current, .fixtures)
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(auth.currentUser?.email, "fixtures@makeready.local")
        XCTAssertEqual(credential, "fx-cookie")
        XCTAssertEqual(devLoginEmails, ["fixtures@makeready.local"])
        XCTAssertNil(auth.loginNotice)
    }

    func testSwitchIdentityRevertsToYouOnFailureAndWritesNoSnapshot() async throws {
        let auth = await signedInAsYou()
        responses["/auth/dev-login"] = (404, #"{"success":false,"error":"User not found"}"#)
        AppState.shared.organizationId = "org-you"
        AppState.shared.persist()   // F17: a debounced save is pending when the switch starts

        do {
            try await EnvironmentActions().switchIdentity(.fixtures, auth: auth)
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error)")
        }

        XCTAssertEqual(DevLoginIdentity.current, .you, "D13: the identity reverts to You")
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(credential)
        XCTAssertEqual(auth.loginNotice, notSeeded, "D14: Login shows the message")
        XCTAssertNil(AppState.shared.organizationId, "the old identity's state is cleared")
        try await Task.sleep(nanoseconds: 800_000_000)   // past StatePersistence's 0.5 s debounce
        XCTAssertNil(StatePersistence.shared.load(), "F17: no snapshot may be written after clearAllData()")
    }

    func testSwitchIdentityToTheCurrentIdentityDoesNothing() async throws {
        let auth = await signedInAsYou()
        try await EnvironmentActions().switchIdentity(.you, auth: auth)
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(credential, "you-cookie")
        XCTAssertTrue(devLoginEmails.isEmpty)
    }

    func testSwitchToLocalLetsFixturesNotSeededThrough() async {
        AppConfiguration.selectedEnvironment = .production
        DevLoginIdentity.current = .fixtures
        responses["/auth/dev-login"] = (404, #"{"success":false,"error":"User not found"}"#)
        let auth = AuthManager(io: io())

        do {
            try await EnvironmentActions(heal: { .healthy(3010) }).switchTo(.local, auth: auth)
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error) — must not be mapped to localServerUnreachable")
        }

        XCTAssertEqual(AppConfiguration.selectedEnvironment, .production, "the switch is rolled back")
        XCTAssertEqual(DevLoginIdentity.current, .you, "D14: the identity reverts to You")
    }

    func testSwitchToUnreachableLocalStillSaysUnreachable() async {
        AppConfiguration.selectedEnvironment = .production
        let auth = AuthManager(io: io())
        do {
            try await EnvironmentActions(heal: { .notFound(base: 3010) }).switchTo(.local, auth: auth)
            XCTFail("expected localServerUnreachable")
        } catch AuthError.localServerUnreachable {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(AppConfiguration.selectedEnvironment, .production)
    }
}
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile: `type 'ProfileStopgapContainer' has no member 'showsIdentityPicker'`, `value of type 'EnvironmentActions' has no member 'switchIdentity'`, `argument passed to call that takes no arguments` (`EnvironmentActions(heal:)`), `value of type 'AuthManager' has no member 'loginNotice'`

- [ ] **Step 3: Write the minimal implementation**

`iphone/MakeReady/AuthManager.swift` — directly after `var isAuthenticated: Bool = false`:

```swift
    /// ui2-fixtures D13/D14: a message for Login after a dev-identity switch failed. The
    /// switch's sign-out unmounts Profile, so Login is where it lands; Login clears it.
    var loginNotice: String?
```

`iphone/MakeReady/State/Actions/EnvironmentActions.swift` — replace `struct EnvironmentActions { … }` (keep `EnvironmentHealth` above it unchanged) with:

```swift
/// SPEC D16: legacy ProfilePage's environment switch, moved out of the view.
/// ui2-fixtures D13: also the Local dev-login identity switch.
struct EnvironmentActions {
    /// Probes (and heals) the Local API port; injectable for tests.
    private let heal: () async -> LocalPortHealer.Outcome

    init(heal: @escaping () async -> LocalPortHealer.Outcome = { await LocalPortHealer.heal() }) {
        self.heal = heal
    }

    static func healthURL(for env: AppConfiguration.SelectedEnvironment) -> URL? {
        switch env {
        case .local:
            // The rows probe all three environments, so Local's URL must not follow the selection.
            return URL(string: "\(AppConfiguration.localAPIBaseURL)/health")
        case .staging: return URL(string: "https://staging.api.makeready.org/health")
        case .production: return URL(string: "https://api.makeready.org/health")
        }
    }

    /// The health probe is a sanctioned direct URLSession call, as in legacy.
    func health(of env: AppConfiguration.SelectedEnvironment) async -> EnvironmentHealth {
        guard let url = Self.healthURL(for: env) else { return .unreachable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let status = (try? await URLSession.shared.data(for: request))?.1 as? HTTPURLResponse
        return status?.statusCode == 200 ? .reachable : .unreachable
    }

    /// Switches the active environment. On a failed switch to Local the previous
    /// environment is restored and the error is thrown for the caller to surface per
    /// `/ios-error-surface`: `AuthError.fixturesNotSeeded` when the Fixtures identity has no
    /// user yet (ui2-fixtures D14 — the identity reverts to You), otherwise
    /// `AuthError.localServerUnreachable`.
    @MainActor
    func switchTo(_ env: AppConfiguration.SelectedEnvironment, auth: AuthManager) async throws {
        let previous = AppConfiguration.selectedEnvironment
        guard previous != env else { return }
        AppState.shared.persistImmediately()
        AppConfiguration.selectedEnvironment = env
        AppState.shared.reloadForEnvironmentSwitch()
        if env == .local {
            let reachable: Bool
            switch await heal() {
            case .healthy, .healed: reachable = true
            case .notFound, .skipped: reachable = false
            }
            var signInError: Error?
            if reachable {
                do {
                    if try await auth.signInToReachableLocal() {
                        if auth.isAuthenticated { await AppState.shared.loadInitialData() }
                        return
                    }
                } catch {
                    signInError = error   // only AuthError.fixturesNotSeeded is thrown here
                }
            }
            AppState.shared.persistImmediately()
            AppConfiguration.selectedEnvironment = previous
            AppState.shared.reloadForEnvironmentSwitch()
            await auth.checkAuthStatus()
            if auth.isAuthenticated { await AppState.shared.loadInitialData() }
            if let signInError {
                if case AuthError.fixturesNotSeeded = signInError { DevLoginIdentity.current = .you }
                throw signInError
            }
            let host = AppConfiguration.localServerIP ?? AppConfiguration.defaultLocalIP
            throw AuthError.localServerUnreachable(host: host, port: AppConfiguration.localAPIPort)
        }
        await auth.checkAuthStatus()
        if auth.isAuthenticated { await AppState.shared.loadInitialData() }
    }

    /// ui2-fixtures D13: switches the Local dev-login identity. Persists it, signs out
    /// (`clearAllData()` drops `AppState` and this environment's snapshot, so one identity's
    /// cached Home never shows under the other), then signs in again — `signIn()` dev-logs
    /// in with the new identity's email. `UI2Root` shows Login while signed out and the
    /// shell's initial load runs on the way back in. On failure the identity reverts to
    /// You, the message is handed to Login (`AuthManager.loginNotice`, D14) — Profile is
    /// unmounted by then — and the error is rethrown for the caller to record.
    @MainActor
    func switchIdentity(_ identity: DevLoginIdentity, auth: AuthManager) async throws {
        guard DevLoginIdentity.current != identity else { return }
        DevLoginIdentity.current = identity
        do {
            try await auth.signOut()
            try await auth.signIn()
        } catch {
            DevLoginIdentity.current = .you
            auth.loginNotice = LoginOutcome.message(for: error)
            throw error
        }
    }
}
```

`iphone/MakeReady/UI2/Containers/Auth/LoginContainer.swift` — `body` becomes:

```swift
    var body: some View {
        LoginScreen(
            state: .init(authenticating: authenticating, errorMessage: errorMessage),
            onSignIn: signIn
        )
        .ignoresSafeArea(edges: .bottom)
        // ui2-fixtures D13/D14: a failed dev-identity switch lands here signed out; show why.
        .onChange(of: authManager.loginNotice, initial: true) { _, notice in
            guard let notice else { return }
            errorMessage = notice
            authManager.loginNotice = nil
        }
    }
```

`iphone/MakeReady/UI2/Containers/Profile/ProfileStopgapContainer.swift` — full file:

```swift
import SwiftUI

/// SPEC D15/D16: a stopgap until profile-home is designed.
/// ui2-fixtures D13: in a dev build on Local it also picks the dev-login identity.
struct ProfileStopgapContainer: View {
    static func showsEnvironmentSwitcher(devMode: Bool) -> Bool { devMode }

    /// ui2-fixtures D13: the "Local identity" group shows only in a dev build pointed at Local.
    static func showsIdentityPicker(devMode: Bool, env: AppConfiguration.SelectedEnvironment) -> Bool {
        devMode && env == .local
    }

    @Environment(AuthManager.self) private var authManager
    @State private var current = AppConfiguration.selectedEnvironment
    @State private var identity = DevLoginIdentity.current
    @State private var health: [AppConfiguration.SelectedEnvironment: EnvironmentHealth] = [:]
    @State private var switchError = ""
    @State private var isSwitching = false

    var body: some View {
        VStack(spacing: Token.Space.sectionGap) {
            Spacer()
            PageActionButton(label: "Sign out", role: .secondary, onTap: signOut)
            if Self.showsEnvironmentSwitcher(devMode: AppConfiguration.devMode) {
                VStack(spacing: 0) {
                    ForEach(AppConfiguration.SelectedEnvironment.allCases, id: \.self) { env in
                        RadioOptionRow(
                            title: env.rawValue,
                            description: (health[env] ?? .checking).label,
                            selected: env == current,
                            onSelect: { select(env) }
                        )
                    }
                }
                if Self.showsIdentityPicker(devMode: AppConfiguration.devMode, env: current) {
                    identityPicker
                }
                if !switchError.isEmpty {
                    Text(switchError)
                        .designTextStyle(Token.TypeStyle.body)
                        .foregroundStyle(Token.negative)
                }
            }
            Spacer()
        }
        .padding(Token.Space.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.layoutBackground)
        .task { await refreshHealth() }
    }

    /// ui2-fixtures D13: You · Fixtures, each row described by the email it dev-logs in with.
    private var identityPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Local identity")
                .designTextStyle(Token.TypeStyle.body)
                .foregroundStyle(Token.textSecondary)
            ForEach(DevLoginIdentity.allCases, id: \.self) { option in
                RadioOptionRow(
                    title: option.title,
                    description: option.email,
                    selected: option == identity,
                    onSelect: { selectIdentity(option) }
                )
            }
        }
    }

    private func signOut() {
        Task { @MainActor in
            do {
                try await authManager.signOut()
            } catch {
                // SPEC D28: no banner host in 2.0 — logged through the one error channel.
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.signOut", surface: false)
            }
        }
    }

    private func select(_ env: AppConfiguration.SelectedEnvironment) {
        guard !isSwitching else { return }   // a second tap mid-switch is ignored
        isSwitching = true
        switchError = ""
        Task { @MainActor in
            defer { isSwitching = false }
            do {
                try await EnvironmentActions().switchTo(env, auth: authManager)
            } catch {
                // SPEC D28: shown inline (no banner host) and logged.
                switchError = error.localizedDescription
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.select", surface: false)
            }
            current = AppConfiguration.selectedEnvironment
            identity = DevLoginIdentity.current
            await refreshHealth()
        }
    }

    /// ui2-fixtures D13: sign out, then back in as `option`. Profile unmounts on the sign-out,
    /// so a failure is shown on Login (`AuthManager.loginNotice`) and only logged here.
    private func selectIdentity(_ option: DevLoginIdentity) {
        guard !isSwitching, option != identity else { return }
        isSwitching = true
        switchError = ""
        identity = option
        Task { @MainActor in
            defer { isSwitching = false }
            do {
                try await EnvironmentActions().switchIdentity(option, auth: authManager)
            } catch {
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.selectIdentity", surface: false)
            }
            identity = DevLoginIdentity.current
        }
    }

    /// Probes the three environments concurrently (each times out at 5 s).
    private func refreshHealth() async {
        for env in AppConfiguration.SelectedEnvironment.allCases { health[env] = .checking }
        await withTaskGroup(of: (AppConfiguration.SelectedEnvironment, EnvironmentHealth).self) { group in
            for env in AppConfiguration.SelectedEnvironment.allCases {
                group.addTask { (env, await EnvironmentActions().health(of: env)) }
            }
            for await (env, result) in group { health[env] = result }
        }
    }
}
```

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test` → BUILD + TEST SUCCEEDED (`EnvironmentIdentitySwitchTests` 5 cases and `ProfileStopgapTests.testIdentityPickerOnlyForDevModeOnLocal` pass; Task 6's cases still pass); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Stage, do NOT commit** — `git add iphone/MakeReady/State/Actions/EnvironmentActions.swift iphone/MakeReady/AuthManager.swift iphone/MakeReady/UI2/Containers/Auth/LoginContainer.swift iphone/MakeReady/UI2/Containers/Profile/ProfileStopgapContainer.swift iphone/MakeReadyCaptureTests/EnvironmentActionsTests.swift iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift` and STOP: the iPhone commit is the human's (commit: manual). Proposed message: `feat(ui2-fixtures): Profile Local-identity picker and switchIdentity`
