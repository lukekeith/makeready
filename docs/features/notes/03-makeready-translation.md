# 03 — Translating Notes into MakeReady

What we already have and what the Notes pattern demands that we do not have. **Analysis only —
no code yet.** Decision-shaped statements in this doc are the working notes behind the rulings;
the finalized versions live in [DECISIONS.md](DECISIONS.md), which wins on any conflict.

---

## 1. What already exists in the monorepo

### Server — a notes domain is already live

| Artifact | Where | Shape |
|---|---|---|
| `StudyNote` model | `server/prisma/schema.prisma:1227` | `id, memberId?, userId?, type, content (Text), isActive, createdAt, updatedAt` |
| `NoteLink` model | `server/prisma/schema.prisma:1252` | `noteId, refType, refId, metadata (Json?)` — unique on `(noteId, refType, refId)` |
| Note types | `server/src/services/notes.service.ts:41` | `OBSERVATION, APPLICATION, PRAYER, JOURNAL, REFLECTION, SCRIPTURE_NOTE, QUESTION` (a string column, deliberately extensible) |
| Link types | `server/prisma/schema.prisma:1255` | `LESSON, LESSON_ACTIVITY, LESSON_SCHEDULE, ENROLLMENT, GROUP, VERSE, PROGRAM` |
| Member routes (phone auth) | `server/src/routes/notes.ts:293, 433, 572, 716, 840` | create, list, list-by-entity, list-with-context, get one |
| User routes (Google auth) | `server/src/routes/notes.ts:1193, 1329, 1449, 1563, 1688, 1822` | create, list (filterable by `type`, `linkType`, `linkRefId`, date range), get, patch, delete, + an entity variant |
| `GET /api/notes/types` | `server/src/routes/notes.ts:1908` | returns the two enum lists |
| Mount point | `server/src/index.ts:494` | `app.use('/api', notesRoutes)` |

Validation today (`server/src/routes/notes.ts:223`):

```ts
createNoteSchema = { type: string, content: string, links?: NoteLink[] }
updateNoteSchema = { content: string }
```

### Client and iPhone — nothing consumes it

- The iPhone app has **no notes surface at all**: no `/api/notes` call, no `StudyNote` model in
  `iphone/MakeReady/State/`, no page under `iphone/MakeReady/Pages/`.
- The web client's notes usage is limited to lesson-embedded SOAP-style input, not a
  browse-and-write notebook.

So the server groundwork is real and the consumer side is greenfield. That is a good position:
the contract can be extended before either consumer is written.

---

## 2. The four things the Notes pattern demands that we don't have

### 2.1 Rich text — `content` is a plain `String` → **DECIDED: GFM markdown**

`StudyNote.content` is `@db.Text`. Every Notes formatting behavior (title style, bold, lists,
block quotes, highlight) needs a **structured document**, not a bare string.

**What Apple actually stores** (see [02-under-the-hood.md](02-under-the-hood.md) §2): a gzipped
protobuf in `ZICNOTEDATA.ZDATA`, holding one plain-text string plus a list of **attribute runs**
— each run a character length plus the styling that applies over it, exactly the
`NSAttributedString` shape. That is a *storage* format optimized for an editor that mutates ranges
in place; it is not a format anyone else should copy.

**Decision (2026-08-31): GitHub-Flavored Markdown, stored in the existing `content` column.**

The deciding argument is that markdown costs us **no migration and no new column** — existing
SOAP notes, list previews, `ILIKE` search, and analytics keep working on the same field, and
plain text is already valid markdown. It is also directly consumable by
`server/src/services/claude.ts` for any later AI feature, diffable, and greppable.

Coverage against the observed Notes feature set:

| Notes feature | GFM | Notes |
|---|---|---|
| Title / Heading / Subheading | `#` / `##` / `###` | ✅ |
| Body | bare paragraph | ✅ |
| Bold / Italic | `**` / `*` | ✅ |
| Strikethrough | `~~` | ✅ (GFM) |
| Monostyled | `` ` `` | ✅ |
| Bulleted / Dashed lists | `- ` | ✅ (dashed collapses to bulleted — acceptable) |
| Numbered list | `1. ` | ✅ |
| Checklist | `- [ ]` / `- [x]` | ✅ (GFM task lists) |
| Block quote | `> ` | ✅ |
| Link | `[text](url)` | ✅ |
| Nested list indent | leading spaces | ✅ |
| **Underline** | — | ❌ no syntax |
| **Highlight** | — | ❌ no standard syntax |
| Indent on a non-list paragraph | — | ❌ no syntax |

Three follow-on rulings:

1. **Two documented extensions, and only two:** `==highlight==` (the widely-used CommonMark
   extension, and the natural pair for the highlighting service shipped in `1647dc8`) and
   `<u>underline</u>` (inline HTML, which every markdown parser already tolerates). Both are
   opt-in on the render side; a parser that doesn't know them shows the literal characters, which
   is a survivable failure.
2. **Drop arbitrary paragraph indent.** It is the one Notes affordance markdown genuinely can't
   express, and it is worth almost nothing in a study-note context.
3. **Memo embeds are a link on its own line:** a paragraph whose entire content is
   `[🎙 Harbor Dr 2](makeready://memo/<uuid>)` renders as an inline audio player in our
   consumers, and degrades to a labelled, clickable link in any dumb renderer. This is the
   convergence point with [`memo`](../memo/README.md) — see §4.

**The one real risk, and the mitigation.** Markdown round-trips are lossy if you serialize on
every keystroke: a literal `**` a user typed becomes markup on the way back in, and cursor
position drifts across parse→serialize. The mitigation is architectural, not textual: **the
editor's live model is still an attributed string / run list.** Parse markdown → runs once on
open; serialize runs → markdown only on the debounced autosave. The document the user is editing
is never re-parsed underneath them, and outbound serialization escapes literal markup characters.

This is also the same content shape the activities spec needs for its WRITE activity
([`activities/08-open-questions.md`](../activities/08-open-questions.md) Q14) — one decision,
three consumers.

### 2.2 Autosave — there is no Save button, so there must be a debounce contract

Notes has no save button because it commits on an idle timer and on resign-first-responder. Our
`PATCH /api/notes/:noteId` is a full-content replace, which is compatible, but nothing today
defines:

- the debounce window (Notes feels like ~1–2 s idle),
- what happens on app background / connection loss (queue locally, flush on resume),
- conflict behavior when the same note is edited on iPhone and web.

Given `AppState` is already disk-cached for offline
([state-management spec](../state-management/)), the natural shape is: **optimistic local write →
debounced PATCH → last-writer-wins on `updatedAt`**, with an explicit note in the contract that
we are *not* doing field-level merge.

### 2.3 A note *list* — sections, previews, and derived titles

Nothing in the current API returns what §2 of the video needs:

- `title` derived from the first non-empty line, `preview` from the second,
- `modifiedAt`-bucketed sections (Today / Previous 7 Days / …),
- sort by `updatedAt` desc,
- a `linkLabel` standing in for Notes' folder line — for us the natural analogue of "folder" is
  **the `NoteLink` target** (this note belongs to *Romans, Lesson 3* / *Men's Group*).

`GET /api/notes` already filters by `type`, `linkType`, `linkRefId`, and date range, so this is
additive response shaping, not a new endpoint. Sectioning is computed **client-side** (as
Notes does) so the same payload serves both consumers.

### 2.4 The editor chrome is custom work on both platforms

None of the iOS 26 chrome comes free to us — we are not using UIKit bar systems.

| Surface | iPhone | Web |
|---|---|---|
| Editor text engine | `UITextView` wrapped in `UIViewRepresentable` — **not** SwiftUI `TextEditor` (no `inputAccessoryView`, no undo manager, no attributed runs) | `contenteditable` or a block editor; the selection callout must be built |
| Format strip | `inputAccessoryView` on the text view — appears with the keyboard for free | fixed strip positioned against the `visualViewport` keyboard inset |
| Popovers | our existing `present-overlay` / `managed-menu` chrome, anchored above the strip button | same twin pattern |
| Floating nav circles | matches our existing `circleBlur` action treatment (see [`parity-member-profile`](../../parity/)) | existing twin conventions |
| Writing Tools row | free on device; **do not build** | not available; do not attempt |

The iPhone side has house rules that apply directly here — new overlay surfaces go through
`/present-overlay`, push navigation through `/push-page`, and any transition code through
`/transition-review`.

---

## 3. Minimum viable feature set

Ordered by how much of the Notes feel each one buys per unit of work.

**Tier 1 — without these it isn't the pattern**

1. Zero-tap start: open a note, keyboard up, caret placed, strip docked.
2. Full-width page with no visible input container.
3. First line = title, styled live, and it is the note's name in the list.
4. No save button; autosave with the debounce contract from §2.2.
5. Keyboard-accessory format strip, horizontally scrollable, with stateful accent-circle toggles.
6. Bold / Italic / Underline / Strikethrough on selection, applied in place, no mode change.
7. Bulleted + Numbered lists, with **return-on-empty-item exits the list**.
8. A note list with derived titles/previews, date sections, and a floating search + compose bar.

**Tier 2 — worth it, but later**

9. Checklists (round checkbox items) — the highest-value Notes feature we'd be missing for group
   study prep.
10. Block quote — natural fit for pasted scripture.
11. Highlight — pairs with the highlighting service shipped in `1647dc8`.
12. Undo button bound to a real command stack.

**Tier 3 — explicitly out of scope**

Tables, drawing/markup, document scanning, note-to-note links, Monostyled/Heading tiers,
collaboration, folders-as-a-first-class-concept (we have `NoteLink` instead).

---

## 4. Open questions

| # | Question | Blocks |
|---|---|---|
| ~~N1~~ | ~~JSON block document vs. markdown for `content`~~ — **DECIDED 2026-08-31: GFM markdown in the existing `content` column, plus exactly two extensions (`==highlight==`, `<u>`), no new column, no migration. See §2.1.** | resolved |
| N2 | Is a note owned by `memberId` or `userId` here? Both columns exist; the iPhone app is leader/admin (Google auth → `userId`), members are phone-auth → `memberId`. Does the iPhone notes surface show *my* notes as a leader, or a member's? | RBAC + list endpoint |
| N3 | Is `NoteLink` the "folder" in the list UI, or do we add a real folder/notebook concept? | list UI + possibly schema |
| N4 | Standalone notes: today every note is created with a `type`; does a free-form note get `JOURNAL`, or do we add `NOTE`? | enum + create call |
| N5 | Autosave conflict policy — last-writer-wins on `updatedAt`, confirmed? | contract freeze |
| N6 | Does the web client get the notes surface in this pass, or is it iPhone-first with web following? (**Constrained 2026-08-31:** the UI must mimic the iPhone Notes app on *both* platforms — so whenever web lands, it lands as a `/compare` twin, not a re-design.) | app-impact scope |
| N7 | Search — server-side (`GET /api/notes?q=`) or client-side over the cached list? | endpoint |

---

## 5. Next step

This is analysis, not a spec. When these questions are settled, the work enters the normal
pipeline:

```
/build-spec-draft notes      → docs/features/notes/ numbered suite (01-architecture … 08-testing)
/build-spec notes            → audit → decisions → plan → build (server first, then consumers)
```

Note that the suite would want to be written **alongside** the memo suite
([`docs/features/memo/`](../memo/README.md)) — see that suite's §3, since a voice memo attached to
a note is the obvious convergence point and it changes the schema decision in N1.
