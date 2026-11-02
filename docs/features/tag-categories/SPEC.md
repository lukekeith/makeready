# tag-categories — spec
> lg · ticket none

## Idea

**Why.** Leaders filter the Media library by tag, and many tags are books of the Bible ("genesis",
"1 kings", "psalms": about 40 of the 76 distinct media tags in dev). Today every tag is one flat A→Z
list, so the books land scattered among the other words ("1 kings" before "acts", "revelation" among the
R's). Books should read as books: grouped together, in the order of the Bible. The Tags filter is also
redesigned to the owner's Figma frame: a wrapping flow of tag chips under small section headers.

**What success looks like.** On iPhone Media, tapping **Tags** opens the new overlay. When any shown tag
is a Bible book, a **BOOKS OF THE BIBLE** section lists those books in canonical order (Genesis → Revelation),
then **CONTENT** lists every other tag A→Z. When no shown tag has a category, there are no headers, just
one A→Z flow. Picking "Psalms" finds photos tagged "psalm" as well as "psalms". Every other filter
(Source, Leaders, Time, and the other pages' filters) looks and works as today.

**In your words.**
- "I want books of the Bible tags to be treated differently than normal tags and appear in the order of the books instead of alphabetically like other tags." → D1, D4
- "I prefer stored tag categories, but categories are not required, if it has no category, then it's uncategorized" → D1, D2
- "if there are no tags with a category, then there's no reason to even show the category headers on the filter overlay" → D7
- "update the filter overlay for tags to be like this" (Figma 4770:11375) → D6

**The concept.** MakeReady defines tag categories and ships them as data; the first is Books of the Bible.
A category holds a closed list of spellings, each with its position in the category and its display label.
Spellings are matched on the tag's normalized text, so a tag is in a category the moment it exists, with no
filing step and no editor. The server serves the categories; the iPhone groups the Tags overlay with them.

```mermaid
flowchart LR
  T[(tag_categories<br/>tag_category_tags)] -->|GET /api/tags/categories| A[AppState.tagCategories]
  P[photos' tags] --> M[MediaHomeMapper.tagSections]
  A --> M --> O[C-036 Tags overlay — sectioned chip flow]
```

**How it fits today.** Tags are free text with no tag record: `MediaTag {mediaId, tag}` and
`StudyProgramTag {studyProgramId, tag}`, stored lowercase and trimmed[^1]. Media's Tags options are the
distinct tags of the loaded photos, sorted A→Z[^2], shown in C-036 FilterMenuOverlay in draft mode
(Clear · Save · ✕)[^3]. The server knows canonical book order and names (`BOOK_MAP`, `Book.bookNumber`)[^4].

**Approaches considered.** Chosen: stored categories defined by MakeReady, membership by normalized
spelling. Rejected: working the category out from the text at read time (only covers categories
recognisable from text, and nothing is stored); assigning tags by hand on an admin screen (adds an
admin UI); categories managed by leaders per org (an editor, permissions and org scoping; the biggest build).

[^1]: server/prisma/schema.prisma:527, :937 · [^2]: iphone/MakeReady/UI2/Containers/Media/MediaHomeMapper.swift:69 · [^3]: iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift (`case .tags`) · [^4]: server/src/utils/bible-reference-parser.ts:24

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | Two tables, Books of the Bible seeded in the migration, `GET /api/tags/categories` | §server |
| client | ⬜ | The frozen parity Library keeps its alphabetical tag filters (D9); the server change only adds data, so nothing there changes or breaks | — |
| iphone | ✅ | `AppState.tagCategories` + load; Media's Tags options grouped, ordered and labelled; the new overlay form (built by d2m) wired | §iphone |

**Sequencing:** contract settled → server implements and verifies (contract FREEZES) → d2m builds the
C-036 tag chip-flow form from Figma 4770:11375 (requested by the iPhone phase, D6) → iPhone wires it →
the walk.

**Backward compatibility:** additive only: two new tables and one new endpoint. Released iPhone builds
never call the endpoint and keep today's alphabetical list; `GET /api/media/tags` and every tag write are
unchanged.

**Blast radius:** nothing existing reads the new tables. Tag text, tag writes, `GET /api/media/tags`,
`GET /api/programs/tags` and the web Library are untouched.

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
| D1 | Categories are stored | A category and its member spellings are rows in `tag_categories` / `tag_category_tags` (§Schema). Rejected: deriving membership from the text at read time, because it can't hold a category that isn't recognisable from text. | Luke 2026-11-01 |
| D2 | A category is optional | A tag whose normalized text matches no `tag_category_tags.tag` is uncategorized. Nothing is written for it. | Luke 2026-11-01 |
| D3 | MakeReady defines categories; membership is automatic | Categories and their spellings are shipped data (seeded in the migration, D11). No create/edit endpoint, no editor screen, no per-org categories. A tag is a member when `normalize(tag)` equals a member's `tag` (D10), whenever and wherever the tag was written. Rejected: assigning by hand on an admin screen (an extra admin UI); leaders managing categories per org (editor, permissions, scoping). | Luke 2026-11-01 |
| D4 | Books of the Bible is the first and only category at launch | `key: bible-books`, `name: Books of the Bible`, `position: 1`. Its members are the 66 books, each at `position` = its canonical book number (Genesis 1 … Revelation 66) and `label` = its name as written in `BOOK_MAP` ("1 Samuel", "Song of Solomon"), plus the spelling variants in §server. The table allows more categories later. | (assumed at brainstorm) |
| D5 | Photos and programs share the categories | Membership is by tag text, so one category list serves `MediaTag` and `StudyProgramTag` alike. Only the iPhone Media Tags overlay reads it now. Rejected: photos only, which would leave a later program tag filter to redo the work. | Luke 2026-11-01 |
| D6 | The Tags overlay follows Figma 4770:11375, and only Tags | Media's Tags chip opens a sectioned chip-flow form of C-036: Clear (top left) · Save (accent, top right) · section headers in small uppercase · tags as a wrapping flow of chips, unselected as plain text and selected as a white pill · the C-082 close disc at bottom centre. d2m builds it from the frame (builder never writes the design). Source, Leaders, Time and every other page's C-036 menus keep the list form. Rejected: restyling every filter overlay (a large restyle, and long names wrap as chips). | Luke 2026-11-01 |
| D7 | Headers only when a category is present | When at least one shown tag is in a category, the overlay shows each such category's header (its `name` in uppercase) over its tags, then a **CONTENT** header over the uncategorized ones (omitted when there are none). When no shown tag is in a category, there are no headers at all: one flow of every tag. A tag that is a category member never also appears under CONTENT. | Luke 2026-11-01 |
| D8 | Order | Category sections in `tag_categories.position` order, CONTENT last. Inside a category: member `position` ascending (book order). Inside CONTENT: display label A→Z, case-insensitive. | (assumed at brainstorm) |
| D9 | Web unchanged | `client` Library tag filters (`library-view.vue`) stay alphabetical; no client change. Rejected: ordering web tags too (the frozen parity screens). | Luke 2026-11-01 |
| D10 | Spelling match = normalized text | `normalize(s)` = lowercase, trim, remove all whitespace ("1 Samuel" → "1samuel"). `tag_category_tags.tag` stores the normalized form. The iPhone compares `normalize(photoTag)` to it. | (assumed at spec) 2026-11-01 |
| D11 | Seed lives in the migration | The category row and its member rows are INSERTs appended to the generated Atlas migration, before commit, so every environment gets them on deploy (seeds run by hand, `npm run db:seed`, aren't run on deploy). Rejected: a versioned seed under `server/seeds/`, which prod would miss. | (assumed at spec) 2026-11-01 |
| D12 | One chip per book | Every spelling of a book forms ONE option: id `cat:<categoryKey>:<position>` (e.g. `cat:bible-books:19`), label the member `label`. Picking it matches photos with any tag whose normalized text is one of that book's spellings. Uncategorized options keep the tag text as id. Rejected: one chip per spelling, because two chips would both read "Psalms". | Luke 2026-11-01 |
| D13 | Display labels | Book options show the member `label` ("1 Samuel"). Uncategorized options show the tag in Title Case: the lowercased tag text (tags are stored lowercase, and the mapper lowercases them) with the first letter of each space-separated word uppercased ("dogs" → "Dogs", "new life" → "New Life"). Stored tag text never changes. The Tags chip's own label (C-035 "first +n") uses these labels. Rejected: showing the stored lowercase text, because the Figma shows proper names. | Luke 2026-11-01 |
| D14 | Categories are cached in AppState | `AppState.tagCategories` (plain `@Observable` reference data, cleared in `clearInMemory()`), loaded by `MediaActions.loadTagCategories()` when Media's container loads its sources. A failed load is console-only, and the overlay falls back to D7's no-header flow. | (assumed at spec) 2026-11-01 |
| D16 | Option ids | An uncategorized option's id is its lowercased tag text (as today). A `cat:<key>:<position>` id is synthetic only when it resolves to a loaded category member; anything else is treated as tag text, so a tag literally typed `cat:…` still works. Selected ids with no current option are skipped when building the chip label and still filter. | (assumed at spec, audit) 2026-11-01 |
| D15 | The endpoint is global and read-only | `GET /api/tags/categories` needs a session (`requireAuth`) and no org permission: the data is MakeReady's, the same for everyone. | (assumed at spec) 2026-11-01 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `GET /api/tags/categories` | server | iphone | session (`requireAuth`) | — | `200 { success: true, categories: [{ key: string, name: string, position: number, tags: [{ tag: string, label: string, position: number }] }] }`: categories by `position`, each `tags` by `position` then `tag`; `tag` normalized (D10); several `tags` may share a `position` + `label` (the spellings of one book) | `401` no session · `500 { success:false, error }` |

## Schema & API changes

| # | ADD/EDIT/RENAME/REMOVE | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| S1 | ADD | `TagCategory` (`tag_categories`): `id` uuid PK · `key` String UNIQUE · `name` String · `position` Int · `createdAt` | `categories[].key/name/position` | D1, D4 · T1 | planned |
| S2 | ADD | `TagCategoryTag` (`tag_category_tags`): `id` uuid PK · `categoryId` → TagCategory (cascade) · `tag` String UNIQUE (normalized) · `label` String · `position` Int · `createdAt`; index `(categoryId, position)` | `categories[].tags[]` | D1, D10, D12 · T1 | planned |
| S3 | ADD | `GET /api/tags/categories` | §Contract | D15 · T2 | planned |

**Data plan:** both tables are new and empty, so there's no backfill of existing rows. The migration
INSERTs one `tag_categories` row and the `tag_category_tags` rows in §server (D11). UNIQUE `tag` means a
spelling belongs to at most one category. Rollback: drop the two tables; nothing else references them.

## server

- **Schema:** S1/S2 in `server/schema/schema.yaml` (copy `MediaTag`'s block). `npm run schema:diff` reads `server/.env` (the 1Password pipe), so run its pieces by hand: `cd server && npm run schema:generate`, then `cd server/atlas && ../scripts/atlas.sh migrate diff --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`. Append the seed INSERTs (explicit `gen_random_uuid()` ids, `ON CONFLICT DO NOTHING`, as `20260411200000.sql`) to that new migration before it is committed (D11), then re-hash: `../scripts/atlas.sh migrate hash`. Then `docker exec makeready-server npx prisma generate`.
- **Seed (closed list):** one member per book: `tag` = the book name with whitespace removed, lowercase;
  `label` = the name; `position` = the book number, for all 66 names in `BOOK_MAP` (the full-name keys only,
  never abbreviations such as `gen`, `ex`, `ne`, `ss`, which would file ordinary words). Plus these
  variants, each with its book's label and position: `psalm` (19) · `songofsongs` (22) · `revelations` (66).
  A test asserts 66 distinct positions, 69 rows, and that no abbreviation key is present.
- **Service** `src/services/tag-categories.ts`: `listTagCategories()` returns the §Contract shape. The
  `normalize()` helper is exported for tests.
- **Route** `src/routes/tags.ts` (thin, copy `routes/makeready-media.ts`): `GET /categories` → the service, mounted `app.use('/api/tags', tagsRoutes)` in `src/index.ts` ahead of the bare `/api` routers; `@openapi` block. `normalize()` = `toLowerCase().replace(/\s+/g, '')`, the parser's own rule.
- `docker restart makeready-server` after edits.

## iphone

- **State:** `TagCategory` / `TagCategoryMember` Codable models; `AppState.tagCategories: [TagCategory]`,
  cleared in `clearInMemory()` (D14).
- **Action:** `MediaActions.loadTagCategories()` writes `AppState.tagCategories` and returns Void, non-throwing like `loadSources()` (cancellation ignored, unauthorized → sign-out path, else `recordError(surface: false)`).
  `MediaHomeContainer` calls it beside `loadSources()`; a failure goes through `recordError` with
  `surface: false`.
- **Mapper:** `MediaHomeMapper.Output.tagOptions: [String]` becomes `tagSections: [TagSection]`
  (`title: String?`, `options: [Option]`), built from the photos' tags and the categories per D7, D8,
  D10, D12 and D13. Tag filtering expands a `cat:` id to its book's spellings (D12).
- **Overlay:** the Tags menu presents the d2m-built chip-flow form (D6) with `tagSections`, still in draft
  mode as today (Clear applies the empty selection and closes · Save applies the draft · ✕ discards it). Requested from d2m with Figma 4770:11375
  plus the frame's two-state tag chip. 🆕 Approving this spec approves requesting that form (a C-036
  extension, or a new component if d2m's registry rules say so) and the tag chip. It doesn't exist yet.
- **Chip label:** `selectedTags` passed to the screen are the D13 display labels, in option order.

## Testing

**server (vitest, `makeready_test`):** the migration file's seed (parsed from the SQL, as `test/media-taken-at-migration.test.ts`; and listed in `atlas.sum`) has one category, 69 member rows, 66 distinct positions, no abbreviation key; the service orders categories and members by position (mocked Prisma); `normalize`
cases ("1 Samuel", "  PSALMS ", "song of songs"); route returns 401 without a session and the contract
shape with one; migration seed assertions (above). Scratch DB only, never `makeready_dev`.

**iphone (XCTest):** `MediaHomeMapper` tag sections: books and others → BOOKS OF THE BIBLE in book order
then CONTENT A→Z; only uncategorized → one untitled section; only books → one titled section, no
CONTENT; "psalm" + "psalms" → one Psalms option; filtering by `cat:bible-books:19` matches both
spellings; Title Case labels; categories empty (failed load) → untitled A→Z.

**Cross-app E2E walk (one):** server up with the migration applied → iPhone Media → Tags.

**Human verification (walk):**
1. Media → Tags: **BOOKS OF THE BIBLE** first, books in Bible order (Genesis before Exodus … 1 Samuel
   before 2 Samuel), then **CONTENT** A→Z with Title Case labels.
2. Pick Genesis and one content tag → Save → the grid shows only matching photos, and the chip reads
   "Genesis +1".
3. Reopen → both are white pills. Toggle one and tap ✕ → the earlier picks are unchanged. Reopen → Clear → the overlay closes and the grid is unfiltered.
4. Search or filter so that no book tag is among the photos → Tags shows no headers, one flow.
5. Leaders, Time and Source still open the list form.

## Out of scope

- A category editor, leader-made or per-org categories, and categories other than Books of the Bible.
- A program tag filter (D5 only prepares it).
- Web (`client`) changes (D9).
- Restyling C-036 for any filter other than Tags (D6).
- Renaming or merging stored tag text: spellings stay as entered.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | "john", "mark", "job", "acts" will always read as the book, even when someone meant a person or a word | Accepted at brainstorm (D3); only full book names and the three variants are members. |
| F2 | Spellings not in the closed list ("1kings" is in; "i kings", "psalmes" are not) stay under CONTENT | Accepted; adding a spelling is one INSERT in a later migration. |
| A1 | Alignment (2026-11-01), the fields Figma 4770:11375 shows → where each lives: chip text ← `TagCategoryTag.label` (books, S2) or the Title-Cased `MediaTag.tag` (D13, no storage) · section header ← `TagCategory.name` (S1) or the literal CONTENT (D7) · section/chip order ← `TagCategory.position` / `TagCategoryTag.position` (S1/S2), A→Z for CONTENT · selected/unselected ← the overlay's draft, then `MediaHomeMapper.Selection.tags`, container `@State`, not persisted (as today) · Clear/Save/✕ ← C-036 draft mode, unchanged. Verdicts: 3 ALIGNED (tag text, selection, draft actions), 4 MISSING → S1/S2/S3 (category name, member label, positions, the endpoint), 0 RENAME/RESHAPE. Released iPhone builds cache none of it. | Owed below as T1–T5. |
| T1 | server: `TagCategory` + `TagCategoryTag` in schema.yaml, generated migration + the seed INSERTs (S1, S2) | blocking |
| T2 | server: `tag-categories` service + `GET /api/tags/categories` route + tests (S3) | blocking |
| T3 | iphone: `TagCategory` models, `AppState.tagCategories` (+ `clearInMemory`), `MediaActions.loadTagCategories()`, the container's load call | trailing |
| T4 | iphone: `MediaHomeMapper` tag sections, labels and `cat:` expansion (D7, D8, D10, D12, D13) + tests | trailing |
| T5 | iphone: request the tag chip-flow form of C-036 + the tag chip from d2m (Figma 4770:11375), then wire Media's Tags menu to it. `MakeReadyUI` has no wrapping layout (the app target's `FlowLayout` isn't reachable from it), so d2m supplies one with the form | trailing |
| F3 | audit: contract parity — the one §Contract row is read only by the iPhone mapper via `AppState.tagCategories`; every field it returns is read (key/name/position for sections, tags[].tag/label/position for options). Additive for released builds. §Apps client ⬜ re-derived: `library-view.vue` keeps its own tag lists from `/api/media/tags` and `/api/programs/tags`, which are unchanged. READY | audit exit |
| F4 | the d2m-built form's states (sections, no-headers, selected pill) have never been rendered | build-time risk — settled by T5's d2m captures |

## Plan

The plan, with its code: `docs/features/tag-categories/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · Tag-category tables and the Books of the Bible seed
- Phase 1 · Task 2 · GET /api/tags/categories
- Phase 2 · Task 3 · Tag categories in AppState, loaded by MediaActions
- Phase 2 · Task 4 · Media's tag sections — order, labels, one chip per book
- Phase 3 · Task 5 · The Tags overlay becomes the sectioned chip flow
