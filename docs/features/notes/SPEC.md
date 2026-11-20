# notes — spec
> lg · ticket: none · leader notes on iPhone: Apple-Notes-style editor + the notes list in the Home tab's Library section

## Idea

**Why.** Leaders get inspired away from a study and have nowhere to put the thought. Today they bury
it in a random lesson. (See the Ongoing board's "Inspirational notes" item: "I want the ability to
create a note based on my inspiration".) The UI 2.0 shell already offers "Write a note" in the
TabBar Add (+) menu, but it does nothing, and the Home tab's Library section shows "coming soon".[^1] This spec
makes both real. The note is a page, not a form: compose lands you on an open canvas with the
keyboard up, the first line is the title, formatting is one tap away, and saving is automatic.
Notes are listed in the Home tab's Library section.

**What success looks like.** A leader taps "Write a note", types without tapping anything first,
leaves, and finds the note in the Library section under "Today" with its title and preview. Reopening it
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
  L[Home › Library: library-home notes list (d2m)] -->|row / compose| E
  E <-->|NSAttributedString| C[NoteDocumentCodec]
  E --> S[NoteAutosaveController 1.5 s debounce, exit, background]
  S --> Q[offline queue] --> N[NoteActions] --> API[/api/notes]
  N --> ST[AppState.studyNotes] --> L
```

**How it fits today.** The leader notes API already exists, scoped to the user, and nothing calls it
yet.[^2] Member notes (`/api/member/notes*`) keep their routes and today have no caller in any app (the web
lesson player submits SOAP through `/api/member/activities/{id}/submit`); only the shared service's
writes gain title/preview.[^3] `StudyNote` lacks `title`/`preview`, `NOTE_TYPES`
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
| client | ⬜ | The web notes surface is out of v1 (DECISIONS §1). No web code calls any notes endpoint: SOAP goes through `/api/member/activities/{id}/submit` (client LessonController.php:70-83), and nothing uses the `/admin/api/{path}` proxy for `notes` (audit 2026-11-20). Member routes keep their envelopes | — |
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
| D3 | Where notes are listed | The Home tab's Library section (`UI2Section.library`, `LibraryHomeContainer`) shows the notes list as library-home's first section. Its comingSoon state is no longer the default. Sections: Today / Yesterday / Previous 7 Days / Previous 30 Days / one per earlier month this year / one per earlier year, computed client-side from `updatedAt`, rows `updatedAt` desc. Date label: time if today, weekday if within 7 days, short date otherwise. Not a standalone page (a second home); not "no list" (unfindable notes) | user 2026-11-20 |
| D4 | Content format | GitHub-Flavored Markdown in `StudyNote.content`, with exactly two extensions: `==text==` (highlight, parsed but not emitted in v1) and `<u>text</u>`. The editor emits only: `# ` (first-line title), bare paragraphs, `**`, `*`, `~~`, `<u>`, `- `, `1. `. Literal `* _ ~ = < > #` in text are backslash-escaped on save | DECISIONS.md N1 · stated 2026-11-20 |
| D5 | Title | The first non-empty line is the title, styled Title live while typing, and saved as `# <line>`. No separate title field | DECISIONS.md R7 · stated 2026-11-20 |
| D6 | Ownership & type | Leader notes use the existing `requireAuth` `/api/notes` family under the session `userId`; another user's note id returns 404. Notes created here use `type: NOTE` (new `NOTE_TYPES.NOTE`), and the list requests `type=NOTE`. Member routes are unchanged | DECISIONS.md N2, N4 · confirmed 2026-11-20 |
| D7 | Conflicts | Last writer wins. PATCH takes optional `baseUpdatedAt` (ISO); the server always writes and returns `stomped: true` when the stored `updatedAt` was later than `baseUpdatedAt`, else `false`. On `stomped` while the editor is open: log it, keep the editor's text (it is what was saved), refresh the list | DECISIONS.md N5 · stated 2026-11-20 · editor behaviour (assumed at brainstorm) 2026-11-20 |
| D8 | Search | `GET /api/notes?q=` filters `content` case-insensitive substring (Prisma `contains`, `mode: insensitive`). The search capsule sends `q` debounced 300 ms. No client-side corpus search | DECISIONS.md N7 · stated 2026-11-20 · 300 ms (assumed at spec) 2026-11-20 |
| D9 | Editor engine | `NoteDocumentCodec` (app side, `Services/Notes/`) converts markdown ⇄ `NSAttributedString` with Apple `swift-markdown` (new SPM dependency, pinned exact version) — parse once on open, serialize only on autosave. Round-trip invariant `parse(serialize(doc)) == doc` is a required test over a fixture corpus covering every D4 construct and every escaped character. The editor view itself (UITextView/TextKit 2, C-001) is d2m's; the codec is the only bridge, and the binding type follows d2m's C-001 contract. **Superseded in part 2026-11-20 (align):** C-001 §4 binds a Swift `AttributedString` (value type) carrying d2m's paragraph-style attribute (Title / Body / Bulleted / Numbered) and the shared `InlineStyle`/`ListStyle` types from `NoteEditorModels.swift`, with `selection` as a UTF-16 `NSRange`; the codec converts markdown ⇄ that `AttributedString` and never defines its own attribute keys. Not `NSAttributedString` (C-001 doesn't take it, so a second bridge would be needed) | DECISIONS.md N9 · stated 2026-11-20 · bridge type: C-001 contract, align 2026-11-20 |
| D10 | Lazy create / empty delete | A new note sends no request until its content (trimmed) is non-empty; the first save is `POST`, later saves `PATCH`. Leaving a note whose content is empty soft-deletes it (`DELETE`). The existing zod `min(1)` stays | DECISIONS.md N10 · confirmed 2026-11-20 |
| D11 | Title/preview columns | `StudyNote.title String?` and `preview String?`, written by the service on every create and update (leader and member): title = first non-empty line, preview = the next non-empty line, each markdown-stripped and cut to 120 chars. The list never parses markdown. Backfill script `scripts/backfill-note-titles.ts` fills every existing row, idempotent (re-runnable), batches of 500. **Superseded in part 2026-11-20 (audit):** the script is `server/src/scripts/backfill-note-titles.ts` (only `dist/` ships in the image; precedent `src/scripts/backfill-program-org.ts`, with `--dry-run`), run as `npm run backfill:note-titles` locally and `node dist/scripts/backfill-note-titles.js` on staging/prod. It writes with raw SQL `UPDATE study_notes SET title, preview WHERE id = $id`, which leaves `updatedAt` untouched (a Prisma `update` bumps `@updatedAt`, which would move every note to Today and stomp its next save). It pages by keyset on `id`, not `WHERE title IS NULL`. **Markdown-stripped** means, per line: drop a leading `#{1,6} `, `- `, `* `, `+ `, `\d+\. ` or `> `; remove `**`, `__`, `~~`, `==`, `<u>`, `</u>` and paired single `*`/`_`; unescape `\X` → `X`; trim. A line that is empty after this is skipped. The cut is 120 code points (`Array.from`, never splitting a surrogate pair). Title/preview are derived only inside `createNote` and `updateNote`, which are the only writers of `content` | DECISIONS.md N11 · confirmed 2026-11-20 · script shape (assumed at spec) 2026-11-20 · audit corrections auto (recommended) 2026-11-20 |
| D12 | Autosave | `NoteAutosaveController`: debounced save 1.5 s after the last edit; immediate flush when leaving the editor and on `scenePhase` → background. Killing the app within 1.5 s of typing may lose only that last burst. No Save button anywhere | DECISIONS.md R6 · stated 2026-11-20 |
| D13 | Offline | Unsent saves persist per note (latest content wins) as JSON in Application Support/notes-queue, and flush one request per note on launch and when `NWPathMonitor` is satisfied. `stomped` is honoured on flush as in D7. A not-yet-created note flushes as `POST`, then its server id replaces the local id in `AppState` and the queue | DECISIONS.md N13 · stated 2026-11-20 · storage (assumed at spec) 2026-11-20 |
| D14 | Format strip | Exactly five controls, in order: Bold, Italic, Underline, Strikethrough, List (Bulleted/Numbered menu). Return continues a list; return on an empty item exits to a body line. Absent with no placeholders: style menu, checklist, table, attach, markup, highlight, link, indent, move, block quote | DECISIONS.md §4 · stated 2026-11-20 |
| D15 | No length limit | No client or server cap is added. A 100 000-character note saves, reopens and scrolls (manual perf check on device) | DECISIONS.md R4 · confirmed 2026-11-20 |
| D16 | Dictation | The editor keeps the system keyboard (no custom `inputView`), so keyboard dictation inserts at the caret. One XCTest asserts `inputView == nil` and the keyboard type is `.default` | DECISIONS.md R5 · stated 2026-11-20 |
| D17 | Entry points | Three routes open `note-editor`: the Add menu's "Write a note" (new note), library-home compose (new note), and a library-home row tap (that note). Each goes through the typed `Route`/`NavigationCoordinator`, never `.sheet`/`.fullScreenCover`. **Superseded in part 2026-11-20 (audit):** UI 2.0 pushes through `UI2Navigator`, not the legacy `Route`/`NavigationCoordinator`. Two new `UI2Destination` cases: `.newNote(flowId: UUID)` (a fresh id per open, as `enrollChecklist` does, so two new notes are never the same destination) and `.noteEditor(noteId: String)`. Each gets a `page(for:)` row and `isFullScreen == true` (no tab bar; the editor draws its own chrome). The Add menu's "Write a note" branch pushes `.newNote` on `model.tab`, as `InviteEntry.open(on:model:)` does. Compose and row tap push through `@Environment(\.ui2Navigator)`. No deep link (the shell drops them) | (assumed at brainstorm) 2026-11-20 · audit auto (recommended) 2026-11-20 |
| D18 | Audience | Any signed-in User (Group Leader, Admin, Owner, Super Admin), owner-private, with no org check; members can't reach it. Already enforced with no new code: iPhone login is leader-gated (`AuthManager.swift:540-556`), and the shell shows only when signed in | (assumed at brainstorm) 2026-11-20 · enforcement confirmed at audit 2026-11-20 |
| D19 | Fixtures | `server/fixtures/screens/library-home.ts`. Its `full` scenario seeds the Fixtures leader's notes across Today, Yesterday, Previous 7 Days, Previous 30 Days, an earlier month and an earlier year, one with a GROUP link for the context line. An `empty` scenario has none. Dates come from `ctx.now` | (assumed at brainstorm) 2026-11-20 |
| D20 | Errors | Save and load failures go through `/ios-error-surface`. A failed autosave is queued (D13) and surfaced console-only; a failed list load shows d2m's library-home error/empty state | (assumed at spec) 2026-11-20 |
| D21 | d2m open questions | The plan's d2m-gate task answers every open question on C-001/002/003/009/015 through `answer_project_change` with d2m's recommended option, with three exceptions. **OQ-C-001-003** takes option 2: memo-embed paragraphs render as plain links in v1, per D2. **OQ-C-003-001 and OQ-C-015-001** (no picture, where the offered options are all Figma or defer) take the free answer "spec from the written measurements; the first accepted capture freezes as the snapshot (D68 precedent)", because D1 rules no Figma ever. **OQ-C-001-001 and OQ-C-002-001** take their option 4, which says the same. Questions on C-005/008/010 are answered the same way once d2m specs them. Not "leave them for the owner": each one blocks a d2m build this feature waits on, and D1 already says where the design comes from | auto (recommended) 2026-11-20 |
| D22 | `contextLabel` choice and scope | The label comes from one link, picked by `refType` priority MEMO > GROUP > PROGRAM, then `createdAt` asc, then `id` asc. A link's name resolves only for an entity the note's user may see: a group or program in an org where the user holds a role, or a memo the user owns that is active. Otherwise null. LESSON, ENROLLMENT, VERSE and unknown types → null. Not "earliest link": `createMany` gives every link of a note the same `createdAt`, so earliest is undefined. Not unscoped: link `refId`s are unchecked on create, so a leader could read any group's name | auto (recommended) 2026-11-20 |
| D23 | `stomped` rule | The iPhone holds `updatedAt` as the server's ISO **string** and sends it back verbatim as `baseUpdatedAt` (precedent: `DraftWire.updatedAt: String`). It parses that string to a `Date` only for D3's sections. The server validates `z.string().datetime({ offset: true })`. In one `$transaction` it locks the row (`SELECT "updatedAt","userId","isActive" … FOR UPDATE`) and sets `stomped = stored > base`, comparing at ms precision when the base carries a fraction and at second precision when it doesn't. A missing, inactive or another user's note → 404. Not `Date` round-tripping: the app's `.iso8601` encoder drops fractional seconds, which would make nearly every save `stomped`. Not read-then-update: it races a concurrent DELETE | auto (recommended) 2026-11-20 |
| D24 | Offline queue semantics | `NoteSaveQueue` entries are `upsert(content, baseUpdatedAt?)` or `delete`, one per note id, latest wins. It is stored as one JSON file per API environment beside the state cache (`StatePersistence`'s per-environment directory), never shared across Local/Staging/Prod. It is cleared in `AppState.clearAllData`. Flush on launch from `UI2Shell`'s `.task` once a session exists, and when `NWPathMonitor` (new to the app) reports satisfied. A 404 on flush drops the entry and removes the note from `AppState.studyNotes`. A note that was never created and is then emptied is dropped from the queue with no request. The autosave shape copies `EnrollDraftSync`: one request in flight, POST then PATCH, the server id adopted, an injectable sleep, and "back" waiting for the save in flight. Supersedes D13's "Application Support/notes-queue" location | auto (recommended) 2026-11-20 |
| D25 | List query bounds | Leader `GET /api/notes` validates its query with zod: `limit` int 1–100 (default 50), `offset` int ≥ 0, `orderBy` ∈ {`createdAt`, `updatedAt`} (default `createdAt`), `q` string ≤ 200, every sort desc with `id desc` as the tiebreak; a bad value → 400. The iPhone pages with `limit=100`. New index `StudyNote [userId, updatedAt]` (SC9). No text-search index: the search is scoped to one user's notes. Not unbounded: `limit` is a raw `parseInt` today | auto (recommended) 2026-11-20 |
| D26 | Disk cache of notes | `AppState.studyNotes` persists via `PersistedState` with `decodeIfPresent` (no schema-version bump), capped at the 200 most recently updated notes with full content. Older notes reload from the server. Added to `clearInMemory`. Not uncapped: every `persist()` encodes every store, and D15 allows 100k-character notes | auto (recommended) 2026-11-20 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/notes` (edit) | server | iphone (`NoteActions.create`) | `requireAuth` | `{ type: "NOTE", content, links? }` (unchanged shape) | `201 { success: true, data: Note }` | 400 `{ success:false, error, details? }` · 401 |
| `GET /api/notes` (edit) | server | iphone (`NoteActions.load`) | `requireAuth` | existing params (`type`, `linkType`, `linkRefId`, `startDate`, `endDate`, `limit` default 50, `offset`) + optional `q` (D8) + optional `orderBy=updatedAt` (default stays `createdAt`, both desc, `id desc` tiebreak), all zod-validated per D25; iPhone sends `type=NOTE&orderBy=updatedAt&limit=100` and pages `offset` until `hasMore` is false | `200 { success: true, data: Note[], pagination: { total, limit, offset, hasMore } }` | 400 · 401 |
| `GET /api/notes/:noteId` (edit) | server | iphone (`NoteActions.loadOne`) | `requireAuth` | — | `200 { success: true, data: Note }` | **404** for a missing, inactive or another user's note (was 403 for another user's; D6) · 401 |
| `PATCH /api/notes/:noteId` (edit) | server | iphone (`NoteAutosaveController` via `NoteActions.update`) | `requireAuth` | `{ content: string (min 1), baseUpdatedAt?: ISO datetime with offset, echoed verbatim from the note's `updatedAt` (D23) }` — a leader-only zod schema with `.strict()`: unknown keys → 400 | `200 { success: true, data: Note, stomped: boolean }` | 400 · **404** missing, inactive or another user's (was 403; D6) · 401 |
| `DELETE /api/notes/:noteId` (edit: status only) | server | iphone (`NoteActions.softDelete`, D10; `NoteSaveQueue` delete entries, D24) | `requireAuth` | — | `200 { success: true, message: "Note deleted" }` (no `data`). Deleting an already-inactive own note is still 200 (idempotent for queue retries) | **404** missing or another user's (was 403; D6) · 401 |
| `NOTE_TYPES.NOTE` | server | iphone (create + list filter) | — | `type: "NOTE"` | — | — |

**`Note` (wire, leader routes):** `{ id, memberId: null, userId, type, content, title: string|null, preview: string|null, contextLabel: string|null, isActive, createdAt, updatedAt, links: [{ id, noteId, refType, refId, metadata, createdAt }] }`, which is the Prisma row as today plus the three new keys. `contextLabel` is resolved in one batch per response per D22: `GROUP` → `Group.name`, `PROGRAM` → `StudyProgram.name`, `MEMO` → `VoiceMemo.title` once memo's D18 lands (null until then); every other `refType` (LESSON, ENROLLMENT, VERSE, unknown) → null. iPhone decodes `refType` as an open `String` so a new value (MEMO) never fails decoding. Member routes (`/api/member/notes*`) keep their envelopes. Those returning the Prisma row gain `title`/`preview`; `/member/notes/with-context` selects explicit fields and gains nothing.

## Schema & API changes

| # | ADD/EDIT/RENAME/REMOVE | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `StudyNote.title` String? | `title` on every note response | D11 · T1, T2 | planned |
| SC2 | ADD | `StudyNote.preview` String? | `preview` on every note response | D11 · T1, T2 | planned |
| SC3 | EDIT | `NOTE_TYPES` + `NOTE` | `type: "NOTE"` (already accepted: `type` is `z.string().min(1)`; this is the constant and the list filter) | D6 | planned |
| SC4 | EDIT | `GET /api/notes` + `q` | query param | D8 | planned |
| SC5 | EDIT | `PATCH /api/notes/:noteId` + `baseUpdatedAt` in, `stomped` out; new leader-only strict body schema | body + response | D7; today's shared `updateNoteSchema` is a non-strict `z.object`, which silently strips unknown keys, so `baseUpdatedAt` would be dropped and nothing is rejected | planned |
| SC6 | EDIT | `GET /api/notes` + `orderBy=updatedAt` | query param | D3 sorts rows `updatedAt` desc; `getNotes` orders by `createdAt` and pages at 50, so an old note edited today could fall off the first page | planned |
| SC7 | ADD | derived `contextLabel` on leader `Note` responses (no column) | response field | D2 (the row's context line shows the linked item's display name); the wire carries only `refType`/`refId`, and the iPhone holds no cache of every linked group, program or memo | planned |
| SC9 | ADD | index `StudyNote [userId, updatedAt]` (schema.yaml) | — | D25: the list sorts by `updatedAt` within one user (T5) | planned |
| SC8 | EDIT | leader `GET`/`PATCH`/`DELETE /api/notes/:noteId` status for another user's note 403 → 404; inactive note → 404 on GET/PATCH | status codes | D6 (another user's note id returns 404); `getNote` doesn't filter `isActive`, so a queued autosave (D13) could PATCH a soft-deleted note back to life invisibly | planned |

**Data plan:** the two nullable columns are generated from `server/schema/schema.yaml` via
`schema:diff`; no NOT NULL, so no migration-time backfill. `src/scripts/backfill-note-titles.ts` (D11)
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
    The shared `updateNoteSchema` stays as it is for the member route, which has no caller. The response adds `stomped` (SC5);
  - another user's note → 404, and an inactive note → 404 on GET/PATCH, through a new
    `findFirst({ id, userId, isActive: true })` lookup (SC8). Member routes keep `getNote`;
  - leader PATCH runs D23's locked transaction;
  - zod query validation on `GET /notes` (D25);
  - `contextLabel` batch-resolved on list and single responses (SC7), in a service helper beside
    `getNotesWithContext`'s resolver.
- `src/scripts/backfill-note-titles.ts` + npm script `backfill:note-titles` (D11).
- `fixtures/screens/library-home.ts` (D19).
- Recipe: `/api`.

## iphone

- **Dependency:** `swift-markdown` via SPM, exact version pinned.
- **`Services/Notes/NoteDocumentCodec.swift`** (D4, D9) + round-trip corpus tests. It converts markdown ⇄ C-001's `AttributedString`, using d2m's `NoteEditorModels.swift` attribute and `InlineStyle`/`ListStyle` types (F5).
- **`Services/Notes/NoteAutosaveController.swift`** (D10, D12, D7) + **`Services/Notes/NoteSaveQueue.swift`** (D13).
- **`State/Actions/NoteActions.swift`:** `load(q:)`, `loadOne`, `create`, `update(baseUpdatedAt:)`,
  `softDelete`. Each refreshes `AppState.studyNotes` in the same call, and it is the only
  `APIClient` user for notes.
- **`State/AppState.swift`:** `let studyNotes = EntityStore<StudyNote>()`, disk-persisted per D26, cleared in `clearInMemory` and `clearAllData`.
- **Dates:** `StudyNote.updatedAt` and `createdAt` are ISO `String`s, echoed verbatim (D23). A new `NotesPagination { total, limit, offset, hasMore }` type is added, because the existing `PaginationInfo` has a different shape.
- **SPM:** `swift-markdown` (+ `swift-cmark`) links to both the `MakeReady` and `MakeReadyCapture` targets. `capture-targets.rb` doesn't sync package products, so add them by hand. It is the first package on an app target. Every new file needs pbxproj entries (no folder sync), then `ruby scripts/capture-targets.rb`.
- **Tests** live in `MakeReadyCaptureTests` with `StubAPIClient`; Actions take `init(api:state:)`.
- **`State/Models/NoteModels.swift`:** `StudyNote` (with `title`, `preview`, `contextLabel`, `links`), `NoteLinkRef` (`refType` an open `String`), `NoteSection`. A null `title` falls back per F4.
- **Paging:** `NoteActions.load` requests `type=NOTE&orderBy=updatedAt` and follows `pagination.hasMore` until the whole list is in `AppState` (SC6), because D3's sections are computed client-side over every note.
- **Containers** under `MakeReady/UI2/Containers/` map state to d2m's view props and callbacks:
  - `LibraryHomeContainer` maps `AppState.studyNotes` → sections and rows (D3), search → `q`, and
    compose and row tap → note-editor;
  - `NoteEditorContainer` hosts d2m's `note-editor` with the codec and the autosave controller.
- **Routing (D17):** two `UI2Destination` cases in `UI2ShellModel.swift` with `page(for:)` rows in
  `UI2Shell.swift`, and the Add menu's "Write a note" branch (today it only closes the menu:
  `UI2Shell.swift:96-99`). Run `/transition-review` on any motion code. The editor must not lift
  itself by a manual keyboard offset (the shell already ignores the keyboard safe area; standing trap).
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
1. Home › Library (the top-nav Library section) shows the notes list in the D19 sections. [risk]
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
| T9 | server: `src/scripts/backfill-note-titles.ts`, idempotent, keyset batches of 500, `updatedAt` preserved (D11) | blocking |
| T10 | server: `fixtures/screens/library-home.ts` (D19) | blocking |
| T11 | iphone: `NoteModels.swift` decoding (open `refType`, nullable title/preview/contextLabel) + `AppState.studyNotes` `EntityStore`, disk-persisted | trailing |
| T12 | iphone: `NoteActions` (load with paging and `orderBy`, loadOne, create, update with `baseUpdatedAt`, softDelete), each refreshing `AppState.studyNotes` | trailing |
| T13 | iphone: `NoteDocumentCodec` markdown ⇄ C-001 `AttributedString` + round-trip corpus (D4, D9) — needs d2m's `NoteEditorModels.swift` (F5) | trailing |
| T14 | iphone: `NoteAutosaveController` + `NoteSaveQueue` (D10, D12, D13, D7) | trailing |
| T15 | iphone: `LibraryHomeContainer` + `NoteEditorContainer` + the three D17 routes — gated on F5 | trailing |
| F6 | audit: the backfill as first written (`prisma.update`) would bump `@updatedAt` on every row | fixed in D11 (raw SQL, `updatedAt` untouched); T9's test asserts `updatedAt` unchanged |
| F7 | contract: `stomped` would be true on nearly every save, because the app's `.iso8601` encoder drops fractional seconds, and read-then-update races | fixed in D23 and §Contract (verbatim echo, locked transaction) |
| F8 | contract: `contextLabel` "earliest link" is undefined (`createMany` gives one `createdAt`), and unscoped resolution leaks group names | fixed in D22 |
| F9 | `VoiceMemo` and memo's `memoLinkRefusal` exist only on unmerged `builder/memo`, which also edits `createNote` and `addNoteLink` in `notes.service.ts`; `feature/memo` doesn't have them yet | build-time risk, T8: no `prisma.voiceMemo` reference on this branch, MEMO → null. Whichever of notes and memo lands second on `feature/memo` adds the MEMO label and resolves the `notes.service.ts` conflict |
| F10 | D16's `inputView == nil` lives inside d2m's C-001 `UITextView`, which an app test can only reach by hosting the view | build-time risk, T15: host C-001 in a `MakeReadyCaptureTests` window and find the `UITextView` in its hierarchy; if C-001 hides it, `request_project_change` for a test hook (D1) |
| F11 | Nothing in v1 creates a link from the iPhone: the editor has no link UI (D14), so only fixtures (D19) and direct API calls produce a context line | accepted: the walk sees the context line through the D19 GROUP fixture |
| F12 | `GET /notes/types` (routes/notes.ts:1907) is shadowed by `/notes/:noteId` (1448) | out of scope: the feature doesn't use it |
| F13 | `q` misses words split by markup (`un**believ**able`), because it searches escaped markdown | accepted for v1 (D8) |
| F14 | Prototype item 8: no in-scope item is built, so there is no render to diff against a snapshot, and every state is unseen | build-time risk, T15: the wiring's walk is the first time these states are seen |
| R1 | repoint (iphone): library-home coming-soon default ← `UI2/Containers/Library/LibraryHomeContainer.swift:7` (this feature); `MakeReadyUI/Screens/Library/LibraryHomeScreen.swift:25,59` and `MakeReadyCapture…/ViewRegistry.swift:3318-3322,6112` (d2m-owned, changed by change cmwoogn700001v0h9l69stkz3) | builder:plan's repoint phase: T15 for the container; the d2m rows ride on F5's gate |
| R2 | repoint (iphone): the inert Add-menu "Write a note" ← `UI2/Shell/UI2Shell.swift:24-32,96-99` | T15 (D17) |
| R3 | repoint (server, client): none. No caller of `/api/notes` or `/api/member/notes*` exists in client/ or iphone/ (audit grep 2026-11-20); nothing depends on the old 403 | — |

