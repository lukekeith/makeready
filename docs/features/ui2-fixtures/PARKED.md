# ui2-fixtures — parked
parked: 2026-10-25 2496e52 · by build phase 3
kind: human-step
blocked: "the iPhone half (the Local identity picker) needs your OK to commit iPhone code — next: /builder:resume --path docs/features/ui2-fixtures, approving the iPhone commits as they are staged"

## What is stuck
Nothing is broken. The server half is built: `server/fixtures/` seeds the fixture world, `fixtures:reset`
works, and the contract is frozen. What remains is phase 3, the iPhone app: the "Local identity" picker
on the Profile stopgap (You / Fixtures) and the dev-login changes behind it. `.claude/builder.md` marks
`iphone` as `commit: manual` (a released artifact), so committing iPhone code is your call at every
size and under every flag, and an unattended run parks at the start of that phase instead of
building it.

## What was tried
- Phases 1–2 (server, Tasks 1–5) built and reviewed: 17ab868, ff6a296, a954f1d, 9446c7f, 9823ce7; contract frozen in 2496e52.
- No iPhone code was written or staged.

## Evidence
- `.claude/builder.md` apps: `- name: iphone … commit: manual … released_artifact: true`.
- Fixtures suite, run fresh by the controller on a throwaway `makeready_fixtures_test` DB (then dropped):
  `Test Files  7 passed (7)` · `Tests  42 passed (42)`. Real-run numbers from Task 4: 23 of 24 days
  non-empty, last-24 vs previous-24 = 108 vs 94 (+14.9%), `watch_seconds` = 144000.
- Server fast gate: tsc ✓, tsc -p fixtures ✓, schema:validate ✓. `test:run` red on 25 tests / 35 files,
  all outside `server/fixtures/` and identical before and after this feature's code — the worktree has
  no `server/.env`, so every DB-backed suite fails `Environment variable not found: DATABASE_URL`.
  `schema:diff` / `migrate:status` exit 127, because `server/bin/atlas` is absent in fleet worktrees.

## Where to dig
- `docs/features/ui2-fixtures/PLAN.md` Task 6 (DevLoginIdentity, identity-aware dev-login, `fixturesNotSeeded`) and Task 7 (`EnvironmentActions.switchIdentity`, the Profile picker, the Login notice) carry the complete Swift code and XCTests.
- SPEC D13, D14 and §iphone are the iPhone rulings, corrected at audit (switch in `EnvironmentActions`, error on Login, both dev-login callers).

## Recommended next step
Run `/builder:resume --path docs/features/ui2-fixtures` in a session where you can approve: the build
picks up at Task 6, the implementer stages each iPhone task, and you approve the commit per task or
once for the phase. Alternatives: build the iPhone tasks yourself from PLAN.md, or drop the iPhone
half via `/builder:revise` and use the fixture identity some other way. Both lose the reviewed plan's
path.

## History
- 2026-10-25 parked — iPhone is commit: manual; server half built and contract frozen
- 2026-10-25 unparked by luke — building phase 3 here with per-task iPhone commit approval
