# Phase 4 — The command + cross-surface E2E  ·  app: capture (+ root `.claude`)

> Part of docs/features/component-browser/. Preconditions: Phase 3 VERIFIED.

## Goal

`/component-resolve <scope>` exists and the whole loop closes: comments made in the browser →
command run in Claude → Swift/fixture edits → replies + resolutions → batch recapture → fresh
versions visible in the browser. The full 08 walk passes and the human-verification script is
ready to hand over.

## Companion skills

The command itself instructs `npm run ios:build-check` before recapture (07 §6) — the go-ahead
covers running it as a gate; launching/archiving/committing the iPhone app stays a user call.

## Tasks (in order)

- [ ] 4.1 Write `.claude/commands/component-resolve.md` per 07 §6 exactly (scope-only
      invocation; `resolve_scope` MCP; iPhone-comments-only; oldest-first per component;
      Swift-or-fixture edits; ambiguity → reply + leave unresolved; `ios:build-check` before
      recapture; batch CLI viewport-first, one run per distinct viewport; summary + browser
      URL) — files: `.claude/commands/component-resolve.md` · spec: 07 §6, 01 D6/D7, 03 §2.5/§4
      · tests: read-through against 07 §6 line by line (R10: invocation = scope only)
- [ ] 4.2 Live command dry-run: leave 2 disposable comments on `Card/CardEvent` (one on an old
      version), run `/component-resolve Card/CardEvent` in a fresh Claude session, confirm:
      both comments addressed (edit or reply), resolutions land, ONE batch recapture runs, a
      fresh version appears — files: none (execution) · spec: 08 §3 step 7 · tests: the run
      itself + `git diff` review of what it changed
- [ ] 4.3 Full E2E walk: 08 §3 steps 1–8 in order, fresh — files: none · spec: 08 §3 ·
      tests: the walk, with each step's observable recorded

## Phase gates (run fresh, record output)

- [ ] `cd capture && npm test` — green
- [ ] `npm run ios:build-check` — green (the dry-run's Swift edit must not break the build)
- [ ] 08 §2 curls — all contract shapes
- [ ] `/compare` regression: 08 §3 step 8

## Verification checklist

- [ ] R7 closed: copy → run → resolve → new render, observed end to end
- [ ] R8 closed: the old-version comment was included in the run, labeled per CR15
- [ ] R10 closed: the copied invocation contains the scope and nothing else
- [ ] 08 §4 human-verification script is accurate to what shipped (re-read it against the UI)

## VERIFIED

⬜ Not yet — verify step (`/build-spec-verify`) follows this phase.