## Plan

The plan, task by task: `docs/features/notes/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · `StudyNote.title`, `preview` and the `[userId, updatedAt]` index
- Phase 1 · Task 2 · title/preview derivation on every write, and `NOTE_TYPES.NOTE`
- Phase 1 · Task 3 · the validated leader list query: `q`, `orderBy`, bounds
- Phase 1 · Task 4 · leader `:noteId` routes: 404 scoping, strict PATCH, locked `stomped`
- Phase 2 · Task 5 · `contextLabel` on every leader note response
- Phase 2 · Task 6 · the title/preview backfill script
- Phase 2 · Task 7 · `library-home` fixture, the §Contract request suite, and the contract freeze
- Phase 3 · Task 8 · `StudyNote` wire models, D3 sectioning, and `AppState.studyNotes`
- Phase 3 · Task 9 · `NoteActions`
- Phase 4 · Task 10 · `NoteSaveQueue` and its connectivity flush
- Phase 4 · Task 11 · `NoteAutosaveController`
- Phase 5 · Task 12 · the d2m gate, `swift-markdown`, and `NoteDocumentCodec`
- Phase 5 · Task 13 · `LibraryHomeContainer`: the notes list
- Phase 5 · Task 14 · `NoteEditorContainer`, the three D17 routes, launch flush

## Prototype

- **Ref:** `--ui2 library-home, C-001, C-002, C-003, C-005, C-008, C-009, C-010, C-015` (d2m changes cmwoogn700001v0h9l69stkz3 for library-home, cmwoogs5g001mv0h9jj3070bk for the editor). No Figma (D1): the contracts are written from `analysis/01-video-analysis.md`, `02-under-the-hood.md` and `DECISIONS.md`.
- **Status at audit (2026-11-20), all unbuilt:**

| Item | Specced | Built | Open questions |
|---|---|---|---|
| library-home (screen) | ✅ (coming-soon only; notes section requested, change blocked) | coming-soon only | the request is carded and blocked on C-005/008/010 |
| `note-editor` (screen) | ❌ not minted | ❌ | — |
| C-001 MarkdownTextEditor | ✅ | ❌ (waits on C-002) | 7, disposed in D21 |
| C-002 FormatStrip | ✅ | ❌ | 5, disposed in D21 |
| C-003 FormatStripButton | ✅ | ❌ | 4, disposed in D21 |
| C-009 EditorNavChrome | ✅ | ❌ | 5, disposed in D21 |
| C-015 ListStyleMenu | ✅ | ❌ | 7, disposed in D21 |
| C-005 NoteListRow · C-008 NotesBottomBar · C-010 NoteSectionHeader | ❌ | ❌ | none yet; D21 applies once specced |

- **Frozen paths:** everything under `iphone/MakeReadyUI/` and `docs/ui2/` is d2m's. This feature only reads it (D1).

## Replaced surfaces

| # | Surface (file:line) | REPLACES/ABSORBS/REUSES | Fingerprint |
|---|---|---|---|
| RS1 | Library coming-soon default (`iphone/MakeReady/UI2/Containers/Library/LibraryHomeContainer.swift:1-9`) | REPLACES (as the default; the coming-soon variant stays d2m's) | 007dd419 |
| RS2 | Inert Add-menu "Write a note" row (`iphone/MakeReady/UI2/Shell/UI2Shell.swift:24-32,96-99`) | REPLACES (the inert close becomes a push) | b3c693f1 |

There are no `S#` gaps: neither surface has a capability today beyond showing a placeholder or closing a menu. The legacy `ExegesisNoteEditorPage` is ADJACENT prior art, not replaced. Client: none.

| # | Design add | App | Disposition |
|---|---|---|---|
| N1 | Notes persist (title, preview, content, formatting) | server | SC1, SC2, T1, T2 |
| N2 | An unsent edit survives quitting and going offline | iphone | D24, T14 (no backend implication beyond PATCH and POST) |
| N3 | Search by any word | server | SC4, T4 |
| N4 | List sorted by last edit | server | SC6, SC9, T5 |
| N5 | Context line naming the linked item | server | SC7, T8 |
