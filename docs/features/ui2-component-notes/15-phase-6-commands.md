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

- [ ] 6.1 `.claude/commands/ui2-component-build.md` — phase 0 loads notes for the target, every
      dependency, **and every screen whose §4 names the target** (09 §G-14), through
      `node capture/lib/ui2-notes.mjs read` (09 §X-2); phases 3–4 state notes are binding and cite
      the note id in the code comment; phase 6 classifies note-caused differences as expected
      (07 §7.1) · tests: C-1, C-2, C-8
- [ ] 6.2 `.claude/commands/ui2-component-update.md` (new) — the six phases in 07 §7.2, the
      **inherited Hard-rules block** (09 §G-12), and the ask-before-capture rule (09 §O-5) ·
      tests: C-3, C-4, C-5, C-7
- [ ] 6.3 `.claude/commands/ui2-screen.md` — phase 2 writes the element map (rects per 07 §1.1
      step 1, `generatedBy: ui2-screen@<date>`, composite nodes recorded as such), exit checklist
      gains the map line; phase 0 reads the screen's notes via the CLI (07 §7.3) · tests: C-6
- [ ] 6.4 The queue printer's `notes` column in `/ui2-component-build` (07 §7.1)

## Phase gates

- [ ] `cd capture && npm test` (the CLI the commands call is under test)
- [ ] Each command file re-read end-to-end for internal contradictions with its siblings

## Verification checklist

- [ ] C-1…C-8 walked (08 §5), with a real note written through the UI as the input
- [ ] `/ui2-component-update` on an unbuilt component prints the requirement set and stops,
      making no edit
- [ ] Two contradicting notes: newer wins on the contested property, older survives elsewhere (R13)
- [ ] `git status --porcelain docs/ui2 | grep -v '/notes/'` is unchanged by an update run (C-5)
- [ ] Spec parity: 03 §3's derivation appears in the command as written, not paraphrased

## VERIFIED

⬜ Not yet — this is the last phase; on sign-off run the verify step.
