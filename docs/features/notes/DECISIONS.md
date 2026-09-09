# Notes — Normative Decisions & Requirements

**This file is the contract.** Every other doc in this directory is analysis or reference; if any
of them disagrees with this file, this file wins. An implementer starts here. Nothing below is a
suggestion — rows marked *(default)* were adopted 2026-08-31 from the readiness review without
explicit user sign-off and may be vetoed, but until vetoed they are decisions, not options.

---

## 1. What ships in v1

A personal note-taking surface in the **iPhone leader app**, replicating the iPhone Notes app's
editor and list. Owned by the signed-in leader (`User`), stored via the existing `/api/notes`
routes. The member web surface is **out of v1 scope** entirely — no web code in this feature's
first pass.

## 2. Requirements → acceptance criteria

| # | Requirement | Passes when |
|---|---|---|
| R1 | Write a note with basic formatting | Every control in §4's strip table works as specified there; formatted content round-trips through save/reopen unchanged |
| R2 | Apple-Notes-style open canvas | Opening a new note: keyboard is up, caret is at top-left, format strip is docked — **zero taps before typing**. No visible input container, border, background tint, or placeholder box anywhere. Text margin ~29 pt both sides |
| R3 | Saved to the leader's account | Notes persist via `POST/PATCH /api/notes` under the session `userId`; another leader's session never sees them |
| R4 | No length limit | No client- or server-side cap added anywhere; a 100,000-character note saves, reopens, and scrolls without dropped frames (manual perf check) |
| R5 | System dictation works | Tap the keyboard mic key with the format strip docked → dictated text lands at the caret. (Zero build; one regression test. Breaks only if a custom `inputView` or non-standard keyboard type is introduced — don't) |
| R6 | Autosave, no Save button | Edits persist with no explicit save action: debounced `PATCH` at **1.5 s idle**, plus a flush on editor exit and on app background. Killing the app ≤ 1.5 s after typing may lose only that final burst |
| R7 | Title is the first line | The first non-empty line renders in Title style **live while typing** and is the note's name in the list. There is no separate title field |

## 3. Decision register

| ID | Decision | Exact ruling |
|---|---|---|
| N1 | Content format | GitHub-Flavored Markdown, stored in the existing `StudyNote.content` column. Exactly two extensions: `==text==` (highlight) and `<u>text</u>` (underline). Arbitrary paragraph indent: unsupported, dropped. Mapping: Title = `# `, body = bare paragraph, bold `**`, italic `*`, strikethrough `~~`, bulleted `- `, numbered `1. `, quote `> `, checklist `- [ ]`/`- [x]` (v2). No other markdown constructs are emitted by the editor |
| N2 | Ownership | `userId` (leader), via the existing `requireAuth` `/api/notes` family. `memberId`/`/api/member/notes` untouched, reserved for the future member surface |
| N3 | Folders | None in v1. One list ("All Notes"). The row's third line renders the note's `NoteLink` target name when one exists, else nothing |
| N4 | Type value | Add `NOTE: 'NOTE'` to `NOTE_TYPES` (`notes.service.ts:41`); all notes from this surface are created with `type: 'NOTE'` *(default)* |
| N5 | Conflict policy | Last-writer-wins. Client sends `baseUpdatedAt` (the `updatedAt` it last received) with each PATCH; server always writes, and responds `stomped: true` when the stored row was newer than `baseUpdatedAt`; client then refetches and re-renders *(default)* |
| N6 | Fidelity standard | See §5 |
| N7 | Search | Server-side: `q` query param on `GET /api/notes` → Prisma `content: { contains: q, mode: 'insensitive' }`. No client-side corpus search *(default)* |
| N8 | Memo embed syntax | A paragraph whose entire content is `[🎙 {title}](makeready://memo/{uuid})` renders as an inline memo player; anywhere else it renders as a plain link. (v1 renders it; *inserting* one ships with the memo feature) |
| N9 | Editor architecture (iOS) | `UITextView` (TextKit 2) wrapped in `UIViewRepresentable` — **not** SwiftUI `TextEditor`. Live model is the attributed string; markdown is parsed once on open (Apple `swift-markdown`) and serialized only on autosave, with literal `*_~=<>#` escaping. Round-trip invariant test required: `parse(serialize(doc)) == doc` |
| N10 | Empty notes | A new note creates **no server record until content is non-empty**; exiting an emptied note soft-deletes its record. (The existing `min(1)` zod validation therefore never blocks the flow) |
| N11 | List metadata | `title` (first non-empty line, markdown-stripped, ≤ 120 chars) and `preview` (next non-empty line, same treatment) are **denormalized columns on `StudyNote`**, written by the service on every create/update. List rendering never parses markdown |
| N12 | List presentation | Sections computed client-side from `updatedAt`: Today / Yesterday / Previous 7 Days / Previous 30 Days / month names / years. Sort `updatedAt` desc. Date column: time if today, weekday if ≤ 7 days, short date otherwise |
| N13 | Offline edits | Queue locally (latest content per note wins), flush one PATCH per note on reconnect, honor `stomped` on flush *(default)* |
| N14 | Component manifest | §4b is the exhaustive UI + supporting-unit list; the build renders nothing outside it (REFERENCE.md §3 rule 7) |

## 4. The v1 format strip — exact contents

One horizontally-scrollable capsule docked as the text view's `inputAccessoryView` (~43 pt tall,
~13 pt side insets, geometry per `01-video-analysis.md` §3.4). Contents, complete, in order:

