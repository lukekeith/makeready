# notes — spec
> lg · ticket: none · leader notes on iPhone: Apple-Notes-style editor + the Library tab's notes list

## Idea

**Why.** Leaders get inspired away from a study and have nowhere to put the thought. Today they bury
it in a random lesson. (See the Ongoing board's "Inspirational notes" item: "I want the ability to
create a note based on my inspiration".) The UI 2.0 shell already offers "Write a note" in the
TabBar Add (+) menu, but it does nothing, and the Library tab shows "coming soon".[^1] This spec
makes both real. The note is a page, not a form: compose lands you on an open canvas with the
keyboard up, the first line is the title, formatting is one tap away, and saving is automatic.
Notes are listed on the Library tab.

**What success looks like.** A leader taps "Write a note", types without tapping anything first,
leaves, and finds the note on the Library tab under "Today" with its title and preview. Reopening it
shows the same text and the same formatting. Search finds it by any word, and nothing is lost when
the leader goes offline or quits mid-sentence beyond the last 1.5 s.

**In your words.**
- "Notes is a page, not a form" (README) → D5, D9
- "zero taps before typing" (DECISIONS R2) → D9
- "I want the ability to create a note based on my inspiration and then easily be able to add it into a lesson" (Ongoing board 12101572041) → D1 (adding into a lesson is out of scope; §Out of scope)
- d2m-from-video, Library home and memo-link rulings (2026-11-20) → D1, D2, D3

**The concept.** d2m owns every view: two screens (`library-home` notes section, a new pushed
`note-editor`) and eight components (C-001, C-002, C-003, C-005, C-008, C-009, C-010, C-015), specced
and built from the Notes.MP4 analysis. This spec owns everything underneath and the wiring:

```mermaid
flowchart LR
  A[+ menu: Write a note] --> E[note-editor (d2m)]
  L[Library tab: library-home notes list (d2m)] -->|row / compose| E
  E <-->|NSAttributedString| C[NoteDocumentCodec]
  E --> S[NoteAutosaveController 1.5 s debounce, exit, background]
  S --> Q[offline queue] --> N[NoteActions] --> API[/api/notes]
  N --> ST[AppState.studyNotes] --> L
```

**How it fits today.** The leader notes API already exists, scoped to the user, and nothing calls it
yet.[^2] Member notes (`/api/member/notes*`) serve the web lesson player and keep their routes; only
the shared service's writes gain title/preview.[^3] `StudyNote` lacks `title`/`preview`, `NOTE_TYPES`
lacks `NOTE`, the list takes no `q`, and PATCH takes only `{content}`.[^4] The body limit is 10 MB.[^5]
The memo spec (D18 there) adds `LINK_TYPES.MEMO`.[^6] `ExegesisNoteEditorPage` is prior art for the
keyboard-overlays-content layout and is not reused.[^7]

**Approaches considered.** Chosen: d2m builds the views from the video analysis, and this spec builds
the engine and wiring. Rejected:
- engine first with the screens later: the editor *is* the feature, so most of the value would wait;
- hand-building in the legacy `Pages/`/`Components/`: it bypasses UI 2.0 and would need rework;
- an inline memo embed: it needs memo's not-yet-built player, and memo's D18 is mid-build;
- a standalone notes page, or no list: a second home for the same content, or notes nobody can find again.

[^1]: iphone/MakeReady/UI2/Shell/UI2Shell.swift:24-32,250 · iphone/MakeReady/UI2/Containers/Library/LibraryHomeContainer.swift:1-9
[^2]: server/src/routes/notes.ts:1191,1328,1448,1562,1687 · server/src/index.ts:518
[^3]: server/src/routes/notes.ts:292-1080
[^4]: server/prisma/schema.prisma:1334-1357 · server/src/services/notes.service.ts:36-59,208,261,536 · server/src/routes/notes.ts:223-231,1340-1348
[^5]: server/src/index.ts:225
[^6]: docs/features/memo/SPEC.md §Decisions D18
[^7]: iphone/MakeReady/Pages/Manage/Program/ExegesisNoteEditorPage.swift:1-25

Reference material (superseded by this SPEC where they differ): `DECISIONS.md` and `analysis/01–04`.

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | `StudyNote.title`/`preview` + backfill; `NOTE` type; `q` search; `baseUpdatedAt` → `stomped` on PATCH; `type` filter used by the list | §server |
| client | ⬜ | The web notes surface is out of v1 (DECISIONS §1). The web lesson player uses `/api/member/notes*`, whose routes and response fields are unchanged; title/preview are new fields it ignores | — |
| iphone | ✅ | Codec, autosave + offline queue, `NoteActions`, `AppState.studyNotes`, `swift-markdown` dependency, and wiring d2m's `library-home` notes section and `note-editor` screen (+ menu, row tap, compose) | §iphone |

**Sequencing:** contract settled → server implements and verifies (contract FREEZES) → iphone codec,
autosave and state build in parallel with d2m's views → iphone wiring once d2m reports both requests
done → the cross-app walk.

**Backward compatibility:** all additive. The two new nullable columns, the optional `q`, the
optional `baseUpdatedAt` and the new `stomped` response field change nothing a released 2.0.0 build
reads. That build doesn't call `/api/notes`, and it keeps the inert menu item and the coming-soon
Library.

**Blast radius:** every `StudyNote` write (leader and member) now derives title/preview in the
service; the backfill touches every existing row once; fixtures gain a `library-home` screen file.

## Decisions

<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | Who builds the views | d2m specs and builds every notes view from `analysis/01-video-analysis.md` + `DECISIONS.md` (no Figma, ever). That covers `library-home`'s notes section (change cmwoogn700001v0h9l69stkz3), the new `note-editor` screen, and C-001/002/003/005/008/009/010/015 (change cmwoogs5g001mv0h9jj3070bk). This spec writes no view, contract, registry row or token. It wires d2m's views from `MakeReady/UI2/Containers`. A view gap found during wiring goes back to d2m via `request_project_change`, never an inline invention. Not engine-first (value waits); not legacy hand-build (bypasses UI 2.0) | user 2026-11-20 |
| D2 | Memo reference | A note references a memo only through a `NoteLink` of `linkType: MEMO` (memo spec D18). The row's context line shows the linked item's display name for every link type, including a memo's title. The codec treats a `makeready://memo/…` link as an ordinary link. No inline memo player. Not inline embed (needs memo's player; memo D18 mid-build); not both (two mechanisms) | user 2026-11-20 |
| D3 | Where notes are listed | The Library tab (`LibraryHomeContainer`) shows the notes list as library-home's first section. Its comingSoon state is no longer the default. Sections: Today / Yesterday / Previous 7 Days / Previous 30 Days / one per earlier month this year / one per earlier year, computed client-side from `updatedAt`, rows `updatedAt` desc. Date label: time if today, weekday if within 7 days, short date otherwise. Not a standalone page (a second home); not "no list" (unfindable notes) | user 2026-11-20 |
| D4 | Content format | GitHub-Flavored Markdown in `StudyNote.content`, with exactly two extensions: `==text==` (highlight, parsed but not emitted in v1) and `<u>text</u>`. The editor emits only: `# ` (first-line title), bare paragraphs, `**`, `*`, `~~`, `<u>`, `- `, `1. `. Literal `* _ ~ = < > #` in text are backslash-escaped on save | DECISIONS.md N1 · stated 2026-11-20 |
| D5 | Title | The first non-empty line is the title, styled Title live while typing, and saved as `# <line>`. No separate title field | DECISIONS.md R7 · stated 2026-11-20 |
| D6 | Ownership & type | Leader notes use the existing `requireAuth` `/api/notes` family under the session `userId`; another user's note id returns 404. Notes created here use `type: NOTE` (new `NOTE_TYPES.NOTE`), and the list requests `type=NOTE`. Member routes are unchanged | DECISIONS.md N2, N4 · confirmed 2026-11-20 |
| D7 | Conflicts | Last writer wins. PATCH takes optional `baseUpdatedAt` (ISO); the server always writes and returns `stomped: true` when the stored `updatedAt` was later than `baseUpdatedAt`, else `false`. On `stomped` while the editor is open: log it, keep the editor's text (it is what was saved), refresh the list | DECISIONS.md N5 · stated 2026-11-20 · editor behaviour (assumed at brainstorm) 2026-11-20 |
| D8 | Search | `GET /api/notes?q=` filters `content` case-insensitive substring (Prisma `contains`, `mode: insensitive`). The search capsule sends `q` debounced 300 ms. No client-side corpus search | DECISIONS.md N7 · stated 2026-11-20 · 300 ms (assumed at spec) 2026-11-20 |
| D9 | Editor engine | `NoteDocumentCodec` (app side, `Services/Notes/`) converts markdown ⇄ `NSAttributedString` with Apple `swift-markdown` (new SPM dependency, pinned exact version) — parse once on open, serialize only on autosave. Round-trip invariant `parse(serialize(doc)) == doc` is a required test over a fixture corpus covering every D4 construct and every escaped character. The editor view itself (UITextView/TextKit 2, C-001) is d2m's; the codec is the only bridge, and the binding type follows d2m's C-001 contract. **Superseded in part 2026-11-20 (align):** C-001 §4 binds a Swift `AttributedString` (value type) carrying d2m's paragraph-style attribute (Title / Body / Bulleted / Numbered) and the shared `InlineStyle`/`ListStyle` types from `NoteEditorModels.swift`, with `selection` as a UTF-16 `NSRange`; the codec converts markdown ⇄ that `AttributedString` and never defines its own attribute keys. Not `NSAttributedString` (C-001 doesn't take it, so a second bridge would be needed) | DECISIONS.md N9 · stated 2026-11-20 · bridge type: C-001 contract, align 2026-11-20 |
| D10 | Lazy create / empty delete | A new note sends no request until its content (trimmed) is non-empty; the first save is `POST`, later saves `PATCH`. Leaving a note whose content is empty soft-deletes it (`DELETE`). The existing zod `min(1)` stays | DECISIONS.md N10 · confirmed 2026-11-20 |
| D11 | Title/preview columns | `StudyNote.title String?` and `preview String?`, written by the service on every create and update (leader and member): title = first non-empty line, preview = the next non-empty line, each markdown-stripped and cut to 120 chars. The list never parses markdown. Backfill script `scripts/backfill-note-titles.ts` fills every existing row, idempotent (re-runnable), batches of 500 | DECISIONS.md N11 · confirmed 2026-11-20 · script shape (assumed at spec) 2026-11-20 |
| D12 | Autosave | `NoteAutosaveController`: debounced save 1.5 s after the last edit; immediate flush when leaving the editor and on `scenePhase` → background. Killing the app within 1.5 s of typing may lose only that last burst. No Save button anywhere | DECISIONS.md R6 · stated 2026-11-20 |
| D13 | Offline | Unsent saves persist per note (latest content wins) as JSON in Application Support/notes-queue, and flush one request per note on launch and when `NWPathMonitor` is satisfied. `stomped` is honoured on flush as in D7. A not-yet-created note flushes as `POST`, then its server id replaces the local id in `AppState` and the queue | DECISIONS.md N13 · stated 2026-11-20 · storage (assumed at spec) 2026-11-20 |
| D14 | Format strip | Exactly five controls, in order: Bold, Italic, Underline, Strikethrough, List (Bulleted/Numbered menu). Return continues a list; return on an empty item exits to a body line. Absent with no placeholders: style menu, checklist, table, attach, markup, highlight, link, indent, move, block quote | DECISIONS.md §4 · stated 2026-11-20 |
| D15 | No length limit | No client or server cap is added. A 100 000-character note saves, reopens and scrolls (manual perf check on device) | DECISIONS.md R4 · confirmed 2026-11-20 |
| D16 | Dictation | The editor keeps the system keyboard (no custom `inputView`), so keyboard dictation inserts at the caret. One XCTest asserts `inputView == nil` and the keyboard type is `.default` | DECISIONS.md R5 · stated 2026-11-20 |
| D17 | Entry points | Three routes open `note-editor`: the Add menu's "Write a note" (new note), library-home compose (new note), and a library-home row tap (that note). Each goes through the typed `Route`/`NavigationCoordinator`, never `.sheet`/`.fullScreenCover` | (assumed at brainstorm) 2026-11-20 |
| D18 | Audience | Any signed-in User (Group Leader, Admin, Owner, Super Admin), owner-private, with no org check; members can't reach it | (assumed at brainstorm) 2026-11-20 |
| D19 | Fixtures | `server/fixtures/screens/library-home.ts`. Its `full` scenario seeds the Fixtures leader's notes across Today, Yesterday, Previous 7 Days, Previous 30 Days, an earlier month and an earlier year, one with a GROUP link for the context line. An `empty` scenario has none. Dates come from `ctx.now` | (assumed at brainstorm) 2026-11-20 |
| D20 | Errors | Save and load failures go through `/ios-error-surface`. A failed autosave is queued (D13) and surfaced console-only; a failed list load shows d2m's library-home error/empty state | (assumed at spec) 2026-11-20 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/notes` (edit) | server | iphone (`NoteActions.create`) | `requireAuth` | `{ type: "NOTE", content, links? }` (unchanged shape) | `201 { success: true, data: Note }` | 400 `{ success:false, error, details? }` · 401 |
| `GET /api/notes` (edit) | server | iphone (`NoteActions.load`) | `requireAuth` | existing params (`type`, `linkType`, `linkRefId`, `startDate`, `endDate`, `limit` default 50, `offset`) + optional `q` (D8) + optional `orderBy=updatedAt` (default stays `createdAt`, both desc); iPhone sends `type=NOTE&orderBy=updatedAt` and pages `offset` until `hasMore` is false | `200 { success: true, data: Note[], pagination: { total, limit, offset, hasMore } }` | 400 · 401 |
| `GET /api/notes/:noteId` (edit) | server | iphone (`NoteActions.loadOne`) | `requireAuth` | — | `200 { success: true, data: Note }` | **404** for a missing, inactive or another user's note (was 403 for another user's; D6) · 401 |
| `PATCH /api/notes/:noteId` (edit) | server | iphone (`NoteAutosaveController` via `NoteActions.update`) | `requireAuth` | `{ content: string (min 1), baseUpdatedAt?: ISO datetime }` — a leader-only zod schema with `.strict()`: unknown keys → 400 | `200 { success: true, data: Note, stomped: boolean }` | 400 · **404** missing, inactive or another user's (was 403; D6) · 401 |
| `DELETE /api/notes/:noteId` (edit: status only) | server | iphone (`NoteActions.softDelete`, D10) | `requireAuth` | — | unchanged | **404** missing or another user's (was 403; D6) · 401 |
| `NOTE_TYPES.NOTE` | server | iphone (create + list filter) | — | `type: "NOTE"` | — | — |

