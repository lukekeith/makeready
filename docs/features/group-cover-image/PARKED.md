# group-cover-image — parked
parked: 2026-10-27 09216fd · by the walk lane (walk readiness, before the agent walk)
kind: human-step
blocked: "config change needed — agent_walk.env has no R2 credentials, so every cover save on the walk 500s [F10] — next: apply the diff in PARKED.md to .claude/builder.md on main, then /builder:agent --path docs/features/group-cover-image"

## What is stuck
The build is finished: every phase is closed, the final review ran, and walk.md is written with
9 [risk] items. The walk can't run them because the walk env's server can't store an image.
`getR2Client` (`server/src/services/storage.ts:13-21`) throws when `R2_ACCOUNT_ID`,
`R2_ACCESS_KEY_ID` or `R2_SECRET_ACCESS_KEY` is unset. `group-cover.ts:9,112` uploads the cover and
the original through it. So server items 2–3 and iPhone items 3–5 in walk.md (upload, re-edit at the
stored framing, view the original) would fail with a 500. That would be the env failing, not the
feature.

Agents never edit the config (AGENT-MODE: the fleet reads the main checkout's copy, and the config
is the owner's to change).

## The diff (to `.claude/builder.md` on main, `agent_walk:` → `env:`, line 46)
Append to the end of the `env:` line:

```
 R2_ACCOUNT_ID="<account id>" R2_ACCESS_KEY_ID="<key id>" R2_SECRET_ACCESS_KEY="<secret>" R2_BUCKET_NAME="<bucket>" R2_PUBLIC_URL="<public base URL, no trailing slash>"
```

- The values are the ones your dev server already uses (the 1Password-piped `server/.env`). This
  agent didn't read them, per the no-1Password-reads rule.
- 🔴 `.claude/builder.md` is committed. Prefer a walk-only bucket or a scoped R2 token over the
  production secret. If the fleet expands `$VARS` in `agent_walk.env`, referencing exported shell
  variables keeps the secret out of git (not verified here).
- `R2_BUCKET_NAME` defaults to `makeready-media` when unset (`storage.ts:35-37`). `R2_PUBLIC_URL` is
  needed for the viewer (View image) and the group page to load the stored URLs.

## What was tried
- 2026-10-27 walk lane (this run): the d2m cause from the previous park is cleared. Edit cover is on
  main (8b83f38), and Tasks 11, 12 and 15 plus the final review are built (ea882fd..81c54de).
  `handoff.mjs read` → trust ok at 09216fd. The walk env is up: the `agent_walk.smoke` health check
  passed (DB healthy) and the client returned 200 on :8102. But `ps eww` on the :3110 server (pid
  4385) shows 0 `R2_*` variables, and `grep R2_` finds nothing in either the worktree's or the main
  checkout's `.claude/builder.md`. F10 holds.
- Readiness steps 1–2 (migrations to makeready_walk, regenerate) were not run. They are idempotent,
  and the fleet re-runs readiness after the unpark.

## Evidence
- Gates at 81c54de: iphone fast PASS. Server fast red only because the env is missing (no
  server/.env). Suite vs makeready_gci_test green apart from the 3 files that are red at base
  (production, lesson-activities, users).
- Smoke 2026-10-27T21:10Z: `{"status":"ok","database":{"status":"healthy"}}` on :3110, 200 on :8102.

## Where to dig
- After the env change: `/builder:agent --path docs/features/group-cover-image` relaunches the
  fleet, which restarts the walk env with the new `env:`. Then walk readiness runs: Atlas migrations
  to makeready_walk (includes `20261027164451_group_cover_image`) and `fixtures_agent_walk`. After
  that comes `/builder:agent-walk` on walk.md.
- Walk item still to add (not in walk.md yet): Auto/straighten on a real tilted photo. Vision's
  horizon sign and `image.cgImage` ignoring `imageOrientation` are unverified (Task 14 review,
  Minor 5).
- Open follow-ups for /ui2-resolve (F3 + final C1): GroupsDetailScreen.onCoverTap,
  ActionMenuPresentation onHidden, FilterMenuOverlay.hostedOverlay, CoverViewerOverlay.

## Recommended next step
Apply the diff above to `.claude/builder.md` on main (real values), then run
`/builder:agent --path docs/features/group-cover-image`.

## History
- 2026-10-27 parked — Edit cover screen not built in d2m [F1]
- 2026-10-27 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-27 re-parked at Task 11 — Phases 5–6 and Task 14 built; edit-cover in flight in d2m (d2m-4a)
- 2026-10-27 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-27 F1 cleared (8b83f38 on main); Tasks 11, 12, 15 + final review built; phases closed at 09216fd
- 2026-10-27 re-parked by the walk lane — agent_walk.env lacks R2_* [F10]; config change is the owner's
