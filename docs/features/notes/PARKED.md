# notes — parked
parked: 2026-11-20 03adf1a4 · by build phase 5 (Task 12 gate)
kind: human-step
blocked: "the notes views d2m builds are not on this branch yet [F1/F5] — next: finish d2m changes cmwoogs5g001mv0h9jj3070bk + cmwoogn700001v0h9l69stkz3 and the note-editor screen, land them on feature/memo, then /builder:agent"

## What is stuck
Phase 5 (Tasks 12–14: the markdown codec, the Library notes list and the note editor) wires d2m's views.
The SPEC gives those views to d2m alone [D1], and the plan's gate [F1/F5] needs them on this branch first.
None of them exists in any branch: `NoteEditorModels.swift`, C-001/002/003/005/008/009/010/015, the
`note-editor` screen, and a notes state in `LibraryHomeScreen.swift`. Phases 1–4 are built and verified
green: the server, its frozen contract, and the iPhone models, actions, offline queue and autosave.

## What was tried
- `git ls-files iphone/MakeReadyUI` on builder/notes, feature/memo and main: no file matching
  MarkdownTextEditor|FormatStrip|ListStyleMenu|EditorNavChrome|NoteEditor|NoteListRow|NotesBottomBar|NoteSectionHeader (0 on each).
- d2m `get_project_change cmwoogs5g001mv0h9jj3070bk` (C-001 editor surface): status `done`, with "Ran: Spec C-003, C-015, C-001,
  C-002, C-009, Build …" and "d2m's edits and builds are in the project checkout (/Users/lukekeith/www/makeready),
  uncommitted". But that checkout (on `main`) holds only `M iphone/MakeReadyUI/Glyph.swift` and four new glyph
  imagesets (bold, italic, strikethrough, underline). There is no view file. The change says it is done, but the views are missing.
- d2m `get_project_change cmwoogn700001v0h9l69stkz3` (library-home): status `carded`, failed. Quoted:
  "Blocked: the new list is built from C-010, C-005 and C-008, and none of them is specced or built yet."
- `note-editor` screen: never minted.
- Not attempted: new `request_project_change` calls for C-005/C-008/C-010/note-editor. d2m writes its output
  uncommitted into the human's main checkout on `main`. Under --agent-walk that is a side effect outside this
  worktree, and landing it on feature/memo needs a commit from that checkout.

## Evidence
- Main checkout `git status --short`: ` M iphone/MakeReadyUI/Glyph.swift`, `?? …/bold.imageset/`, `?? …/italic.imageset/`,
  `?? …/strikethrough.imageset/`, `?? …/underline.imageset/`, `?? iphone/build-device/`.

## Where to dig
- d2m change cmwoogs5g001mv0h9jj3070bk: why it says `done` with no view files. Its builds may have written somewhere else,
  or failed silently.
- PLAN.md Task 12's gate block, which lists the d2m answers to give per D21 (OQ-C-001-003 → option 2, and so on).

## Recommended next step
In the main checkout, have d2m (re)build C-001/002/003/009/015, spec and build C-005/008/010, retry
cmwoogn700001v0h9l69stkz3, and request the `note-editor` screen. Commit the results to feature/memo, merge
feature/memo into builder/notes (or rebase onto it), then run `/builder:agent --path docs/features/notes`. The
build resumes at Task 12. Alternatives: ship phases 1–4 alone (the server and iPhone plumbing have no UI), or
revise the spec so the iPhone writes its own views (this reverses D1).

## History
- 2026-11-20 parked — d2m notes views absent at the Phase 5 gate
- 2026-11-21 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-21 cause cleared — d2m views landed on feature/memo (dc83bf78) and merged in; gate passed with d2m's real type names; Library screen hooks obtained via d2m fast lane cmwq42w6m0003v02opee66eoo; phase 5 built and GREEN
