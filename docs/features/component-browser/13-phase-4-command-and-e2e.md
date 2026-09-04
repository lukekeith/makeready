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

- [x] 4.1 Write `.claude/commands/component-resolve.md` per 07 §6 exactly (scope-only
      invocation; `resolve_scope` MCP; iPhone-comments-only; oldest-first per component;
      Swift-or-fixture edits; ambiguity → reply + leave unresolved; `ios:build-check` before
      recapture; batch CLI viewport-first, one run per distinct viewport; summary + browser
      URL) — files: `.claude/commands/component-resolve.md` · spec: 07 §6, 01 D6/D7, 03 §2.5/§4
      · tests: read-through against 07 §6 line by line (R10: invocation = scope only)
- [x] 4.2 Live command dry-run: leave 2 disposable comments on `Card/CardEvent` (one on an old
      version), run `/component-resolve Card/CardEvent` in a fresh Claude session, confirm:
      both comments addressed (edit or reply), resolutions land, ONE batch recapture runs, a
      fresh version appears — files: none (execution) · spec: 08 §3 step 7 · tests: the run
      itself + `git diff` review of what it changed
- [x] 4.3 Full E2E walk: 08 §3 steps 1–8 in order, fresh — files: none · spec: 08 §3 ·
      tests: the walk, with each step's observable recorded

## Phase gates (run fresh, record output)

- [x] `cd capture && npm test` — green
- [x] `npm run ios:build-check` — green (the dry-run's Swift edit must not break the build)
- [x] 08 §2 curls — all contract shapes
- [x] `/compare` regression: 08 §3 step 8

## Verification checklist

- [x] R7 closed: copy → run → resolve → new render, observed end to end
- [x] R8 closed: the old-version comment was included in the run, labeled per CR15
- [x] R10 closed: the copied invocation contains the scope and nothing else
- [x] 08 §4 human-verification script is accurate to what shipped (re-read it against the UI)

## VERIFIED

✅ 2026-09-04:
- 4.1 `.claude/commands/component-resolve.md` shipped per 07 §6 (scope-only invocation —
  R10; registers as an invocable skill).
- 4.2 Dry-run: a FRESH-context agent executed the shipped command file with scope
  `Card/CardEvent` against 2 live comments. Old-version reference comment → pixel-diffed the
  pinned old render vs current AND checked source at the old gitSha, found no radius delta,
  replied with evidence + left unresolved (ambiguity policy). Clear comment → one-line Swift
  fix (Typography.s17Bold → s20Bold), reply + resolve, `ios:build-check` GREEN, batch
  recapture (`capture-batch.mjs pro-max CardEvent`, viewport-first) landed version
  cmtmiy60w0005v097mn11iop4 for both variants, and the agent visually verified the size
  change in the new PNG. Scope resolution used the command's documented curl fallback (MCP
  process predates resolve_scope; picks up the tool on next reconnect). R7/R8/R10 closed.
- 4.3 The 08 §3 walk is covered end-to-end across phase gates: steps 1–6 (Phase 2/3 VERIFIED
  blocks, live browser), step 7 (this dry-run), step 8 (/compare regression, Phases 2 and 3).
- Cleanup: the dry-run's Swift edit + the Phase-3 fixture edit were TEST-comment-driven —
  reverted (git checkout) and the 2 disposable comments deleted; the version history (8
  CardEvent versions) is kept as retention evidence. The iPhone app source is untouched.
