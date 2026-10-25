# home-dashboard-data — parked
parked: 2026-10-25 c589088 · by build phase 4
kind: human-step
blocked: "iPhone commits are yours to approve (commit: manual); the server half is built and its contract frozen — next: /builder:resume --path docs/features/home-dashboard-data, approving each staged iPhone task"

## What is stuck
Nothing is broken. The server half (phases 1–3, tasks 1–7) is built, reviewed and gated, and the
contract froze on 2026-10-25. Phase 4 is the iPhone app, which `.claude/builder.md` marks
`commit: manual` (a released artifact), so every iPhone commit is the owner's call. An unattended run
may not make it, so the build stops at the start of that phase (resume §`--agent-walk`).

## What was tried
- Tasks 1–7 built by subagents, each task-reviewed (one fix round on Task 5: deleted programs now hidden from Following) — 54168ac..6c50700
- Server fast gates at 6c50700: tsc ✓ · tsc fixtures ✓ · schema:validate ✓ · schema:diff ✓ · migrate:status ✓ · test:run 589 pass / 27 fail, and all 27 are pre-existing (below)
- The new matview migration (`server/atlas/migrations/20261025120000.sql`) applied cleanly to a throwaway DB, and the fixtures DB tests pass 49/49 there

## Evidence
- Same 27 failures on the pre-feature tree 39ff29f, run in an export of it against the same DB: `src/routes/__tests__/users.test.ts` 1 (`expected 500 to be 404`), `test/lesson-activities.test.ts` 11 (`PrismaClientKnownRequestError`), `test/integration/production.test.ts` 15 (fetches the live production URL: `Unexpected token '<', "<!DOCTYPE "...`)
- The server gates need env vars because a worktree has no `server/.env`: the config's `agent_walk.env` values plus `DATABASE_URL` pointed at a throwaway DB. Without them, passport throws `OAuth2Strategy requires a clientID option` at import and 35 files go red.

## Where to dig
- `docs/features/home-dashboard-data/PLAN.md` Task 8–12 — the iPhone tasks, each ending in `git add` plus a proposed message, never a commit
- The build ledger `.builder/home-dashboard-data/progress.md` — every ruling and deferred minor so far. It is git-ignored, so its rulings are repeated here:
  - server test:run is judged on the delta (the 3 pre-existing files above)
  - Task 5: /following also filters `studyProgram.isActive`
  - Task 6: the live `/api/home/*` smoke check is deferred to the walk lane (`--no-dev-env`)
  - the gate runner's fast set includes `docker restart makeready-server`, which ran 3 times despite `--no-dev-env`. That is a config issue for `/builder:init --update`, as is marking the 3 red files `@known-red`.

## Recommended next step
Run `/builder:resume --path docs/features/home-dashboard-data` in an interactive session (no
`--agent-walk`). It unparks the feature and the build continues at Task 8. Each iPhone task stages its
diff and you approve the commit, per task or once for the phase. After Task 12 come the final review,
the walk and verify. Alternatives: commit the iPhone tasks yourself from the staged trees (slower, and
nothing reviews them); or change iphone to `commit: auto` in `.claude/builder.md` (it loses the
released-artifact guard).

## History
- 2026-10-25 parked — iPhone phase needs the owner's commit approval (commit: manual)
