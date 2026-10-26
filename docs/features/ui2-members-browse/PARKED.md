# ui2-members-browse — parked
parked: 2026-10-26 f329b92 · by build phase 3
kind: human-step
blocked: "iPhone commits are yours to approve (commit: manual); the server half is built and its contract frozen — next: /builder:resume --path docs/features/ui2-members-browse, approving each staged iPhone task"

## What is stuck
Nothing is broken. The server half (phases 1–2, tasks 1–8) is built, task-reviewed and gated, and
the contract froze on 2026-10-26. Phase 3 is the iPhone app, which `.claude/builder.md` marks
`commit: manual` (a released artifact), so every iPhone commit is the owner's call. An unattended run
may not make it, so the build stops at the start of that phase (resume §`--agent-walk`). Tasks 9–16
are untouched: nothing is staged.

## What was tried
- Design → align → audit → decisions → plan → go-ahead, all under `--agent-walk`. D14–D21 were ruled
  `auto (recommended)` at the decisions gate; D22–D23 at plan. Read them in SPEC §Decisions before
  the walk.
- Tasks 1–8 built by subagents and task-reviewed — 104802f..48ce230. Fix rounds: Task 7 (with
  `memberId` and no `organizationId`, `/api/home/days` read sessions from every org the caller can
  see; now limited to orgs where the caller can see the member). Task 4 (its request test failed
  only in the full suite: supertest listened on every interface and another worktree's server
  answered; the test now binds 127.0.0.1). Task 5 (`test/member-authorization.test.ts` expected
  pre-D7 200s; updated to D7, plus system-Admin and creator-leader 200 cases).
- Server fast gates at 48ce230: tsc ✓ · tsc fixtures ✓ · schema:validate ✓ · schema:diff ✓ (no new
  migration) · migrate:status ✓ · test:run 693 pass / 27 fail, all 27 in 3 pre-existing files (below).
- Migration `server/atlas/migrations/20261026045033.sql` (three nullable `members` columns) applied
  cleanly to the throwaway DB `makeready_mb_test`; `fixtures:reset` on it exits 0 (users 2,
  user_roles 2, groups 4, group_members 27, 13 avatar photos).

## Evidence
- The 3 red files fail on the pre-feature base f34ce53 in the same env, or are untouched by this
  branch: `test/integration/production.test.ts` 15 (fetches live production URLs),
  `src/routes/__tests__/users.test.ts` 1 (fails to load), `test/lesson-activities.test.ts` 11
  (`lesson-fixtures.ts:109` writes `user-…` ids into a uuid column: "Error creating UUID, invalid
  character … found `u` at 1"; file unchanged since fc69ddb).
- The server gates need env vars because a worktree has no `server/.env`: `NODE_ENV=test`,
  `DATABASE_URL`/`DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_mb_test`,
  `GOOGLE_CLIENT_ID/SECRET=walk-unconfigured`, `GOOGLE_CALLBACK_URL=http://localhost:3110/auth/google/callback`,
  `SESSION_SECRET=walk-session-secret`. Against `makeready_walk` instead, 89 tests fail with "The
  column `members.address` does not exist" — that DB is shared and not on this branch's schema.

## Where to dig
- `docs/features/ui2-members-browse/PLAN.md` Tasks 9–16 — the iPhone tasks. Each ends in `git add`
  plus a proposed message, never a commit.
- The build ledger `.builder/ui2-members-browse/progress.md` holds every ruling and deferred minor so
  far. It is git-ignored, so the rulings are repeated here:
  - D7/F6 scope non-admin leaders by `Group.creatorId`. This is the recorded exception to the "never
    creatorId" constraint: it narrows visibility, it doesn't authorize.
  - The server suite is judged on the delta (the 3 pre-existing files above).
  - Throwaway DB `makeready_mb_test` (created + migrated + seeded here) rather than migrating the
    shared `makeready_walk`. Drop it at ship: `docker exec makeready-postgres dropdb -U postgres makeready_mb_test`.
  - Task 7's org-leak fix was promoted from a minor into the fix loop (tenancy isolation).
  - The gate runner's fast set includes `docker restart makeready-server`, which restarts the MAIN
    checkout's container (it ran 4 times). That is a config issue for `/builder:init --update`, as is
    marking the 3 red files `@known-red`.
- Deferred minors the final review will see include: the stale `@openapi` doc on the members list, a
  `getScopedMember` DB error mapped to 404, and the repo-wide supertest port-race exposure in other
  bare-app request tests.

## Recommended next step
Run `/builder:resume --path docs/features/ui2-members-browse` in an interactive session (no
`--agent-walk`). It unparks the feature and the build continues at Task 9. Each iPhone task stages its
diff and you approve the commit, per task or once for the phase. After Task 16 come the final review,
the walk and verify. Alternatives: commit the iPhone tasks yourself from the staged trees (slower, and
nothing reviews them); or change iphone to `commit: auto` in `.claude/builder.md` (it loses the
released-artifact guard).

## History
- 2026-10-26 parked — iPhone phase needs the owner's commit approval (commit: manual)
- 2026-10-26 unparked by Luke — iPhone phase (tasks 9–16) built in session; owner approved its commits for the whole phase; then handed back to the fleet for the agent walk, verify and merge
- 2026-10-26 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-26 fleet retry — cause no longer holds (iphone commit: auto, 8c5fcae); tasks 10–16 built + reviewed (b77c9a8..0a72e85), final-review PATCH D7 leak fixed (d10a057), handed to the walk lane at 1150e0d
- 2026-10-26 walk lane — park cause still void (iphone commit: auto); readiness on makeready_walk: 0 pending migrations (at 20261026045033), prisma regenerated, fixtures reset, every §Contract row smoked as Owner + Leader (D7 404s on GET/PATCH/engagement/days), server log clean → state built, on to the agent walk
