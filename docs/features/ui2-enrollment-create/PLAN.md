# ui2-enrollment-create — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaders create an enrollment from the UI 2.0 "New enrollment" checklist (the d2m-built `groups-enroll-program` screen and its six pickers), and the server stores the calendar's exact dates plus a lesson-access mode that it enforces for members.

**Architecture:** The server takes `scheduleDates` + `lessonAccess` on `POST /api/enrollments`, refuses 0-member groups and out-of-scope programs, gates the member lesson player for one-at-a-time enrollments before each lesson's day, and adds `completedEnrollmentCount` to `GET /api/programs`. The iPhone holds one memory-only `EnrollmentDraft` per flow in `AppState`; pure mappers derive every d2m screen's `State` from it, and thin containers wire the seven screens into the UI2 shell. The web lesson player renders the server's not-yet message instead of a 404.

**Tech Stack:** server — Express + Prisma + zod + vitest, YAML schema → Atlas migration · iphone — SwiftUI, `@Observable` AppState + Actions, XCTest in `MakeReadyCaptureTests` · client — Laravel 11 Blade + PHPUnit feature tests, design-token SCSS.

**Spec:** `docs/features/ui2-enrollment-create/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-enrollment-create): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

**Plan notes (apply to every task):**
- `.claude/builder.md` marks iphone `commit: auto` (owner 2026-10-26, carve-out in `iphone/.claude/CLAUDE.md`): inside this pipeline an iPhone task commits like any other — the "stage and STOP" line above is superseded for builder agents.
- `server/.env` is a 1Password pipe: never run host `npm run migrate:*`, `npm run schema:diff`, `npx prisma …` that loads `.env`, or `dotenv --`. Each task names the exact command form to use.
- Never edit a file under `iphone/MakeReadyUI/` — d2m owns it. Containers, mappers and state live under `iphone/MakeReady/`.
- A new Swift file must join its target in `iphone/MakeReady.xcodeproj` (files are registered by hand, not folder-synced). Use the `xcodeproj` gem the repo's scripts already use, then resync the capture target:
  ```bash
  cd iphone && ruby -e 'require "xcodeproj"; p=Xcodeproj::Project.open("MakeReady.xcodeproj"); t=p.targets.find{|x| x.name==ARGV[0]}; ARGV[1..].each{|f| g=p.main_group.find_subpath(File.dirname(f), true); g.set_source_tree("<group>"); r=g.files.find{|x| x.real_path.to_s.end_with?(f)} || g.new_reference(File.basename(f)); t.add_file_references([r]) unless t.source_build_phase.files_references.include?(r)}; p.save' MakeReady MakeReady/State/EnrollmentDraft.swift
  cd iphone && ruby scripts/capture-targets.rb
  ```
  (first argument = target `MakeReady` for app sources, `MakeReadyCaptureTests` for tests; then the repo-relative paths under `iphone/`). Check `git diff --stat iphone/MakeReady.xcodeproj` shows only additions.
- iPhone tests run with `npm run ios:build-check -- --test` from the repo root (it runs the whole `MakeReadyCaptureTests` suite; read the result for your test class).

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–3 | `Enrollment.lessonAccess` exists; `POST /api/enrollments` stores exact dates and access, refuses 0-member groups and out-of-scope programs | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run schema:validate` |
| 2 | server | 4–6 | one-at-a-time lessons 403 before their day; programs carry `completedEnrollmentCount`; the walk fixtures exist; the contract freezes | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` |
| 3 | iphone | 7–10 | models decode the new fields; `createEnrollment` sends the new body and refreshes the stores; the draft and every pure mapper exist with tests | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 11–14 | the seven screens are wired: routes, three entries, the checklist container with enroll, and six picker containers | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | client | 15 | the member lesson player shows "This lesson is available on «date»" on the server's not-yet 403 | `cd client && npm run build` · `cd client && npm test` · `cd client && npm run guard` · `cd client && ./vendor/bin/phpunit` |

---

### Task 1: `LessonAccess` enum + `Enrollment.lessonAccess` column (SC1)
App: server
Phase: 1
Recipe: `/api` (server schema section) · server/.claude/CLAUDE.md §Database Management

**Files:**
- Modify: `server/schema/enums.yaml` (after `EnrollmentSyncMode`, ~line 133)
- Modify: `server/schema/schema.yaml` (Enrollment block, after `syncMode`, ~line 2395)
- Generated (commit them): `server/prisma/schema.prisma`, `server/atlas/.schema.hcl`, `server/atlas/migrations/<timestamp>.sql`, `server/atlas/migrations/atlas.sum`
- Test: `server/test/enrollment-lesson-access-migration.test.ts`

**Interfaces:**
- Produces: Prisma enum `LessonAccess` (`ONE_AT_A_TIME` | `ALL_AT_ONCE`) and `Enrollment.lessonAccess: LessonAccess` (NOT NULL, default `ALL_AT_ONCE`). Every existing row reads `ALL_AT_ONCE` (D4) — the column DEFAULT is the backfill.

- [ ] **Step 1: Write the failing test** — `server/test/enrollment-lesson-access-migration.test.ts`

```ts
/**
 * ui2-enrollment-create SC1 (D4): Enrollment.lessonAccess — a NOT NULL enum column whose DEFAULT
 * 'ALL_AT_ONCE' fills every existing enrollment in the same statement (existing ones stay open).
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { Prisma } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes('ADD COLUMN "lessonAccess"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 migration', () => {
  it('creates the LessonAccess enum', () => {
    expect(findMigration().sql).toContain(`CREATE TYPE "LessonAccess" AS ENUM ('ONE_AT_A_TIME', 'ALL_AT_ONCE')`)
  })

  it('adds the column NOT NULL with the ALL_AT_ONCE default (the backfill)', () => {
    expect(findMigration().sql).toMatch(
      /ALTER TABLE "enrollments" ADD COLUMN "lessonAccess" "LessonAccess" NOT NULL DEFAULT 'ALL_AT_ONCE'/,
    )
  })

  it('runs no separate UPDATE', () => {
    expect(findMigration().sql).not.toMatch(/UPDATE\s+"enrollments"/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma field and enum', () => {
    expect(Object.keys(Prisma.EnrollmentScalarFieldEnum)).toContain('lessonAccess')
    expect(Object.values((Prisma as any).LessonAccess ?? {})).toEqual(['ONE_AT_A_TIME', 'ALL_AT_ONCE'])
  })
})
```

If `Prisma.LessonAccess` is not exported on the namespace in this Prisma version, import the enum from `'../src/generated/prisma/index.js'` as `{ LessonAccess }` and assert `Object.values(LessonAccess)` instead.

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/enrollment-lesson-access-migration.test.ts` → FAIL, `expected [] to have a length of 1`

- [ ] **Step 3: Edit the YAML**

`server/schema/enums.yaml`, after the `EnrollmentSyncMode` block:

```yaml
  # ui2-enrollment-create D4: when an enrollment's lessons open to members.
  # ONE_AT_A_TIME = each lesson opens on its scheduled day (in the enrollment's timezone);
  # ALL_AT_ONCE = every lesson is open from the start (every pre-existing enrollment).
  LessonAccess:
    values:
      - ONE_AT_A_TIME
      - ALL_AT_ONCE
```

`server/schema/schema.yaml`, Enrollment fields, directly after `syncMode`:

```yaml
      lessonAccess:
        type: enum
        enum: LessonAccess
        default: "ALL_AT_ONCE"
        description: "When lessons open to members: ONE_AT_A_TIME on each lesson's day, ALL_AT_ONCE from the start (ui2-enrollment-create D4)"
```

- [ ] **Step 4: Validate, generate, diff** (never `npm run schema:diff` — it reads the 1Password `.env`):

```bash
cd server && npm run schema:validate
cd server && npm run schema:generate
cd server/atlas && ../scripts/atlas.sh migrate diff --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_dev npx prisma generate --schema prisma/schema.prisma
```

Open the new migration and confirm it contains exactly the `CREATE TYPE "LessonAccess"`, the `ALTER TABLE "enrollments" ADD COLUMN "lessonAccess" "LessonAccess" NOT NULL DEFAULT 'ALL_AT_ONCE'` and the `COMMENT ON COLUMN` — the shape of `server/atlas/migrations/20260706062151.sql:1-9`. Anything else in the diff (drift from another feature) → STOP and report; never hand-edit it.

- [ ] **Step 5: Run it and watch it pass** — `cd server && npx vitest run test/enrollment-lesson-access-migration.test.ts` → PASS (5 tests); `cd server && npx tsc --noEmit` → clean

- [ ] **Step 6: Commit** — `feat(ui2-enrollment-create): Enrollment.lessonAccess enum column (SC1)` — the YAML, the generated Prisma schema + HCL, the migration + `atlas.sum`, and the test

### Task 2: shared timezone util + `validateScheduleDates` (D3, D16)
App: server
Phase: 1
Recipe: `/api` · SPEC §server (D16)

**Files:**
- Create: `server/src/utils/timezone.ts`
- Create: `server/src/utils/__tests__/timezone.test.ts`
- Modify: `server/src/services/analytics.service.ts:429-445` (delegate to the util)
- Modify: `server/src/services/enrollment-schedule.ts` (add `validateScheduleDates`)
- Modify: `server/src/services/__tests__/enrollment-schedule.test.ts`

**Interfaces:**
- Produces (`server/src/utils/timezone.ts`):
  - `isValidTimezone(tz: string): boolean`
  - `localDate(instant: Date, tz: string): string` — `yyyy-MM-dd` of `instant` in `tz`
  - `todayInTimezone(tz: string, now?: Date): string`
  - `zonedMidnight(date: string, tz: string): Date` — the UTC instant of 00:00 on `date` in `tz`
  - `formatLongDay(instant: Date, tz: string): string` — e.g. `"Monday, November 3"`
- Produces (`enrollment-schedule.ts`): `validateScheduleDates(dates: string[], lessonCount: number, tz: string, now: Date): { ok: true; dates: Date[] } | { ok: false; error: string }`
- `analytics.service.ts` keeps exporting `todayInTimezone` and `assertValidTimezone` with today's signatures (its callers in `routes/members.ts`, `routes/home.ts`, `routes/program-analytics.ts` are unchanged).

- [ ] **Step 1: Write the failing tests**

`server/src/utils/__tests__/timezone.test.ts`:

```ts
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
```

Append to `server/src/services/__tests__/enrollment-schedule.test.ts` (and extend its import to `import { generateScheduleDates, enabledDayNumbers, validateScheduleDates } from '../enrollment-schedule'`):

```ts
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
  })
})
```

- [ ] **Step 2: Run them and watch them fail** — `cd server && npx vitest run src/utils/__tests__/timezone.test.ts src/services/__tests__/enrollment-schedule.test.ts` → FAIL, `Failed to resolve import "../timezone"`

- [ ] **Step 3: Write the util** — `server/src/utils/timezone.ts`

```ts
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
```

- [ ] **Step 4: Point analytics at it** — in `server/src/services/analytics.service.ts`, replace the bodies at `:429-445`:

```ts
import { isValidTimezone, todayInTimezone } from '../utils/timezone.js'
export { todayInTimezone }

export function assertValidTimezone(tz: string): void {
  if (!isValidTimezone(tz)) throw new AnalyticsQueryError(400, `Invalid timezone: ${tz}`)
}
```

(put the `import` with the file's other imports; delete the old local `todayInTimezone` function; keep `addDays` and `DATE_RE` where they are).

- [ ] **Step 5: Write `validateScheduleDates`** — append to `server/src/services/enrollment-schedule.ts`:

```ts
import { localDate, todayInTimezone, zonedMidnight } from '../utils/timezone.js'

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
```

(move the `import` to the top of the file.)

- [ ] **Step 6: Run them and watch them pass** — `cd server && npx vitest run src/utils/__tests__/timezone.test.ts src/services/__tests__/enrollment-schedule.test.ts src/services/__tests__/analytics-metrics.test.ts` → PASS; `cd server && npx tsc --noEmit` → clean

- [ ] **Step 7: Commit** — `feat(ui2-enrollment-create): shared timezone util and validateScheduleDates (D3, D16)`

### Task 3: `POST /api/enrollments` — exact dates, lesson access, eligibility, program scope (SC2, D3–D5, D16, T12)
App: server
Phase: 1
Recipe: `/api` · SPEC §server *POST* · §Contract row 1

**Build-time risks carried here:** **T12** — the program lookup has no org scope (`enrollments.ts:147-175`, "any active program"): spread `programReadFilter(userId)` → 404 outside it. **A1** — every existing POST test enrolls a group with no active member and turns red under D5: add an active `groupMember` in each (`src/routes/__tests__/program-publish.test.ts:229-240`, `src/routes/__tests__/enrollment-sync.test.ts:151,214`, `src/routes/__tests__/enrollment-sync-engine.test.ts:167,508`, `src/routes/__tests__/enrollment-edit.test.ts:41`, `src/routes/__tests__/member-version-resolution.test.ts:114` — `grep -rn "post('/api/enrollments')" server/src server/test` finds any others). **A2** — the 400 names the expected count (Task 2's message).

**Files:**
- Modify: `server/src/routes/enrollments.ts:112-492` (+ the `@openapi` block above it)
- Create: `server/test/enrollment-create.test.ts`
- Modify: `server/test/enrollment-authorization.test.ts` (tenancy case)
- Modify: the A1 test files above (add an active member before posting)

**Interfaces:**
- Consumes: `validateScheduleDates`, `isValidTimezone` (Task 2); `Enrollment.lessonAccess` (Task 1); `programReadFilter(userId): Promise<Prisma.StudyProgramWhereInput>` (`services/study-program.service.ts:129`)
- Produces (§Contract row 1, frozen at Task 6): body gains `scheduleDates?: string[]` (`yyyy-MM-dd`) and `lessonAccess?: 'ONE_AT_A_TIME' | 'ALL_AT_ONCE'`; `timezone` must be a valid IANA zone. Response `enrollment` adds `lessonAccess` and `syncMode`. Errors: 400 zod (incl. invalid timezone), 400 `{success:false, error:"Schedule doesn't match the program: …"}`, 400 `{success:false, error:"group_has_no_members", message:"Group has no members"}`, 404 `Study program not found` outside `programReadFilter`.

- [ ] **Step 1: Write the failing test** — `server/test/enrollment-create.test.ts`

```ts
/**
 * ui2-enrollment-create SC2 (D3, D4, D5, D16, T12): POST /api/enrollments takes the app's exact
 * dates and lesson access, refuses a 0-member group and a program outside the caller's read scope.
 * Real DB + API-key auth, as enrollment-authorization.test.ts.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'
import { todayInTimezone } from '../src/utils/timezone.js'

const TZ = 'America/Chicago'
const addDays = (ymd: string, n: number) => {
  const d = new Date(`${ymd}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10)
}

describe('POST /api/enrollments (ui2-enrollment-create)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let stranger: TestUserWithToken
  let orgId: string
  let otherOrgId: string
  let groupId: string
  let emptyGroupId: string
  let programId: string
  let foreignProgramId: string
  let memberId: string
  const today = todayInTimezone(TZ)

  const body = (extra: Record<string, unknown> = {}) => ({
    groupId, studyProgramId: programId, startDate: new Date().toISOString(),
    enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], timezone: TZ, ...extra,
  })
  const post = (b: Record<string, unknown>) =>
    request(app).post('/api/enrollments').set('Authorization', bearer(owner.token)).send(b)

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `ec-owner-${stamp}@cl.test`, name: 'EC Owner' })
    stranger = await createUserWithApiKey({ email: `ec-stranger-${stamp}@cl.test`, name: 'EC Stranger' })
    orgId = (await prisma.organization.create({ data: { name: `EC Org ${stamp}`, ownerId: owner.userId } })).id
    otherOrgId = (await prisma.organization.create({ data: { name: `EC Other ${stamp}`, ownerId: stranger.userId } })).id
    groupId = (await prisma.group.create({ data: { name: `EC Group ${stamp}`, code: `ecg-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    emptyGroupId = (await prisma.group.create({ data: { name: `EC Empty ${stamp}`, code: `ece-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    memberId = (await prisma.member.create({ data: { firstName: 'Ann', lastName: 'Lee', phoneNumber: `+1555${String(stamp).slice(-7)}` } })).id
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })
    const mkProgram = async (org: string, creator: string, name: string) => {
      const p = await prisma.studyProgram.create({
        data: { name, days: 3, creatorId: creator, organizationId: org, isPublished: true, publishedAt: new Date() },
      })
      for (const day of [1, 2, 3]) await prisma.lesson.create({ data: { studyProgramId: p.id, dayNumber: day } })
      return p.id
    }
    programId = await mkProgram(orgId, owner.userId, `EC Program ${stamp}`)
    foreignProgramId = await mkProgram(otherOrgId, stranger.userId, `EC Foreign ${stamp}`)
  })

  afterAll(async () => {
    const orgs = [orgId, otherOrgId]
    await prisma.enrollment.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.groupMember.deleteMany({ where: { memberId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.lesson.deleteMany({ where: { studyProgram: { organizationId: { in: orgs } } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.apiKey.deleteMany({ where: { userId: { in: [owner.userId, stranger.userId] } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: [owner.userId, stranger.userId] } } })
  })

  it('stores the sent dates verbatim as 00:00 in the request zone; endDate = last; startDate = first', async () => {
    const dates = [addDays(today, 1), addDays(today, 3), addDays(today, 6)]
    const res = await post(body({ scheduleDates: dates, lessonAccess: 'ONE_AT_A_TIME', syncMode: 'OFF' }))
    expect(res.status).toBe(200)
    expect(res.body.enrollment.lessonAccess).toBe('ONE_AT_A_TIME')
    expect(res.body.enrollment.syncMode).toBe('OFF')
    const schedules = await prisma.lessonSchedule.findMany({
      where: { enrollmentId: res.body.enrollment.id }, orderBy: { scheduledDate: 'asc' },
    })
    const local = (d: Date) => new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(d)
    const hour = (d: Date) => new Intl.DateTimeFormat('en-US', { timeZone: TZ, hour: '2-digit', hour12: false }).format(d)
    expect(schedules.map((s) => local(s.scheduledDate))).toEqual(dates)
    expect(schedules.every((s) => hour(s.scheduledDate) === '00')).toBe(true)
    const e = await prisma.enrollment.findUniqueOrThrow({ where: { id: res.body.enrollment.id } })
    expect(local(e.startDate)).toBe(dates[0])
    expect(local(e.endDate)).toBe(dates[2])
  })

  it('derives the dates as before when scheduleDates is absent, and defaults lessonAccess to ALL_AT_ONCE', async () => {
    const res = await post(body())
    expect(res.status).toBe(200)
    expect(res.body.enrollment.lessonAccess).toBe('ALL_AT_ONCE')
    expect(await prisma.lessonSchedule.count({ where: { enrollmentId: res.body.enrollment.id } })).toBe(3)
  })

  it('400s a wrong count, naming the expected one (A2)', async () => {
    const res = await post(body({ scheduleDates: [addDays(today, 1)] }))
    expect(res.status).toBe(400)
    expect(res.body.error).toBe("Schedule doesn't match the program: expected 3 dates, got 1")
  })

  it('400s unsorted dates and a past first date', async () => {
    expect((await post(body({ scheduleDates: [addDays(today, 3), addDays(today, 2), addDays(today, 4)] }))).status).toBe(400)
    expect((await post(body({ scheduleDates: [addDays(today, -1), addDays(today, 2), addDays(today, 4)] }))).status).toBe(400)
  })

  it('400s an invalid timezone (D16)', async () => {
    expect((await post(body({ timezone: 'Mars/Olympus' }))).status).toBe(400)
  })

  it('400s a 0-member group with group_has_no_members (D5)', async () => {
    const res = await post(body({ groupId: emptyGroupId }))
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'group_has_no_members', message: 'Group has no members' })
  })

  it('404s a program outside the caller\'s read scope (T12)', async () => {
    const res = await post(body({ studyProgramId: foreignProgramId }))
    expect(res.status).toBe(404)
    expect(res.body.error).toBe('Study program not found')
  })
})
```

Check `server/test/helpers/api-auth.ts` for the exact `createUserWithApiKey` signature and `server/schema/schema.yaml` `Member` for its required fields before running; adjust the `member.create` data to them (never loosen an assertion).

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/enrollment-create.test.ts` → FAIL (first case: `lessonAccess` undefined; the 0-member case returns 200; the foreign program returns 200)

- [ ] **Step 3: Implement in `server/src/routes/enrollments.ts`**

Imports at the top:

```ts
import { generateScheduleDates, validateScheduleDates } from '../services/enrollment-schedule.js'
import { isValidTimezone } from '../utils/timezone.js'
import { programReadFilter } from '../services/study-program.service.js'
```

(merge with the existing `generateScheduleDates` import; `programReadFilter` may already be importable from a barrel — use the file path above.)

The zod schema at `:118-127` becomes:

```ts
    const schema = z.object({
      groupId: z.string().uuid(),
      studyProgramId: z.string().uuid(),
      startDate: z.string().datetime(),
      enabledDays: z.array(z.enum(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])).min(1),
      smsTime: z.string().regex(/^\d{2}:\d{2}$/).optional(), // "HH:MM" format
      // D16: an invalid zone is a 400, never a silent UTC fallback.
      timezone: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).optional(),
      requireResponse: z.boolean().optional(), // Override program default (inherits from program if not specified)
      syncMode: z.enum(['OFF', 'AUTO', 'APPROVAL']).optional(), // "Sync to study": how this enrollment tracks published curriculum updates
      // ui2-enrollment-create D3: the app's exact lesson dates (overrides included); absent → derived.
      scheduleDates: z.array(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).min(1).optional(),
      // D4: when lessons open to members; absent → the column default ALL_AT_ONCE.
      lessonAccess: z.enum(['ONE_AT_A_TIME', 'ALL_AT_ONCE']).optional(),
    })
```

The group lookup (`:135-145`) selects the active-member count and refuses an empty group (D5, as `groups.ts:240` counts):

```ts
    const group = await prisma.group.findFirst({
      where: {
        id: body.groupId,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
      include: { _count: { select: { members: { where: { isActive: true } } } } },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // D5: an enrollment needs someone to enroll — the pickers hide empty groups, this guards every caller.
    if (group._count.members === 0) {
      return res.status(400).json({ success: false, error: 'group_has_no_members', message: 'Group has no members' })
    }
```

The program lookup (`:147-175`): replace the comment "Any active program can be used…" with `// T12: only a program the caller can read (programReadFilter, the GET /api/programs/:id scope).` and change `where` to:

```ts
      where: {
        id: body.studyProgramId,
        isActive: true,
        ...(await programReadFilter(userId)),
      },
```

The date block (`:196-200`) becomes:

```ts
    // D3: the app's exact dates when sent (00:00 in `timezone`, D16); else the weekday walk.
    let scheduleDates: Date[]
    if (body.scheduleDates) {
      const checked = validateScheduleDates(body.scheduleDates, program.lessons.length, body.timezone ?? 'UTC', new Date())
      if (!checked.ok) {
        return res.status(400).json({ success: false, error: checked.error })
      }
      scheduleDates = checked.dates
    } else {
      scheduleDates = generateScheduleDates(new Date(body.startDate), body.enabledDays, program.lessons.length)
    }
    const startDate = body.scheduleDates ? scheduleDates[0] : new Date(body.startDate)
    const endDate = scheduleDates[scheduleDates.length - 1]
```

In `prisma.enrollment.create` data add `lessonAccess: body.lessonAccess ?? 'ALL_AT_ONCE',` after `syncMode`. In the response `select` (`:405-418`) add `lessonAccess: true,` and `syncMode: true,` after `timezone: true,`. In the `@openapi` block above the route add the two request properties (`scheduleDates` array of `date` strings, `lessonAccess` enum) and the 400 `group_has_no_members` description.

- [ ] **Step 4: Fix the A1 tests** — in each file listed under *Build-time risks*, before its `post('/api/enrollments')`, create an active member in the group it posts for, using the file's own member/group variables, e.g. for `program-publish.test.ts:229`:

```ts
    const member = await prisma.member.create({ data: { firstName: 'Pub', lastName: 'Member', phoneNumber: `+1555${String(Date.now()).slice(-7)}` } })
    await prisma.groupMember.create({ data: { groupId: group.id, memberId: member.id, isActive: true } })
```

and delete that member in the file's existing cleanup. Then add the tenancy case to `server/test/enrollment-authorization.test.ts` (a stranger's program in another org → 404 when the owner posts it), using that file's `owner`/`stranger`/`groupId` and creating an active member for its group.

- [ ] **Step 5: Run it and watch it pass** — `docker restart makeready-server` is not needed for supertest (it imports `app`); run `cd server && npx vitest run test/enrollment-create.test.ts test/enrollment-authorization.test.ts src/routes/__tests__/program-publish.test.ts src/routes/__tests__/enrollment-sync.test.ts src/routes/__tests__/enrollment-sync-engine.test.ts src/routes/__tests__/enrollment-edit.test.ts src/routes/__tests__/member-version-resolution.test.ts` → PASS; then `cd server && npx tsc --noEmit` and `cd server && npm run test:run` → green

- [ ] **Step 6: Commit** — `feat(ui2-enrollment-create): POST /api/enrollments takes exact dates and lesson access, refuses empty groups and out-of-scope programs (SC2)`

### Task 4: one-at-a-time lesson gate (SC3, D4, D15)
App: server
Phase: 2
Recipe: `/api` · SPEC §server *Lesson gate* · §Contract row 2

**Files:**
- Create: `server/src/services/lesson-availability.ts`
- Create: `server/src/services/__tests__/lesson-availability.test.ts`
- Modify: `server/src/services/member-progress.service.ts:637-720` (`getMemberLessonDetail`)
- Modify: `server/src/routes/member-lessons.ts:555-620`
- Modify: `server/src/routes/enrollments.ts:2420-2482` (`/lessons/today/:enrollmentId`)
- Modify: `server/src/routes/__tests__/member-lessons.test.ts`, `server/src/routes/__tests__/lesson-lookup.test.ts`

**Interfaces:**
- Consumes: `localDate`, `formatLongDay` (Task 2); `Enrollment.lessonAccess`, `Enrollment.timezone`
- Produces: `lessonAvailability(scheduledDate: Date, enrollment: { lessonAccess: 'ONE_AT_A_TIME' | 'ALL_AT_ONCE'; timezone: string | null }, now: Date): { available: true } | { available: false; availableOn: string; message: string }` and the 403 body `{ success:false, error:"not_yet_available", message:"This lesson is available on «Weekday, Month d»", availableOn:"yyyy-MM-dd" }` on `GET /api/member/lessons/:lessonScheduleId` (members only — group leaders/managers exempt) and `GET /api/lessons/today/:enrollmentId`. `GET /api/lessons/code/:code` and `/lessons/view/:scheduleId` are NOT changed.

- [ ] **Step 1: Write the failing tests**

`server/src/services/__tests__/lesson-availability.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { lessonAvailability } from '../lesson-availability'
import { zonedMidnight } from '../../utils/timezone'

const TZ = 'America/Chicago'
const lesson = zonedMidnight('2035-01-10', TZ) // Wed Jan 10, 00:00 Chicago

describe('lessonAvailability (D4, D15)', () => {
  it('ALL_AT_ONCE is open on any day', () => {
    expect(lessonAvailability(lesson, { lessonAccess: 'ALL_AT_ONCE', timezone: TZ }, new Date('2035-01-01T12:00:00Z'))).toEqual({ available: true })
  })

  it('ONE_AT_A_TIME is closed before its day, with the date and message', () => {
    expect(lessonAvailability(lesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: TZ }, new Date('2035-01-10T05:59:00Z'))).toEqual({
      available: false, availableOn: '2035-01-10', message: 'This lesson is available on Wednesday, January 10',
    })
  })

  it('ONE_AT_A_TIME opens at 00:00 on its day in the enrollment zone', () => {
    expect(lessonAvailability(lesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: TZ }, new Date('2035-01-10T06:00:00Z')).available).toBe(true)
  })

  it('a null timezone reads UTC', () => {
    const utcLesson = zonedMidnight('2035-01-10', 'UTC')
    expect(lessonAvailability(utcLesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: null }, new Date('2035-01-09T23:00:00Z')).available).toBe(false)
    expect(lessonAvailability(utcLesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: null }, new Date('2035-01-10T00:00:00Z')).available).toBe(true)
  })
})
```

In `server/src/routes/__tests__/member-lessons.test.ts`, inside `describe('GET /api/member/lessons/:lessonScheduleId', …)`, add:

```ts
    it('403s a member opening a one-at-a-time lesson before its day (D4, D15)', async () => {
      const future = new Date(); future.setDate(future.getDate() + 3)
      await prisma.enrollment.update({ where: { id: testEnrollment.id }, data: { lessonAccess: 'ONE_AT_A_TIME', timezone: 'UTC' } })
      await prisma.lessonSchedule.update({ where: { id: testLessonSchedule.id }, data: { scheduledDate: future } })

      const response = await request(app)
        .get(`/api/member/lessons/${testLessonSchedule.id}`)
        .set('Cookie', memberCookies)

      expect(response.status).toBe(403)
      expect(response.body).toMatchObject({ success: false, error: 'not_yet_available', availableOn: future.toISOString().slice(0, 10) })
      expect(response.body.message).toMatch(/^This lesson is available on \w+, \w+ \d{1,2}$/)
    })

    it('opens a one-at-a-time lesson on its day, and an all-at-once lesson any day', async () => {
      await prisma.enrollment.update({ where: { id: testEnrollment.id }, data: { lessonAccess: 'ONE_AT_A_TIME', timezone: 'UTC' } })
      expect((await request(app).get(`/api/member/lessons/${testLessonSchedule.id}`).set('Cookie', memberCookies)).status).toBe(200)
      const future = new Date(); future.setDate(future.getDate() + 3)
      await prisma.enrollment.update({ where: { id: testEnrollment.id }, data: { lessonAccess: 'ALL_AT_ONCE' } })
      await prisma.lessonSchedule.update({ where: { id: testLessonSchedule.id }, data: { scheduledDate: future } })
      expect((await request(app).get(`/api/member/lessons/${testLessonSchedule.id}`).set('Cookie', memberCookies)).status).toBe(200)
    })
```

The leader exemption is covered at the service level — add to `lesson-availability.test.ts`'s sibling: a unit test is enough because `getMemberLessonDetail(memberId, id, true)` is called with `isGroupLeader` from the route; add in `member-lessons.test.ts`:

```ts
    it('lets a group leader open a one-at-a-time lesson early (D15 exemption)', async () => {
      const { getMemberLessonDetail } = await import('../../services/member-progress.service')
      const future = new Date(); future.setDate(future.getDate() + 3)
      await prisma.enrollment.update({ where: { id: testEnrollment.id }, data: { lessonAccess: 'ONE_AT_A_TIME', timezone: 'UTC' } })
      await prisma.lessonSchedule.update({ where: { id: testLessonSchedule.id }, data: { scheduledDate: future } })
      expect((await getMemberLessonDetail(testMember.id, testLessonSchedule.id, true)).success).toBe(true)
      expect((await getMemberLessonDetail(testMember.id, testLessonSchedule.id, false)).notYet?.availableOn).toBe(future.toISOString().slice(0, 10))
    })
```

In `server/src/routes/__tests__/lesson-lookup.test.ts` add a `describe('one-at-a-time (D15)')` block:

```ts
  describe('one-at-a-time (D15)', () => {
    const makeFuture = async () => {
      const future = new Date(); future.setDate(future.getDate() + 3)
      await prisma.enrollment.update({ where: { id: testEnrollment.id }, data: { lessonAccess: 'ONE_AT_A_TIME', timezone: 'UTC' } })
      await prisma.lessonSchedule.update({ where: { id: testLessonSchedule.id }, data: { scheduledDate: future } })
    }

    it('leaves /lessons/code and /lessons/view open (the join flow needs them)', async () => {
      await makeFuture()
      expect((await request(app).get(`/api/lessons/code/${TEST_STUDY_CODE}`)).status).toBe(200)
      expect((await request(app).get(`/api/lessons/view/${testLessonSchedule.id}`)).status).toBe(200)
    })

    it('/lessons/today opens a one-at-a-time lesson on its own day', async () => {
      // the setup's schedule is today; the gate must not block it (the closed case is the unit test's)
      await prisma.enrollment.update({ where: { id: testEnrollment.id }, data: { lessonAccess: 'ONE_AT_A_TIME', timezone: 'UTC' } })
      expect((await request(app).get(`/api/lessons/today/${testEnrollment.id}`)).status).toBe(200)
    })

    it('/lessons/today stays 200 for an all-at-once enrollment', async () => {
      expect((await request(app).get(`/api/lessons/today/${testEnrollment.id}`)).status).toBe(200)
    })
  })
```

(the closed-before-its-day branch of `/lessons/today` is covered by `lesson-availability.test.ts`: the route only finds today's schedule, so a route-level "too early" case would depend on the machine's zone. Check `/lessons/view`'s exact path and auth in `enrollments.ts:2294` before running; send the headers the file's existing `/lessons/view` cases send.)

- [ ] **Step 2: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/lesson-availability.test.ts src/routes/__tests__/member-lessons.test.ts src/routes/__tests__/lesson-lookup.test.ts` → FAIL, `Failed to resolve import "../lesson-availability"`

- [ ] **Step 3: Write the service** — `server/src/services/lesson-availability.ts`

```ts
/**
 * ui2-enrollment-create D4/D15: whether a member may open a lesson yet. ONE_AT_A_TIME opens each
 * lesson at 00:00 on its scheduled day in the enrollment's timezone (UTC when null); ALL_AT_ONCE
 * is always open. Callers exempt group leaders and managers before asking.
 */
