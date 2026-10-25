# ui2-fixtures — parked
parked: 2026-10-25 2e6c852 · by the fleet (the run that parked it wrote no record)
kind: stuck
blocked: "the walk env would not start (walk env didn't come up — see /Users/lukekeith/www/makeready/.builder/fleet/logs/ui2-fixtures-start.log) and an agent run could not fix it — next: run agent_walk.start in /Users/lukekeith/www/makeready.fleet/ui2-fixtures and fix what it prints, then /builder:agent"

## What is stuck
the walk env would not start (walk env didn't come up — see /Users/lukekeith/www/makeready/.builder/fleet/logs/ui2-fixtures-start.log) and an agent run could not fix it

## What was tried
- 2 fleet run(s) in all — `git log --oneline -- docs/features/ui2-fixtures` lists what each changed

## Evidence
- the run that parked it: /Users/lukekeith/www/makeready/.builder/fleet/logs/ui2-fixtures-02.log — its last lines:

```
· Two causes so far: the `dotenv` CLI is missing from the install, and `server/bin/atlas` is gitignored, so worktrees don't have it. Checking the install state next.
· Confirmed: `cd client && npm ci` treats client as the only workspace and prunes the server's packages from the shared root `node_modules`. Next I'll check which server deps it removes.
· Now I'll run the fleet's exact sync and reset commands to verify.
· Sync is green, every workspace's deps are present, and the lockfile is unchanged. Running reset next:
· Reset passes. Checking that ports 3110/8102 are free, then running start and smoke:
· The server crashed on start. Reading its log:
· No stray processes are left from my run. To see whether Twilio is the only boot blocker, I'm running a timed probe with Twilio test mode on:
· I fixed the reset failure and committed it as `2e6c852`. But the walk env still won't come up: the next step, start, fails because the server is missing its secrets file, and fixing that needs a change to `.claude/builder.md`, which I wasn't allowed to make.

**Why reset failed (two causes, both fixed in this branch):**
1. **The client install deleted the server's packages.** Run inside `client/`, `npm ci` installs only the client and clears the server-only packages from the shared root `node_modules` (`dotenv-cli`, `@prisma/client`, `express-session` and 43 others). So `migrate:apply` died with `dotenv: command not found`, which left the tables uncreated, and seed then failed on the missing `public.permissions` table.
   - **Fix:** a root `postinstall` script (`scripts/restore-workspace-deps.mjs`). npm runs it even for a client-only `npm ci`. If any app's dependencies are missing, it reinstalls them once from the lockfile without changing `package.json` or the lockfile. It only acts during `npm ci` and can't call itself in a loop.
2. **The Atlas binary isn't in worktrees.** `server/bin/atlas` is gitignored, so this worktree never had it.
   - **Fix:** the three migrate scripts now go through `server/scripts/atlas.sh`. It uses `server/bin/atlas` when present and otherwise the `atlas` on PATH (`/opt/homebrew/bin/atlas` on this machine).

**Verified:** the fleet's exact sync command succeeds with every package present and the lockfile unchanged, and reset (drop, create, `migrate:apply`, `db:seed`) exits 0.

**What still blocks the walk:** start launches the server, which crashes immediately because there is no `server/.env` in the worktree. `agent_walk.copy` only copies `client/.env` and `capture/.env`. Without that file the server stops on the missing Twilio credentials, and even with Twilio test mode on it stops on the missing Google OAuth client ID. Smoke can't pass until `server/.env` is added to the `agent_walk.copy` line in `.claude/builder.md`. I didn't try to make the server start without its secrets.

I stopped the client server I started on :8102, nothing of mine is still running on 3110 or 8102, and I killed nothing else.
```
- the walk env's start log: /Users/lukekeith/www/makeready/.builder/fleet/logs/ui2-fixtures-start.log

## Where to dig
- start from the run's last lines above and the evidence it names; nothing has been ruled out yet

## Recommended next step
run agent_walk.start in /Users/lukekeith/www/makeready.fleet/ui2-fixtures and fix what it prints, then /builder:agent

## History
- 2026-10-25 parked — iPhone is commit: manual; server half built and contract frozen
- 2026-10-25 unparked by luke — building phase 3 here with per-task iPhone commit approval
- 2026-10-25 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-25 parked — the walk env would not start (walk env didn't come up — see /Users/lukekeith/www/makeready/.builder/fleet/logs/ui2-fixtures-start.log) and an agent run could not fix it
- 2026-10-25 unparked by the fleet — automatic retry 1 of 2
- 2026-10-25 unparked by the fleet — automatic retry 2 of 2
