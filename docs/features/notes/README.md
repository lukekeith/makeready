# Notes — Native-iPhone-Notes-style note taking

**Status:** ANALYSIS (no code yet — feeds a future `/build-spec-draft notes`)
**Date:** 2026-08-31
**Source:** one screen recording of the iPhone **Notes** app — `~/Makeready/Notes/Notes.MP4`,
55.92 s, 60 fps, 1320×2868 (3×), dark mode, iOS 26 generation.
**Method:** 4 fps contact sheets end-to-end, full-resolution frames at every state change,
10–15 fps windows over the two motion interactions, plus a survey of the existing notes domain
across `server/`, `client/`, and `iphone/`.

## What this is

The goal is to give MakeReady users note taking that feels like the note taking they already
know — the iPhone Notes app. This suite documents that app precisely enough to rebuild it: what
the screens are, what every control does, how the text engine actually behaves underneath, and
what it would take in our monorepo.

## The pattern in one paragraph

Notes is **a page, not a form**. Compose puts you straight into a full-width document with the
keyboard already up and the caret blinking — no container, no border, no placeholder box, no
Save button. The first line you type *is* the title, styled live, and it is the note's name in
the list. All formatting lives in a single horizontally-scrollable capsule strip docked above the
keyboard; option pickers open as small popovers anchored to their own button, so the document is
never covered and never moves. Toggle buttons reflect whatever the caret is standing in. The list
you come back to is grouped by recency, with titles and previews derived from the document
itself.

## Doc suite

| Doc | Contents |
|---|---|
| **[DECISIONS.md](DECISIONS.md)** | **THE NORMATIVE CONTRACT — read first.** Requirements with acceptance criteria, the full decision register (N1–N13), the exact v1 format-strip contents, the operational fidelity standard with enumerated deviations, the complete v1 server change list, environment notes, and the **§4b component manifest** — every UI unit with parameters, file path, and usage; nothing exists today and the build may render nothing outside it |
| [01-video-analysis.md](01-video-analysis.md) | Frame-level findings: both screens, all chrome, the format strip inventory, every formatting behavior, measured geometry, full timestamped outline, and an explicit list of what the video does *not* show |
| [02-under-the-hood.md](02-under-the-hood.md) | How it really works: `UITextView`/TextKit, attributed-string document model, why toolbar state never desyncs, autosave-instead-of-save, derived list metadata, CloudKit sync, and the iOS 26 chrome system — with a cost table for reproducing each piece |
| [03-makeready-translation.md](03-makeready-translation.md) | What we already have (`StudyNote`, `NoteLink`, `/api/notes` — all live; zero consumers on iPhone), the four gaps (rich text, autosave contract, list shaping, custom chrome), a tiered MVP, and seven open questions |
| [04-implementation-readiness.md](04-implementation-readiness.md) | Gap/feasibility review: **proposed answers to every remaining open question** (N2 dual-owner is already the house pattern; leader-first v1; no folders — `NoteLink` is the context line; add `NOTE` type; LWW + stomp flag; server-side `q`), plus findings — empty-note discard vs `min(1)` validation, denormalized title/preview, the web-editor-engine decision (TipTap recommended) |

## Headline findings

1. **The server half is already built.** `StudyNote` + `NoteLink` + full CRUD at `/api/notes` are
   live and unused by the iPhone app. This is a consumer-side feature, not a ground-up one.
2. **`content` is a plain string, and the fix is markdown.** Apple stores a gzipped protobuf of
   text-plus-attribute-runs; nobody else should copy that. **Decided: GitHub-Flavored Markdown in
   the existing `content` column** — no new column, no migration, existing previews/search/
   analytics keep working, and Claude consumes it directly. Two extensions only (`==highlight==`,
   `<u>`); arbitrary paragraph indent is dropped. Same decision the activities WRITE surface is
   waiting on.
3. **The format strip is the whole design.** A keyboard-accessory capsule with popover pickers
   replaced the old half-sheet panel; it is what keeps the document visible at all times, and
   it's the single most copyable idea in the recording.
4. **Nothing about the interaction is modal.** No preview/commit split, no formatting mode, no
   sheet ever covering the text. Style toggles read the caret's attribute run, which is why they
   are instant and never wrong.
5. **The Writing Tools row is not Notes.** It is the system keyboard. Don't build it, and don't
   expect it on web.

## Decisions & requirements

All of it — user-stated critical requirements operationalized into acceptance criteria, every
decision with its exact ruling (including the memo-embed syntax, now **N8**), the v1 strip
contents, and the fidelity standard — lives in **[DECISIONS.md](DECISIONS.md)**, which overrides
any other doc here on conflict. The only open item is §8 there (member web timing + its editor
engine).

## Pipeline gate

**GATE: INCOMPLETE (2026-08-31)** — `/build-spec-verify notes` run on explicit request. Root
cause is singular: **the feature has not entered the build pipeline** — no `01-architecture` …
`09-gaps-and-decisions` suite exists (the numbered files here are analysis docs), no phase docs,
no ledger, and **zero feature code in any app** (no `api/notes` consumer in `iphone/` or
`client/resources/js`; DECISIONS.md §6's server changes — `NOTE` type, `title`/`preview`
columns — are unapplied). Checklist: items 1, 2, 3, 6, 8, 9, 10, 11 **FAIL** on absent
artifacts; items 4, 5, 7 are vacuously true (nothing built to violate them) and carry no force
toward READY. Clearing step for every item: `/build-spec-draft notes` → `/build-spec notes`
(audit → plan → build), then re-run this gate.

## Related

- [`docs/features/memo/`](../memo/README.md) — the companion voice-memo analysis. A voice memo
  attached to a note is the obvious convergence point between the two.
- [`docs/features/activities/11-notes-editor-analysis.md`](../activities/11-notes-editor-analysis.md)
  — an earlier, narrower pass over this same recording, scoped to the lesson WRITE activity's
  input surface.
- [`docs/features/activities/10-text-editing-analysis.md`](../activities/10-text-editing-analysis.md)
  — the Instagram canvas-text pattern, which fits styled *display* text; this suite covers
  document-style *writing*.