import { formatLongDay, localDate } from '../utils/timezone.js'

export type LessonAvailability =
  | { available: true }
  | { available: false; availableOn: string; message: string }

export function lessonAvailability(
  scheduledDate: Date,
  enrollment: { lessonAccess: 'ONE_AT_A_TIME' | 'ALL_AT_ONCE'; timezone: string | null },
  now: Date,
): LessonAvailability {
  if (enrollment.lessonAccess !== 'ONE_AT_A_TIME') return { available: true }
  const tz = enrollment.timezone || 'UTC'
  const lessonDay = localDate(scheduledDate, tz)
  if (localDate(now, tz) >= lessonDay) return { available: true }
  return {
    available: false,
    availableOn: lessonDay,
    message: `This lesson is available on ${formatLongDay(scheduledDate, tz)}`,
  }
}

/** The 403 body both gated routes send (§Contract row 2). */
export function notYetBody(a: { availableOn: string; message: string }) {
  return { success: false, error: 'not_yet_available', message: a.message, availableOn: a.availableOn }
}
```

- [ ] **Step 4: Gate the member lesson player** — in `getMemberLessonDetail` (`member-progress.service.ts`):
  - widen the return type to `{ success: boolean; data?: LessonDetail; error?: string; notYet?: { availableOn: string; message: string } }`;
  - in the `enrollment: { select: { … } }` block (`:677-697`) add `lessonAccess: true,` and `timezone: true,`;
  - directly after the `members.length === 0` check add:

```ts
    // D15: one-at-a-time enrollments open each lesson on its day — group leaders/managers exempt.
    if (!isGroupLeader) {
      const availability = lessonAvailability(schedule.scheduledDate, schedule.enrollment, new Date())
      if (!availability.available) {
        return { success: false, error: 'not_yet_available', notYet: { availableOn: availability.availableOn, message: availability.message } }
      }
    }
```

  with `import { lessonAvailability } from './lesson-availability.js'` at the top.

  In `member-lessons.ts:604-611`, before the generic error branch:

```ts
      if (result.notYet) {
        return res.status(403).json(notYetBody(result.notYet))   // D4/D15
      }
```

  with `import { notYetBody } from '../services/lesson-availability.js'`. Add the 403 `not_yet_available` response to that route's `@openapi` block.

- [ ] **Step 5: Gate `/lessons/today/:enrollmentId`** (`enrollments.ts:2420`): add `enrollment: { select: { lessonAccess: true, timezone: true } },` to the `findFirst` `include`, and after the `if (!schedule)` 404:

```ts
    // D15: a one-at-a-time lesson not yet open in the enrollment's zone.
    const availability = lessonAvailability(schedule.scheduledDate, schedule.enrollment, new Date())
    if (!availability.available) {
      return res.status(403).json(notYetBody(availability))
    }