**`Note` (wire, leader routes):** `{ id, memberId: null, userId, type, content, title: string|null, preview: string|null, contextLabel: string|null, isActive, createdAt, updatedAt, links: [{ id, noteId, refType, refId, metadata, createdAt }] }`, which is the Prisma row as today plus the three new keys. `contextLabel` is the display name of the note's earliest link (by `createdAt`), resolved in one batch per response: `GROUP` → `Group.name`, `PROGRAM` → `StudyProgram.name`, `MEMO` → `VoiceMemo.title` once memo's D18 lands (null until then); every other `refType` (LESSON, ENROLLMENT, VERSE, unknown) → null. iPhone decodes `refType` as an open `String` so a new value (MEMO) never fails decoding. Member routes (`/api/member/notes*`) keep their envelopes; their rows gain `title`/`preview` and nothing else.

## Schema & API changes

| # | ADD/EDIT/RENAME/REMOVE | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `StudyNote.title` String? | `title` on every note response | D11 · T1, T2 | planned |
| SC2 | ADD | `StudyNote.preview` String? | `preview` on every note response | D11 · T1, T2 | planned |
| SC3 | EDIT | `NOTE_TYPES` + `NOTE` | `type: "NOTE"` accepted | D6 | planned |
| SC4 | EDIT | `GET /api/notes` + `q` | query param | D8 | planned |
| SC5 | EDIT | `PATCH /api/notes/:noteId` + `baseUpdatedAt` in, `stomped` out; new leader-only strict body schema | body + response | D7; today's shared `updateNoteSchema` is a non-strict `z.object`, which silently strips unknown keys, so `baseUpdatedAt` would be dropped and nothing is rejected | planned |
| SC6 | EDIT | `GET /api/notes` + `orderBy=updatedAt` | query param | D3 sorts rows `updatedAt` desc; `getNotes` orders by `createdAt` and pages at 50, so an old note edited today could fall off the first page | planned |
| SC7 | ADD | derived `contextLabel` on leader `Note` responses (no column) | response field | D2 (the row's context line shows the linked item's display name); the wire carries only `refType`/`refId`, and the iPhone holds no cache of every linked group, program or memo | planned |
| SC8 | EDIT | leader `GET`/`PATCH`/`DELETE /api/notes/:noteId` status for another user's note 403 → 404; inactive note → 404 on GET/PATCH | status codes | D6 (another user's note id returns 404); `getNote` doesn't filter `isActive`, so a queued autosave (D13) could PATCH a soft-deleted note back to life invisibly | planned |

