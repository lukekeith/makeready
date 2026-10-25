# ui2-fixtures — spec
> ✅ SHIPPED 2026-10-25 — merged into ui2-preview-build · no ticket · 🤖 agent signed off (walk round 2), not human-tested
> lg · ticket none

## Idea

**Why.** Every UI 2.0 screen gets walked locally before it ships, and an empty local database makes
that walk worthless: the new Home renders zeros in every section, so its charts, trends and day cards
are never seen with real numbers. The owner wants a local fixture world that each new UI 2.0 screen
adds to, with Home as the first layer, and a way to return it to a known state at any time.

**What success looks like.** On the Local environment, the owner picks "Fixtures" as the dev identity
on the Profile stopgap. Home's Overview then shows a 24-day completed-lessons sparkline with a non-zero
total and an upward trend, plus a non-zero total video time. Activity shows lesson counts on most past
days. Running `npm run fixtures:reset` in the server container at any time rebuilds that world, with
dates moved to stay relative to today. The owner's own local org and data are never touched. Every
later UI 2.0 screen feature ships its own fixture layer, so its walk starts with data too.

**In your words.**
- "I need a set of seeded fixtures locally to test so I can test the whole home page full with data" → D1, D6
- "Fixtures locally will also need a way to be reset at any time" → D4, D7
- "this is something I want to do with every new ui2.0 screen we implement so I can locally test" → D2, D5

**The concept.** One fixture org, owned by a dedicated fixture user, built in layers: a **base** layer
(org, owner, groups, members, programs, enrollments, lesson schedules) and one **screen layer** per
UI 2.0 screen, each adding only what its screen reads. Each layer takes a scenario name. Today only
`full` is filled in; `empty` runs the base layer alone. Reset deletes the whole fixture graph by its
fixed IDs, re-runs every layer with dates computed from "now", then refreshes the analytics
materialized view so Home reads the new rows straight away.

```mermaid
flowchart LR
  CMD[npm run fixtures:reset -- full] --> G{guard: NODE_ENV=development<br/>+ local DB host}
  G --> W[wipe fixture graph by fixed IDs]
  W --> B[base.ts]
  B --> L1[screens/home-dashboard.ts]
  L1 --> Ln[screens/&lt;next screen&gt;.ts]
  Ln --> R[refreshAnalytics — retried until it runs]
  R --> DB[(makeready_dev)]
  iPhone[iPhone Local · dev identity = Fixtures] -- POST /auth/dev-login fixtures@makeready.local --> DB
```

**How it fits today.** Home reads Overview and Activity from `POST /api/analytics/query` over the
`analytics_events` materialized view¹. Its `lc:` arm projects `member_lesson_progress.completedAt` and
its `vw:` arm projects `member_video_progress.watchedSeconds`, each joined through `lesson_schedules →
enrollments → groups → organizationId`². The view refreshes every 10 minutes³. Home filters every query
to `AppState.organizationId`, which is the org the signed-in user **owns**
(`/api/organizations/my/organization`)⁴. Local sign-in is a hard-wired dev-login as the owner's own
account⁵, which owns their real local "MakeReady" org. So fixtures seeded into any other org would be
invisible, and that is why a dedicated fixture identity is needed. Sessions, Engagement and Following
are rendered empty by design (ui2-shell D8) until their server endpoints exist. The existing
`prisma/seed-dev.ts` starts with `deleteMany({})` on every table, users and orgs included, and seeds no
progress rows. It is neither reused nor changed here.

**Approaches considered.** *Chosen:* one shared fixture world with a layer per screen, under a
dedicated fixture account. Reset is isolated by construction, and every screen sees the same groups,
members and enrollments. *Rejected:* independent per-screen packs (entities duplicated, screens
disagree on numbers); one growing seed file (no ownership per screen, unreadable over time); fixtures
inside the owner's own org (numbers blend with hand-made data, and reset needs row-level bookkeeping);
an app-side fixture mode (fills every section but tests none of the real data path).