```

  importing `lessonAvailability, notYetBody` from `'../services/lesson-availability.js'`. Document the 403 in its `@openapi` block.

- [ ] **Step 6: Run them and watch them pass** — same command as Step 2 → PASS; `cd server && npx tsc --noEmit` → clean; `docker restart makeready-server` (route code changed)

- [ ] **Step 7: Commit** — `feat(ui2-enrollment-create): one-at-a-time lessons 403 before their day on the member player and /lessons/today (SC3, D15)`

### Task 5: `GET /api/programs` `completedEnrollmentCount` (SC4, D8)
App: server
Phase: 2
Recipe: `/api` · SPEC §server *GET /api/programs* · tiny

**Files:**
- Modify: `server/src/routes/programs.ts:434-525`
- Test: `server/src/routes/__tests__/programs-list.request.test.ts`

**Interfaces:**
- Produces: each program in `GET /api/programs` gains `completedEnrollmentCount: number` — enrollments of that program whose `endDate` is before the start of today (UTC), 0 when none. `_count.enrollments` is unchanged.

- [ ] **Step 1: Write the failing test** — in `programs-list.request.test.ts` add `enrollment: { groupBy: vi.fn() },` to `prismaMock`, `prismaMock.enrollment.groupBy.mockResolvedValue([{ studyProgramId: 'p1', _count: { _all: 2 } }])` to `beforeEach`, and:

```ts
  it('adds completedEnrollmentCount from one grouped query over ended enrollments (D8)', async () => {
    const res = await request(app()).get('/api/programs')
    expect(res.body.programs[0].completedEnrollmentCount).toBe(2)
    expect(prismaMock.enrollment.groupBy).toHaveBeenCalledTimes(1)
    const arg = prismaMock.enrollment.groupBy.mock.calls[0][0]
    expect(arg.by).toEqual(['studyProgramId'])
    expect(arg.where.studyProgramId).toEqual({ in: ['p1'] })
    const startOfTodayUtc = new Date(); startOfTodayUtc.setUTCHours(0, 0, 0, 0)
    expect(arg.where.endDate.lt.toISOString()).toBe(startOfTodayUtc.toISOString())
  })

  it('reads 0 for a program with no ended enrollment', async () => {
    prismaMock.enrollment.groupBy.mockResolvedValue([])
    const res = await request(app()).get('/api/programs')
    expect(res.body.programs[0].completedEnrollmentCount).toBe(0)
  })
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/programs-list.request.test.ts` → FAIL, `expected undefined to be 2`

- [ ] **Step 3: Implement** — in `programs.ts`, after the org-name lookup (`:508-512`):

```ts
    // ui2-enrollment-create D8: enrollments that ended before today (UTC), one grouped query —
    // a filtered _count can't sit beside the _count.enrollments the iPhone already reads.
    const startOfTodayUtc = new Date()
    startOfTodayUtc.setUTCHours(0, 0, 0, 0)
    const completed = programs.length
      ? await prisma.enrollment.groupBy({
          by: ['studyProgramId'],
          where: { studyProgramId: { in: programs.map((p) => p.id) }, endDate: { lt: startOfTodayUtc } },
          _count: { _all: true },
        })
      : []
    const completedCount = new Map(completed.map((c) => [c.studyProgramId, c._count._all]))