**Data plan:** the two nullable columns are generated from `server/schema/schema.yaml` via
`schema:diff`; no NOT NULL, so no migration-time backfill. `scripts/backfill-note-titles.ts` (D11)
then fills existing rows, idempotently. Run it locally in the build, and on staging/prod after deploy
(an ops step named in the ship notes). Undo = drop the two columns; nothing reads them but the list.

## server

- `server/schema/schema.yaml` StudyNote + `title`, `preview` → migration (SC1, SC2).
- `notes.service.ts`:
  - `NOTE_TYPES.NOTE`;
  - a `deriveTitlePreview(content)` helper, called from `createNote`/`updateNote` and the member
    equivalents;
  - `getNotes` gains `q`;
  - `updateNote` takes `baseUpdatedAt` and returns `stomped`.
- `routes/notes.ts` (leader routes only):
  - `q` and `orderBy` on `GET /notes` (SC4, SC6);
  - a new `updateUserNoteSchema = z.object({ content, baseUpdatedAt? }).strict()` for leader PATCH.
    The shared `updateNoteSchema` stays as it is for the member route, so the web lesson player is
    untouched. The response adds `stomped` (SC5);
  - another user's note → 404, and an inactive note → 404 on GET/PATCH (SC8);
  - `contextLabel` batch-resolved on list and single responses (SC7), in a service helper beside
    `getNotesWithContext`'s resolver.