| # | Control | Behavior |
|---|---|---|
| 1 | **B** | Toggles bold on selection or at caret (`typingAttributes`). Active state: filled accent circle (~37 pt), cleared ~200 ms after caret exits a bold run |
| 2 | *I* | Same, italic |
| 3 | U̲ | Same, underline (serializes to `<u>`) |
| 4 | S̶ | Same, strikethrough |
| 5 | ≡ list | Opens a popover anchored above the button with exactly two rows: **Bulleted**, **Numbered**. Choosing applies to the current paragraph and dismisses instantly. Return continues a list; **return on an empty item exits the list** to a flush-left body line |

That is the entire v1 strip. Explicitly **absent** in v1 (do not build placeholders for them):
`Aa` style menu, checklist, table, attach, markup, AI, highlight, link, indent, move up/down,
block quote. Title styling needs no button (R7 handles it). The strip still uses the scrollable
capsule component so later additions need no redesign.

## 4b. Component manifest — nothing exists; every row is (new)

**Premise (user-stated, verified in code):** no notes UI exists anywhere in the iPhone app — no
`Pages/Notes/`, no notes components, no `StudyNote` in `AppState`. Everything below is created
from scratch. **This manifest is exhaustive by construction** (REFERENCE.md §3 rule 7): the build
step renders only these units, with these parameters, at these paths; needing anything not listed
here is a spec defect resolved by a dated amendment + delta audit *before* code — never an inline
invention. Paths follow the app's existing directory conventions
(`iphone/MakeReady/Components/{Button,Card,Display,Input,Navigation,Overlays}`, `Pages/<Domain>/`).

### Pages

| Component (new) | Path | Parameters | Usage |
|---|---|---|---|
| `NotesListPage` | `Pages/Notes/NotesListPage.swift` | none — reads `AppState.studyNotes` | The All-Notes screen: large title, N12 date sections, floating bottom bar; row tap → editor; compose → editor with `noteId: nil` |
| `NoteEditorPage` | `Pages/Notes/NoteEditorPage.swift` | `noteId: String?` (`nil` = new note, N10 lazy-create) | The canvas (R2): hosts `MarkdownTextEditor` + `EditorNavChrome`; zero-tap start; autosave via `NoteAutosaveController` |

### Components

