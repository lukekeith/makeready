# Phase 6 — The three command files  ·  app: root `.claude/`

> Preconditions: Phase 5 **VERIFIED** — `/ui2-component-update` verifies against notes, so real
> notes must be writable before its behavior can be checked.

## Goal

Notes become normative build input: `/ui2-component-build` loads and honors them,
`/ui2-component-update` exists and derives → verifies → fixes → recaptures → reports, and
`/ui2-screen` authors element maps going forward. R10, R11, R12, R13 are demonstrable.

## Companion skills

The sibling command files themselves are the pattern: `.claude/commands/ui2-component-build.md`
(phase structure + exit checklists + Hard rules) and `.claude/commands/ui2-resolve.md`.

## Tasks (in order)

- [x] 6.1 `.claude/commands/ui2-component-build.md` — phase 0 loads notes for the target, every
      dependency, **and every screen whose §4 names the target** (09 §G-14), through
      `node capture/lib/ui2-notes.mjs read` (09 §X-2); phases 3–4 state notes are binding and cite
      the note id in the code comment; phase 6 classifies note-caused differences as expected
      (07 §7.1) · tests: C-1, C-2, C-8
- [x] 6.2 `.claude/commands/ui2-component-update.md` (new) — the six phases in 07 §7.2, the
      **inherited Hard-rules block** (09 §G-12), and the ask-before-capture rule (09 §O-5) ·
      tests: C-3, C-4, C-5, C-7
- [x] 6.3 `.claude/commands/ui2-screen.md` — phase 2 writes the element map (rects per 07 §1.1
      step 1, `generatedBy: ui2-screen@<date>`, composite nodes recorded as such), exit checklist
      gains the map line; phase 0 reads the screen's notes via the CLI (07 §7.3) · tests: C-6
- [x] 6.4 The queue printer's `notes` column in `/ui2-component-build` (07 §7.1)

## Phase gates

- [x] `cd capture && npm test` — **103 / 102 pass / 1 pre-existing**
- [x] Each command file re-read end-to-end; every path they cite exists on disk
      (`ui2-notes.mjs`, `runners/ui2/capture.mjs`, `scripts/ui2-screen-elements.mjs`,
      `preview-build.md`, `registry.md`, `03-data-and-api.md`), and the queue printer with its
      new `notes` column was run and produces a table

## Verification checklist

- [x] **C-3** `/ui2-component-update` on an unbuilt component (C-031) printed the effective set
      and stopped, pointing at `/ui2-component-build`, with no edit made
- [x] **C-4** two contradicting notes on C-031: the newer won the contested property (disc
      placement), and the older note's *other* statement (label case) survived — per-property
      supersession, R13
- [x] **C-5** `git status --porcelain docs/ui2 | grep -v '/notes/'` empty after the run
- [x] **C-8** all three note sources load through the CLI (target, dependency, consuming
      screen); an unknown or traversing target exits 2
- [x] Spec parity: 03 §3's five derivation steps appear in phase 1 as written
- [~] **C-1, C-2, C-6, C-7** require a real build / capture / re-spec run — see below

## VERIFIED

✅ **2026-09-10** — with four checks explicitly deferred to a real run (below).

**What the three command files now do.**

- `ui2-component-build.md` — phase 0 gains step 7: load notes for the target, **every
  dependency**, and **every screen whose §4 names the row** (09 §G-14), always through
  `node capture/lib/ui2-notes.mjs read` and never by eye (09 §X-2), printed with their ids
  before anything uses them. Phase 3 states notes bind and requires the note's id in the code
  comment that implements it. Phase 6 gains **note-driven divergence** as its own class,
  reported separately from gaps — a difference a note caused is expected, and "fixing" it
  would undo the owner's instruction. The queue printer gains a `notes` column (run and
  verified).
- `ui2-component-update.md` (new) — the six phases in 07 §7.2, inheriting
  `/ui2-component-build`'s **entire Hard-rules block** (09 §G-12) plus four of its own, and
  asking before it captures (09 §O-5).
- `ui2-screen.md` — phase 0 reads the screen's own notes; phase 2 **writes the element map**
  with the rules phase 3 learned the hard way (parent-relative coordinates accumulated down
  the tree, section exports including their padding, smallest-area-first with deepest-first
  ties, unresolved instances omitted), and its exit checklist now requires one map per frozen
  snapshot.

**C-3/C-4 walked for real.** Two deliberately contradicting notes were written on C-031
(unbuilt) through the live route, then phase 0–1 executed exactly as written. The derivation
produced the effective set, named the drift (`spec §2.1 leading → note 02:38:24 trailing`),
and reported the first note's *other* statement as still in force. It then stopped without
editing, which is the correct outcome for an unbuilt target — not a failure. Notes deleted
afterwards.

**Deferred, and why.** **C-1** and **C-2** (a build that honours a note, and a dependency's
note binding its host) need a full `/ui2-component-build` run: SwiftUI compile plus a
simulator capture, which is an explicit user call. **C-6** (a `/ui2-screen` run writing a map)
needs a full screen re-spec against Figma. **C-7** (the update command asking before capture
and re-printing the Hard rules) can only be observed in a real run of that command. All four
are in the human-verification handoff rather than claimed here — the commands are prose the
model executes, and the only honest verification is executing them.