¹ `server/src/services/analytics.service.ts` · ² `server/atlas/migrations/20260730040000.sql` (lc:, vw:, mj:, ce: arms) · ³ `analytics.service.ts:42` · ⁴ `iphone/MakeReady/State/AppState.swift:919`, ui2-shell D26 · ⁵ `iphone/MakeReady/AuthManager.swift:128`

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | New `server/fixtures/` (runner, base layer, `home-dashboard` layer, README, own `tsconfig.json`), `fixtures:reset` / `fixtures:seed` npm scripts, and a `./server/fixtures:/app/fixtures` + `./server/package.json:/app/package.json` volume on the `server` service in the root `docker-compose.yml` (D16). No route, no schema, no service change | §server |
| client | ⬜ | Web renders no UI 2.0 screen, and the fixture user has no `googleId`, so it can't sign in to `/admin`. Nothing on web reads or changes | — |
| iphone | ✅ | Dev-only "Local identity" picker on the Profile stopgap (You / Fixtures). `AuthManager` dev-login uses the selected identity's email. Hidden when `DEV_MODE` ≠ YES | §iphone |
| capture | ⬜ | Capture uses its own `makeready_capture` database and JSON fixtures, not `makeready_dev`. The fixture world is never captured | — |

Repo config (no app): `.claude/builder.md` gains the house rule (D5).

**Sequencing:** server (the fixture world + the fixed identity; contract freezes when it verifies) →
iphone (picker against the frozen identity) → builder.md rule → the walk.

**Backward compatibility:** A released iPhone build has `DEV_MODE` off: no picker, and Local is
unreachable. It sees nothing. Older dev builds keep dev-logging in as the owner, as today.

**Blast radius:** Fixture rows live in `makeready_dev`, so every reader of that database sees them only
when scoped to the fixture org. The analytics view gains fixture rows, scoped by `organizationId`. A
Super Admin's unscoped analytics on Local will include them (D11).

## Decisions