| Component (new) | Path | Parameters | Usage |
|---|---|---|---|
| `NoteListRow` | `Components/Card/NoteListRow.swift` | `title: String`, `preview: String?`, `dateLabel: String`, `contextLabel: String?`, `onTap: () -> Void` | One note row, 3-line layout (title / date+preview / N3 context line); consumed only by `NotesListPage` |
| `NoteSectionHeader` | `Components/Display/NoteSectionHeader.swift` | `title: String` | Flush-left section label (`Today`, `Previous 7 Days`, …) between row groups |
| `NotesBottomBar` | `Components/Navigation/NotesBottomBar.swift` | `searchText: Binding<String>`, `onCompose: () -> Void` | Floating search capsule + compose circle over list content (no bar background); search drives N7's `q` |
| `MarkdownTextEditor` | `Components/Input/MarkdownTextEditor.swift` | `text: Binding<AttributedString>`, `activeStyles: Binding<Set<InlineStyle>>`, `onEvent: (EditorEvent) -> Void` | The `UIViewRepresentable` `UITextView` (N9): title auto-style (R7), list continue/escape, caret-run style reporting, dictation-safe (R5); `FormatStrip` is its `inputAccessoryView` |
| `FormatStrip` | `Components/Input/FormatStrip.swift` | `activeStyles: Set<InlineStyle>`, `onToggle: (InlineStyle) -> Void`, `onListMenu: (CGRect) -> Void` | The §4 capsule (5 controls, scrollable); docked with the keyboard as the editor's accessory view |
| `FormatStripButton` | `Components/Button/FormatStripButton.swift` | `glyph: Image`, `isActive: Bool`, `action: () -> Void` | Stateful toggle: plain glyph ⇄ filled accent circle (~37 pt), ~200 ms clear on deactivation; consumed only by `FormatStrip` |
| `ListStyleMenu` | `Components/Overlays/ListStyleMenu.swift` | `onSelect: (ListStyle) -> Void` | Two-row popover (Bulleted / Numbered) anchored above the strip's list button; presented via the typed `Route` system (`/present-overlay`), never covering the document |
| `EditorNavChrome` | `Components/Navigation/EditorNavChrome.swift` | `canUndo: Bool`, `onBack: () -> Void`, `onUndo: () -> Void`, `onDone: () -> Void` | Floating circles over the canvas: back · undo (hidden until `canUndo`) · accent-filled Done (edit mode only) |

### Supporting non-UI units (same no-invention rule)

| Unit (new) | Path | Contract | Usage |
|---|---|---|---|
| `NoteDocumentCodec` | `Services/Notes/NoteDocumentCodec.swift` | `parse(markdown: String) -> AttributedString` / `serialize(AttributedString) -> String` | N1 GFM ↔ runs, with literal-character escaping; ships with the round-trip test `parse(serialize(x)) == x` |
| `NoteAutosaveController` | `Services/Notes/NoteAutosaveController.swift` | 1.5 s debounce; flush on exit + background; sends `baseUpdatedAt`, honors `stomped` (N5); offline queue (N13); lazy-create/empty-delete (N10) | Owned by `NoteEditorPage` |
| `NoteActions` | `State/Actions/NoteActions.swift` | `load / create / update / softDelete` against `/api/notes` | Sole API surface; refreshes derived state per house rule |
| `AppState.studyNotes` | `State/AppState.swift` | `EntityStore<StudyNote>` | Disk-cached source for the list + editor |
| `InlineStyle`, `ListStyle`, `EditorEvent` | `State/Models/NoteEditorModels.swift` | `bold, italic, underline, strikethrough` / `bulleted, numbered` / editor callbacks | Shared vocabulary between editor, strip, and codec |

The member **web twin's** manifest is written when that phase is drafted (out of v1 per §1) —
under the same rule. If the draft-step inventory pass proves an existing primitive genuinely fits
a row above, the swap is a **dated manifest amendment**, never a silent substitution.

## 5. Fidelity standard (what "similar to Apple Notes" means, operationally)

