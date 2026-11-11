# bible-verse-picker — parked
parked: 2026-11-10 9cbfce14 · by build phase 4 (fleet retry after unpark)
kind: human-step
blocked: "the Bible picker's four pages (books, chapters, verses, reader) can't be built until they exist as d2m screens, and only the owner's screen spec can create them — next: /ui2-screen bible-books, bible-chapters, bible-verses, bible-reader, then /builder:agent"

## What is stuck
The picker's four pages have to be d2m-built screens under `iphone/MakeReadyUI/Screens/Bible/`. They
are Books with its search state, Chapters, Verses and Reader, plus the new BibleVerseReader component
the Reader renders (SPEC D1–D4, D7). d2m only builds a screen it already has, and none of the four
exists in d2m. No builder or d2m-channel tool can create one. A screen comes only from the owner's
spec program (`/ui2-screen`), which builder reads and never writes. Tasks 10–11 (phase 4) render
exactly these screens, so the build can't finish. Every other task is done (1–9, 12–15).

## What was tried
- Run 3: in Task 8, d2m built C-052, C-085, C-092, the activities-editor changes and the five Bible
  tokens (dc12ee75). The four screen requests were refused (`unknown_subject`). Tasks 9 and 12–15
  were built ahead of 10–11, since none of them reads the missing screens (247389cf..8337e8af).
- This run (2026-11-10): re-checked whether the cause still holds. `list_screens` (search "bible") →
  "No screen matched". `check_project_change` on subject `bible-reader` → `NOT_FOUND …
  unknown_subject`. The d2m-channel tool list still has no tool that creates a screen
  (answer/approve/cancel/check/get_*/list_*/report/request/retry/set_color_token/wait).
- Considered and rejected:
  - Minting BibleVerseReader as `new:<Name>` on an existing screen's request. It is possible, but it
    leaves the four pages missing, so Tasks 10–11 stay blocked.
  - Hand-writing the four screens under `MakeReadyUI/`, or laying them out in `iphone/MakeReady/UI2/`
    containers from existing components. Both break the d2m ownership rule: every `MakeReadyUI/`
    file is d2m-built, containers only wire them, and `/builder:*` never writes the design. That
    call belongs to the owner, and no ruling can make it.

## Evidence
- `check_project_change({subject:"bible-reader", kinds:["composition"]})` on 2026-11-10 → `no component
  or screen "bible-reader" in makeready 2.0 … "reason": "unknown_subject" … A reference may also name
  new:<Name> for a component this request mints (screen requests only).`
- `.builder/bible-verse-picker/d2m-api.md` (git-ignored) is the record of what d2m shipped for Task 8.
  Quote: "Screens bible-books … bible-reader … and the new component BibleVerseReader.
  `request_project_change` refuses an unknown subject (`unknown_subject`), and minting a new component
  (`new:<Name>`) is allowed only on a request to an EXISTING screen."
- Ledger (`.builder/bible-verse-picker/progress.md`): Tasks 1–7, 9, 12–15 complete. Phases 1–2 closed
  GREEN. Phase 5 tier GREEN at 8337e8a (mwbkcztr-b65500). The only red is client-tokenization, which
  is already red on main (ruled at phase 1).

## Where to dig
- SPEC D1–D4, D7 define the four screens fully by composition (C-040, C-131, C-035/036, C-052 label
  and number grids, C-085 book/verse rows, C-132, C-020, BibleVerseReader). They are the input for
  `/ui2-screen` in doc-source mode, since there is no Figma for them.
- PLAN Task 8 Behaviour has the exact request list: the screen ids, fixtures
  `server/fixtures/screens/bible-books.ts` and `bible-reader.ts` (already landed in Task 4), and the
  BibleVerseReader gestures per D4/F17.
- Not yet ruled out: whether the owner wants these pages as d2m screens at all, or would allow
  container-composed pages from existing components. That is an owner call; SPEC D3 implies screens.

## Recommended next step
`/ui2-screen` for bible-books, bible-chapters, bible-verses and bible-reader (doc source: SPEC
D1–D7), then `/builder:agent`. The next run finishes Task 8's screen requests plus BibleVerseReader,
then builds Tasks 10–11, runs the phase-4 tier and the final review. Alternatives: hand-built pages
(breaks d2m ownership); retrying unchanged (fails the same way, which is why this is now a
human-step park rather than `stuck`).

## History
- 2026-11-10 parked — d2m cannot create the four picker screens; the screens are the owner's /ui2-screen step
- 2026-11-11 parked — the four Bible picker screens do not exist in d2m, and only the owner's /ui2-screen can create them
- 2026-11-11 unparked by the fleet — automatic retry 1 of 2
- 2026-11-10 parked again (human-step) — re-verified: still no such screens, still no tool that creates one