- `scripts/backfill-note-titles.ts` (D11).
- `fixtures/screens/library-home.ts` (D19).
- Recipe: `/api`.

## iphone

- **Dependency:** `swift-markdown` via SPM, exact version pinned.
- **`Services/Notes/NoteDocumentCodec.swift`** (D4, D9) + round-trip corpus tests. It converts markdown ⇄ C-001's `AttributedString`, using d2m's `NoteEditorModels.swift` attribute and `InlineStyle`/`ListStyle` types (F5).
- **`Services/Notes/NoteAutosaveController.swift`** (D10, D12, D7) + **`Services/Notes/NoteSaveQueue.swift`** (D13).
- **`State/Actions/NoteActions.swift`:** `load(q:)`, `loadOne`, `create`, `update(baseUpdatedAt:)`,
  `softDelete`. Each refreshes `AppState.studyNotes` in the same call, and it is the only
  `APIClient` user for notes.
- **`State/AppState.swift`:** `let studyNotes = EntityStore<StudyNote>()`, disk-persisted.
- **`State/Models/NoteModels.swift`:** `StudyNote` (with `title`, `preview`, `contextLabel`, `links`), `NoteLinkRef` (`refType` an open `String`), `NoteSection`. A null `title` falls back per F4.
- **Paging:** `NoteActions.load` requests `type=NOTE&orderBy=updatedAt` and follows `pagination.hasMore` until the whole list is in `AppState` (SC6), because D3's sections are computed client-side over every note.
- **Containers** under `MakeReady/UI2/Containers/` map state to d2m's view props and callbacks:
  - `LibraryHomeContainer` maps `AppState.studyNotes` → sections and rows (D3), search → `q`, and
    compose and row tap → note-editor;
  - `NoteEditorContainer` hosts d2m's `note-editor` with the codec and the autosave controller.