- **Normative sources:** the measurements and behaviors in `01-video-analysis.md` (geometry,
  type sizes, margins, active-state timings) are the target values, in MakeReady's design tokens
  (accent color is the app's tint, not Notes-amber).
- **Behavioral parity checklist** = R2, R5, R6, R7 plus §4's per-control behaviors. Each is a
  test, not an aspiration.
- **Enumerated deviations** (complete list — anything else that differs is a defect):
  1. v1 strip is 5 controls, not 18 (§4).
  2. No system Writing Tools row dependency (it appears on-device by itself; never replicated).
  3. Row 3 of a list item shows the `NoteLink` target, not a folder.
  4. No Siri suggestion banner, gallery view, pinning, sharing, or note-level `⋯` menu in v1.
  5. Accent color is MakeReady's, not amber.

## 5b. Measured motion & reference values (30 fps re-analysis, 2026-08-31)

Normative targets for every transition the video demonstrates (±0.03 s; `Notes.MP4`).

| Transition | Measured behavior |
|---|---|
| Compose → editor | Standard navigation push, list slides left / canvas in from right, **~0.35 s**. The format strip is **already docked during the push**; the keyboard slides up concurrently (~0.25–0.30 s), fully settled with the caret blinking by **~0.55 s after tap**. Zero-tap start confirmed frame-level |
| List popover (open) | Scale + fade **from the anchor button, ~0.10–0.15 s**. While open, the popover **replaces the strip** (strip hidden, revealed again after) |
| List popover (choose) | The bullet inserts **on the same frame as the tap** — content change does not wait for the dismissal. Popover then fades + scales back toward the anchor over **~0.10 s**; the strip re-reveals in place at its scrolled position with a brief fade-in (~0.1 s) |
| B toggle (from 10 fps pass) | Tap-down: accent circle pops in slightly oversized then settles (~150 ms); deactivation fades white → gray → plain over **~200 ms** (±100 ms — below the video's reliable resolution; tune within Motion tokens) |
| Formatting stability | Across every formatting act: the document never moves, resizes, or re-insets (verified frame-level) |

**Reference palette** (sampled; per §5 mapped to MakeReady tokens — the accent is ours, not amber):

| Element | Sampled |
|---|---|
| Page background | `#000000` |
| Accent (caret, Done fill) | `#DEA30D`–`#DFA40C` (systemYellow in dark mode) |
| Format strip fill | `#181818` (+ system translucency) |
| List card fill | `#1A191C` |

**Not derivable from the video — normative source is THIS FILE:** Done was never tapped and the
editor was never exited (the return-to-list transition is unobserved — use the push's reverse),
undo was never tapped, row swipe/delete/search/`Aa` menu were never opened, and light mode never
appears. Specified by §2–§4 and platform conventions; do not hunt the video for them.

## 6. Server changes (complete list for v1)

1. Prisma: add `title String?`, `preview String?` to `StudyNote` + backfill script (N11).
2. `notes.service.ts`: add `NOTE` type (N4); derive title/preview on write (N11); `q` filter (N7).
3. `routes/notes.ts`: accept `q` on list; accept `baseUpdatedAt` on PATCH and return `stomped`
   (N5). **No new route modules. No changes to member routes.**

## 7. Implementation environment notes (for a fresh session)

- Server runs in Docker and does **not** hot-reload host edits: `docker restart makeready-server`
  after editing `server/src`. `curl` tests need a non-bot User-Agent.
- iPhone: rebuild/launch via the `/rebuild-iphone` skill. New overlays must go through
  `/present-overlay`; push-style sub-screens through `/push-page`; any animation diff through
  `/transition-review`; error handling per `/ios-error-surface`.
- Deployment target is iOS 26.0 (root CLAUDE.md's "17.0+" is stale).

## 8. Genuinely open (nothing else is)

- When the member web surface ships, and whether TipTap is its editor engine (recommended in
  `04-implementation-readiness.md` F3 — decision deferred with the web phase; nothing in v1
  depends on it).