<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | What the Home fixtures fill | Real database rows read through the real API. Overview (both KPI cards) and Activity are non-empty after a `full` reset. The `home-dashboard` layer also seeds `membership_events` and `client_events`, so Sessions, Engagement and Following have data the day their endpoints land. No iPhone data-path change. Why: tests the real end-to-end path. Rejected: Overview + Activity rows only (must be extended later); build the three missing endpoints (large, blocked on OQ-home-dashboard-1/2/4); an app-side fixture mode (tests no real data path) | user 2026-10-25 |
| D2 | Layout of the fixture world | `server/fixtures/index.ts` (runner) → `base.ts` → every file in `server/fixtures/screens/`, run in filename order, all sharing one `FixtureContext` (fixed IDs, `now`, the created entities). A screen layer may read base entities and must not create orgs, users or groups of its own. Why: screens share entities, so one world keeps their numbers consistent. Rejected: independent per-screen packs (duplicated entities, screens disagree); one growing seed file (no per-screen ownership) | user 2026-10-25 |
| D3 | Fixture identity | User `fixtures@makeready.local`, name "Fixture Leader", owner of org "MakeReady Fixtures"; both have fixed IDs. iPhone dev builds pick the Local dev-login identity: **You** (`luke@lukekeith.com`, today's behaviour) or **Fixtures**. Why: Home scopes to the user's owned org, so only a separate owner sees the fixture org; an isolated graph makes reset unable to touch real data. Rejected: seed inside the owner's MakeReady org (numbers blend, row-level reset); wipe the owner's local org on reset (destroys hand-made data) | user 2026-10-25 |
| D4 | How seed and reset run | `server/package.json` scripts `fixtures:reset` (wipe + seed) and `fixtures:seed` (seed only; fails if the fixture user already exists), each taking an optional scenario argument (default `full`). Run as `docker exec makeready-server npm run fixtures:reset [-- <scenario>]`. No HTTP endpoint and no in-app button. Why: simplest surface. Rejected: an in-app reset button via a dev-only endpoint (more surface); a capture-tool button (needs capture running) | user 2026-10-25 |
| D5 | Pipeline enforcement | `.claude/builder.md` §House rules gains a **fixtures** line: a feature that wires a UI 2.0 screen into the iPhone app adds `server/fixtures/screens/<screen-id>.ts` (screen id as in `docs/ui2/screens/`), whose `full` scenario makes every section the feature wires non-empty. §Walk readiness gains `fixtures: docker exec makeready-server npm run fixtures:reset`, run before the walk. The audit flags a missing layer. Why: "every new screen" holds only if enforced. Rejected: a README convention (screens ship without fixtures) | user 2026-10-25 |
| D6 | Scenarios | Each layer exports `{ full?: (ctx) => Promise<void>, sparse?, extreme? }`. The runner accepts `full` (default) and `empty`; `empty` runs base only. Naming an unknown scenario, or one no layer implements beyond base, exits non-zero and lists the available scenarios. A screen adds `sparse`/`extreme` when its spec lists those states. Why: specs list empty/overflow states, and the slot avoids boxing in later screens. Rejected: one full world only (no empty-state testing); all four for Home now (3× the first layer, sets that bar for every screen) | user 2026-10-25 |
| D7 | What reset deletes | Exactly, in this order: `client_events` whose `organizationId` is the fixture org or whose `memberId` is a fixture member (no FKs, so explicit); the fixture members by fixed ID (cascades `group_members`, `member_organizations`, all three progress tables and `membership_events`); `groups` and `study_programs` whose `organizationId` is the fixture org (a backstop: `organizationId` has no FK); then the fixture user, which cascades the owned org (`organizations.ownerId` Cascade) and — because the base layer sets every group's and program's `creatorId` to the fixture user — its groups, programs, lessons, activities, enrollments, schedules, `user_roles` and `member_organizations`. The system `Owner` role is never deleted. Nothing else. Corrected at audit 2026-10-25: the org→groups/programs cascade the first ruling assumed does not exist (schema.prisma:247, :860). Reset is idempotent: running it twice leaves the same row counts. Why: isolation by construction. Rejected: reusing `seed-dev.ts` (wipes every table) | (assumed at brainstorm) |
| D8 | Safety guard | The runner refuses (exit 1, message names the reason) unless `NODE_ENV` is `development` or `test` **and** the `DATABASE_URL` host is one of `postgres`, `localhost`, `127.0.0.1`. `test` is admitted because `server/test/setup.ts:19` forces `NODE_ENV=test` for every vitest run; the host check is what keeps a test run off a remote database (amended at audit 2026-10-25, auto (recommended)). Why: it deletes rows and must never reach staging or production. Rejected: no guard (one mistyped env deletes a real account's graph) | (assumed at spec) 2026-10-25 |
| D9 | Dates move with the reset | Every timestamp is computed from `now` at run time in UTC; nothing is a literal date. After any reset, Home's 24-day window and its previous-24-day comparison window are both populated. Why: literal dates age out of the window. Rejected: frozen dates (Home empties within weeks) | (assumed at brainstorm) |
| D10 | Analytics refresh | After seeding, the runner calls `refreshAnalytics()` (returns `{refreshed, skippedLockHeld?, error?}`, never throws — analytics.service.ts:90) and, while it returns `skippedLockHeld: true`, retries every 2 s for up to 30 s. It exits non-zero if no call returned `refreshed: true`, printing the `error` when there was one. The runner ends with `process.exit`, because the service's `pg.Pool` has no exported close (corrected at audit 2026-10-25: there is no `locked` value). Why: without it Home shows nothing for up to 10 min. Rejected: waiting for the scheduled refresh (walk starts on stale data) | (assumed at brainstorm) |
| D11 | Home `full` scenario content | Base: 3 groups ("Tuesday Men's Group", "Young Adults", "Women's Bible Study"), 24 members (8 per group, fake numbers `+1555010xxxx`, `phoneVerified` true), 2 published programs (21 and 30 days, 3 activities per lesson incl. one VIDEO), 4 enrollments, every day enabled (`enabledDays` all seven), `timezone` `America/Chicago`, `createdById` the fixture user, staggered so their schedules together cover every day from now−48 d to now+7 d (one schedule per lesson — `@@unique([enrollmentId, lessonId])`, schema.prisma:1053): E1 group 1 × 30-day program, days −48…−19; E2 group 2 × 30-day program, days −29…0; E3 group 3 × 21-day program, days −20…0; E4 group 1 × 21-day program, days −13…+7 (stagger added at audit 2026-10-25, auto (recommended)). Home layer: `member_lesson_progress.completedAt` on past schedules for 48 days, with a weekday rhythm (Sat/Sun ≈ 40% of weekdays) and volume rising so the last 24 days total 15% (±3%) more than the 24 before; `member_video_progress` totalling 40 h (±2 h) `watchedSeconds`; one `membership_events` ADDED per member; `client_events` `LESSON_OPENED` spread across 07:00–21:00 `America/Chicago`; completions and watch times are placed in the same 07:00–21:00 Chicago band, so they fall on the same calendar day on any US-timezone device (zone fixed at audit 2026-10-25, auto (recommended)). Super Admin unscoped analytics on Local include these rows; accepted. Why: fills every number Home reads with realistic shape. Rejected: uniform random data (no trend, no rhythm to eyeball) | (assumed at brainstorm) · numbers fixed at spec 2026-10-25 |
| D12 | Leader gate | The fixture user passes `GET /auth/leader-access` because it owns the fixture org (`canAccessIosApp`). No role rows are required for that; the base layer also gives it a `UserRole` (`organizationId` the fixture org) on the **system** `Owner` role, looked up by name (`isSystem`, `organizationId` NULL) and never created, so RBAC-checked endpoints behave as they do for a real owner. Why: ui2-shell D7 signs out a denied account | (assumed at spec) 2026-10-25 |
| D13 | iPhone identity picker | Below the environment radios on `ProfileStopgapContainer`, shown only when `DEV_MODE` is YES **and** the selected environment is Local: a "Local identity" group of two existing `RadioOptionRow`s (You · Fixtures, the description showing the email). The selection persists in `UserDefaults` (`devLoginIdentity`, default You). Picking the other identity calls `EnvironmentActions.switchIdentity(_:auth:)` (beside `switchTo`, not in the container), which persists the identity, runs `AuthManager.signOut()` (`clearAllData()` drops `AppState` and the environment's disk cache), then `signIn()`, which dev-logs in with the selected email. `UI2Root` shows Login while signed out (UI2Root.swift:10-14), so the switch passes through a brief Login and lands on Home. On failure the identity reverts to You and the error renders on Login through `LoginOutcome.message(for:)`. `AuthManager.signInToReachableLocal()` (AuthManager.swift:531) also dev-logs in with the selected identity's email. Why: the existing switcher is the dev-tools home, and clearing state stops one identity's cached Home bleeding into the other. Rejected: a picker on Login (Login has no dev controls in 2.0); identity without sign-out (stale `AppState.dashboard` from the other org); an inline error on Profile (Profile is unmounted by the sign-out). | (assumed at spec) 2026-10-25 · corrected at audit 2026-10-25, auto (recommended) |
| D14 | Fixture user not found | When the Fixtures identity is selected and `/auth/dev-login` returns 404 with body `error: "User not found"` (fixtures never seeded — a 404 `Not found` means the server is not in development and keeps today's handling), `devLogin` throws `AuthError.fixturesNotSeeded`, from both `signIn()` and `signInToReachableLocal()` (so `switchTo(.local)` surfaces it instead of `localServerUnreachable`), and the message on Login reads "Fixtures not seeded — run npm run fixtures:reset in the server container." and the identity reverts to You. Why: the likeliest first-run failure gets an actionable message | (assumed at spec) 2026-10-25 |
| D15 | Layer authoring guide | `server/fixtures/README.md` documents: the run command, scenarios, the `FixtureContext` API, the fixed-ID scheme (valid UUIDs prefixed `f1f1f1f1-` with a per-kind second group, e.g. `f1f1f1f1-0003-…` for groups), the rule that dates come from `ctx.now`, and a 20-line template for a new `screens/<screen-id>.ts`. Why: D5 makes every UI 2.0 feature write a layer | (assumed at spec) 2026-10-25 |
| D16 | Where `fixtures:*` runs | The root `docker-compose.yml` `server` service gains volumes `./server/fixtures:/app/fixtures` and `./server/package.json:/app/package.json`; after this feature lands, one `docker compose up -d --build server` makes `docker exec makeready-server npm run fixtures:reset` work (README states it). The same scripts also run from the host (`cd server && npm run fixtures:reset`) with `DATABASE_URL` pointing at `localhost:5434`, which is how the agent walk env runs them. Why: the container mounts only `src`, `prisma`, `atlas` and bakes `package.json` at build (docker-compose.yml:26-30), so D4's command could not run. Rejected: host-only (contradicts D4's container command); copying fixtures into the image (needs a rebuild per layer edit) | auto (recommended) 2026-10-25 |
| D17 | Typechecking the fixtures | `server/fixtures/tsconfig.json` extends `../tsconfig.json` with `rootDir: ".."`, `include: ["./**/*.ts", "../src/**/*.ts"]`, `noEmit: true`; the server fast gate adds `cd server && npx tsc --noEmit -p fixtures`. Why: `server/tsconfig.json` has `include: ["src"]`, `rootDir: "./src"`, so `tsc --noEmit` never sees `fixtures/`, and adding it there breaks `rootDir` (TS6059). Rejected: widening the root tsconfig (changes the build output layout) | auto (recommended) 2026-10-25 |
| D18 | Which database the fixture tests use | The DB-backed tests (§Testing b–e) read `FIXTURES_TEST_DATABASE_URL`; absent, the suite is skipped with a printed `fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL` line, never silently. The build runs them against a throwaway `makeready_fixtures_test` database on the local postgres (`localhost:5434`), created and migrated (`npm run migrate:apply`) by the task and dropped after, and quotes the output. Guard (a) and scenario (f) tests need no database. Why: the server has no test database — `test/setup.ts` falls back to `.env`, i.e. `makeready_dev` — and the isolation test must not run against the owner's data. Rejected: running against `makeready_dev` (touches the owner's dev DB); skipping DB tests entirely (no evidence for D7/D9/D11) | auto (recommended) 2026-10-25 |
| D19 | What Activity shows in the walk | Activity is "non-empty" (D1) when past day cards read non-zero "N lessons" with weekends lower and today/future at 0. Bars are not expected: `HomeDashboardMapper.swift:36,45` (ui2-shell) sets `chartScheduled` and every `daySeries` to zeros and `DualSeriesBarChart` draws columns only when some scheduled count is above 0, so no fixture rows can draw them without the iPhone data-path change D1 rules out. §Testing step 5 reworded to match. Why: the agent walk round 1 found the counts right and the bars flat, from the consumer code, not the data. Rejected: changing the mapper here (contradicts D1; ui2-shell owns it) | auto (recommended) 2026-10-25 — agent walk round 1 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| Fixture identity — `POST /auth/dev-login` (existing, unchanged) with `email: fixtures@makeready.local` | server (fixtures base layer seeds the user) | iphone (D13 picker) | none; dev only (`NODE_ENV=development`) | `{ email }` | 200 `{ success, user, sessionCookie }` as today | 404 `{success:false, error:"User not found"}` when not seeded (→ D14); 404 `{error:"Not found"}` when `NODE_ENV` ≠ development (auth.ts:1185-1198) |
| Fixture world — the fixture org's rows are readable through existing endpoints (`/api/analytics/query`, `/api/organizations/my/organization`, `/auth/leader-access`) as for any owner | server | iphone (Home via `DashboardActions`, unchanged) | session | unchanged | unchanged; non-empty for the fixture org after a `full` reset | unchanged |
| `npm run fixtures:reset [-- full\|empty]` / `fixtures:seed` | server | the owner (terminal); the builder walk (D5) | container shell (D16) or host shell with a local `DATABASE_URL` | scenario name | exit 0 + a summary table of row counts per model | exit 1: guard refused (D8), unknown scenario (D6), refresh never ran (D10); `fixtures:seed` with an existing fixture user |

## Schema & API changes

No schema change (established 2026-10-25). No API change: `/auth/dev-login` and every read endpoint are
used as they are.

**Data plan:** Only rows under the fixture IDs are created or deleted (D7). Existing local rows are
never read or modified.

## server

- `server/fixtures/index.ts`: CLI entry. Parses the scenario and runs the guard (D8). On `reset` it
  runs the wipe (D7), then base plus each screen layer's scenario function in filename order (D2, D6),
  then the refresh (D10), and prints row counts per model. Uses the generated Prisma client.
- `server/fixtures/context.ts`: `FixtureContext { now: Date, ids, prisma, created: { user, org, groups[], members[], programs[], enrollments[], schedules[] } }`, plus helpers `daysAgo(n)`, `atLocalHour(date, h)`, and a deterministic seeded PRNG (fixed seed, so two resets produce identical relative data).
- `server/fixtures/ids.ts`: every fixed UUID (user, org, groups, members, programs, enrollments) in one place.
- `server/fixtures/base.ts`: the D3/D11/D12 base world.
- `server/fixtures/screens/home-dashboard.ts`: the D11 Home layer (`full` only).
- `server/fixtures/README.md`: D15.
- `server/package.json`: `fixtures:reset`, `fixtures:seed` (via `tsx`).
- `server/fixtures/tsconfig.json` (D17).
- Root `docker-compose.yml`: the D16 volumes. One `docker compose up -d --build server` after landing; no restart per layer edit after that.
- Not touched: `server/src/**`, `prisma/seed-dev.ts`, the seeds manifest.
- Required fields the base layer must set (no default): User `email`,`name`; Organization `name`,`ownerId`; Group `name`,`creatorId`,`organizationId`; Member `phoneNumber` (global `@unique`); StudyProgram `name`,`creatorId`, plus `organizationId`, `isPublished: true`, `publishedAt`; Lesson `dayNumber`; LessonActivity `activityType`,`title`; Enrollment `startDate`,`endDate`,`enabledDays` (JSON string),`createdById`; LessonSchedule `scheduledDate`; ClientEvent `id`,`eventType`,`occurredAt`; UserRole `userId`,`roleId`,`organizationId`; MembershipEvent `memberId`,`action`,`organizationId`. Members also get `member_organizations` rows for the fixture org. Progress rows carry `lessonScheduleId` (the `lc:`/`vw:` arms inner-join through it); `member_lesson_progress` rows leave `pinnedVersionId` and `removedAt` NULL; `member_video_progress` sets `lastWatchedAt` explicitly.

## iphone

- `AuthManager.swift`: replace the `devLoginEmail` constant (`:128`) with `DevLoginIdentity.current.email` at both callers, `signIn()` (`:141`) and `signInToReachableLocal()` (`:531`). `devLogin` stops throwing a bare `URLError` on non-200 (`:465-470`): a 404 whose body `error` is `User not found` while the identity is `.fixtures` throws `AuthError.fixturesNotSeeded` (D14); other failures keep today's error.
- `LoginOutcome.swift`: `message(for:)` gains the D14 string for `.fixturesNotSeeded`.
- New `DevLoginIdentity` enum (`you`, `fixtures`; `email`, `title`; `current` read/written in UserDefaults `devLoginIdentity`) **inside** `Configuration.swift`, beside `SelectedEnvironment`, so no new file needs pbxproj entries.
- `EnvironmentActions.swift`: `switchIdentity(_:auth:)` per D13; `switchTo(.local)` lets `fixturesNotSeeded` through instead of mapping it to `localServerUnreachable`.
- `ProfileStopgapContainer.swift` (`MakeReady/UI2/Containers/Profile/`): the D13 identity group (`RadioOptionRow` title + email description) and a static `showsIdentityPicker(devMode:env:)`. Switching environment away from Local hides the group and leaves the stored identity.
- The dead `#if DEBUG` bypass in legacy `LoginView.swift:132` is left alone.
- 🔴 Commit is the owner's (`commit: manual`): the task stages and stops.

## Testing

**server** — vitest under `server/fixtures/__tests__/` against the local test DB:
(a) the guard refuses for `NODE_ENV=production` and for a non-local host; (b) `reset full` twice gives
identical row counts per model (idempotence); (c) after `reset full`, a row-count snapshot of rows not
under fixture IDs is unchanged (isolation); (d) after `reset full`, `analytics.service` query for
`lesson_completions` × `day` scoped to the fixture org over the last 24 days is non-zero on ≥ 18 days,
its total is 115% (±3%) of the previous 24 days, and `watch_seconds` — a snapshot metric, queried with no time range (the service 400s on one, as Home's own query omits it, DashboardActions.swift:41) — is 144 000 (±7 200); days bucketed in `America/Chicago`; (e) `reset
empty` leaves the base entities and zero progress rows; (f) an unknown scenario exits 1. Plus
`npx tsc --noEmit` and `npx tsc --noEmit -p fixtures` (D17). DB-backed tests per D18.

**iphone** — XCTest in `MakeReadyCaptureTests`: `DevLoginIdentity` default is `.you` and persists; `AuthManager` chooses the email
by identity in both `signIn()` and `signInToReachableLocal()` (the `AuthIO` seam, as `AuthManagerLaunchTests.swift`); a 404 `User not found` for `.fixtures` maps to `fixturesNotSeeded` and a 404 `Not found` does not; `EnvironmentActions.switchIdentity` reverts to `.you` on failure (`EnvironmentActionsTests.swift`); `showsIdentityPicker(devMode:env:)` is
true only for `(true, .local)` (`ProfileStopgapTests.swift`). Plus `npm run ios:build-check -- --test` and swiftlint from `iphone/`.

**Cross-app E2E walk (verify):** `fixtures:reset` → simulator dev build on Local → Profile → identity
Fixtures → Home shows non-zero Overview + Activity → identity You → Home shows the owner's own numbers.

**Human verification script:**
1. `docker exec makeready-server npm run fixtures:reset`: exits 0 and prints counts (3 groups, 24 members, 4 enrollments).
2. In the simulator (dev build, Local), open Profile: a "Local identity" group shows You (selected) and Fixtures.
3. Pick Fixtures: the app passes through a brief Login and lands on Home, signed in as Fixture Leader.
4. Overview: "Completed lessons" has a filled sparkline, a non-zero total and an up trend near +15%. "Total video time" reads about 40.0hrs.
5. Activity: most past days show "N lessons" (non-zero), weekend counts visibly lower than weekdays, and today and future days at 0. The bars stay flat in release 1 — ui2-shell's mapper never feeds scheduled counts (D19).
6. Sessions, Engagement, Following still show their empty states (ui2-shell D8).
7. Run `fixtures:reset` again, then relaunch the app: the same shape, with no duplicated totals.
8. `fixtures:reset -- empty`, then relaunch: Home is zeroed but signs in fine.
9. Pick You: Home shows your own org's numbers, unchanged by any of the above.
10. Switch environment to Production: the identity group disappears.

## Out of scope

- Sessions, Engagement and Following endpoints and wiring (the home-dashboard API-GAPs).
- Fixture layers for any screen other than `home-dashboard`. Each later UI 2.0 feature adds its own (D5).
- `sparse` and `extreme` scenarios for Home.
- Changing or retiring `prisma/seed-dev.ts`, `seed-lessons.ts`, `seed-e2e.mjs` or the versioned seeds.
- Fixtures in the capture database, on web, or in any deployed environment.
- An HTTP reset endpoint or an in-app reset button (D4).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | stale-spec: the container mounts only `src`, `prisma`, `atlas` and bakes `package.json` (docker-compose.yml:26-30), so `docker exec makeready-server npm run fixtures:reset` could never find the scripts; §server's "no container restart" was wrong | D16 added; §Apps, §server, §Contract corrected |
| F2 | data-integrity: `groups.organizationId` and `study_programs.organizationId` have no FK (schema.prisma:247, :860); the org→group cascade D7 relied on does not exist. They cascade from the user through `creatorId` | D7 rewritten with the real delete order and an `organizationId` backstop |
| F3 | stale-spec: `refreshAnalytics()` never returns `locked`; it returns `skippedLockHeld` and owns an unclosable `pg.Pool` (analytics.service.ts:57, :90, :114) | D10 corrected |
| F4 | stale-spec: `@@unique([enrollmentId, lessonId])` caps an enrollment at one schedule per lesson, so a 56-day window cannot come from 21/30-day programs without a stagger | D11 stagger E1–E4 |
| F5 | gap: "06:00–22:00 local" named no timezone while Home buckets by device timezone | D11 fixes `America/Chicago` and a 07:00–21:00 band; §Testing (d) buckets in it |
| F6 | stale-spec: `watch_seconds` is a snapshot metric and a ranged query 400s (analytics.service.ts:539) | §Testing (d) corrected |
| F7 | stale-spec: `tsc --noEmit` never checks `fixtures/` (tsconfig `include: ["src"]`, `rootDir: "./src"`) | D17 |
| F8 | gap: vitest forces `NODE_ENV=test` (test/setup.ts:19), which the D8 guard refused, and the server has no test database | D8 amended; D18 |
| F9 | contract: both 404s from `/auth/dev-login` look the same to the iPhone (`URLError(.userAuthenticationRequired)`, AuthManager.swift:465-470); D14 must key on the body | D14 + §Contract keyed on `User not found` |
| F10 | design-affecting: a sign-out unmounts Profile (UI2Root.swift:10-14), so D13's inline error could never show; the switch belonged beside `switchTo` in `EnvironmentActions` | D13 corrected: switch in `EnvironmentActions`, error on Login |
| F11 | contract: `signInToReachableLocal()` (AuthManager.swift:531) is a second dev-login caller the spec missed; with Fixtures unseeded, a switch to Local would say "Can't reach the local server" | D14 + §iphone cover both callers |
| F12 | ⬜ claims re-derived: client reads no analytics query (its dashboards read `activity-logs/stats`; it only ingests events), and capture uses `makeready_capture` (capture/db/index.mjs:14) | both ⬜ rows stand |
| F13 | released build: Release.xcconfig:15 sets `DEV_MODE = NO`, so the picker and dev-login are unreachable; every iPhone change is additive behind DEV_MODE | §Apps *Backward compatibility* stands |
| F14 | note: the session table has no FK, so with the fixed user ID an iPhone session survives a reset — the walk's step 7 relaunch stays signed in | intended; no change |
| F15 | build-time risk: Prisma may override an explicit `lastWatchedAt` on create (`@updatedAt`) | Phase 1, the `home-dashboard` layer task — assert it in test (d) |
| F16 | build-time risk: the +15% (±3%) trend and ≥ 18 non-empty days depend on tuning the PRNG against the D11 stagger | Phase 1, the `home-dashboard` layer task — test (d) settles it |
| F17 | build-time risk: on every identity switch `signOut()` calls `/auth/logout` and removes the push token, and `StatePersistence`'s debounced save could rewrite the old identity's snapshot after `clear()` | Phase 2, the `switchIdentity` task — test that no snapshot is written after `clearAllData()` |
| F18 | build-time risk: the agent walk env runs the server natively, so D5's walk-readiness `fixtures:` line must use the host form (`cd server && npm run fixtures:reset`) under `agent_walk.env`; the dev-env form stays `docker exec` | Phase 3, the builder.md task — write both forms |
| F19 | follow-up (ui2-shell, not this feature): Home's Activity bars and day-card mini-charts never draw for any account, because `HomeDashboardMapper.swift:36,45` zeroes `chartScheduled`/`daySeries`, and each day card's first line is hardcoded `"0 mins"` (:46), so per-day watch time never shows either. The fixture world now has 102 `lesson_schedules` to light them up once ui2-shell maps scheduled counts. Also seen: the Activity rail opens at the window's end, not today (ui2-shell D22) | D19; carried to the hand-off for the owner |
