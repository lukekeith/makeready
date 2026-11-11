# bible-verse-picker — parked
parked: 2026-11-10 8337e8af · by build phase 4 (Task 8 partial, Tasks 10–11 not started)
kind: human-step
blocked: "the four Bible picker screens (books, chapters, verses, reader) don't exist in d2m, and only the owner's /ui2-screen can create them — next: /ui2-screen for bible-books, bible-chapters, bible-verses, bible-reader, then /builder:agent"

## What is stuck
The picker's four pages (Books with search + translation, Chapters, Verses, the Reader with word selection)
are d2m-built views (SPEC §iphone: "Requested through d2m"), plus one new component, BibleVerseReader (D4).
d2m has no screen with any of these slugs, and nothing a build agent can call creates one. Until they
exist, the four picker destinations render an empty page, so a leader cannot yet pick a passage in the app.

Everything else is built and green: the server half (contract frozen 2026-11-10), the iPhone models,
BibleActions/AppState, the picker flow + one-write return (Task 9), and the editor's whole Bible handling
(Tasks 12–15). DayChip, SearchResultRow, CanvasTextObject, ActivitiesEditorScreen and the five bible
colour tokens landed through d2m (commit dc12ee75).

## What was tried
- `request_project_change` subject `bible-reader` → `unknown_subject` (Task 8)
- `request_project_change` subject `new:BibleVerseReader` → `unknown_subject`: d2m mints a new component only
  on a request to an EXISTING screen (Task 8)
- `list_screens` search "bible" → no screens
- The d2m-channel tool schema was checked by the controller: `request_project_change` takes a component code
  or an existing screen slug; no tool creates a screen. Calling d2m's HTTP API directly was deliberately not
  done — screen specs are the owner's `/ui2-screen` program, which `/builder:*` never writes.

## Evidence
- `.builder/bible-verse-picker/task-8-report.md` (git-ignored) — "request_project_change with subject
  new:BibleVerseReader and with bible-reader both fail unknown_subject. new:<Name> minting is allowed only on a
  request to an EXISTING screen, and no screen bible-* exists (list_screens "bible" → none)."
- `server/fixtures/screens/bible-books.ts`, `bible-reader.ts` — the screen fixtures already exist (Task 4).
- SPEC §Decisions D3–D7, D17 and §iphone — the requirements for the four screens and BibleVerseReader;
  F17 is the build-time risk for the reader's gestures.

## Where to dig
- `iphone/MakeReady/UI2/Shell/UI2Shell.swift` `page(for:)` — the four `.bible*` destinations render
  `EmptyView()` (Task 9 placeholder); Tasks 10–11 replace them with containers.
- `.builder/bible-verse-picker/d2m-api.md` — the names d2m shipped so far; Task 8's rest appends the screens'.

## Recommended next step
Create the four screens in d2m with `/ui2-screen` (doc source: this SPEC — D3–D7, D17, §iphone; slugs
`bible-books`, `bible-chapters`, `bible-verses`, `bible-reader`), then `/builder:agent`. The build resumes at
the rest of Task 8 (request the four screens + `new:BibleVerseReader` on `bible-reader`), then Tasks 10–11,
then closes phase 4 and runs the final review.
Alternatives: building the pages as hand-written SwiftUI outside MakeReadyUI (violates D3 and the d2m rule,
and the design would be invented); shipping without a picker (the feature's core is missing).

Also for the owner: d2m wrote its Task-8 output UNCOMMITTED into the main checkout
(/Users/lukekeith/www/makeready, branch feature/text-activity) — 8 files under iphone/MakeReadyUI/,
iphone/MakeReadyCaptureTests/ and docs/ui2/design-system/tokens.md. The same diff is committed here as
dc12ee75; those 8 files there can be reverted with `git checkout --` once you have checked them.

## History
- 2026-11-10 parked — d2m cannot create the four picker screens; the screens are the owner's /ui2-screen step