```

and in the `programs.map` add `completedEnrollmentCount: completedCount.get(p.id) ?? 0,`. Add `completedEnrollmentCount` (integer) to the route's `@openapi` program item.

- [ ] **Step 4: Run it and watch it pass** — same command → PASS; `cd server && npx tsc --noEmit` → clean; `docker restart makeready-server`

- [ ] **Step 5: Commit** — `feat(ui2-enrollment-create): GET /api/programs carries completedEnrollmentCount (SC4)`

### Task 6: `groups-enroll-program` fixture layer + DB test; record the contract freeze (D12)
App: server
Phase: 2
Recipe: `server/fixtures/README.md` · REFERENCE §Contract and the contract freeze

**Files:**
- Create: `server/fixtures/screens/groups-enroll-program.ts`
- Create: `server/fixtures/__tests__/groups-enroll-program.db.test.ts`
- Modify: `docs/features/ui2-enrollment-create/MANIFEST.md` (the freeze — via `advance.mjs`, Step 6)

**Interfaces:**
- Consumes: `FIXTURE_GROUP_IDS`, `FIXTURE_ORG_ID`, `FIXTURE_USER_ID`, `fixtureId` (`fixtures/ids.ts`); `FixtureContext` (`ctx.prisma`, `ctx.daysAgo(n)`, `ctx.at(offset, hour)`); `lessonId(programIndex, day)` from `fixtures/base.ts`
- Produces: `ENROLL_PROGRAM_ID` (program n 5, "Romans in 12 Days", published, 12 lessons, one ended enrollment on base group 2 → completed count 1); `ENROLL_EMPTY_PROGRAM_ID` (program n 6, published, `days` 0, no lessons — hidden by the picker); enrollment id `fixtureId('enrollment', 900)`, schedule ids `fixtureId('schedule', 900_000 + day)`. Creates no org, user or group.

- [ ] **Step 1: Write the failing DB test** — `server/fixtures/__tests__/groups-enroll-program.db.test.ts`

```ts
/**
 * groups-enroll-program layer (ui2-enrollment-create D12) against a throwaway database: the picker's
 * visible/hidden split and the completed count. Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_EMPTY_GROUP_ID, FIXTURE_ORG_ID } from '../ids.js'
import { ENROLL_EMPTY_PROGRAM_ID, ENROLL_PROGRAM_ID } from '../screens/groups-enroll-program.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('groups-enroll-program full scenario against the test database', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('adds a published 12-lesson program with exactly one ended enrollment', async () => {
    const p = await db.prisma.studyProgram.findUniqueOrThrow({ where: { id: ENROLL_PROGRAM_ID }, include: { lessons: true } })
    expect(p).toMatchObject({ isPublished: true, days: 12, organizationId: FIXTURE_ORG_ID })
    expect(p.lessons).toHaveLength(12)
    const ended = await db.prisma.enrollment.count({ where: { studyProgramId: ENROLL_PROGRAM_ID, endDate: { lt: new Date() } } })
    expect(ended).toBe(1)
  })

  it('adds a published 0-day program the picker hides', async () => {
    const p = await db.prisma.studyProgram.findUniqueOrThrow({ where: { id: ENROLL_EMPTY_PROGRAM_ID }, include: { lessons: true } })
    expect(p.isPublished).toBe(true)
    expect(p.days).toBe(0)
    expect(p.lessons).toHaveLength(0)
  })

  it('keeps the 0-member base group (the picker hides it)', async () => {
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID, isActive: true } })).toBe(0)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run fixtures/__tests__/groups-enroll-program.db.test.ts` → FAIL, `Failed to resolve import "../screens/groups-enroll-program.js"` (with `FIXTURES_TEST_DATABASE_URL` unset the suite skips once the import resolves — that is the harness's documented behaviour; `npx tsc --noEmit -p fixtures` is the always-on check)

- [ ] **Step 3: Write the layer** — `server/fixtures/screens/groups-enroll-program.ts`

```ts
/**
 * groups-enroll-program layer (ui2-enrollment-create D12): one layer for the New-enrollment checklist
 * and its six pickers. Base already gives the walk the 0-member group (FIXTURE_EMPTY_GROUP_ID, hidden
 * by the group picker), group 1 with its active enrollment 4 (the already-enrolled warning) and the
 * study-program-home layer's unpublished 0-lesson program 4 (hidden). This layer adds:
 *  - program n 5 "Romans in 12 Days" — published, 12 lessons — with one enrollment on base group 2
 *    that ended before ctx.now (the program picker's completed count reads 1);
 *  - program n 6 "Coming Soon Study" — published with days 0 and no lessons (hidden by the picker).
 * Ids from a fresh n 900+ range. Creates no org, user or group; wipe.ts removes the programs (and
 * their lessons, enrollments and schedules by cascade) with the fixture org.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const ENROLL_PROGRAM_ID = fixtureId('program', 5)
export const ENROLL_PROGRAM_NAME = 'Romans in 12 Days'
export const ENROLL_EMPTY_PROGRAM_ID = fixtureId('program', 6)
export const ENROLL_PROGRAM_DAYS = 12
export const ENROLL_ENDED_ENROLLMENT_ID = fixtureId('enrollment', 900)
const lessonIdFor = (day: number) => fixtureId('lesson', 900_000 + day)
const scheduleIdFor = (day: number) => fixtureId('schedule', 900_000 + day)

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.studyProgram.createMany({
    data: [
      {
        id: ENROLL_PROGRAM_ID,
        name: ENROLL_PROGRAM_NAME,
        description: 'Twelve short readings through Paul\'s letter to the Romans.',
        days: ENROLL_PROGRAM_DAYS,
        creatorId: FIXTURE_USER_ID,
        leaderId: FIXTURE_USER_ID,
        organizationId: FIXTURE_ORG_ID,
        isPublished: true,
        publishedAt: ctx.daysAgo(60),
        createdAt: ctx.daysAgo(60),
      },
      {
        id: ENROLL_EMPTY_PROGRAM_ID,
        name: 'Coming Soon Study',
        days: 0,
        creatorId: FIXTURE_USER_ID,
        leaderId: FIXTURE_USER_ID,
        organizationId: FIXTURE_ORG_ID,
        isPublished: true,
        publishedAt: ctx.daysAgo(2),
        createdAt: ctx.daysAgo(2),
      },
    ],
  })
  const days = Array.from({ length: ENROLL_PROGRAM_DAYS }, (_, i) => i + 1)
  await prisma.lesson.createMany({
    data: days.map((day) => ({ id: lessonIdFor(day), studyProgramId: ENROLL_PROGRAM_ID, dayNumber: day, title: `Day ${day}` })),
  })
  // Ran days −40 … −29: ended before today, so it counts as completed (D8/D17).
  await prisma.enrollment.create({
    data: {
      id: ENROLL_ENDED_ENROLLMENT_ID,
      groupId: FIXTURE_GROUP_IDS[1],
      studyProgramId: ENROLL_PROGRAM_ID,
      startDate: ctx.at(-40, 12),
      endDate: ctx.at(-29, 12),
      enabledDays: JSON.stringify(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
      smsTime: '08:00',
      timezone: 'America/Chicago',
      createdById: FIXTURE_USER_ID,
      createdAt: ctx.daysAgo(41),
    },
  })
  await prisma.lessonSchedule.createMany({
    data: days.map((day) => ({
      id: scheduleIdFor(day),
      enrollmentId: ENROLL_ENDED_ENROLLMENT_ID,
      lessonId: lessonIdFor(day),
      scheduledDate: ctx.at(-41 + day, 12),
      title: `Day ${day}`,
    })),
  })
}
```

Before running: confirm `ctx.at(offset, hour)` exists on `FixtureContext` (`fixtures/context.ts:139-160`) — `base.ts:296` calls it as `ctx.at(e.startOffset, 12)`; confirm `fixtureId('lesson', …)`/`('schedule', …)` accept 900 001+ (`MAX_N` in `ids.ts`); confirm `wipe.ts` deletes by `organizationId: FIXTURE_ORG_ID` (`wipe.ts:27`). If a lesson/schedule field above does not exist on the model, drop it rather than invent one.

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx tsc --noEmit -p fixtures` → clean; `cd server && npx vitest run fixtures/__tests__/groups-enroll-program.db.test.ts fixtures/__tests__/runner.test.ts` → PASS (or the documented skip line when `FIXTURES_TEST_DATABASE_URL` is unset); `cd server && npm run test:run` → green

- [ ] **Step 5: Record the contract freeze** — the server phase is the producer; this is its last task. Write the manifest line without a commit of its own, so it rides in this task's one commit:

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.5.0/scripts/advance.mjs docs/features/ui2-enrollment-create --set "contract=frozen $(date +%F)" --no-commit
git add docs/features/ui2-enrollment-create/MANIFEST.md
```

(if the brief names a different `<builder>` path, use it; if `advance.mjs` refuses to run without `--commit`, set the `contract:` line in `MANIFEST.md` to `frozen YYYY-MM-DD` by hand instead). From here §Contract is not edited to suit a consumer — a needed change is a `/builder:revise`.

- [ ] **Step 6: Commit** — `feat(ui2-enrollment-create): groups-enroll-program fixture layer (D12); contract frozen` — the layer, its DB test and `MANIFEST.md`

### Task 7: models — `lessonAccess`, `syncMode`, `completedEnrollmentCount` (T6)
App: iphone
Phase: 3
Recipe: SPEC §iphone *Models* · tiny

**Files:**
- Modify: `iphone/MakeReady/State/Models/EnrollmentModels.swift:17-172` (`EnrollmentWithProgram`)
- Modify: `iphone/MakeReady/State/Models/StudyModels.swift:19-175` (`StudyProgram`)
- Modify: `iphone/MakeReady/State/Actions/EnrollmentActions.swift:1243` (`Enrollment`, the POST response)
- Create: `iphone/MakeReadyCaptureTests/EnrollmentCreateModelTests.swift` (register in target `MakeReadyCaptureTests`)

**Interfaces:**
- Produces: `EnrollmentWithProgram.lessonAccess: String?`, `EnrollmentWithProgram.syncMode: String?`; `StudyProgram.completedEnrollmentCount: Int?`; `Enrollment.lessonAccess: String?`, `Enrollment.syncMode: String?`. All decode with `decodeIfPresent` and encode with `encodeIfPresent` — a cache written by a released build (no keys) decodes them nil; no `schemaVersion` bump.

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/EnrollmentCreateModelTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create T6: the new wire fields decode tolerantly and survive the disk cache.
final class EnrollmentCreateModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.apiDecoder.decode(T.self, from: Data(json.utf8))
    }

    func testEnrollmentWithProgramDecodesLessonAccessAndSyncMode() throws {
        let e = try decode(EnrollmentWithProgram.self,
            #"{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-20T06:00:00.000Z","lessonAccess":"ONE_AT_A_TIME","syncMode":"OFF"}"#)
        XCTAssertEqual(e.lessonAccess, "ONE_AT_A_TIME")
        XCTAssertEqual(e.syncMode, "OFF")
        let round = try JSONDecoder.apiDecoder.decode(EnrollmentWithProgram.self, from: JSONEncoder.apiEncoder.encode(e))
        XCTAssertEqual(round.lessonAccess, "ONE_AT_A_TIME")
        XCTAssertEqual(round.syncMode, "OFF")
    }

    func testEnrollmentWithProgramWithoutTheKeysDecodesNil() throws {
        let e = try decode(EnrollmentWithProgram.self,
            #"{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z"}"#)
        XCTAssertNil(e.lessonAccess)
        XCTAssertNil(e.syncMode)
    }

    func testStudyProgramDecodesCompletedEnrollmentCount() throws {
        let p = try decode(StudyProgram.self,
            #"{"id":"p1","name":"Romans","days":12,"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","completedEnrollmentCount":3}"#)
        XCTAssertEqual(p.completedEnrollmentCount, 3)
        let round = try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: JSONEncoder.apiEncoder.encode(p))
        XCTAssertEqual(round.completedEnrollmentCount, 3)
        let old = try decode(StudyProgram.self,
            #"{"id":"p1","name":"Romans","days":12,"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z"}"#)
        XCTAssertNil(old.completedEnrollmentCount)
    }

    func testCreateResponseEnrollmentDecodesTheNewFields() throws {
        let e = try decode(Enrollment.self,
            #"{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-20T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}"#)
        XCTAssertEqual(e.lessonAccess, "ALL_AT_ONCE")
        XCTAssertEqual(e.syncMode, "AUTO")
    }
}
```

Check the encoder/decoder names the existing decoding tests use (`MakeReadyCaptureTests/ProgramDecodingTests.swift`) — if the encoder is not `JSONEncoder.apiEncoder`, use theirs.

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → build FAILS, `value of type 'EnrollmentWithProgram' has no member 'lessonAccess'`

- [ ] **Step 3: Implement**
  - `EnrollmentWithProgram`: add `var lessonAccess: String?` and `var syncMode: String?` (with a `/// ui2-enrollment-create T6: …` comment: server raw values, nil on a cache from before); `case lessonAccess, syncMode` in `CodingKeys`; `lessonAccess = try container.decodeIfPresent(String.self, forKey: .lessonAccess)` and the same for `syncMode` in `init(from:)`; `try container.encodeIfPresent(lessonAccess, forKey: .lessonAccess)` / `syncMode` in `encode(to:)`; memberwise init gains `lessonAccess: String? = nil, syncMode: String? = nil` (last two parameters) assigning both.
  - `StudyProgram`: add `var completedEnrollmentCount: Int?` (`/// ui2-enrollment-create D8: enrollments that ended before today; nil on an old cache`), `case completedEnrollmentCount` in `CodingKeys`, `decodeIfPresent(Int.self, forKey: .completedEnrollmentCount)` and `encodeIfPresent`; its memberwise `init(` (`StudyModels.swift:176`) gains `completedEnrollmentCount: Int? = nil` as its last parameter.
  - `Enrollment` (`EnrollmentActions.swift:1243`): add `let lessonAccess: String?` and `let syncMode: String?` (synthesized `Codable` treats optionals as `decodeIfPresent`).

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `EnrollmentCreateModelTests` 4/4 pass, the suite green; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violation

- [ ] **Step 5: Commit** — `feat(ui2-enrollment-create): enrollment and program models carry lessonAccess, syncMode and completedEnrollmentCount (T6)`

### Task 8: `createEnrollment` sends exact dates + access and refreshes the stores (T9, T13)
App: iphone
Phase: 3
Recipe: `/ios-error-surface` · SPEC §iphone *After create* · §Contract *Wire ↔ app mapping*

**Files:**
- Modify: `iphone/MakeReady/State/Actions/EnrollmentActions.swift:209-268`
- Create: `iphone/MakeReadyCaptureTests/EnrollmentCreateActionTests.swift` (register in `MakeReadyCaptureTests`)

**Interfaces:**
- Consumes: `Enrollment.lessonAccess/syncMode` (Task 7)
- Produces:
  - `enum EnrollmentWire` (in `EnrollmentActions.swift`): `static let dayNames = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]`; `static func dayNames(_ days: Set<Int>) -> [String]` (0 = Sun … 6 = Sat, week order); `static func ymd(_ date: Date, in zone: TimeZone = .current) -> String`; `static func lessonAccessWire(_ screen: String) -> String?` (`"one-at-a-time"` → `"ONE_AT_A_TIME"`, `"all-at-once"` → `"ALL_AT_ONCE"`, else nil)
  - `createEnrollment(groupId:studyProgramId:startDate:enabledDays:smsTime:timezone:requireResponse:syncMode:scheduleDates:lessonAccess:)` — two new trailing parameters `scheduleDates: [Date]? = nil`, `lessonAccess: String? = nil` (wire value). With `scheduleDates`, the body carries `scheduleDates: [yyyy-MM-dd]` formatted in `TimeZone.current`; with `lessonAccess`, `lessonAccess`. Existing callers compile unchanged.
  - After a successful create the Action reloads `loadEnrollments(groupId:)` and `ProgramActions(api:state:).getProgramEnrollments(programId:forceRefresh: true)` and clears `state.nextStudyByGroupId[groupId]`; a refresh failure is recorded console-only and does not fail the create.

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/EnrollmentCreateActionTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create T9/T13: the POST body the 2.0 checklist sends, and the stores it refreshes.
@MainActor
final class EnrollmentCreateActionTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let created = #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-12T06:00:00.000Z","enabledDays":"[\"Mon\",\"Wed\"]","smsTime":"07:30","timezone":"America/Chicago","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ONE_AT_A_TIME","syncMode":"OFF"}}"#

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }

    func testWireHelpers() {
        XCTAssertEqual(EnrollmentWire.dayNames([3, 1, 0]), ["Sun", "Mon", "Wed"])
        XCTAssertEqual(EnrollmentWire.ymd(day("2035-01-08")), "2035-01-08")
        XCTAssertEqual(EnrollmentWire.lessonAccessWire("one-at-a-time"), "ONE_AT_A_TIME")
        XCTAssertEqual(EnrollmentWire.lessonAccessWire("all-at-once"), "ALL_AT_ONCE")
        XCTAssertNil(EnrollmentWire.lessonAccessWire(""))
    }

    func testBodyCarriesScheduleDatesLessonAccessSyncModeAndWeekdayNames() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/programs/") ? APIError.serverError("not stubbed") : nil }
        let e = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: EnrollmentWire.dayNames([1, 3]), smsTime: "07:30", timezone: "America/Chicago",
            syncMode: .off,
            scheduleDates: [day("2035-01-08"), day("2035-01-10"), day("2035-01-12")],
            lessonAccess: "ONE_AT_A_TIME")
        XCTAssertEqual(e.lessonAccess, "ONE_AT_A_TIME")
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertEqual(body?["scheduleDates"] as? [String], ["2035-01-08", "2035-01-10", "2035-01-12"])
        XCTAssertEqual(body?["lessonAccess"] as? String, "ONE_AT_A_TIME")
        XCTAssertEqual(body?["syncMode"] as? String, "OFF")
        XCTAssertEqual(body?["enabledDays"] as? [String], ["Mon", "Wed"])
        XCTAssertEqual(body?["smsTime"] as? String, "07:30")
        XCTAssertEqual(body?["timezone"] as? String, "America/Chicago")
    }

    func testOmitsTheNewKeysWhenNotGiven() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        _ = try? await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: ["Mon"], smsTime: nil, timezone: nil)
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertNil(body?["scheduleDates"])
        XCTAssertNil(body?["lessonAccess"])
    }

    func testRefreshesTheGroupsEnrollmentsAndClearsNextStudyAfterCreate() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        _ = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: ["Mon"], smsTime: nil, timezone: nil)
        XCTAssertEqual(api.callCount("GET", "/api/groups/g1/enrollments"), 1)
        XCTAssertTrue(api.calls.contains { $0.method == "GET" && $0.endpoint.hasPrefix("/api/programs/p1") })
        XCTAssertNil(state.nextStudyByGroupId["g1"])
    }

    func testARefreshFailureDoesNotFailTheCreate() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/groups/") || endpoint.hasPrefix("/api/programs/") ? APIError.serverError("down") : nil }
        let e = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: ["Mon"], smsTime: nil, timezone: nil)
        XCTAssertEqual(e.id, "e9")
        XCTAssertNil(state.activeSurfacedError)
    }
}
```

Read `loadEnrollments(groupId:)` (`EnrollmentActions.swift:104-143`) for the exact GET path and JSON shape it decodes, and `getProgramEnrollments` (`ProgramActions.swift:785`) for its path; fix the stubbed paths/JSON to match them (the assertions on the POST body stay as written).

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → build FAILS, `cannot find 'EnrollmentWire' in scope`

- [ ] **Step 3: Implement** — in `EnrollmentActions.swift`, above `// MARK: - Create Enrollment`'s struct extension or at file scope after the struct:

```swift
/// ui2-enrollment-create §Contract *Wire ↔ app mapping*: the transforms between the draft's
/// forms and POST /api/enrollments, written once.
enum EnrollmentWire {
    static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// 0 = Sun … 6 = Sat → the server's day names, in week order (the 1.0 map).
    static func dayNames(_ days: Set<Int>) -> [String] {
        days.sorted().compactMap { dayNames.indices.contains($0) ? dayNames[$0] : nil }
    }

    private static let ymdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// D16: a calendar day as the server reads it — formatted in the calendar's zone.
    static func ymd(_ date: Date, in zone: TimeZone = .current) -> String {
        ymdFormatter.timeZone = zone
        return ymdFormatter.string(from: date)
    }

    /// The screen's kebab value → the server enum (nil = not chosen).
    static func lessonAccessWire(_ screen: String) -> String? {
        switch screen {
        case "one-at-a-time": return "ONE_AT_A_TIME"
        case "all-at-once": return "ALL_AT_ONCE"
        default: return nil
        }
    }
}
```

`createEnrollment` gains `scheduleDates: [Date]? = nil, lessonAccess: String? = nil` after `syncMode`, and before the `Response` struct:

```swift
        // ui2-enrollment-create D3/D16: the calendar's exact days, in its own zone.
        if let scheduleDates {
            body["scheduleDates"] = scheduleDates.map { EnrollmentWire.ymd($0) }
        }
        if let lessonAccess {                                   // D4: ONE_AT_A_TIME | ALL_AT_ONCE
            body["lessonAccess"] = lessonAccess
        }
```

After `state.persist()` and before the log line:

```swift
        // T13: the index adds alone left loadEnrollmentCounts skipping this group and the group /
        // program pages without the new row — reload what they read. Background: a failure here
        // never fails the create.
        state.nextStudyByGroupId[groupId] = nil
        do { _ = try await loadEnrollments(groupId: groupId) } catch {
            state.recordError(error, context: "EnrollmentActions.createEnrollment.refreshGroup")
        }
        do { _ = try await ProgramActions(api: api, state: state).getProgramEnrollments(programId: studyProgramId, forceRefresh: true) } catch {
            state.recordError(error, context: "EnrollmentActions.createEnrollment.refreshProgram")
        }
```

(`EnrollmentActions` stores its `api`/`state` from `init(api:state:)` at `:26` — use the stored names that file uses.)

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `EnrollmentCreateActionTests` 5/5, suite green; swiftlint from `iphone/` → no new violation (the `ymdFormatter` is `static`, as the formatter rule requires)

- [ ] **Step 5: Commit** — `feat(ui2-enrollment-create): createEnrollment sends exact dates and lesson access, refreshes group and program enrollments (T9, T13)`

### Task 9: `EnrollmentDraft` in `AppState` + the checklist mapper (D9, D10, D13, T7, T8)
App: iphone
Phase: 3
Recipe: SPEC §iphone *Draft* · iphone/.claude/CLAUDE.md §Where does this data live

**Build-time risk carried here:** **A4** — `EnrollmentDateState.calculatedEndDate` stops at its iteration cap short of `lessonCount` (`MakeReadyUI/EnrollCalendar.swift:154-174`): `EnrollScheduleMath.dates` asserts `count == lessonCount` and returns `nil` otherwise, which leaves the schedule row not done.

**Files:**
- Create: `iphone/MakeReady/State/EnrollmentDraft.swift` (target `MakeReady`)
- Modify: `iphone/MakeReady/State/AppState.swift` (property + 4 methods near `:452`; `clearInMemory()` `:845`)
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollChecklistMapper.swift` (target `MakeReady`)
- Create: `iphone/MakeReadyCaptureTests/EnrollmentDraftTests.swift`, `iphone/MakeReadyCaptureTests/EnrollChecklistMapperTests.swift` (target `MakeReadyCaptureTests`)

**Interfaces:**
- Produces (`EnrollmentDraft.swift`):

```swift
struct EnrollmentDraft: Equatable {
    enum Phase: String { case checklist, processing, enrolled }
    let id: UUID
    var groupId: String?
    var studyProgramId: String?
    var startDate: Date?
    var enabledDays: Set<Int> = []          // 0 = Sun … 6 = Sat
    var overriddenDates: Set<Date> = []
    var scheduleDates: [Date] = []           // [] = schedule not done
    var endDate: Date?
    var smsTime: String?                     // "HH:mm"
    var timezone: String?
    var syncMode: String?                    // "AUTO" | "OFF"
    var lessonAccess: String?                // "one-at-a-time" | "all-at-once"
    var phase: Phase = .checklist
    var scheduleDone: Bool
    mutating func setProgram(_ id: String?)  // design rule 2
}
enum EnrollScheduleMath {
    static func dates(start: Date, days: Set<Int>, overrides: Set<Date>, lessonCount: Int) -> [Date]?
}
```

- Produces (`AppState`): `var enrollmentDrafts: [UUID: EnrollmentDraft]` (memory-only — `PersistedState` never encodes it, D13); `func startEnrollmentDraft(groupId: String?, studyProgramId: String?) -> UUID`; `func updateEnrollmentDraft(_ id: UUID, _ change: (inout EnrollmentDraft) -> Void)`; `func endEnrollmentDraft(_ id: UUID)`; `func pruneEnrollmentDrafts(keeping ids: Set<UUID>)`.
- Produces (`EnrollChecklistMapper`): `static func state(_ draft: EnrollmentDraft, group: UserGroup?, program: StudyProgram?, today: Date = Date()) -> GroupsEnrollProgramScreen.State`; `static func preloadedGroupId(_ id: String?, groups: [UserGroup]) -> String?`; `static func preloadedProgramId(_ id: String?, programs: [StudyProgram]) -> String?`; `static func isEligible(_ g: UserGroup) -> Bool` (`memberCount >= 1`); `static func isEligible(_ p: StudyProgram) -> Bool` (`isPublished == true && days >= 1`); `static func longDate(_ d: Date) -> String` ("January 3rd, 2025"); `static func initials(_ name: String) -> String`.

- [ ] **Step 1: Write the failing tests**

`iphone/MakeReadyCaptureTests/EnrollmentDraftTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create D9/D10/D13: the draft's lifetime and design rules 1–2.
@MainActor
final class EnrollmentDraftTests: XCTestCase {
    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }

    func testStartUpdateEndAndPrune() {
        let state = AppState()
        let a = state.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        let b = state.startEnrollmentDraft(groupId: nil, studyProgramId: "p1")
        XCTAssertEqual(state.enrollmentDrafts[a]?.groupId, "g1")
        state.updateEnrollmentDraft(a) { $0.smsTime = "07:30" }
        XCTAssertEqual(state.enrollmentDrafts[a]?.smsTime, "07:30")
        state.pruneEnrollmentDrafts(keeping: [b])
        XCTAssertNil(state.enrollmentDrafts[a])
        state.endEnrollmentDraft(b)
        XCTAssertTrue(state.enrollmentDrafts.isEmpty)
    }

    func testClearAllDataClearsDrafts() {
        let state = AppState()
        _ = state.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        state.clearAllData()
        XCTAssertTrue(state.enrollmentDrafts.isEmpty)
    }

    func testProgramChangeUndoesTheScheduleButKeepsItsSeed() {
        var d = EnrollmentDraft(id: UUID())
        d.setProgram("p1")
        d.startDate = day("2035-01-08"); d.enabledDays = [1, 3]; d.overriddenDates = [day("2035-01-10")]
        d.scheduleDates = [day("2035-01-08")]; d.endDate = day("2035-01-08")
        XCTAssertTrue(d.scheduleDone)
        d.setProgram("p1")                                  // same program: nothing changes
        XCTAssertTrue(d.scheduleDone)
        d.setProgram("p2")
        XCTAssertFalse(d.scheduleDone)
        XCTAssertEqual(d.startDate, day("2035-01-08"))
        XCTAssertEqual(d.enabledDays, [1, 3])
        XCTAssertEqual(d.overriddenDates, [day("2035-01-10")])
        XCTAssertNil(d.endDate)
    }

    func testScheduleMathMatchesTheCalendarAndRefusesAShortList() {
        // Mon/Wed from Mon 2035-01-08, skipping Wed 01-10 by override → 01-08, 01-15, 01-17
        let dates = EnrollScheduleMath.dates(start: day("2035-01-08"), days: [1, 3],
                                             overrides: [day("2035-01-10")], lessonCount: 3)
        XCTAssertEqual(dates, [day("2035-01-08"), day("2035-01-15"), day("2035-01-17")])
        XCTAssertNil(EnrollScheduleMath.dates(start: day("2035-01-08"), days: [], overrides: [], lessonCount: 3)) // A4
    }
}
```

`iphone/MakeReadyCaptureTests/EnrollChecklistMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create T8: draft → GroupsEnrollProgramScreen.State (design §3 rows), D10 preloads.
final class EnrollChecklistMapperTests: XCTestCase {
    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }
    private func group(_ id: String, members: Int) throws -> UserGroup {
        try JSONDecoder.apiDecoder.decode(UserGroup.self, from: Data(
            #"{"id":"\#(id)","code":"C1","name":"Young Professionals","isPrivate":false,"allowInvites":true,"memberDirectory":true,"memberCount":\#(members),"creatorId":"u1","creatorName":"Tony Stark","createdAt":"2025-01-03T12:00:00.000Z","updatedAt":"2025-01-03T12:00:00.000Z","coverImageUrl":"https://x/g.png"}"#.utf8))
    }
    private func program(_ id: String, days: Int, published: Bool) throws -> StudyProgram {
        try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: Data(
            #"{"id":"\#(id)","name":"Romans in 30 days","description":"A deep dive","days":\#(days),"isPublished":\#(published),"coverImageUrl":"https://x/p.png","createdAt":"2025-01-01T00:00:00.000Z","updatedAt":"2025-01-01T00:00:00.000Z"}"#.utf8))
    }

    func testEmptyDraftIsZeroOfSixAndDefaultsNeverCountAsDone() {
        let s = EnrollChecklistMapper.state(EnrollmentDraft(id: UUID()), group: nil, program: nil)
        XCTAssertEqual(s.phase, "checklist")
        XCTAssertEqual(s.groupName, "")
        XCTAssertEqual(s.programName, "")
        XCTAssertEqual(s.scheduleStartDay, "")
        XCTAssertEqual(s.smsTime, "")
        XCTAssertEqual(s.syncMode, "")
        XCTAssertEqual(s.lessonAccess, "")
    }

    func testGroupAndProgramRows() throws {
        var d = EnrollmentDraft(id: UUID()); d.groupId = "g1"; d.setProgram("p1")
        let s = EnrollChecklistMapper.state(d, group: try group("g1", members: 13), program: try program("p1", days: 30, published: true))
        XCTAssertEqual(s.groupName, "Young Professionals")
        XCTAssertEqual(s.groupInitials, "YP")
        XCTAssertEqual(s.groupImageURL, "https://x/g.png")
        XCTAssertEqual(s.groupActiveMembers, 13)
        XCTAssertTrue(s.groupCreatedOn.hasPrefix("January 3rd, 2025") || s.groupCreatedOn.hasPrefix("January 2nd, 2025")) // device zone
        XCTAssertEqual(s.programName, "Romans in 30 days")
        XCTAssertEqual(s.programDescription, "A deep dive")
    }

    func testScheduleRowAndTheRestWhenDone() {
        var d = EnrollmentDraft(id: UUID()); d.setProgram("p1")
        d.startDate = day("2035-01-08"); d.enabledDays = [5, 1, 3]
        d.scheduleDates = [day("2035-01-08"), day("2035-01-10")]; d.endDate = day("2035-10-18")
        d.smsTime = "07:30"; d.syncMode = "OFF"; d.lessonAccess = "one-at-a-time"
        let s = EnrollChecklistMapper.state(d, group: nil, program: nil, today: day("2035-01-08"))
        XCTAssertEqual(s.scheduleStartWeekday, "Monday")
        XCTAssertEqual(s.scheduleStartMonth, "January")
        XCTAssertEqual(s.scheduleStartDay, "8")
        XCTAssertTrue(s.scheduleStartToday)
        XCTAssertEqual(s.scheduleWeekdays, ["Monday", "Wednesday", "Friday"])
        XCTAssertEqual(s.scheduleEndDate, "October 18th, 2035")
        XCTAssertEqual(s.smsTime, "07:30")
        XCTAssertEqual(s.syncMode, "OFF")
        XCTAssertEqual(s.lessonAccess, "one-at-a-time")
    }

    func testScheduleNotDoneMapsEmptyEvenWithASeed() {
        var d = EnrollmentDraft(id: UUID()); d.startDate = day("2035-01-08"); d.enabledDays = [1]
        XCTAssertEqual(EnrollChecklistMapper.state(d, group: nil, program: nil).scheduleStartDay, "")
    }

    func testPhaseIsPassedThrough() {
        var d = EnrollmentDraft(id: UUID()); d.phase = .processing
        XCTAssertEqual(EnrollChecklistMapper.state(d, group: nil, program: nil).phase, "processing")
    }

    func testPreloadsPassOnlyWhenEligible() throws {   // D10 / design rule 1
        let groups = [try group("g1", members: 3), try group("g0", members: 0)]
        XCTAssertEqual(EnrollChecklistMapper.preloadedGroupId("g1", groups: groups), "g1")
        XCTAssertNil(EnrollChecklistMapper.preloadedGroupId("g0", groups: groups))
        XCTAssertNil(EnrollChecklistMapper.preloadedGroupId("gX", groups: groups))
        let programs = [try program("p1", days: 12, published: true), try program("p2", days: 0, published: true),
                        try program("p3", days: 5, published: false)]
        XCTAssertEqual(EnrollChecklistMapper.preloadedProgramId("p1", programs: programs), "p1")
        XCTAssertNil(EnrollChecklistMapper.preloadedProgramId("p2", programs: programs))
        XCTAssertNil(EnrollChecklistMapper.preloadedProgramId("p3", programs: programs))
    }

    func testLongDateOrdinals() {
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-01")), "January 1st, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-02")), "January 2nd, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-03")), "January 3rd, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-11")), "January 11th, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-22")), "January 22nd, 2035")
    }
}
```

Copy a valid `UserGroup` JSON from `MakeReadyCaptureTests/GroupsBrowseDecodingTests.swift` if the one above is missing a required key.

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → build FAILS, `cannot find 'EnrollmentDraft' in scope`

- [ ] **Step 3: Write the draft** — `iphone/MakeReady/State/EnrollmentDraft.swift`

```swift
import Foundation

/// ui2-enrollment-create D9: one "New enrollment" flow's choices — the checklist's source of truth.
/// Each picker writes it only on Select/Save; row done/disabled is derived on read, never stored.
/// Memory-only (D13): `PersistedState` never encodes it, so a relaunch or sign-out discards it.
struct EnrollmentDraft: Equatable {
    enum Phase: String { case checklist, processing, enrolled }

    let id: UUID
    var groupId: String?
    private(set) var studyProgramId: String?
    var startDate: Date?
    var enabledDays: Set<Int> = []
    var overriddenDates: Set<Date> = []
    var scheduleDates: [Date] = []
    var endDate: Date?
    var smsTime: String?
    var timezone: String?
    var syncMode: String?
    var lessonAccess: String?
    var phase: Phase = .checklist

    init(id: UUID, groupId: String? = nil, studyProgramId: String? = nil) {
        self.id = id
        self.groupId = groupId
        self.studyProgramId = studyProgramId
    }

    /// The schedule row is done once its exact dates exist (A4: a short list is never stored).
    var scheduleDone: Bool { startDate != nil && !scheduleDates.isEmpty }

    /// Design rule 2: a different program un-does the schedule but keeps start / weekdays /
    /// overrides as the schedule picker's seed. Picking the same program changes nothing.
    mutating func setProgram(_ id: String?) {
        guard id != studyProgramId else { return }
        studyProgramId = id
        scheduleDates = []
        endDate = nil
    }
}

/// The calendar's own rule (MakeReadyUI's `EnrollmentDateState`, the 1.0 port) — never re-implemented.
enum EnrollScheduleMath {
    /// One date per lesson, start-of-day, ascending; nil when the rule cannot reach `lessonCount`
    /// (A4: the port's iteration cap) or there is no lesson.
    @MainActor
    static func dates(start: Date, days: Set<Int>, overrides: Set<Date>, lessonCount: Int) -> [Date]? {
        guard lessonCount > 0, !days.isEmpty else { return nil }
        let scratch = EnrollmentDateState(lessonCount: lessonCount)
        scratch.startDate = start
        scratch.enabledDays = days
        scratch.overriddenDates = overrides
        let dates = scratch.highlightedDates.sorted()
        return dates.count == lessonCount ? dates : nil
    }
}
```

If `EnrollmentDateState` is not `@MainActor`-isolated, drop the attribute (and the test's `@MainActor` stays harmless). If `private(set)` on `studyProgramId` breaks the memberwise use elsewhere, keep it `private(set)` and route every write through `setProgram`.

- [ ] **Step 4: Add it to `AppState`** — next to `groupLeaders` (`AppState.swift:452`):

```swift
    // MARK: - Enrollment drafts (ui2-enrollment-create D9/D13)

    /// One per open "New enrollment" flow, keyed by the flow id its routes carry. Memory-only:
    /// `PersistedState` never encodes it (D13); `clearInMemory()` empties it.
    var enrollmentDrafts: [UUID: EnrollmentDraft] = [:]

    func startEnrollmentDraft(groupId: String?, studyProgramId: String?) -> UUID {
        let id = UUID()
        enrollmentDrafts[id] = EnrollmentDraft(id: id, groupId: groupId, studyProgramId: studyProgramId)
        return id
    }

    func updateEnrollmentDraft(_ id: UUID, _ change: (inout EnrollmentDraft) -> Void) {
        guard var draft = enrollmentDrafts[id] else { return }
        change(&draft)
        enrollmentDrafts[id] = draft
    }

    func endEnrollmentDraft(_ id: UUID) { enrollmentDrafts[id] = nil }

    /// D13: a flow whose checklist left every stack (back-swipe, Home re-tap) loses its draft.
    func pruneEnrollmentDrafts(keeping ids: Set<UUID>) {
        enrollmentDrafts = enrollmentDrafts.filter { ids.contains($0.key) }
    }
```

and `enrollmentDrafts = [:]` inside `clearInMemory()`.

- [ ] **Step 5: Write the checklist mapper** — `iphone/MakeReady/UI2/Containers/Enrollments/EnrollChecklistMapper.swift`

```swift
import Foundation

/// ui2-enrollment-create T8: draft → `GroupsEnrollProgramScreen.State`, the design's §3 rows. The
/// screen derives done/disabled from these strings ("" = to do), so a value the draft has not got
/// maps to "" — defaults never count as done (design rule 1). Pure.
enum EnrollChecklistMapper {
    static func isEligible(_ group: UserGroup) -> Bool { group.memberCount >= 1 }               // D5
    static func isEligible(_ program: StudyProgram) -> Bool { program.isPublished == true && program.days >= 1 }

    /// D10: a preloaded group counts only when it is eligible; otherwise it arrives not done.
    static func preloadedGroupId(_ id: String?, groups: [UserGroup]) -> String? {
        guard let id, let g = groups.first(where: { $0.id == id }), isEligible(g) else { return nil }
        return id
    }

    static func preloadedProgramId(_ id: String?, programs: [StudyProgram]) -> String? {
        guard let id, let p = programs.first(where: { $0.id == id }), isEligible(p) else { return nil }
        return id
    }

    static func state(_ draft: EnrollmentDraft, group: UserGroup?, program: StudyProgram?,
                      today: Date = Date()) -> GroupsEnrollProgramScreen.State {
        let cal = Calendar.current
        let start = draft.scheduleDone ? draft.startDate : nil
        return GroupsEnrollProgramScreen.State(
            phase: draft.phase.rawValue,
            groupName: group?.name ?? "",
            groupInitials: group.map { initials($0.name) } ?? "",
            groupImageURL: group?.coverImageUrl ?? "",
            groupCreatedOn: group.map { longDate($0.createdAt) } ?? "",
            groupActiveMembers: group?.memberCount ?? 0,
            programName: program?.name ?? "",
            programDescription: program?.description ?? "",
            programImageURL: program?.coverImageUrl ?? "",
            scheduleStartWeekday: start.map { format($0, "EEEE") } ?? "",
            scheduleStartMonth: start.map { format($0, "MMMM") } ?? "",
            scheduleStartDay: start.map { String(cal.component(.day, from: $0)) } ?? "",
            scheduleStartToday: start.map { cal.isDate($0, inSameDayAs: today) } ?? false,
            scheduleWeekdays: start == nil ? [] : draft.enabledDays.sorted().compactMap { fullDayNames.indices.contains($0) ? fullDayNames[$0] : nil },
            scheduleEndDate: (draft.scheduleDone ? draft.endDate : nil).map(longDate) ?? "",
            smsTime: draft.smsTime ?? "",
            syncMode: draft.syncMode ?? "",
            lessonAccess: draft.lessonAccess ?? ""
        )
    }

    static let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// "January 3rd, 2025" — the design's §3 date form.
    static func longDate(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return "\(format(date, "MMMM")) \(day)\(ordinal(day)), \(format(date, "yyyy"))"
    }

    static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private static func ordinal(_ day: Int) -> String {
        if (11...13).contains(day % 100) { return "th" }
        switch day % 10 { case 1: return "st"; case 2: return "nd"; case 3: return "rd"; default: return "th" }
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func format(_ date: Date, _ pattern: String) -> String {
        formatter.timeZone = .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
```

Register both new files in target `MakeReady` and both test files in `MakeReadyCaptureTests` (plan note), then `ruby scripts/capture-targets.rb`.

- [ ] **Step 6: Run them and watch them pass** — `npm run ios:build-check -- --test` → `EnrollmentDraftTests` 4/4, `EnrollChecklistMapperTests` 7/7, suite green; swiftlint from `iphone/` → no new violation

- [ ] **Step 7: Commit** — `feat(ui2-enrollment-create): memory-only EnrollmentDraft in AppState and the checklist mapper (D9, D10, D13)`

### Task 10: picker mappers — group (D5, D14, D19), program (D5, D17, D19), schedule seed (T8, T10)
App: iphone
Phase: 3
Recipe: SPEC §iphone *Picker containers*, *Org/Leader chips* · §Contract *Wire ↔ app mapping*

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupMapper.swift` (`eligibleOnly`, `organizations`, `pickedOrgIds`, `selectedId` inputs; defaults keep invite as today)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupContainer.swift:20` (D14: count `isActive` only)
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectProgramMapper.swift`
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectScheduleMapper.swift`
- Modify: `iphone/MakeReadyCaptureTests/InviteSelectGroupMapperTests.swift`
- Create: `iphone/MakeReadyCaptureTests/EnrollPickerMapperTests.swift`

**Interfaces:**
- Consumes: `EnrollmentDraft`, `EnrollChecklistMapper.isEligible(_:)` (Task 9); `StudyProgram.completedEnrollmentCount` (Task 7)
- Produces:
  - `InviteSelectGroupMapper.Input` gains `eligibleOnly: Bool = false`, `organizations: [OrganizationData] = []`, `pickedOrgIds: Set<String> = []`, `selectedId: String? = nil`; `Output` gains `orgOptions: [LeaderOption]`. With `organizations.count > 1` the Orgs chip shows (`orgFilterVisible`) and `pickedOrgIds` narrows by `organizationId`; `eligibleOnly` drops `memberCount < 1`; `selectedId` sets `selectedIndex`. `static func activeEnrollmentCounts(_ groups: [UserGroup], enrollmentsFor: (String) -> [EnrollmentWithProgram]) -> [String: Int]` (D14: `isActive` only).
  - `EnrollSelectProgramMapper.Input { programs: [StudyProgram]; query: String; leaderIds: Set<String>; leaders: [GroupLeader]; draftGroupEnrollments: [EnrollmentWithProgram]?; selectedId: String?; loading: Bool; today: Date }`, `Output { state: EnrollmentSelectProgramScreen.State; programIds: [String]; leaderOptions: [InviteSelectGroupMapper.LeaderOption] }`, `static func output(_:) -> Output`. Rows: eligible only (D5), A→Z; Orgs hidden (D19); Leaders filter on `leaderId ?? creatorId`; created label `MMM yyyy`; completed count = D17 (group set → that group's enrollments of the program with `endDate < startOfDay(today)`; else `completedEnrollmentCount ?? 0`).
  - `EnrollSelectScheduleMapper.state(draft: EnrollmentDraft, lessonCount: Int, existingLessonDates: [Date], today: Date) -> EnrollmentSelectScheduleScreen.State` and `EnrollSelectScheduleMapper.apply(start: Date, end: Date, days: Set<Int>, overrides: Set<Date>, lessonCount: Int, to draft: inout EnrollmentDraft) -> Bool` (false = A4 short list, draft unchanged).

- [ ] **Step 1: Write the failing tests**

Append to `InviteSelectGroupMapperTests.swift` (reuse that file's group-building helper; if it builds `UserGroup` via JSON, add `"organizationId"` to the JSON for the org cases):

```swift
    // ui2-enrollment-create D5/D14/D19 — the enroll picker's inputs; invite's defaults unchanged.
    func testEligibleOnlyHidesEmptyGroups() {
        let out = InviteSelectGroupMapper.output(.init(groups: [makeGroup(id: "a", name: "A", members: 0), makeGroup(id: "b", name: "B", members: 2)],
                                                       enrollmentCounts: [:], query: "", leaderIds: [], loading: false, failed: false,
                                                       eligibleOnly: true))
        XCTAssertEqual(out.groupIds, ["b"])
    }

    func testOrgsChipShowsOnlyForMultiOrgCallersAndFilters() {
        let groups = [makeGroup(id: "a", name: "A", members: 1, org: "o1"), makeGroup(id: "b", name: "B", members: 1, org: "o2")]
        let orgs = [OrganizationData(id: "o1", name: "Grace"), OrganizationData(id: "o2", name: "Hope")]
        let one = InviteSelectGroupMapper.output(.init(groups: groups, enrollmentCounts: [:], query: "", leaderIds: [],
                                                       loading: false, failed: false, organizations: [orgs[0]]))
        XCTAssertFalse(one.state.orgFilterVisible)
        let two = InviteSelectGroupMapper.output(.init(groups: groups, enrollmentCounts: [:], query: "", leaderIds: [],
                                                       loading: false, failed: false, organizations: orgs, pickedOrgIds: ["o2"]))
        XCTAssertTrue(two.state.orgFilterVisible)
        XCTAssertEqual(two.groupIds, ["b"])
        XCTAssertEqual(two.orgOptions.map(\.label), ["Grace", "Hope"])
    }

    func testSelectedIdSetsTheSelectedIndex() {
        let out = InviteSelectGroupMapper.output(.init(groups: [makeGroup(id: "a", name: "A", members: 1), makeGroup(id: "b", name: "B", members: 1)],
                                                       enrollmentCounts: [:], query: "", leaderIds: [], loading: false, failed: false,
                                                       selectedId: "b"))
        XCTAssertEqual(out.state.selectedIndex, 1)
    }

    func testActiveEnrollmentCountsCountOnlyActiveOnes() {   // D14
        let g = makeGroup(id: "a", name: "A", members: 1)
        let past = EnrollmentWithProgram(id: "e1", groupId: "a", studyProgramId: "p", startDate: .distantPast, endDate: Date(timeIntervalSinceNow: -86_400))
        let live = EnrollmentWithProgram(id: "e2", groupId: "a", studyProgramId: "p", startDate: .distantPast, endDate: Date(timeIntervalSinceNow: 86_400))
        XCTAssertEqual(InviteSelectGroupMapper.activeEnrollmentCounts([g], enrollmentsFor: { _ in [past, live] }), ["a": 1])
    }
```

(Add a `makeGroup(id:name:members:org:)` helper if the file has none — decoding JSON as `EnrollChecklistMapperTests.group` does, with `"organizationId"` when `org` is non-nil. `OrganizationData` has an implicit memberwise init over `id, name, ownerId, createdAt, updatedAt`; pass the extra ones as `nil` if the compiler asks.)

`iphone/MakeReadyCaptureTests/EnrollPickerMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create D5/D17/D19 (program picker) and T8 (schedule seed + Select).
@MainActor
final class EnrollPickerMapperTests: XCTestCase {
    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }
    private func program(_ id: String, _ name: String, days: Int, published: Bool = true, leader: String? = nil,
                         creator: String = "u1", completed: Int? = nil) throws -> StudyProgram {
        let leaderJSON = leader.map { #","leaderId":"\#($0)""# } ?? ""
        let completedJSON = completed.map { #","completedEnrollmentCount":\#($0)"# } ?? ""
        return try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: Data(
            #"{"id":"\#(id)","name":"\#(name)","days":\#(days),"isPublished":\#(published),"creatorId":"\#(creator)","createdAt":"2025-03-15T12:00:00.000Z","updatedAt":"2025-03-15T12:00:00.000Z"\#(leaderJSON)\#(completedJSON)}"#.utf8))
    }
    private func input(_ programs: [StudyProgram], group: [EnrollmentWithProgram]? = nil, leaderIds: Set<String> = [],
                       selectedId: String? = nil) -> EnrollSelectProgramMapper.Input {
        .init(programs: programs, query: "", leaderIds: leaderIds, leaders: [], draftGroupEnrollments: group,
              selectedId: selectedId, loading: false, today: day("2035-01-08"))
    }

    func testProgramPickerListsOnlyPublishedProgramsWithLessonsAToZ() throws {
        let out = EnrollSelectProgramMapper.output(input([
            try program("p2", "Zeal", days: 5), try program("p1", "Acts", days: 3),
            try program("p3", "Draft", days: 5, published: false), try program("p4", "Empty", days: 0),
        ]))
        XCTAssertEqual(out.programIds, ["p1", "p2"])
        XCTAssertEqual(out.state.programTitles, ["Acts", "Zeal"])
        XCTAssertEqual(out.state.programDayCounts, [3, 5])
        XCTAssertEqual(out.state.programCreatedLabels, ["Mar 2025", "Mar 2025"])
        XCTAssertFalse(out.state.orgFilterVisible)                       // D19
        XCTAssertEqual(out.state.selectedIndex, -1)
    }

    func testCompletedCountIsTheServersWithNoGroupAndTheGroupsOwnWithOne() throws {   // D17
        let p = try program("p1", "Acts", days: 3, completed: 7)
        XCTAssertEqual(EnrollSelectProgramMapper.output(input([p])).state.programCompletedCounts, [7])
        let ended = EnrollmentWithProgram(id: "e1", groupId: "g", studyProgramId: "p1", startDate: day("2034-12-01"), endDate: day("2035-01-01"))
        let running = EnrollmentWithProgram(id: "e2", groupId: "g", studyProgramId: "p1", startDate: day("2035-01-01"), endDate: day("2035-02-01"))
        let other = EnrollmentWithProgram(id: "e3", groupId: "g", studyProgramId: "pX", startDate: day("2034-12-01"), endDate: day("2035-01-01"))
        XCTAssertEqual(EnrollSelectProgramMapper.output(input([p], group: [ended, running, other])).state.programCompletedCounts, [1])
    }

    func testLeadersFilterOnLeaderElseCreatorAndSelectedId() throws {   // D19
        let ps = [try program("p1", "Acts", days: 3, leader: "l1"), try program("p2", "Zeal", days: 5, creator: "l2")]
        XCTAssertEqual(EnrollSelectProgramMapper.output(input(ps, leaderIds: ["l2"])).programIds, ["p2"])
        XCTAssertEqual(EnrollSelectProgramMapper.output(input(ps, selectedId: "p2")).state.selectedIndex, 1)
    }

    func testScheduleSeedFromTheDraft() {
        var d = EnrollmentDraft(id: UUID()); d.setProgram("p1")
        d.startDate = day("2035-01-08"); d.enabledDays = [1, 3]; d.overriddenDates = [day("2035-01-10")]
        let s = EnrollSelectScheduleMapper.state(draft: d, lessonCount: 3, existingLessonDates: [day("2035-01-15")], today: day("2035-01-07"))
        XCTAssertTrue(s.programChosen)
        XCTAssertEqual(s.lessonCount, 3)
        XCTAssertEqual(s.today, "2035-01-07")
        XCTAssertEqual(s.startDate, "2035-01-08")
        XCTAssertEqual(s.enabledDays, [1, 3])
        XCTAssertEqual(s.overriddenDates, ["2035-01-10"])
        XCTAssertEqual(s.existingLessonDates, ["2035-01-15"])
        XCTAssertEqual(s.prompt, "none")
        let none = EnrollSelectScheduleMapper.state(draft: EnrollmentDraft(id: UUID()), lessonCount: 0, existingLessonDates: [], today: day("2035-01-07"))
        XCTAssertFalse(none.programChosen)
        XCTAssertEqual(none.startDate, "")
        XCTAssertEqual(none.enabledDays, [])
    }

    func testApplyWritesTheExactDatesOrRefusesAShortList() {
        var d = EnrollmentDraft(id: UUID()); d.setProgram("p1")
        XCTAssertTrue(EnrollSelectScheduleMapper.apply(start: day("2035-01-08"), end: day("2035-01-17"), days: [1, 3],
                                                       overrides: [day("2035-01-10")], lessonCount: 3, to: &d))
        XCTAssertEqual(d.scheduleDates, [day("2035-01-08"), day("2035-01-15"), day("2035-01-17")])
        XCTAssertEqual(d.endDate, day("2035-01-17"))
        XCTAssertTrue(d.scheduleDone)
        var e = EnrollmentDraft(id: UUID())
        XCTAssertFalse(EnrollSelectScheduleMapper.apply(start: day("2035-01-08"), end: day("2035-01-08"), days: [], overrides: [], lessonCount: 3, to: &e))
        XCTAssertFalse(e.scheduleDone)
    }
}
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → build FAILS, `extra argument 'eligibleOnly' in call`

- [ ] **Step 3: Extend the group mapper** — in `InviteSelectGroupMapper.swift`:

```swift
    struct Input {
        var groups: [UserGroup]
        var enrollmentCounts: [String: Int]
        var query: String
        var leaderIds: Set<String>
        var loading: Bool
        var failed: Bool
        /// ui2-enrollment-create D5: the enroll picker lists only groups with an active member.
        var eligibleOnly: Bool = false
        /// D19: the caller's orgs — the Orgs chip shows for 2+ (GroupsHomeMapper's rule).
        var organizations: [OrganizationData] = []
        var pickedOrgIds: Set<String> = []
        /// The picked group to show selected on open; nil = none.
        var selectedId: String? = nil
    }
```

`Output` gains `var orgOptions: [LeaderOption]`. In `output(_:)` add `.filter { !input.eligibleOnly || EnrollChecklistMapper.isEligible($0) }` and `.filter { input.pickedOrgIds.isEmpty || $0.organizationId.map(input.pickedOrgIds.contains) == true }` to `rows`; build `orgOptions` from `input.organizations` sorted by name; set `orgFilterVisible: input.organizations.count > 1`, `orgFilterLabel: FilterMenuOverlay.chipLabel(picked: orgOptions.filter { input.pickedOrgIds.contains($0.id) }.map(\.label), resting: restingOrgLabel, noun: "orgs")`, `selectedIndex: input.selectedId.flatMap { id in rows.firstIndex { $0.id == id } } ?? -1`. Add:

```swift
    /// ui2-enrollment-create D14: the third chip counts active enrollments only (upcoming counts).
    static func activeEnrollmentCounts(_ groups: [UserGroup],
                                       enrollmentsFor: (String) -> [EnrollmentWithProgram]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: groups.map { g in (g.id, enrollmentsFor(g.id).filter(\.isActive).count) })
    }
```

and in `InviteSelectGroupContainer.swift:20` replace the `enrollmentCounts:` argument with `InviteSelectGroupMapper.activeEnrollmentCounts(groups, enrollmentsFor: { app.enrollmentsFor(groupId: $0) })` (D14: the invite picker shows the same number).

- [ ] **Step 4: Write the program mapper** — `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectProgramMapper.swift`

```swift
import Foundation

/// ui2-enrollment-create D5/D17/D19: AppState's programs → `EnrollmentSelectProgramScreen.State`.
/// Published programs with lessons only, A→Z; search and Leaders (leaderId ?? creatorId) narrow
/// locally; Orgs hidden (GET /api/programs is scoped to the session org). Pure.
enum EnrollSelectProgramMapper {
    struct Input {
        var programs: [StudyProgram]
        var query: String
        var leaderIds: Set<String>
        var leaders: [GroupLeader]
        /// D17: the draft group's enrollments; nil = no group in the draft.
        var draftGroupEnrollments: [EnrollmentWithProgram]?
        var selectedId: String?
        var loading: Bool
        var today: Date
    }

    struct Output {
        var state: EnrollmentSelectProgramScreen.State
        var programIds: [String]
        var leaderOptions: [InviteSelectGroupMapper.LeaderOption]
    }

    static func output(_ input: Input) -> Output {
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let leaderOf = { (p: StudyProgram) in p.leaderId ?? p.creatorId ?? "" }
        let rows = input.programs
            .filter(EnrollChecklistMapper.isEligible)
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .filter { input.leaderIds.isEmpty || input.leaderIds.contains(leaderOf($0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let leaderOptions = input.leaders
            .map { InviteSelectGroupMapper.LeaderOption(id: $0.id, label: $0.displayName) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        let picked = leaderOptions.filter { input.leaderIds.contains($0.id) }.map(\.label)
        let startOfToday = Calendar.current.startOfDay(for: input.today)
        let completed: (StudyProgram) -> Int = { p in
            guard let enrollments = input.draftGroupEnrollments else { return p.completedEnrollmentCount ?? 0 }
            return enrollments.filter { $0.studyProgramId == p.id && $0.endDate < startOfToday }.count
        }
        let state = EnrollmentSelectProgramScreen.State(
            searchText: input.query,
            orgFilterVisible: false,
            orgFilterLabel: InviteSelectGroupMapper.restingOrgLabel,
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: picked, resting: InviteSelectGroupMapper.restingLeaderLabel, noun: "leaders"),
            programTitles: rows.map(\.name),
            programCoverURLs: rows.map { $0.coverImageUrl ?? "" },
            programCreatedLabels: rows.map { monthYear($0.createdAt) },
            programDayCounts: rows.map(\.days),
            programCompletedCounts: rows.map(completed),
            selectedIndex: input.selectedId.flatMap { id in rows.firstIndex { $0.id == id } } ?? -1,
            loading: input.loading
        )
        return Output(state: state, programIds: rows.map(\.id), leaderOptions: leaderOptions)
    }

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM yyyy"
        return f
    }()

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.timeZone = .current
        return monthYearFormatter.string(from: date)
    }
}
```

(`GroupLeader.displayName` exists at `GroupMembershipModels.swift:97`.)

- [ ] **Step 5: Write the schedule mapper** — `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectScheduleMapper.swift`

```swift
import Foundation

/// ui2-enrollment-create T8: the draft ↔ `EnrollmentSelectScheduleScreen`. The screen's strings are
/// `yyyy-MM-dd` in the device zone (its own decoder); Select's dates become the draft's exact list.
enum EnrollSelectScheduleMapper {
    static func state(draft: EnrollmentDraft, lessonCount: Int, existingLessonDates: [Date],
                      today: Date) -> EnrollmentSelectScheduleScreen.State {
        EnrollmentSelectScheduleScreen.State(
            programChosen: draft.studyProgramId != nil,
            lessonCount: lessonCount,
            today: EnrollmentWire.ymd(today),
            startDate: draft.startDate.map { EnrollmentWire.ymd($0) } ?? "",
            enabledDays: draft.enabledDays.sorted(),
            overriddenDates: draft.overriddenDates.sorted().map { EnrollmentWire.ymd($0) },
            existingLessonDates: existingLessonDates.sorted().map { EnrollmentWire.ymd($0) },
            prompt: "none"
        )
    }

    /// Select: start/end/weekdays/overrides plus the calendar's exact dates (A4: a list short of
    /// `lessonCount` is refused and the draft is left as it was).
    @MainActor
    static func apply(start: Date, end: Date, days: Set<Int>, overrides: Set<Date>, lessonCount: Int,
                      to draft: inout EnrollmentDraft) -> Bool {
        guard let dates = EnrollScheduleMath.dates(start: start, days: days, overrides: overrides,
                                                   lessonCount: lessonCount) else { return false }
        draft.startDate = start
        draft.enabledDays = days
        draft.overriddenDates = overrides
        draft.scheduleDates = dates
        draft.endDate = dates.last ?? end
        return true
    }
}
```

Register the new files (plan note) and resync the capture target.

- [ ] **Step 6: Run them and watch them pass** — `npm run ios:build-check -- --test` → `EnrollPickerMapperTests` 5/5 and the extended `InviteSelectGroupMapperTests` green (their existing cases unchanged); swiftlint from `iphone/` → no new violation

- [ ] **Step 7: Commit** — `feat(ui2-enrollment-create): group, program and schedule picker mappers (D5, D14, D17, D19)`

### Task 11: routes, shell page switch and draft pruning (D2, D13)
App: iphone
Phase: 4
Recipe: `/nav-route` · `/push-page` (container pattern only — the pages are pushed `UI2Destination`s, no SlideStack)

**Build-time risk carried here:** **A3** — five pickers were `updateNeeded: true` in d2m at audit. Implementers have no d2m MCP, so before wiring compare each screen's `init(` signature against Task 9/10/12–14's calls (`grep -n "^    init(" -A10 iphone/MakeReadyUI/Screens/Groups/EnrollmentSelect*Screen.swift iphone/MakeReadyUI/Screens/Groups/GroupsEnrollProgramScreen.swift`). A signature that differs from the one this plan's code calls → STOP and report it (the orchestrator calls `check_project_change`), never edit `MakeReadyUI/`.

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:19-50` (seven cases)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:178-197` (page switch) + a path observer
- Modify: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`

**Interfaces:**
- Produces: `UI2Destination.enrollChecklist(flowId: UUID)`, `.enrollSelectGroup(flowId: UUID)`, `.enrollSelectProgram(flowId: UUID)`, `.enrollSelectSchedule(flowId: UUID)`, `.enrollSelectInviteTime(flowId: UUID)`, `.enrollSelectSync(flowId: UUID)`, `.enrollSelectAccess(flowId: UUID)`; `UI2ShellModel.enrollmentFlowIds: Set<UUID>` (every `.enrollChecklist` flow id on any tab's path). The shell maps each case to `EnrollChecklistContainer(flowId:)`, `EnrollSelectGroupContainer(flowId:)`, `EnrollSelectProgramContainer(flowId:)`, `EnrollSelectScheduleContainer(flowId:)`, `EnrollSelectInviteTimeContainer(flowId:)`, `EnrollSelectSyncContainer(flowId:)`, `EnrollSelectAccessContainer(flowId:)` — defined by Tasks 12–14. Until those land, this task adds each as a placeholder `struct … : View { let flowId: UUID; var body: some View { EmptyView() } }` in `iphone/MakeReady/UI2/Containers/Enrollments/EnrollContainers.swift`; Tasks 12–14 replace them one by one (and delete that file when it is empty).

- [ ] **Step 1: Write the failing test** — append to `UI2ShellModelTests.swift`:

```swift
    // ui2-enrollment-create D2/D13: the flow's seven pages, and the flow ids still on a stack.
    func testEnrollmentFlowIdsAreTheChecklistsOnAnyPath() {
        var model = UI2ShellModel()
        let a = UUID(), b = UUID()
        model.push(.enrollChecklist(flowId: a), on: .home)
        model.push(.enrollSelectGroup(flowId: a), on: .home)
        model.push(.enrollChecklist(flowId: b), on: .calendar)
        XCTAssertEqual(model.enrollmentFlowIds, [a, b])
        model.pop(on: .home); model.pop(on: .home)
        XCTAssertEqual(model.enrollmentFlowIds, [b])
    }

    func testEnrollmentPagesAreNotFullScreen() {
        let id = UUID()
        for d: UI2Destination in [.enrollChecklist(flowId: id), .enrollSelectGroup(flowId: id), .enrollSelectProgram(flowId: id),
                                  .enrollSelectSchedule(flowId: id), .enrollSelectInviteTime(flowId: id),
                                  .enrollSelectSync(flowId: id), .enrollSelectAccess(flowId: id)] {
            XCTAssertFalse(d.isFullScreen)
        }
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → build FAILS, `type 'UI2Destination' has no member 'enrollChecklist'`

- [ ] **Step 3: Implement**
  - `UI2ShellModel.swift`, in `UI2Destination` after `editProgramCover`:

```swift
    /// ui2-enrollment-create D2/D9: the "New enrollment" checklist; `flowId` keys its draft in
    /// `AppState.enrollmentDrafts`. Pushed on the stack it was opened from.
    case enrollChecklist(flowId: UUID)
    /// ui2-enrollment-create: the six pickers, each above its checklist; Select/Save writes the draft and pops.
    case enrollSelectGroup(flowId: UUID)
    case enrollSelectProgram(flowId: UUID)
    case enrollSelectSchedule(flowId: UUID)
    case enrollSelectInviteTime(flowId: UUID)
    case enrollSelectSync(flowId: UUID)
    case enrollSelectAccess(flowId: UUID)
```

  and in `UI2ShellModel`:

```swift
    /// ui2-enrollment-create D13: the flows whose checklist is still on some stack — every other
    /// draft is pruned when the paths change.
    var enrollmentFlowIds: Set<UUID> {
        Set(paths.values.flatMap { $0 }.compactMap {
            if case let .enrollChecklist(flowId) = $0 { return flowId } else { return nil }
        })
    }
```

  - `UI2Shell.swift` `page(for:)`, after `editProgramCover`:

```swift
        case let .enrollChecklist(flowId): EnrollChecklistContainer(flowId: flowId)                 // ui2-enrollment-create D2
        case let .enrollSelectGroup(flowId): EnrollSelectGroupContainer(flowId: flowId)
        case let .enrollSelectProgram(flowId): EnrollSelectProgramContainer(flowId: flowId)
        case let .enrollSelectSchedule(flowId): EnrollSelectScheduleContainer(flowId: flowId)
        case let .enrollSelectInviteTime(flowId): EnrollSelectInviteTimeContainer(flowId: flowId)
        case let .enrollSelectSync(flowId): EnrollSelectSyncContainer(flowId: flowId)
        case let .enrollSelectAccess(flowId): EnrollSelectAccessContainer(flowId: flowId)
```

  - On the shell's root view (where it already applies modifiers to its body), add:

```swift
        // ui2-enrollment-create D13: a checklist that left every stack (swipe-back, Home re-tap)
        // takes its draft with it.
        .onChange(of: model.enrollmentFlowIds) { _, ids in AppState.shared.pruneEnrollmentDrafts(keeping: ids) }
```

  - Create `iphone/MakeReady/UI2/Containers/Enrollments/EnrollContainers.swift` with the seven placeholder structs named above; register it in target `MakeReady`; resync the capture target.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → the two new `UI2ShellModelTests` pass, suite green; swiftlint from `iphone/` → no new violation

- [ ] **Step 5: Commit** — `feat(ui2-enrollment-create): enrollment flow routes and draft pruning in the UI2 shell (D2, D13)`

### Task 12: checklist container, enroll submit and the three entries (D2, D6, A5)
App: iphone
Phase: 4
Recipe: `/ios-error-surface` · `/nav-route` · SPEC §iphone *Checklist container*, *Entries*, *Back-swipe and the draft*

**Build-time risk carried here:** **A5** — POST has no idempotency: the `processing` phase ignores a second Enroll and arms `UI2BackSwipeGuard` (`UI2Navigation.swift:117`), so neither a double tap nor a swipe-back can send twice.

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollChecklistContainer.swift` (replaces the placeholder from Task 11)
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollEntry.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift:49-70` (`onEnrollProgram`)
- Modify: `iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeContainer.swift:63-83` (`onAddEnrollment`)
- Modify: `iphone/MakeReady/UI2/Shell/TopNavHost.swift:98-104` (`.enrollments` add)
- Create: `iphone/MakeReadyCaptureTests/EnrollSubmitTests.swift`

**Interfaces:**
- Consumes: `AppState.startEnrollmentDraft/updateEnrollmentDraft/endEnrollmentDraft`, `EnrollmentDraft`, `EnrollChecklistMapper` (Task 9); `EnrollmentWire`, `createEnrollment(… scheduleDates:lessonAccess:)` (Task 8); `UI2Destination.enroll*` (Task 11)
- Produces:
  - `enum EnrollSubmit { static let failedMessage = "Couldn't enroll"; @MainActor static func run(flowId: UUID, actions: EnrollmentActions = EnrollmentActions(), state: AppState? = nil, onUnauthorized: @escaping @MainActor () async -> Void) async -> Bool }` — sets phase `processing`, posts, sets `enrolled` on success; on failure: cancellation → phase back to `checklist`, silent; 401 → `onUnauthorized`, phase `checklist`, nothing surfaced; else `recordError(…, context: "EnrollChecklistContainer.enroll", surface: true, friendlyMessage: "Couldn't enroll", retry:)` and phase `checklist` (D6).
  - `enum EnrollEntry { @MainActor static func open(groupId: String?, studyProgramId: String?, push: (UI2Destination) -> Void, state: AppState? = nil) }` — creates the draft with D10-checked preloads and pushes `.enrollChecklist(flowId:)`.

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/EnrollSubmitTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create D6: Enroll's phases and error routing; D2/D10: the entry's preloads.
@MainActor
final class EnrollSubmitTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let created = #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-12T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}}"#

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/enrollments") ? nil : APIError.serverError("refresh not stubbed") }
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func readyDraft() -> UUID {
        let id = state.startEnrollmentDraft(groupId: "g1", studyProgramId: "p1")
        state.updateEnrollmentDraft(id) {
            $0.startDate = Date(timeIntervalSince1970: 2_051_222_400)
            $0.enabledDays = [1]
            $0.scheduleDates = [Date(timeIntervalSince1970: 2_051_222_400)]
            $0.endDate = $0.scheduleDates.last
            $0.smsTime = "07:30"; $0.timezone = "America/Chicago"; $0.syncMode = "AUTO"; $0.lessonAccess = "all-at-once"
        }
        return id
    }

    private func run(_ id: UUID, onUnauthorized: @escaping @MainActor () async -> Void = {}) async -> Bool {
        await EnrollSubmit.run(flowId: id, actions: EnrollmentActions(api: api, state: state), state: state, onUnauthorized: onUnauthorized)
    }

    func testSuccessPostsTheDraftAndEndsEnrolled() async {
        api.stub("POST", "/api/enrollments", json: created)
        let id = readyDraft()
        let ok = await run(id)
        XCTAssertTrue(ok)
        XCTAssertEqual(state.enrollmentDrafts[id]?.phase, .enrolled)
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertEqual(body?["lessonAccess"] as? String, "ALL_AT_ONCE")
        XCTAssertEqual(body?["syncMode"] as? String, "AUTO")
        XCTAssertEqual((body?["scheduleDates"] as? [String])?.count, 1)
        XCTAssertEqual(body?["enabledDays"] as? [String], ["Mon"])
    }

    func testFailureSurfacesCouldntEnrollAndReturnsToTheChecklist() async {
        api.errorFor = { _, _ in APIError.serverError("boom") }
        let id = readyDraft()
        let ok = await run(id)
        XCTAssertFalse(ok)
        XCTAssertEqual(state.enrollmentDrafts[id]?.phase, .checklist)
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't enroll")
        XCTAssertEqual(state.errors.last?.context, "EnrollChecklistContainer.enroll")
    }

    func testUnauthorizedSignsOutAndSurfacesNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        let id = readyDraft()
        _ = await run(id, onUnauthorized: { signedOut = true })
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testAnIncompleteOrProcessingDraftSendsNothing() async {
        let id = state.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        let incomplete = await run(id)
        XCTAssertFalse(incomplete)
        let ready = readyDraft()
        state.updateEnrollmentDraft(ready) { $0.phase = .processing }      // A5: a second tap
        let second = await run(ready)
        XCTAssertFalse(second)
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testEntryPreloadsOnlyEligibleRows() throws {   // D10
        state.groups.upsert(try JSONDecoder.apiDecoder.decode(UserGroup.self, from: Data(
            #"{"id":"g0","code":"C","name":"Empty","isPrivate":false,"allowInvites":true,"memberDirectory":true,"memberCount":0,"creatorId":"u1","createdAt":"2025-01-03T12:00:00.000Z","updatedAt":"2025-01-03T12:00:00.000Z"}"#.utf8)))
        var pushed: [UI2Destination] = []
        EnrollEntry.open(groupId: "g0", studyProgramId: nil, push: { pushed.append($0) }, state: state)
        guard case let .enrollChecklist(flowId)? = pushed.first else { return XCTFail("no checklist pushed") }
        XCTAssertNil(state.enrollmentDrafts[flowId]?.groupId)
    }
}
```

(`EntityStore`'s insert method may be named differently — use the one `GroupActions.createGroup` calls on `state.groups`.)

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → build FAILS, `cannot find 'EnrollSubmit' in scope`

- [ ] **Step 3: Write `EnrollEntry.swift`**

```swift
import SwiftUI

/// ui2-enrollment-create D2/D10: every "New enrollment" entry — the group page's Enrollments `add`
/// (group preloaded), the program page's (program preloaded) and the TopNav Enrollments `add`
/// (nothing). A preload counts only when it passes D5's eligibility; otherwise the row arrives to do.
enum EnrollEntry {
    @MainActor
    static func open(groupId: String?, studyProgramId: String?, push: (UI2Destination) -> Void,
                     state appState: AppState? = nil) {
        let state = appState ?? .shared
        let flowId = state.startEnrollmentDraft(
            groupId: EnrollChecklistMapper.preloadedGroupId(groupId, groups: state.groups.all),
            studyProgramId: EnrollChecklistMapper.preloadedProgramId(studyProgramId, programs: state.programs.all))
        push(.enrollChecklist(flowId: flowId))
    }
}
```

- [ ] **Step 4: Write `EnrollChecklistContainer.swift`** (delete its placeholder from `EnrollContainers.swift`):

```swift
import SwiftUI

/// ui2-enrollment-create D6: Enroll — the POST and its error routing, apart from the view so it is
/// testable (the CreateGroupSubmit precedent).
enum EnrollSubmit {
    static let failedMessage = "Couldn't enroll"

    /// true = enrolled. Sends nothing unless every row is done and the draft is not already
    /// processing (A5). A cancelled request is silent; a 401 signs out and surfaces nothing; any
    /// other failure surfaces `failedMessage` with Retry and returns the page to its 6/6 checklist.
    @MainActor
    static func run(flowId: UUID, actions: EnrollmentActions = EnrollmentActions(), state: AppState? = nil,
                    onUnauthorized: @escaping @MainActor () async -> Void) async -> Bool {
        let state = state ?? .shared
        guard let d = state.enrollmentDrafts[flowId], d.phase == .checklist,
              let groupId = d.groupId, let programId = d.studyProgramId,
              let start = d.startDate, d.scheduleDone, let smsTime = d.smsTime,
              let syncMode = d.syncMode, let access = d.lessonAccess.flatMap(EnrollmentWire.lessonAccessWire)
        else { return false }
        state.updateEnrollmentDraft(flowId) { $0.phase = .processing }
        do {
            _ = try await actions.createEnrollment(
                groupId: groupId, studyProgramId: programId, startDate: start,
                enabledDays: EnrollmentWire.dayNames(d.enabledDays), smsTime: smsTime,
                timezone: d.timezone ?? TimeZone.current.identifier,
                syncMode: syncMode == "AUTO" ? .auto : .off,
                scheduleDates: d.scheduleDates, lessonAccess: access)
            state.updateEnrollmentDraft(flowId) { $0.phase = .enrolled }
            return true
        } catch {
            state.updateEnrollmentDraft(flowId) { $0.phase = .checklist }
            if GroupActions.isCancellation(error) { return false }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()                                   // ui2-shell D27
                return false
            }
            state.recordError(error, context: "EnrollChecklistContainer.enroll", surface: true,
                              friendlyMessage: failedMessage,
                              retry: { Task { @MainActor in _ = await run(flowId: flowId, actions: actions, state: state, onUnauthorized: onUnauthorized) } })
            return false
        }
    }
}

/// ui2-enrollment-create D2/D6/D9: hosts the d2m-built `GroupsEnrollProgramScreen`. Every row
/// derives from the flow's draft; a row tap pushes its picker; Back (checklist) and Done/Back
/// (enrolled) end the draft and pop to the page that pushed the checklist.
struct EnrollChecklistContainer: View {
    let flowId: UUID

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @Environment(\.ui2BackSwipeGuard) private var backSwipe

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId] ?? EnrollmentDraft(id: flowId)
        GroupsEnrollProgramScreen(
            state: EnrollChecklistMapper.state(draft,
                                               group: draft.groupId.flatMap { app.groups[$0] },
                                               program: draft.studyProgramId.flatMap { app.programs[$0] }),
            onBack: leave,
            onSelectStep: { navigator.push(Self.destination(for: $0, flowId: flowId)) },
            onEnroll: enroll,
            onDone: leave
        )
        .ui2PushedPageFill()
        .onAppear {
            // A5: no swipe-back while the POST is in flight.
            backSwipe?.blocksBackSwipe = { AppState.shared.enrollmentDrafts[flowId]?.phase == .processing }
        }
    }

    static func destination(for step: GroupsEnrollProgramScreen.Step, flowId: UUID) -> UI2Destination {
        switch step {
        case .group: return .enrollSelectGroup(flowId: flowId)
        case .studyProgram: return .enrollSelectProgram(flowId: flowId)
        case .schedule: return .enrollSelectSchedule(flowId: flowId)
        case .inviteTime: return .enrollSelectInviteTime(flowId: flowId)
        case .sync: return .enrollSelectSync(flowId: flowId)
        case .accessibility: return .enrollSelectAccess(flowId: flowId)
        }
    }

    private func leave() {
        AppState.shared.endEnrollmentDraft(flowId)
        navigator.popIfTop(.enrollChecklist(flowId: flowId))
    }

    private func enroll() {
        Task { @MainActor in
            _ = await EnrollSubmit.run(flowId: flowId, onUnauthorized: { [authManager] in
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "EnrollChecklistContainer.signOut", surface: false)
                }
            })
        }
    }
}
```

Check `GroupActions.isCancellation` is `static` and reachable (`GroupActions.swift:839`), `EnrollmentSyncMode` has `.auto` and `.off` cases, and `app.groups[id]` / `app.programs[id]` subscripts exist (as `GroupDetailContainer` uses `AppState.shared.groups[groupId]`). Add a test case asserting `EnrollChecklistContainer.destination(for: .schedule, flowId: id) == .enrollSelectSchedule(flowId: id)` to `EnrollSubmitTests`.

- [ ] **Step 5: Wire the three entries**
  - `GroupDetailContainer.swift`, in the `GroupsDetailScreen(` call after `onInviteMember`:

```swift
                    // ui2-enrollment-create D2: Enrollments `add` → the checklist with this group preloaded.
                    onEnrollProgram: { EnrollEntry.open(groupId: groupId, studyProgramId: nil, push: navigator.push) },
```

  - `StudyProgramHomeContainer.swift`, in the `StudyProgramHomeScreen(` call after `onAddLesson`:

```swift
                        // ui2-enrollment-create D2: enrollments `add` → the checklist with this program preloaded.
                        onAddEnrollment: { EnrollEntry.open(groupId: nil, studyProgramId: programId, push: navigator.push) },
```

  - `TopNavHost.swift` `onAdd` switch, before `default`:

```swift
                case .enrollments?:                                            // ui2-enrollment-create D2
                    EnrollEntry.open(groupId: nil, studyProgramId: nil, push: { model.push($0, on: .home) })
```

  Keep each argument in the screen init's declared order (Swift requires it) — check the init at `GroupsDetailScreen.swift:130-155` / `StudyProgramHomeScreen.swift:95-118`.

- [ ] **Step 6: Run it and watch it pass** — `npm run ios:build-check -- --test` → `EnrollSubmitTests` green, suite green; swiftlint from `iphone/` → no new violation; run `/transition-review` on the diff (it touches a back-swipe guard)

- [ ] **Step 7: Commit** — `feat(ui2-enrollment-create): checklist container with Enroll, and the group, program and TopNav entries (D2, D6)`

### Task 13: group + program picker containers with the warnings (D5, D11, D14, D18, D19)
App: iphone
Phase: 4
Recipe: `/present-overlay` (C-066 via `.actionMenuPresentation`, as `GroupDetailContainer.swift:77`) · SPEC §iphone *Picker containers*, *Picker selection by id*

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectGroupContainer.swift`
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectProgramContainer.swift`
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollPickerWarnings.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollContainers.swift` (remove two placeholders)
- Create: `iphone/MakeReadyCaptureTests/EnrollPickerWarningsTests.swift`

**Interfaces:**
- Consumes: `InviteSelectGroupMapper` (+ Task 10 inputs), `EnrollSelectProgramMapper` (Task 10), `EnrollmentDraft.setProgram`, `AppState.updateEnrollmentDraft` (Task 9), `InviteSelectGroupContainer.loadEnrollmentCounts(for:)`
- Produces:
  - `enum EnrollPickerWarnings { enum Warning: Equatable { case alreadyEnrolled, lessonOverlap }; static func forGroup(enrollments: [EnrollmentWithProgram], programId: String?, scheduleDates: [Date], existingLessonDates: [Date]) -> Warning?; static func forProgram(groupEnrollments: [EnrollmentWithProgram]?, programId: String) -> Warning?; static func confirmLabel(_ w: Warning) -> String; static let chooseAnother = "Choose another" }` — `alreadyEnrolled` when an `isActive` enrollment of `programId` exists; `lessonOverlap` when any draft schedule date is the same calendar day as an existing lesson date; `confirmLabel`: `"Already enrolled — select anyway"` / `"Lesson already scheduled — select anyway"`.

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/EnrollPickerWarningsTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create D11/D18: the picker warnings never block — they ask once.
final class EnrollPickerWarningsTests: XCTestCase {
    private let now = Date()
    private func enrollment(_ program: String, active: Bool) -> EnrollmentWithProgram {
        EnrollmentWithProgram(id: UUID().uuidString, groupId: "g", studyProgramId: program, startDate: .distantPast,
                              endDate: now.addingTimeInterval(active ? 86_400 : -86_400))
    }

    func testAlreadyEnrolledNeedsAnActiveEnrollmentOfTheDraftsProgram() {
        XCTAssertEqual(EnrollPickerWarnings.forGroup(enrollments: [enrollment("p1", active: true)], programId: "p1",
                                                     scheduleDates: [], existingLessonDates: []), .alreadyEnrolled)
        XCTAssertNil(EnrollPickerWarnings.forGroup(enrollments: [enrollment("p1", active: false)], programId: "p1",
                                                   scheduleDates: [], existingLessonDates: []))
        XCTAssertNil(EnrollPickerWarnings.forGroup(enrollments: [enrollment("p1", active: true)], programId: nil,
                                                   scheduleDates: [], existingLessonDates: []))
    }

    func testLessonOverlapComparesCalendarDays() {
        let day = Calendar.current.startOfDay(for: now)
        XCTAssertEqual(EnrollPickerWarnings.forGroup(enrollments: [], programId: "p1", scheduleDates: [day],
                                                     existingLessonDates: [day.addingTimeInterval(9 * 3600)]), .lessonOverlap)
        XCTAssertNil(EnrollPickerWarnings.forGroup(enrollments: [], programId: "p1", scheduleDates: [day],
                                                   existingLessonDates: [day.addingTimeInterval(86_400)]))
    }

    func testProgramPickerWarnsAgainstTheDraftsGroupOnly() {
        XCTAssertEqual(EnrollPickerWarnings.forProgram(groupEnrollments: [enrollment("p1", active: true)], programId: "p1"), .alreadyEnrolled)
        XCTAssertNil(EnrollPickerWarnings.forProgram(groupEnrollments: nil, programId: "p1"))
    }

    func testLabels() {
        XCTAssertEqual(EnrollPickerWarnings.confirmLabel(.alreadyEnrolled), "Already enrolled — select anyway")
        XCTAssertEqual(EnrollPickerWarnings.confirmLabel(.lessonOverlap), "Lesson already scheduled — select anyway")
        XCTAssertEqual(EnrollPickerWarnings.chooseAnother, "Choose another")
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → build FAILS, `cannot find 'EnrollPickerWarnings' in scope`

- [ ] **Step 3: Write `EnrollPickerWarnings.swift`**

```swift
import Foundation

/// ui2-enrollment-create D11/D18: the group and program pickers' Select warnings. They never block
/// — the container shows C-066 with "… — select anyway" and "Choose another" (a recorded deviation:
/// C-066 draws no title or body; a titled confirm is a `/ui2-component-update C-066` follow-up).
enum EnrollPickerWarnings {
    enum Warning: Equatable { case alreadyEnrolled, lessonOverlap }

    static let chooseAnother = "Choose another"

    static func confirmLabel(_ warning: Warning) -> String {
        switch warning {
        case .alreadyEnrolled: return "Already enrolled — select anyway"
        case .lessonOverlap: return "Lesson already scheduled — select anyway"
        }
    }

    static func forGroup(enrollments: [EnrollmentWithProgram], programId: String?, scheduleDates: [Date],
                         existingLessonDates: [Date]) -> Warning? {
        if let programId, enrollments.contains(where: { $0.studyProgramId == programId && $0.isActive }) {
            return .alreadyEnrolled
        }
        let cal = Calendar.current
        let taken = Set(existingLessonDates.map { cal.startOfDay(for: $0) })
        if scheduleDates.contains(where: { taken.contains(cal.startOfDay(for: $0)) }) { return .lessonOverlap }
        return nil
    }

    static func forProgram(groupEnrollments: [EnrollmentWithProgram]?, programId: String) -> Warning? {
        guard let groupEnrollments else { return nil }
        return groupEnrollments.contains { $0.studyProgramId == programId && $0.isActive } ? .alreadyEnrolled : nil
    }
}
```

- [ ] **Step 4: Write `EnrollSelectGroupContainer.swift`** (delete its placeholder):

```swift
import SwiftUI

/// ui2-enrollment-create D5/D11/D14/D18/D19: the checklist's group picker. Hosts the d2m-built
/// `EnrollmentSelectGroupScreen` unchanged: eligible groups only (D5), active-enrollment chip (D14),
/// Orgs for multi-org callers and Leaders (D19); Select warns once (D11/D18), then writes the draft
/// and pops. The picked row is tracked by id and the screen is re-keyed when its rows change, so
/// `onSelect(index)` always names the highlighted row.
struct EnrollSelectGroupContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var query = ""
    @State private var leaderIds: Set<String> = []
    @State private var orgIds: Set<String> = []
    @State private var leaderMenuOpen = false
    @State private var orgMenuOpen = false
    @State private var pickedId: String?
    @State private var pendingWarning: (groupId: String, warning: EnrollPickerWarnings.Warning)?

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId]
        let groups = app.groups.all
        let output = InviteSelectGroupMapper.output(.init(
            groups: groups,
            enrollmentCounts: InviteSelectGroupMapper.activeEnrollmentCounts(groups, enrollmentsFor: { app.enrollmentsFor(groupId: $0) }),
            query: query, leaderIds: leaderIds,
            loading: groups.isEmpty && app.loadingStates.isLoading(.groups), failed: false,
            eligibleOnly: true, organizations: app.myOrganizations, pickedOrgIds: orgIds,
            selectedId: pickedId ?? draft?.groupId))
        EnrollmentSelectGroupScreen(
            state: output.state,
            scrollsList: true,
            onBack: { navigator.pop() },
            onSelect: { index in
                guard output.groupIds.indices.contains(index) else { return }
                select(output.groupIds[index])
            },
            onSearch: { query = $0 },
            onOpenOrgFilter: { orgMenuOpen = true },
            onOpenLeaderFilter: { leaderMenuOpen = true },
            onPickGroup: { index in if output.groupIds.indices.contains(index) { pickedId = output.groupIds[index] } }
        )
        .id(output.groupIds)
        .ui2PushedPageFill()
        .filterMenuPresentation(isPresented: leaderMenuOpen, onDismiss: { leaderMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: leaderIds,
                onClose: { leaderMenuOpen = false },
                onSave: { leaderIds = $0; leaderMenuOpen = false })
        }
        .filterMenuPresentation(isPresented: orgMenuOpen, onDismiss: { orgMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.orgOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: orgIds,
                onClose: { orgMenuOpen = false },
                onSave: { orgIds = $0; orgMenuOpen = false })
        }
        .actionMenuPresentation(isPresented: pendingWarning != nil, onDismiss: { pendingWarning = nil }) {
            ActionMenuOverlay(
                actions: [.init(glyph: "triangle-alert", label: pendingWarning.map { EnrollPickerWarnings.confirmLabel($0.warning) } ?? ""),
                          .init(glyph: "x", label: EnrollPickerWarnings.chooseAnother)],
                onSelect: { item in
                    let groupId = pendingWarning?.groupId
                    pendingWarning = nil
                    if item.label != EnrollPickerWarnings.chooseAnother, let groupId { commit(groupId) }
                },
                onDone: { pendingWarning = nil })
        }
        .task { await InviteSelectGroupContainer.loadEnrollmentCounts(for: groups.map(\.id)) }
    }

    private func select(_ groupId: String) {
        let app = AppState.shared
        guard let draft = app.enrollmentDrafts[flowId] else { return navigator.pop() }
        Task { @MainActor in
            let existing = await EnrollSelectScheduleContainer.existingLessonDates(groupId: groupId)
            if let warning = EnrollPickerWarnings.forGroup(enrollments: app.enrollmentsFor(groupId: groupId),
                                                           programId: draft.studyProgramId,
                                                           scheduleDates: draft.scheduleDates,
                                                           existingLessonDates: existing) {
                pendingWarning = (groupId, warning)
            } else {
                commit(groupId)
            }
        }
    }

    private func commit(_ groupId: String) {
        AppState.shared.updateEnrollmentDraft(flowId) { $0.groupId = groupId }   // group change cascades nothing
        navigator.popIfTop(.enrollSelectGroup(flowId: flowId))
    }
}
```

`EnrollSelectScheduleContainer.existingLessonDates(groupId:)` is produced by Task 14; until it lands, add it to this task as a `static func` on a temporary `extension EnrollSelectScheduleContainer` in `EnrollContainers.swift` with the body Task 14 specifies (Step 3 there), and Task 14 moves it. Glyph names must exist in the glyph set C-067 uses — check `ActionMenuRow`'s glyph source (`grep -rn "glyph:" iphone/MakeReady/UI2/Containers | head`) and use two names already used elsewhere if `triangle-alert`/`x` are absent.

- [ ] **Step 5: Write `EnrollSelectProgramContainer.swift`** (delete its placeholder):

```swift
import SwiftUI

/// ui2-enrollment-create D5/D11/D17/D18/D19: the checklist's program picker. Hosts the d2m-built
/// `EnrollmentSelectProgramScreen` unchanged. Programs load cache-first (`loadPrograms` sends no
/// isPublished, so eligibility is filtered locally, D5); the completed chip follows D17; Leaders
/// options come from `AppState.groupLeaders`. Select warns once against the draft's group (D11/D18),
/// then `setProgram` (design rule 2) and pops.
struct EnrollSelectProgramContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var query = ""
    @State private var leaderIds: Set<String> = []
    @State private var leaderMenuOpen = false
    @State private var pickedId: String?
    @State private var pendingProgramId: String?

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId]
        let programs = app.programs.all
        let output = EnrollSelectProgramMapper.output(.init(
            programs: programs, query: query, leaderIds: leaderIds, leaders: app.groupLeaders,
            draftGroupEnrollments: draft?.groupId.map { app.enrollmentsFor(groupId: $0) },
            selectedId: pickedId ?? draft?.studyProgramId,
            loading: programs.isEmpty && app.loadingStates.isLoading(.programs), today: Date()))
        EnrollmentSelectProgramScreen(
            state: output.state,
            onBack: { navigator.pop() },
            onSelect: { index in
                guard output.programIds.indices.contains(index) else { return }
                select(output.programIds[index])
            },
            onSearch: { query = $0 },
            onOpenLeaderFilter: { leaderMenuOpen = true },
            onPickProgram: { index in if output.programIds.indices.contains(index) { pickedId = output.programIds[index] } }
        )
        .id(output.programIds)
        .ui2PushedPageFill()
        .filterMenuPresentation(isPresented: leaderMenuOpen, onDismiss: { leaderMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: leaderIds,
                onClose: { leaderMenuOpen = false },
                onSave: { leaderIds = $0; leaderMenuOpen = false })
        }
        .actionMenuPresentation(isPresented: pendingProgramId != nil, onDismiss: { pendingProgramId = nil }) {
            ActionMenuOverlay(
                actions: [.init(glyph: "triangle-alert", label: EnrollPickerWarnings.confirmLabel(.alreadyEnrolled)),
                          .init(glyph: "x", label: EnrollPickerWarnings.chooseAnother)],
                onSelect: { item in
                    let id = pendingProgramId
                    pendingProgramId = nil
                    if item.label != EnrollPickerWarnings.chooseAnother, let id { commit(id) }
                },
                onDone: { pendingProgramId = nil })
        }
        .task { await load() }
    }

    private func select(_ programId: String) {
        let app = AppState.shared
        let groupEnrollments = app.enrollmentDrafts[flowId]?.groupId.map { app.enrollmentsFor(groupId: $0) }
        if EnrollPickerWarnings.forProgram(groupEnrollments: groupEnrollments, programId: programId) != nil {
            pendingProgramId = programId
        } else {
            commit(programId)
        }
    }

    private func commit(_ programId: String) {
        AppState.shared.updateEnrollmentDraft(flowId) { $0.setProgram(programId) }
        navigator.popIfTop(.enrollSelectProgram(flowId: flowId))
    }

    /// Cache-first; background failures stay console-only.
    @MainActor
    private func load() async {
        let app = AppState.shared
        do { try await ProgramActions().loadPrograms() } catch {
            app.recordError(error, context: "EnrollSelectProgramContainer.loadPrograms")
        }
        do { try await ProgramActions().loadGroupLeaders() } catch {
            app.recordError(error, context: "EnrollSelectProgramContainer.loadGroupLeaders")
        }
        if let groupId = app.enrollmentDrafts[flowId]?.groupId, !app.groupEnrollmentIndex.hasChildren(groupId) {
            do { _ = try await EnrollmentActions().loadEnrollments(groupId: groupId) } catch {
                app.recordError(error, context: "EnrollSelectProgramContainer.loadEnrollments")
            }
        }
    }
}
```

Check `LoadingStateManager` has a `.programs` key (as `.groups` is used in invite) and `loadPrograms()`'s parameter defaults (`ProgramActions.swift:43`).

- [ ] **Step 6: Run it and watch it pass** — `npm run ios:build-check -- --test` → `EnrollPickerWarningsTests` 4/4, suite green; swiftlint from `iphone/` → no new violation (`server_collection_in_view_state`: these containers hold ids, never model arrays, in `@State`)

- [ ] **Step 7: Commit** — `feat(ui2-enrollment-create): group and program picker containers with the already-enrolled and overlap warnings (D11, D18, D19)`

### Task 14: schedule, invite-time, sync and access picker containers (D7, D10, D11, T8)
App: iphone
Phase: 4
Recipe: `/ios-error-surface` · SPEC §iphone *Picker containers*

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectScheduleContainer.swift`
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectValueContainers.swift` (invite time, sync, access)
- Delete: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollContainers.swift` (the last placeholders; move Task 13's temporary `existingLessonDates` here)
- Create: `iphone/MakeReadyCaptureTests/EnrollValuePickerTests.swift`

**Interfaces:**
- Consumes: `EnrollSelectScheduleMapper` (Task 10), `EnrollmentDraft` (Task 9), `EnrollmentActions.loadEnrollments(groupId:)` / `getEnrollmentDetails(id:)` (`EnrollmentActions.swift:104,147`)
- Produces:
  - `EnrollSelectScheduleContainer(flowId:)` and `@MainActor static func existingLessonDates(groupId: String, state: AppState? = nil, api: APIClientProtocol? = nil) async -> [Date]` — every `lessonSchedules[].scheduledDate` of the group's active enrollments (`getEnrollmentDetails` per active enrollment, as 1.0; A6 accepted); failures console-only, return what loaded.
  - `enum EnrollValueWrite { static func inviteTime(_ smsTime: String, timezone: String, into d: inout EnrollmentDraft); static func sync(_ mode: String, into d: inout EnrollmentDraft) -> Bool; static func access(_ value: String, into d: inout EnrollmentDraft) -> Bool }` — sync accepts only `AUTO`/`OFF`; access only `one-at-a-time`/`all-at-once` (the access screen opens on one-at-a-time with an empty value — the draft stays not-done until Save, V1).
  - `EnrollSelectInviteTimeContainer(flowId:)`, `EnrollSelectSyncContainer(flowId:)`, `EnrollSelectAccessContainer(flowId:)`.

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/EnrollValuePickerTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollment-create D7 + design §3: the three value pickers write the draft only with a valid
/// value; the schedule's existing lesson dates come from the group's active enrollments.
@MainActor
final class EnrollValuePickerTests: XCTestCase {
    func testInviteTimeStoresTimeAndZone() {
        var d = EnrollmentDraft(id: UUID())
        EnrollValueWrite.inviteTime("07:30", timezone: "America/Chicago", into: &d)
        XCTAssertEqual(d.smsTime, "07:30")
        XCTAssertEqual(d.timezone, "America/Chicago")
    }

    func testSyncAcceptsOnlyAutoOrOff() {
        var d = EnrollmentDraft(id: UUID())
        XCTAssertFalse(EnrollValueWrite.sync("APPROVAL", into: &d))
        XCTAssertNil(d.syncMode)
        XCTAssertTrue(EnrollValueWrite.sync("OFF", into: &d))
        XCTAssertEqual(d.syncMode, "OFF")
    }

    func testAccessAcceptsOnlyTheTwoModes() {
        var d = EnrollmentDraft(id: UUID())
        XCTAssertFalse(EnrollValueWrite.access("", into: &d))
        XCTAssertNil(d.lessonAccess)
        XCTAssertTrue(EnrollValueWrite.access("one-at-a-time", into: &d))
        XCTAssertEqual(d.lessonAccess, "one-at-a-time")
    }

    func testExistingLessonDatesReadTheActiveEnrollmentsSchedules() async {
        let state = AppState()
        let api = StubAPIClient()
        api.stub("GET", "/api/groups/g1/enrollments", json:
            #"{"success":true,"enrollments":[{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-01T00:00:00.000Z","endDate":"2099-01-01T00:00:00.000Z"},{"id":"e0","groupId":"g1","studyProgramId":"p0","startDate":"2020-01-01T00:00:00.000Z","endDate":"2020-02-01T00:00:00.000Z"}]}"#)
        api.stub("GET", "/api/enrollments/e1", json:
            #"{"success":true,"enrollment":{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-01T00:00:00.000Z","endDate":"2099-01-01T00:00:00.000Z","lessonSchedules":[{"id":"s1","enrollmentId":"e1","lessonId":"l1","scheduledDate":"2035-01-08T06:00:00.000Z"}]}}"#)
        let dates = await EnrollSelectScheduleContainer.existingLessonDates(groupId: "g1", state: state, api: api)
        XCTAssertEqual(dates.count, 1)
        XCTAssertEqual(api.callCount("GET", "/api/enrollments/e0"), 0)   // ended enrollments are skipped
    }
}
```

Read `loadEnrollments(groupId:)` and `getEnrollmentDetails(id:)` (`EnrollmentActions.swift:104-182`) for their exact paths and response wrappers (key names, any query string) and make the stubs match them; the three assertions stay.

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → build FAILS, `cannot find 'EnrollValueWrite' in scope`

- [ ] **Step 3: Write `EnrollSelectScheduleContainer.swift`**

```swift
import SwiftUI

/// ui2-enrollment-create T8/D10/D11: hosts the d2m-built `EnrollmentSelectScheduleScreen`. Seeds it
/// from the draft (start/weekdays/overrides survive a program change, design rule 2), gives it the
/// draft group's existing lesson dates for its overlap prompt, and on Select writes the calendar's
/// exact dates (A4: a short list is refused, the draft stays as it was).
struct EnrollSelectScheduleContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var existing: [Date] = []

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId] ?? EnrollmentDraft(id: flowId)
        let lessonCount = draft.studyProgramId.flatMap { app.programs[$0]?.days } ?? 0   // A2: days, as the server expects
        EnrollmentSelectScheduleScreen(
            state: EnrollSelectScheduleMapper.state(draft: draft, lessonCount: lessonCount,
                                                    existingLessonDates: existing, today: Date()),
            onBack: { navigator.pop() },
            onSelect: { start, end, days, overrides in
                var applied = false
                AppState.shared.updateEnrollmentDraft(flowId) {
                    applied = EnrollSelectScheduleMapper.apply(start: start, end: end, days: days, overrides: overrides,
                                                               lessonCount: lessonCount, to: &$0)
                }
                if applied { navigator.popIfTop(.enrollSelectSchedule(flowId: flowId)) }
            }
        )
        .id(existing)
        .ui2PushedPageFill()
        .task {
            guard let groupId = draft.groupId else { return }
            existing = await Self.existingLessonDates(groupId: groupId)
        }
    }

    /// D11: the group's lesson dates across its active enrollments (as 1.0 — A6 accepted).
    @MainActor
    static func existingLessonDates(groupId: String, state: AppState? = nil, api: APIClientProtocol? = nil) async -> [Date] {
        let state = state ?? AppState.shared
        let actions = EnrollmentActions(api: api ?? APIClient.shared, state: state)
        let enrollments: [EnrollmentWithProgram]
        do { enrollments = try await actions.loadEnrollments(groupId: groupId) } catch {
            state.recordError(error, context: "EnrollSelectScheduleContainer.loadEnrollments")
            enrollments = state.enrollmentsFor(groupId: groupId)
        }
        var dates: [Date] = []
        for enrollment in enrollments where enrollment.isActive {
            do { dates += try await actions.getEnrollmentDetails(id: enrollment.id).lessonSchedules.map(\.scheduledDate) } catch {
                state.recordError(error, context: "EnrollSelectScheduleContainer.getEnrollmentDetails")
            }
        }
        return dates
    }
}
```

(`@State private var existing: [Date]` is a list of dates, not server models — screen-local, outside `Pages/`/`Components/`; if `server_collection_in_view_state` still flags it, keep it and note it in the report rather than baselining.)

- [ ] **Step 4: Write `EnrollSelectValueContainers.swift`**

```swift
import SwiftUI

/// ui2-enrollment-create D7 + design §3: the three value pickers' writes — only a valid value lands.
enum EnrollValueWrite {
    static func inviteTime(_ smsTime: String, timezone: String, into d: inout EnrollmentDraft) {
        d.smsTime = smsTime
        d.timezone = timezone                         // D16: the picker's zone is the enrollment's
    }

    static func sync(_ mode: String, into d: inout EnrollmentDraft) -> Bool {
        guard mode == "AUTO" || mode == "OFF" else { return false }
        d.syncMode = mode
        return true
    }

    static func access(_ value: String, into d: inout EnrollmentDraft) -> Bool {
        guard value == "one-at-a-time" || value == "all-at-once" else { return false }
        d.lessonAccess = value
        return true
    }
}

/// D7: the invite time (`HH:mm`) and its zone are stored and sent; sending invites is out of scope.
struct EnrollSelectInviteTimeContainer: View {
    let flowId: UUID
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        EnrollmentSelectInviteTimeScreen(
            state: .init(smsTime: AppState.shared.enrollmentDrafts[flowId]?.smsTime ?? ""),
            onBack: { navigator.pop() },
            onSelect: { time, zone in
                AppState.shared.updateEnrollmentDraft(flowId) { EnrollValueWrite.inviteTime(time, timezone: zone, into: &$0) }
                navigator.popIfTop(.enrollSelectInviteTime(flowId: flowId))
            }
        )
        .ui2PushedPageFill()
    }
}

struct EnrollSelectSyncContainer: View {
    let flowId: UUID
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        EnrollmentSelectSyncScreen(
            state: .init(syncMode: AppState.shared.enrollmentDrafts[flowId]?.syncMode ?? ""),
            onBack: { navigator.pop() },
            onSave: { mode in
                var saved = false
                AppState.shared.updateEnrollmentDraft(flowId) { saved = EnrollValueWrite.sync(mode, into: &$0) }
                if saved { navigator.popIfTop(.enrollSelectSync(flowId: flowId)) }
            }
        )
        .ui2PushedPageFill()
    }
}

struct EnrollSelectAccessContainer: View {
    let flowId: UUID
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        EnrollmentSelectAccessScreen(
            state: .init(lessonAccess: AppState.shared.enrollmentDrafts[flowId]?.lessonAccess ?? ""),
            onBack: { navigator.pop() },
            onSave: { value in
                var saved = false
                AppState.shared.updateEnrollmentDraft(flowId) { saved = EnrollValueWrite.access(value, into: &$0) }
                if saved { navigator.popIfTop(.enrollSelectAccess(flowId: flowId)) }
            }
        )
        .ui2PushedPageFill()
    }
}
```

Delete `EnrollContainers.swift` and remove it from the target (`p.files.find{...}.remove_from_project` with the same gem, or Xcode's reference removal via the ruby snippet), register the two new files, resync the capture target.

- [ ] **Step 5: Run it and watch it pass** — `npm run ios:build-check -- --test` → `EnrollValuePickerTests` 4/4, suite green; swiftlint from `iphone/` → no new violation; `grep -rn "EnrollContainers.swift" iphone/MakeReady.xcodeproj` → no hit

- [ ] **Step 6: Commit** — `feat(ui2-enrollment-create): schedule, invite-time, sync and access picker containers (D7, D11)`

### Task 15: member lesson player renders the not-yet message (T11, D15)
App: client
Phase: 5
Recipe: `/page` · SPEC §client

**Files:**
- Modify: `client/app/Http/Controllers/LessonController.php:31-38`
- Create: `client/resources/views/pages/lesson-not-yet.blade.php`
- Create: `client/resources/css/pages/lesson-not-yet.scss`
- Modify: `client/resources/css/app.scss:305` (add the `@use`)
- Test: `client/tests/Feature/ContentPagesTest.php`

**Interfaces:**
- Consumes: §Contract row 2 — `GET /api/member/lessons/:lessonScheduleId` → 403 `{success:false, error:"not_yet_available", message:"This lesson is available on «Weekday, Month d»", availableOn:"yyyy-MM-dd"}`
- Produces: `GET /member/groups/{groupId}/lessons/{lessonScheduleId}/{step?}` renders `pages.lesson-not-yet` with HTTP 403 and the body's `message` on that response; every other non-200 still `abort(404)`.

- [ ] **Step 1: Write the failing test** — in `ContentPagesTest.php`, after `test_lesson_page_requires_auth`:

```php
    /**
     * ui2-enrollment-create D15: a one-at-a-time lesson opened early shows the server's message.
     */
    public function test_lesson_page_shows_not_yet_message_on_not_yet_available(): void
    {
        $this->fakeAuth([
            '*/api/member/lessons/schedule-1*' => Http::response([
                'success'     => false,
                'error'       => 'not_yet_available',
                'message'     => 'This lesson is available on Monday, November 3',
                'availableOn' => '2026-11-03',
            ], 403),
        ]);

        $response = $this->get('/member/groups/group-1/lessons/schedule-1/1');

        $response->assertStatus(403);
        $response->assertSee('This lesson is available on Monday, November 3');
        $response->assertSee('LessonNotYetPage', false);
        $response->assertDontSee('data-vue="LessonIsland"', false);
    }

    /**
     * Any other non-200 still 404s.
     */
    public function test_lesson_page_still_404s_on_other_errors(): void
    {
        $this->fakeAuth([
            '*/api/member/lessons/schedule-1*' => Http::response(['success' => false, 'error' => 'Member is not part of this group'], 403),
        ]);

        $this->get('/member/groups/group-1/lessons/schedule-1/1')->assertStatus(404);
    }