- **Routing (D17):** the `UI2Shell` Add menu "Write a note" action plus a typed route to
  note-editor, via `/nav-route` and `/push-page`. Run `/transition-review` on any motion code.
- **Gate:** wiring tasks start only when both d2m changes report done. A missing prop or state is
  sent back to d2m (D1).

## Testing

**server (vitest):**
- `deriveTitlePreview` cases: markdown stripped, blank lines skipped, 120-char cut;
- create/update write title/preview, leader and member;
- `q` matching case-insensitively;
- `stomped` true/false around `baseUpdatedAt`;
- the strict PATCH body rejecting unknown keys;
- another user's note → 404;
- backfill idempotence;
- `type=NOTE` filtering;
- a request test per §Contract row.

**iphone (XCTest):**
- codec round-trip over the corpus (every D4 construct, nested bold-italic, escapes, lists, the
  title line);
- autosave: debounce at 1.5 s, flush on exit and background, no request for an empty new note, and
  DELETE when a note is emptied (D10);
- queue: persist, relaunch, flush, POST-then-PATCH id swap, stomped handling;
- `NoteActions` refresh `AppState.studyNotes`;
- section bucketing against a fixed clock (D3);
- editor `inputView == nil` (D16).

**Cross-app E2E walk (the dev or agent-walk env, Fixtures identity, `fixtures:` first):**
1. Library tab shows the notes list in the D19 sections. [risk]
2. + → "Write a note" opens the editor with the keyboard up and the caret placed. [risk]
3. Type a title line + body, use Bold and a bulleted list, wait 2 s, then back → the row shows that title and preview under Today. [risk]
4. Reopen → identical text and formatting.
5. Search a body word → only that note.
6. Empty a note and leave → gone from the list.
7. The server log shows no errors throughout.

**Human verification:**
- dictation into the editor on a device (D16);
- the 100k-character perf check (D15);
- offline typing, then reconnect, then confirm the server copy;
- the feel against the Notes video: the strip docked during the push, and the toggle animation.

## Out of scope

- The web notes editor and any client change (DECISIONS §1).
- Adding a note into a lesson (Ongoing 12101572041's second half: a later feature).
- Checklists, tables, attachments, highlight emission, links, indent, block quote, the style menu (D14).
- Folders, pinning, sharing, a note `⋯` menu.
- Inline memo players and inserting memo links from the editor (D2; arrives with memo's screens).
- Member-facing notes.
- The other sections of library-home (memos, videos).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | iPhone wiring depends on two d2m changes finishing (D1) | build-time risk: the plan gates the wiring phase on both d2m changes being done; a stalled change parks the feature with the change id |
| F2 | d2m's C-001 binding type is unknown until it is specced; the codec must bridge to it | **settled 2026-11-20 (align):** C-001 is specced; it binds `AttributedString` + `NSRange` (D9 superseded in part) |
| F3 | Markdown round-trip fidelity is the hardest invariant | the corpus test is mandatory (D9) |
| F4 | The backfill must run on staging/prod after deploy | ops step at ship; title/preview stay null until it runs, and a row with a null title shows its content's first non-empty line with leading `#`s trimmed (a string op, not a markdown parse — D11 holds) |
| F5 | Design status at align (2026-11-20, via d2m): C-001/002/003/009/015 are specced but **unbuilt**. The "done" change cmwoogs5g001mv0h9jj3070bk produced only four glyph assets, left uncommitted in the main checkout. C-001 has 7 open questions and its build waits on C-002. C-005/008/010 are not specced. Change cmwoogn700001v0h9l69stkz3 (library-home) is **blocked** on them. No `note-editor` screen exists in d2m. `NoteEditorModels.swift`, which the codec's types live in, doesn't exist yet | build-time risk: settled by the plan's d2m gate (F1). Server tasks T1–T10 and iphone T11, T12 and T14 don't depend on d2m; T13 (codec) needs `NoteEditorModels.swift`, and T15 (wiring) needs every view and the `note-editor` screen. Getting there takes a `retry_project_change` on cmwoogn700001v0h9l69stkz3 once C-005/008/010 are built, plus a `request_project_change` for the `note-editor` screen if d2m didn't mint it |
| T1 | server: `schema.yaml` `StudyNote.title`, `preview` (nullable) → `schema:diff` migration (SC1, SC2) | blocking |
| T2 | server: `deriveTitlePreview(content)` called on every create and update, leader and member (SC1, SC2; D11) | blocking |
| T3 | server: `NOTE_TYPES.NOTE` (SC3) | blocking |
| T4 | server: `getNotes` `q`, case-insensitive `contains` on `content` (SC4) | blocking |
| T5 | server: `getNotes` `orderBy` option + route param `orderBy=updatedAt` (SC6) | blocking |
| T6 | server: leader `updateUserNoteSchema` (strict, `baseUpdatedAt`) + `updateNote` returns `stomped` (SC5) | blocking |
| T7 | server: leader `:noteId` routes return 404 for another user's or an inactive note (SC8) | blocking |
| T8 | server: `contextLabel` batch resolution on leader list + single responses (SC7) | blocking |
| T9 | server: `scripts/backfill-note-titles.ts`, idempotent, batches of 500 (D11) | blocking |
| T10 | server: `fixtures/screens/library-home.ts` (D19) | blocking |
| T11 | iphone: `NoteModels.swift` decoding (open `refType`, nullable title/preview/contextLabel) + `AppState.studyNotes` `EntityStore`, disk-persisted | trailing |
| T12 | iphone: `NoteActions` (load with paging and `orderBy`, loadOne, create, update with `baseUpdatedAt`, softDelete), each refreshing `AppState.studyNotes` | trailing |
| T13 | iphone: `NoteDocumentCodec` markdown ⇄ C-001 `AttributedString` + round-trip corpus (D4, D9) — needs d2m's `NoteEditorModels.swift` (F5) | trailing |
| T14 | iphone: `NoteAutosaveController` + `NoteSaveQueue` (D10, D12, D13, D7) | trailing |
| T15 | iphone: `LibraryHomeContainer` + `NoteEditorContainer` + the three D17 routes — gated on F5 | trailing |