```

- [ ] **Step 2: Run it and watch it fail** — `cd client && ./vendor/bin/phpunit --filter 'test_lesson_page_shows_not_yet_message|test_lesson_page_still_404s'` → FAIL, `Expected response status code [403] but received 404`

- [ ] **Step 3: Implement**

`LessonController.php`, replacing `:36-38`:

```php
        if ($result['status'] !== 200) {
            // ui2-enrollment-create D15: a one-at-a-time lesson before its day — show the server's
            // message instead of the 404 page.
            $body = $result['body'] ?? [];
            if ($result['status'] === 403 && ($body['error'] ?? null) === 'not_yet_available') {
                return response()->view('pages.lesson-not-yet', [
                    'message' => $body['message'] ?? 'This lesson is not available yet',
                ], 403);
            }
            abort(404);
        }
```

`client/resources/views/pages/lesson-not-yet.blade.php`:

```blade
{{-- ui2-enrollment-create D15: a one-at-a-time lesson opened before its day. --}}
@extends('layouts.auth')

@section('title', 'Lesson not available yet — MakeReady')

@section('content')
<div class="LessonNotYetPage">
    <p class="LessonNotYetPage__message">{{ $message }}</p>
</div>
@endsection
```

`client/resources/css/pages/lesson-not-yet.scss` (tokens only — the page shell matches `.NotFoundPage`'s centring):

```scss
// ui2-enrollment-create D15: the not-yet line on the member lesson player.
.LessonNotYetPage {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: var(--space-lg);
  background: var(--color-background-dark);

  &__message {
    max-width: 32rem;
    margin: 0;
    font-size: var(--text-lead);
    font-weight: var(--font-weight-medium);
    color: var(--color-white-80);
    text-align: center;
  }
}
```

`app.scss`, after line 305: `@use 'pages/lesson-not-yet' as page-lesson-not-yet;`

Confirm `$result['body']` is the decoded array (`ApiService.php:56-79`), and that `--text-lead`, `--color-background-dark`, `--color-white-80`, `--space-lg`, `--font-weight-medium` are defined in `resources/css/styles` (`grep -rn -- "--text-lead:" client/resources/css/styles`); use the nearest defined token if one is not.

- [ ] **Step 4: Run it and watch it pass** — `cd client && ./vendor/bin/phpunit --filter ContentPagesTest` → PASS; `cd client && npm run build` → ok; `cd client && npm run guard` → record the before/after violation count (the delta must be 0)

- [ ] **Step 5: Commit** — `feat(ui2-enrollment-create): lesson player shows the not-yet message on a one-at-a-time 403 (D15)`
