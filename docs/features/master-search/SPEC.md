# master-search — spec
> lg · ticket none · prototype mode (`ui2: search-home`; Figma 4536:8480)

## Idea

**Why.** Leaders have no way to find something when they don't know where it lives. The 2.0 Search tab is a blank page, and the server's search only works for someone who owns an org, returns results grouped by type, and has no way to compare a program with a member. This feature makes the Search tab the place a leader finds anything across every org they belong to.

**What success looks like.** A leader taps Search, types "romans" and sees one list with the best match first, whatever its type. They narrow it with Type, Orgs, Groups, Leaders and Tags. With an empty field they see what they recently opened, and can remove any of it.

**In your words.** "it shows recent searches and can search all object types. The search needs to be good enough to rank results across all content types so we can determine relevancy." → D1, D2, D10

**The concept.**

```mermaid
flowchart LR
  A[SearchHomeContainer] -->|C1 ranked search| S[server search service]
  A -->|C2 list / C3 record / C4 delete| R[(search_recent_results)]
  A -->|C5 filter options| S
  S --> T[(9 content types, one scope, one score)]
  R --> T
```

**How it fits today.** `GET /api/search` resolves the org the caller owns and answers 400 for anyone else, runs one searcher per type and groups the answer; every searcher but LESSON is a case-insensitive word match in recency order, and none returns a score.[^1] No content table has a search index; `verses.searchVector` is the only one.[^2] pgvector and embeddings exist for Bible tables only.[^3] `SearchHistory` holds Bible query strings and its DELETE clears everything.[^4] Tags exist only on Media and StudyProgram; Video has no org, and a Media row points to it.[^5] On iPhone `.search` renders `EmptyPage`, and `AppState` has no search domain.[^6] The old search page and its result card are no longer compiled into the app, so there is nothing to remove.[^7]

**Approaches considered.** Chosen: keyword tiers behind one scoring function, in a new endpoint beside the existing one. Rejected: keywords plus embeddings (every type embedded on every save plus a backfill, loose matches can outrank intent, hard to explain); keywords plus typo tolerance (an extension and more indexes, weak matches). Both can be added later inside the scoring function without an app change.

[^1]: server/src/routes/search.ts:214, :253-258, :270-282, :651
[^2]: server/schema/schema.yaml:1482
[^3]: server/src/services/embeddings.ts:24, server/src/services/semantic-search.ts
[^4]: server/schema/schema.yaml:1921, server/src/routes/search.ts:995, :1394
[^5]: server/schema/schema.yaml:1016, :1147, :1296, :2253
[^6]: iphone/MakeReady/UI2/Shell/UI2Shell.swift:183, iphone/MakeReady/State/AppState.swift
[^7]: iphone/MakeReady.xcodeproj/project.pbxproj — GlobalSearchPage, CardSearchResult, EventDetailPage, LessonDetailPage, PostDetailPage have no Sources entry

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | Ranked search, recents table and endpoints, filter options, search indexes, screen fixture | §server |
| client | ⬜ | The web search view keeps calling `GET /api/search`, which does not change; search-home's platform is iphone | — |
| iphone | ✅ | Search tab root: container, mapper, `AppState` search domain, result-tap routing | §iphone |

**Sequencing:** contract settled → server implements and verifies (contract FREEZES) → iphone builds against the frozen contract → the cross-app walk.

**Backward compatibility:** released iPhone builds call `GET /api/search`, `/api/search/smart`, `/api/search/suggestions` and `GET /api/search/recent?type=bible`; none of them change. Everything here is additive: a new table, new indexes, new routes.

**Blast radius:** `GET /api/search`'s live consumer (`client/.../leader-search.store.ts`) is untouched; iPhone's `GlobalSearchEngine` still compiles but has no caller, and its removal is a follow-up because `UserActivity` lives in that file. New indexes add a small write cost on the content tables. Deleting a user cascades to their recents.

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
| D1 | Ranking | One scoring function ranks every type. Score = tier + rank, where tier is 4 exact title, 3 title starts with the query, 2 every query word found in the title, 1 match only in other searched fields, and rank is `ts_rank` normalized to 0–1 (`ts_rank(…, 32)`). The last query word matches as a prefix. Ties break on `createdAt` desc, then `id`. Rejected: embeddings (per-save embedding and backfill on every type, loose matches outrank intent); typo tolerance (extension and indexes, weak matches). | owner 2026-11-03 |
| D2 | Result shape | C1 returns one list across types, never grouped. Rejected: extending the grouped shape (no cross-type order). | design ref search-home 2026-11-03 |
| D3 | New endpoint | `GET /api/search` stays byte-for-byte as it is and C1 is new. Rejected: changing its shape (released iPhone builds and web decode it). | (assumed at brainstorm) 2026-11-03 |
| D4 | Visibility | A caller sees all content of every org from `getUserOrganizations`, whatever their role (Owner, Admin, Group Leader). Members match on name, email or phone. Rejected: Group Leaders limited to their groups (stricter than other screens, new scope rule); contact matching limited to Owners and Admins (extra rule, small gain). The audit found the stricter-than-other-screens premise false for members and private programs, so D30 and D33 reopen those two. | owner 2026-11-03 |
| D5 | Searchable types | Closed list: PROGRAM, TEMPLATE, MEMBER, GROUP, LESSON, EVENT, POST, VIDEO, PHOTO. The Type chip's Programs sends PROGRAM and TEMPLATE. Rejected: the Video table for VIDEO (no org or tags; D15 uses Media). | design ref search-home 2026-11-03 |
| D6 | Filters | Picks OR within a filter, filters AND together, and an object with no value for a set filter drops out. Filters apply identically to C1 and C2. Rejected: filters ignoring types without that dimension (the list would not really narrow). | design ref search-home 2026-11-03 |
| D7 | Inherited values | Org: PROGRAM, TEMPLATE, GROUP, PHOTO, VIDEO own column; EVENT, POST via group; LESSON via program; MEMBER via membership. Group: GROUP itself; EVENT, POST, PHOTO, VIDEO own column; MEMBER active memberships; PROGRAM via Enrollment; LESSON via its program's Enrollments. Leader (every column is a `User.id`): GROUP `creatorId`; PROGRAM `leaderId`; TEMPLATE `creatorId`; EVENT `createdById` (name corrected at align; the app wins); POST `authorId`; PHOTO, VIDEO `uploadedBy`; LESSON its program's leader; MEMBER none. Tags: PROGRAM, PHOTO, VIDEO own; LESSON its program's; others none. Rejected: own values only (a Group filter removes all programs and lessons, a Tag filter removes all lessons). | owner 2026-11-03 |
| D8 | MakeReady content | Results include the caller's orgs plus system templates (`isSystem`). MakeReady library Media is excluded. A set Orgs filter drops system templates. Rejected: orgs only (loses what search finds today); library included (stock images compete in the ranking). | owner 2026-11-03 |
| D9 | Tapping a type with no screen | LESSON opens its program, EVENT and POST open their group, VIDEO pushes the Media page. Every C1 and C2 item carries `parent` for this. PROGRAM opens study-program-home (TEMPLATE: D27 settles it, because that page cannot load a template id), MEMBER members-profile, GROUP groups-detail, PHOTO the ImageViewer. Rejected: no tap action (looks broken, can't become a recent); leaving the types out (drops lesson content). | owner 2026-11-03 |
| D10 | Recents | Recents are recently opened results, per user, one entry per resource, in a new table; re-opening moves an entry to the top. Rejected: extending `SearchHistory` (holds query strings). | design ref search-home 2026-11-03 |
| D11 | Recents read rules | C2 returns newest first and drops rows the caller can no longer see or whose resource is deleted or inactive. | design ref search-home 2026-11-03 |
| D12 | Recents retention | Keep a user's newest 100 entries: C3 deletes older ones in the same transaction. C2 returns at most 50. Rejected: unbounded (a table that only grows). | (assumed at spec) 2026-11-03 |
| D13 | Filter options | C5 is the one source for all five chips' options except Type, which is the closed list in D5. Rejected: changing `/api/group-leaders` and `/api/media/tags` (other screens read their one-org answer). | (assumed at brainstorm) 2026-11-03 |
| D14 | Tags | A tag is a lowercase string matched against `MediaTag.tag` and `StudyProgramTag.tag`. C5 merges both into one list, with `category` from `TagCategoryTag` where one exists. The Tags chip opens C-036's tag flow with one section per category and an untitled section for the rest. | design ref search-home 2026-11-03 |
| D15 | Video and photo source | VIDEO is `Media` with `type = 'video'`, PHOTO is `Media` with `type = 'photo'`, both `isActive` and `uploadStatus = 'ready'`, because a pending row has no usable image. No `GET /api/media` exists; the list route is `GET /api/organizations/:organizationId/media`, which applies `Media.visibility` only when asked, so D4's whole-org rule applies and `visibility` is not filtered. Rejected: the `Video` table (no org, group or tags). | (assumed at brainstorm) 2026-11-03; route, `uploadStatus` corrected at align |
| D16 | Searched fields | Title: GROUP, PROGRAM, TEMPLATE `name`; LESSON, EVENT, POST, PHOTO, VIDEO `title`; MEMBER first + last name. Other: GROUP description, code; PROGRAM, TEMPLATE description; LESSON `LessonActivity` title, `readContent`, `helpTitle`, `helpDescription`, and `ActivityReadBlock` title and content where `lessonActivityId` is set (scheduled copies are out); EVENT description, `locationName`; POST content; PHOTO, VIDEO none beyond `MediaTag.tag`; MEMBER email, `phoneNumber`. An exact email or phone match scores tier 4. Member names and contact fields use the `simple` text config; everything else, including GROUP, PROGRAM and TEMPLATE `name`, uses `english`, so "romans" still finds "Roman". | (assumed at spec) 2026-11-03; names corrected at align |
| D17 | Paging | C1 pages by an opaque cursor over (score, createdAt, id), built as D39 says. `limit` 1–50, default 20. | (assumed at spec) 2026-11-03 |
| D18 | Query length | `q` is trimmed, then C1 answers 400 below 2 characters; the screen never sends one. Above 200 characters, or containing NUL, is also a 400. | (assumed at spec) 2026-11-03 |
| D19 | Caller with no orgs | C1, C2 and C5 answer 200 with their normal shape. C1 can still return system templates. Rejected: today's 400 (the screen has no error UI). | (assumed at spec) 2026-11-03 |
| D20 | Screen rules | Query at 2 or more characters after 300 ms; next page near the list's end; prior results stay until the next response; a stale response is dropped; a failed request keeps the last rendered state with no error UI; query and picks live in screen `@State`, recents and results in `AppState`. D41 holds the rules for an unanswered query. | design ref search-home 2026-11-03 |
| D21 | Result rows | C-085 `trailing=none` for results, `trailing=remove` for recents. Kind map: PROGRAM, TEMPLATE → program; MEMBER → member; GROUP → group; LESSON → lesson; EVENT → event; POST → post; VIDEO → media; PHOTO → photo. Description is `Created <date>`. | design ref search-home 2026-11-03 |
| D22 | Recent removal | Tapping ✕ removes the row at once and restores it in place if C4 fails. | design ref search-home 2026-11-03 |
| D23 | Search indexes | One GIN index per searched table over its D16 text, plus a lower-case title index for tiers 3 and 4. Rejected: on-the-fly `to_tsvector` as LESSON does today (no index, slow as content grows). | (assumed at spec) 2026-11-03 |
| D24 | Recording failure | A failed C3 never blocks opening the item; it logs and moves on, and the next open records it. | (assumed at spec) 2026-11-03 |
| D25 | Screen fixture | `server/fixtures/screens/search-home.ts` `full` seeds every D5 type sharing a word, tags on both stores, and recents for the Fixtures identity. Rejected: no fixture (house rule, and the walk needs mixed types). | (assumed at spec) 2026-11-03 |
| D26 | iPhone wiring | `SearchHomeContainer` + `SearchHomeMapper` under `UI2/Containers/Search/`, `SearchActions` + an `AppState` search domain; recents and filter options survive leaving the tab in memory and refresh from C2 on open, with no disk cache of their own; results clear, because the tab unmounts and the query goes with it. Recents and results are ordered `[SearchItem]` arrays de-duplicated by type + id, because `EntityStore.all` is unordered and a ranked list has no key to re-sort by; all of it is cleared in `AppState.clearInMemory()`. Rejected: wiring inside the d2m screen (overwritten on rebuild, ui2-shell D2). | (assumed at spec) 2026-11-03 |
| D27 | Tapping a template | OPEN. The design's edge sends a template to study-program-home, but that page loads `GET /api/programs/:id`, which answers 404 for a `LessonTemplate` id, and no UI 2.0 surface shows templates. **Recommended:** a TEMPLATE row records its recent and pushes the Programs list, the same exit-to-the-nearest-page D9 gives VIDEO. Rejected: study-program-home (a failed page on every tap); leaving templates out (reverses D8); a new template page (no design for it; `/d2m:screen:update search-home` owns that edge if the owner wants it). | |
| D28 | Results with no stored title | OPEN. C-085 requires a title, while `Post.title`, `Lesson.title` and `Member.firstName`/`lastName` are nullable. **Recommended:** `title` is never null on C1 or C2: POST uses title, else the first line of content cut to 80 characters; LESSON uses title, else `Day <dayNumber>`; MEMBER uses first + last name trimmed, else email, else `phoneNumber`. Tiers 2–4 score stored title text only, so a fallback title scores tier 1 at most. Rejected: a nullable wire `title` (each consumer invents its own fallback). | |
| D29 | Repeated and generated events | OPEN. A recurring event stores one row per occurrence with the same title (`services/recurrence.ts`), and an enrollment writes `type = 'LESSON'` events titled `Day <n>: <program>` (`services/enrollment-edit.ts:533`). **Recommended:** the EVENT arm excludes `type = 'LESSON'` and returns one row per `recurrenceGroupId`, the earliest active row by (date, id). Rejected: every row (a 30-day enrollment puts 30 near-identical rows above the program); parent rows only (deleting the parent occurrence loses the whole series, `services/recurrence.ts:271-294`). | |
| D30 | Which members a leader finds | OPEN, and it reverses part of owner ruling D4. D4 lists every org member for every role, rejecting a Group Leader limit as stricter than other screens, but the Members screens already apply that limit: `memberAccessScope` (`services/member-access.ts:27`, ui2-members-browse D7) lets anyone but an Owner or Admin see only members of active groups they created, and `.memberDetail`'s `GET /api/members/:memberId` answers 404 otherwise. **Recommended:** the MEMBER arm applies `memberAccessScope` per org on C1, C2 and C3: Owners and Admins get every `MemberOrganization` row, group-less members included; anyone else gets active members of active groups they created. Rejected: D4 as written (a Group Leader can turn any phone number in the org into a name, then the tap fails with no error UI); widening `GET /api/members/:memberId` (contradicts ui2-members-browse D7). | |
| D33 | Private programs | OPEN, and it narrows D4. `privateProgramVisibility` (`services/study-program.service.ts:64`, ui2-programs D13) lists a private program only to its creator, its leader, its org's owner, Owners and Admins, and super admins. **Recommended:** PROGRAM and LESSON arms apply it on C1, C2 and C3. Rejected: D4 as written (search reveals what the Programs list hides from a Group Leader, reversing ui2-programs D13). | |
| D34 | Cover images in results | OPEN. A group or program cover is copied into `Media` as `<name> - Cover Image` with `source = 'auto_capture'` (`routes/programs.ts:3963`, `routes/groups.ts:1316`), so it scores tier 3 beside its own program. **Recommended:** D15 also excludes `source = 'auto_capture'`. Rejected: keeping them to match the Media page (each program then appears twice for its own name). | |
| D35 | Finding a member by phone | OPEN. Phones are stored E.164 only (`services/member-fields.ts:6`), and today's `GET /api/search` substring-matches them. **Recommended:** tier 4 compares `normalizePhone(q)` to `phoneNumber`, and a digits-only `q` of at least 4 digits also runs `LIKE '%digits%'` on in-scope member rows at tier 1; email compares with `lower()`. Rejected: exact only (a typed `555-0100` finds nothing, a regression). | |
| D36 | A failed recent removal | OPEN. D22 restores the row and design §3 says no error UI, but `/ios-error-surface` requires a user-initiated delete to surface, and the shell's banner already exists (`UI2Shell.swift:104`). **Recommended:** restore the row and surface `Couldn't remove that search` with a retry. Rejected: silent restore (a row returning unexplained reads as a bug; it would need a written `// Silent:` ruling against the skill). | |
| D37 | Who counts as a program's leader | OPEN, and it edits D7. `leaderId` is nullable, and the Programs filter matches `leaderId` or `creatorId` (`services/study-program.service.ts:117`). **Recommended:** the Leaders filter matches `leaderId` or `creatorId` for PROGRAM and LESSON; MEMBER stays without a leader, as D7 rules. Rejected: `leaderId` alone (null-leader programs vanish here while the Programs list shows them under the same pick). | |
| D38 | Scope edges | Scope is `getUserOrganizations` for every caller and any `UserRole`: no Super Admin bypass, and a caller's own org-less program is out. A set `orgIds` with no overlap answers an empty list on C1 and C2, never a wider one. Foreign or malformed ids in `orgIds`, `groupIds` or `leaderIds` never 400 and only narrow; a list above 50 ids is a 400. EVENT, POST, group-bound media and D7 memberships need an active group, and LESSON an active program. Members are one row across orgs, and ids are compared as text. A phone-only session gets 401; an API key acts as its owner. C5's orgs, groups and leaders sort by name, then id; leaders are active group creators plus Owner, Admin and Group Leader role holders (`routes/programs.ts:648`). Rejected: dropping a filter whose ids are all foreign (widens results and brings system templates back against D8). | audit 2026-11-03 |
| D39 | Query mechanics | Tokens are `[\p{L}\p{N}]+`, each quoted, joined with `&`, the last with `:*`, bound as one parameter to `to_tsquery`. No tokens skips the text predicates and tiers 3 and 4 still run, so punctuation answers 200. `%`, `_` and `\` are escaped in the prefix pattern. A row matches on lower-case title exact or prefix, or title tsquery, or other-text tsquery, or D35's contact rule. Filter joins are `EXISTS`, so a many-activity lesson or many-enrollment program is one row; LESSON's rank is `GREATEST` over its texts via `LATERAL`, as `routes/search.ts` does. The cursor holds raw float8 score, `"createdAt"::text` and id, all descending, because `timestamp` keeps microseconds and a JS `Date` doesn't; wire `score` may round, and wire dates stay `.SSSZ` ISO 8601. Rejected: `plainto_tsquery` and `websearch_to_tsquery` (no prefix). | audit 2026-11-03 |
| D40 | How the search indexes are managed | SC2 is a hand-managed Atlas migration (`atlas migrate new`, then hash), the repo's existing form for indexes the desired state can't express (`20260614223043.sql`), kept from `migrate diff` by `drop_index` skip in `atlas/atlas.hcl:33`, with a `schema.yaml` comment naming it on each table. Each arm's text is one TS constant equal to its index expression, proved by an `EXPLAIN` test; titles use `text_pattern_ops`; the member expression is `coalesce("firstName",'') \|\| ' ' \|\| coalesce("lastName",'')` plus contact fields. Rejected: teaching `yaml-to-hcl.ts`, `yaml-to-prisma.ts` and `validate-schema.ts` GIN and expression indexes (three generators and CI's `prisma db push` path for indexes nothing else reads, with Atlas's diff stability unproven). | audit 2026-11-03 |
| D41 | An unanswered query | `SearchHomeScreen` prints `No results` whenever its own query has 2+ characters and no rows (`SearchHomeScreen.swift:125,195`), so it lies during the debounce, the network wait and a failure. The screen gains `State.queryAnswered: Bool = true`, through `check_project_change` as `input-added-with-default`, or `request_project_change` if that answers handover. No-results needs `queryAnswered`; with no rows and no answer the screen keeps the last render. The container sets it only on a response for the current trimmed query, and a failure leaves it false. Below 2 trimmed characters, including the field's ✕, the container cancels the debounce, invalidates the in-flight request, clears results and refetches C2 if picks changed. Rejected: accepting the flash (contradicts design §3 states 5 and 6). | auto (recommended) 2026-11-03: bounded design fix |
| D42 | Keeping recents true | C3's Action moves the item to the top locally, and C2 refreshes when the root reappears; C1 waits for the next query. A pending-removal set filters C2 merges until C4 settles. `forgetGroup`, `forgetProgram` and `deleteMedia` drop matching rows. After every await a load checks its request token, `Task.isCancelled` and `initialLoad.isCurrent(generation)`, because a superseded GET still returns success through the coalescer and a late one could refill the next user's state. Rejected: relying on task cancellation (`APIClient.swift:149`, `:467`). | audit 2026-11-03 |
| D31 | Tag identity | A tag is compared by its `normalizeTag` form (lowercase, all whitespace removed; `services/tag-categories.ts`), because stored tags keep their spaces (`1 samuel`), `TagCategoryTag.tag` is normalized (`1samuel`), and one category member can have several spellings sharing a `position`. C5 returns one option per category member (its first spelling, its `label`, `category` = `TagCategory.name`) and one per remaining normalized tag (`label` title-cased, `category` null), in display order: categories by `position`, members by `position`, then the uncategorized by label. C1 and C2 expand a picked category member to all its spellings and match the normalized stored tag. Rejected: D14's plain string match (a pick misses every other spelling, unlike the Media page's `wantedSpellings`). | align, the app wins, 2026-11-03 |
| D32 | Response form | C1–C5 answer `{ success: true, … }` and errors `{ success: false, error }`, and C3 and C4 answer 200 `{ success: true }`, the form `/api/search` and the iPhone `APISuccessResponse` decoding already use. Rejected: bare objects and 204s (a new form for one feature; `api.delete` decodes a body). | align, the app wins, 2026-11-03 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| C1 `GET /api/search/ranked` | server | iphone | `requireAuth` | `q`, optional comma lists `types`, `orgIds`, `groupIds`, `leaderIds`, `tags`, `limit`, `cursor` | `{ success: true, items: [SearchItem], nextCursor: string \| null }` | 400 bad `q`, `types`, `limit` or `cursor`, or a filter list above 50; 401 |
| C2 `GET /api/search/recent-results` | server | iphone | `requireAuth` | optional `types`, `orgIds`, `groupIds`, `leaderIds`, `tags`, `limit` (default and max 50) | `{ success: true, items: [SearchItem & { openedAt: ISO8601 }] }`; `score` is `null` | 400 bad `types` or `limit`, or a filter list above 50; 401 |
| C3 `PUT /api/search/recent-results` | server | iphone | `requireAuth` | `{ type: SearchType, id: string }` | 200 `{ success: true }` | 400 bad body; 401; 404 not found, or not visible by the same per-type rules as C1 (a PHOTO id sent as VIDEO is a 404) |
| C4 `DELETE /api/search/recent-results/:type/:id` | server | iphone | `requireAuth` | path only | 200 `{ success: true }`, including when no entry exists | 400 bad type; 401 |
| C5 `GET /api/search/filter-options` | server | iphone | `requireAuth` | none | `{ success: true, organizations: [{ id, name }], groups: [{ id, name, organizationId }], leaders: [{ id, name }], tags: [{ tag, label, category: string \| null }] }`; `tags` in D31's display order | 401 |

`SearchType` is D5's closed list. `SearchItem` is:

```json
{ "type": "LESSON", "id": "…", "title": "Day 3: Grace", "createdAt": "2026-10-03T…Z",
  "score": 2.41, "imageUrl": null,
  "parent": { "type": "PROGRAM", "id": "…", "name": "Romans in 30 days" } }
```

`imageUrl` is `Media.url` for PHOTO and `null` for every other type. `parent` is set for LESSON (PROGRAM), EVENT and POST (GROUP), and `null` otherwise. `score` is a number on C1 and is comparable only within one response's query. `title` is never null (D28, once ruled). `id` is always the row's own table id: MEMBER is `Member.id`, which `.memberDetail` loads. Ids are serialized as text whatever the column's type.

## Schema & API changes

| # | ADD/EDIT/RENAME/REMOVE | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `SearchRecentResult` (`id`, `userId` FK cascade + `User` relation, `resourceType` string validated as `SearchType` like `SearchHistory.searchType`, `resourceId` text, `openedAt`; unique `userId, resourceType, resourceId`; index `userId, openedAt`) | C2, C3, C4 | D10: the design's record of an opened result (T1) | planned |
| SC2 | ADD | GIN and lower-case title indexes behind D16: `Group`, `StudyProgram`, `LessonTemplate`, `Lesson`, `LessonActivity`, `ActivityReadBlock`, `Event`, `Post`, `Member`, `Media`, plus a GIN on `MediaTag.tag` | C1 | D23: the design's one ranked list (T2) | planned |
| SC3 | ADD | Routes C1–C5 | C1–C5 | §Contract: the design's §5 API gaps (T3, T4, T5) | planned |

**Data plan:** both migrations are additive, with no backfill: recents start empty for everyone, and indexes build over existing rows. Undone by dropping the table and the indexes. `resourceId` has no FK because it spans tables, which is why D11 filters at read time. **Generate** with `npm run schema:generate`, then `cd atlas && ../scripts/atlas.sh migrate diff --env local --var database_url=…`: `npm run schema:diff` goes through `dotenv`, which reads the 1Password pipe, and a fleet worktree has no `server/.env`. **SC1's `userId` takes the type `users.id` actually has**: dev and prod ids are text and a migrations-only database has uuid, so the migration uses the `DO $$ … format_type` block of `20261102071026_invitations.sql`, and it is tested on a migrations-only database and on a restore of a dev dump. SC2 follows D40; plain `CREATE INDEX` locks writes while it runs (F15). **Ordering:** SC1 and SC2 are independent.

## server

- **`src/services/master-search.ts` (new)** owns scope, filters, scoring and hydration. `src/routes/search.ts` stays thin and adds C1–C5, with zod on the C3 body and all query parameters. The existing handlers are not edited.
- **Scope:** `getUserOrganizations` (`src/services/organization.ts:144`) gives the org list; requested `orgIds` intersect it, so an org outside it is ignored rather than refused. Org scoping lives in the service.
- **Query:** one raw SQL `UNION ALL` over the requested types, each arm applying D7's filters and computing D1's score, ordered and limited once. Member rows are one per member across orgs. Every arm casts ids to text (`"id"::text`) and compares them as text, because the column is text on dev and prod and uuid on a migrations-only database. Rows carry `isActive` except `Lesson`, which takes its program's.
- **C3 write:** visibility check, then raw `INSERT … ON CONFLICT DO UPDATE SET "openedAt" = now()` and a delete by `ORDER BY "openedAt" DESC, id DESC OFFSET 100`, in one transaction, so a double tap can't surface P2002.
- **Docs:** C1–C5 carry `@openapi` blocks, as `routes/search.ts` does.
- **C5 leaders:** the `/api/group-leaders` definition (group creators and role holders) across the caller's orgs, one row per user.
- **Fixture:** `server/fixtures/screens/search-home.ts`, whose `full` scenario adds rows of every D5 type sharing a word so one query returns mixed types, tags on both stores, and recents for the Fixtures identity; a test beside the others in `fixtures/__tests__/`.

## iphone

- **`UI2/Containers/Search/SearchHomeContainer.swift` (new)** renders the d2m `SearchHomeScreen`, debounces 300 ms (the screen doesn't), holds query and picks in `@State`, and presents `.filterMenuPresentation` and `.imageViewerPresentation` as `MediaHomeContainer.swift:167,179` do.
- **`SearchHomeMapper.swift` (new)** is pure: items to `State`, `chipLabel` via `FilterMenuOverlay.chipLabel`, D14's tag sections, D9's routing target per item. Unit-tested.
- **`State/Actions/SearchActions.swift` (new) + `AppState` search domain:** recents and results keyed by type + id, filter options; no `APIClient` from the container.
- **`UI2Shell.swift`:** `.search` renders `SearchHomeContainer()`; `page(for:)` and `UI2Destination` gain `.mediaHome` for D9's video exit and `.programsHome` for D27's recommended exit. Both reuse their section containers, which draw no back button when pushed (`MediaHomeContainer` draws `PageHeader` only in `.pick`), so each gains the pushed `PageHeader`.
- **Photo row:** `ImageViewer(url: imageUrl, sourceFrame: nil, …)`, the one-image init; it grows in place because a row has no tile frame.
- **Errors:** D20 and D24 are deliberate, per `/ios-error-surface`: `recordError(…, surface: false)`, no banner, because none is designed. Every call routes a 401 through `onUnauthorized`, and cancellation checks use `GroupActions.isCancellation`.
- **Root scroll:** the screen has no `ScrollView`, and off Home nothing supplies one. The container adds it with `.scrollDismissesKeyboard(.interactively)`, `.scrollBounceBehavior(.always, axes: .vertical)` and `HomeSectionLayout`'s status-bar strip, and no extra top padding (`.underScreenHeader` already gives safe area + 16). `.search` and `.calendar` split into their own cases, and `.calendar` stays `EmptyPage()`.
- **Pushed pages:** `.mediaHome` is a new `MediaHomeContainer.Mode.pushed` (header, viewer on, no upload, grid measured below the header). `.programsHome` is a small host: `PageHeader` + `ScrollView` + `.pullDownRefresh` + `.ui2PushedPageFill()`, because `StudyProgramsContainer` relies on the shell's scroll. Both keep the TabBar.
- **Row lookup:** index-to-item comes from the mapper's output in `body` (`GroupsHomeContainer`'s `atRow`), never a stored copy.
- **API:** C3 uses `api.request(endpoint:method:"PUT",body:responseType:)`, since there is no `api.put`. `q`, `cursor` and lists encode with `DashboardActions.queryValue`, because `urlQueryAllowed` keeps `+` and would break a phone or email match. `type` decodes as a string and the mapper drops unknown types, so a later type can't fail a page in a released build; `score` isn't decoded; `openedAt` is optional. New types avoid the names `SearchResult` and `RecentSearch`, already taken. C2 and C5 run in `.task` without `loadInitialData()`.
- **Member days:** `MemberActions.loadMemberDays` omits `organizationId` when the member isn't in the active org; otherwise a member from a second org opens with an empty rail (`MemberActions.swift:96`).
- **Project files:** new sources and tests need explicit `project.pbxproj` entries (no synchronized groups), then `ruby iphone/scripts/capture-targets.rb`, checked with `--check`. Tests live in `MakeReadyCaptureTests`.
- **d2m views are edited only through d2m's channel.** `iphone/MakeReadyUI/` belongs to d2m; D41's input goes through `check_project_change`, then `report_project_change`.

## Testing

**server (vitest, never `makeready_dev`):** every tier ordering in D1, across types; D6 and each D7 row, including drop-outs; D4 for an Owner, an Admin, a Group Leader and a caller outside the org; D8; cursor paging with no repeats or gaps; D11's three drop-outs; C3 upsert, D12's cap and its 404; C4 idempotence; D19; D28's fallbacks; D29's one row per series; D30's group-less member; D31 with two spellings of one category member; `uploadStatus` drop-out; every query on both id types (migrations-only and a text-id restore); each D38 rule; D30 for Owner, Admin and Group Leader; D33; D34; D35 with formatted and partial phones; D37 on a null `leaderId`; D39 with `'`, `:`, `&`, `!`, `%`, `_`, NUL, punctuation only, stop words (`the`, `gospel of j`), one row per many-activity lesson and many-enrollment program, and tied scores across pages; an `EXPLAIN` showing each arm uses its index; C3's 404 per type, a concurrent PUT; C4 on another user's entry; `createdAt` and `openedAt` as `.SSSZ`; `score` as a JSON number; a second `fixtures:reset`; a test proving `GET /api/search`'s response is unchanged.

**iphone (XCTest):** mapper kind map, labels, routing targets (TEMPLATE included) and tag sections in C5's order; decode C1–C5 with nulls; actions merge pages, drop stale responses through a coalescer-style barrier, restore a failed removal and surface it (D36), hold no-results until answered (D41), clear on ✕, move an opened item to the top, filter a C2 merge during a removal, ignore a response after sign-out, clear in `clearAllData`, send PUT with its body, encode `+ & =`, drop an unknown type, sign out on each 401, keep `.calendar` as `EmptyPage`.

**Cross-app walk (Fixtures identity, after `fixtures:`):**
1. Search tab with no filters: "Recent searches" lists the seeded items, newest first.
2. Type `grace`: one list with mixed type glyphs, no headings, an exact title first.
3. Set Type to Photos: only photos; tap one and the viewer opens (the image may be blank where the walk has no R2 images).
4. Clear it, set Tags: programs, lessons, photos and videos only.
5. Clear the picks and type `video study`: the seeded system template shows. Set Orgs: it is gone.
6. Tap a lesson: its program opens. Go back, clear the query: that lesson is at the top of recents.
7. Tap ✕ on a recent: it goes, and stays gone after relaunch.
8. Type nonsense: `No results for "<query>"`.
9. Filter recents to nothing: the section is hidden, title included.

## Out of scope

- Web search changes (owner 2026-11-03: iPhone screen).
- Finding by meaning, typo tolerance (owner 2026-11-03, D1).
- Dedicated video, event, lesson and post screens (owner 2026-11-03, D9).
- MakeReady library images in results (owner 2026-11-03, D8).
- Bible search and `SearchHistory`.
- Re-tapping the Search tab to scroll and focus: `shell-tabs` owns it (design §3).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | d2m's `SearchHomeScreen.swift` and `SearchResultRow.swift` are committed (a1237eba) and in the app target; their "PREVIEW ONLY" header comments are now stale. | Closed at align. The comments are d2m's to change, and nothing depends on them. |
| F2 | `docs/ui2/references/filter-rail.md` still says Search's chips are buttons (OQ-search-home-010). | Routed to d2m; builder doesn't write the design. |
| F3 | The schema YAML can't express D23's indexes: `yaml-to-hcl.ts` writes plain column indexes only. | Settled by D40. |
| F4 | Lesson text spans several tables, so a `UNION ALL` arm could be slow. | build-time risk — measure in the server phase against fixture data; store a search column on `lessons` if slow. |
| F5 | This branch is stacked on `feature/library-home`, which is not merged yet. | Merge Library first, or carry it with this branch. |
| F6 | The Media grid shows photos only (`MediaHomeMapper.output` filters `type == "photo"`), so D9's video exit opens a page that does not show the tapped video. | Owner's D9 stands, and the design calls the edge interim ("media detail when specced"). Named in the hand-off; a video page is out of scope. |
| F7 | `tags` is a comma list, as on `GET /api/programs`, and tags are free-form, so a tag containing a comma cannot be picked. | Accepted: same limit as the Programs filter. |
| T1 | server: `SearchRecentResult` model, `User` relation and migration with the id-type block (SC1) | blocking |
| T2 | server: hand-managed index migration per D40, `schema.yaml` comments, `EXPLAIN` test (SC2) | blocking |
| T3 | server: `master-search.ts` and C1 — scope, D7 filters, D1 score, D16 fields, D28–D31, D33–D35, D37–D39, text-cast ids, cursor, `@openapi` (SC3) | blocking |
| T4 | server: C2, C3, C4 — hydration through the same arms, D11 drop-outs, D12 cap (SC3) | blocking |
| T5 | server: C5 — orgs, groups, leaders across orgs, D31 tag options (SC3) | blocking |
| T6 | server: `fixtures/screens/search-home.ts` and its test, with shared word `Grace` (a base first name) and one exact-title row. New id kinds for post, template, program tag and recent. A non-system org template plus its wipe line and `wipe.test.ts` update, since a template survives reset otherwise. Unconditional `uploadStatus: 'ready'` photo and video rows, because `media-home`'s layer exits with images off. An untitled post, a recurring series, a generated lesson event. No new member, since `members.db.test` asserts 24: D30's group-less case is a vitest row | trailing |
| T7 | iphone: `AppState` search domain, `SearchActions`, C1–C5 models | trailing |
| T8 | iphone: `SearchHomeContainer` and `SearchHomeMapper` | trailing |
| T9 | iphone: `.search` root and scroll, `.mediaHome` and `.programsHome` per §iphone; `UI2Shell.swift:57`'s stale "none pushes yet" comment | trailing |
| T10 | iphone: D41's `queryAnswered` input through d2m's channel; `loadMemberDays` without a foreign org | trailing |
| F8 | No search-specific rate limit: the general 200/min per IP covers C1, and a 429 is silent per D20. A shared church IP could reach it. | Accepted. A per-user limiter on C1 wouldn't help, because the per-IP limiter runs first (`src/index.ts:153`). |
| F9 | `VERBOSE_LOGGING=true` writes `req.query`, so a searched phone or email reaches the logs (`middleware/request-logger.ts:154`). | Accepted: the flag is off by default and `GET /api/search` logs the same way. |
| F10 | `docs/ui2/README.md:80` and `screen-map.md:89` still say Search is not a tab; design §7 describes the older build; `updateNeeded` is true with nothing changed since spec. | Routed to d2m; builder doesn't write the design. |
| F11 | build-time risk: rows with `onAppear` sit in an eager `VStack` inside the screen's lazy stack, so every row may fire at once and page through everything (`SearchHomeScreen.swift:207-220`). | T8 logs `onResultAppear` with 40 rows; if it chains, rows move into the lazy stack through d2m's channel (T10). |
| F12 | build-time risk: `fetchPrograms` calls `replaceAll`, so a program opened by id but missing from the list could lose its store row while open (`ProgramActions.swift:95`). | T9 compares `GET /api/programs` scope with D38. Groups the same. |
| F13 | build-time risk: stop-word-only prefix queries may yield an empty tsquery, with a NOTICE. | T3's stop-word tests. |
| F14 | build-time risk: a prefix `LIKE $1` on a generic plan may skip `text_pattern_ops`; `concat` immutability in the member expression; how `simple` tokenizes `+1555…` and `a.b@c.org`. | T2's `EXPLAIN` after 6+ executions, else a range comparison. |
| F15 | build-time risk: plain `CREATE INDEX` blocks writes on `posts`, `lesson_activities` and others during deploy. | T2 weighs prod row counts and `-- atlas:txmode none` with `CONCURRENTLY`. |
| F16 | Design open questions: screen 0 open; C-085, C-034, C-035, C-020, C-036 0 open. OQ-C-131-001 (`initiallyFocused`), OQ-C-131-002 (enrollment pickers) and OQ-C-130-001 (chip overflow wording) are open, non-blocking. | Irrelevant here: search-home passes no `initiallyFocused`, isn't a picker, and the rail's geometry holds. |
| F17 | Render: `recents-populated` matches its frozen frame, by eye on d2m's latest render (the shell draws the TabBar, deviation 2). The other five states have no design snapshot. No pixel diff was run in this audit. | d2m's build recorded them; the walk sees them. |
| R1 | repoint (iphone): `case .calendar, .search: EmptyPage()` ← `iphone/MakeReady/UI2/Shell/UI2Shell.swift:183`, the only hit; no deep link or notification targets Search | builder:plan's repoint + retire phase |

## Prototype

Ref: `search-home` (d2m, era 2.0, namespace search, iphone). Six states: recents populated, recents empty, querying results, querying no results, loading, error. Ten screen questions closed. Built: C-131, C-034, C-130, C-035, C-020, C-085 (with `photo`), C-084, C-083, C-036. Frozen frame: `search-home`, sha `5746ec91…`. The d2m status line saying the build waits on OQ-C-085-005 is stale: C-085 has no open question.

**Seams:** the design persists one thing, per-user recents (D10). Query and picks don't survive leaving the screen.

**Alignment (2026-11-03).** Each row is traced from model through wire to the iPhone property. Consumer properties are all new except where named.

| Design field | Verdict | Producer → iPhone |
|---|---|---|
| `type` | ALIGNED | arm constant; `Media.type` → PHOTO, VIDEO → `kind` by D21 |
| `id` | ALIGNED | row id as text → `UI2Destination` ids |
| `title` | RESHAPE | nullable on Post, Lesson, Member → required C-085 `title` (D28) |
| `createdAt` → "Created <date>" | ALIGNED | present on all nine sources → `description` |
| `score` | MISSING | derived, D1 → list order only |
| `imageUrl` | ALIGNED | `Media.url` → `ImageViewer(url:)`, the field Media's `fullURL` reads |
| `parent` | ALIGNED | `StudyProgram.name`, `Group.name` → `.studyProgramHome`, `.groupDetail` |
| recent entry + `openedAt` | MISSING | SC1 → `AppState` search domain |
| Orgs filter | ALIGNED | D7 columns; nullable `StudyProgram.organizationId` falls out of scope |
| Groups filter | ALIGNED | D7 columns; `Enrollment` for PROGRAM and LESSON |
| Leaders filter | RENAME | `Event.createdById`, not `createdBy`; all targets are `User` |
| Tags filter | RESHAPE | normalized spellings (D31) |
| C5 organizations | ALIGNED | `getUserOrganizations` `id`, `name` |
| C5 groups | ALIGNED | `Group` `id`, `name`, `organizationId` |
| C5 leaders | ALIGNED | `User.id`, `User.name` (required), by the `/group-leaders` rule at `routes/programs.ts:638`, across orgs |
| C5 tags | RESHAPE | D31 order and category → `FilterMenuOverlay.Section` |
| Row exits | ALIGNED except TEMPLATE, MEMBER | program and group detail use `getManageableOrgIds`, a superset of D4's orgs; TEMPLATE MISSING (D27); MEMBER narrowed for non-admins (D30) |

Searched-field names corrected to the app: `phoneNumber`, `ActivityReadBlock`, `LessonTemplate`, `locationName` (D16, SC2). DESIGN-ONLY: none. Released builds cache nothing here, since every field is new and unread by them, so §Apps *Backward compatibility* stands.

## Replaced surfaces

| # | Surface (file:line) | REPLACES/ABSORBS/REUSES | Fingerprint | App |
|---|---|---|---|---|
| R1 | `iphone/MakeReady/UI2/Shell/UI2Shell.swift:183` | REPLACES | `case .calendar, .search: EmptyPage()` | iphone |
| R2 | `iphone/MakeReadyUI/FilterMenuOverlay.swift:91,117` | REUSES | list and tag-flow inits | iphone |
| R3 | `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift:167,179` | REUSES | filter menu and image viewer presentation | iphone |
| R4 | `server/src/services/organization.ts:144` | REUSES | `getUserOrganizations` | server |
| R5 | `server/src/routes/search.ts:214` | REUSES unchanged | `router.get('/', requireAuth` | server |

**S# gaps**

| # | Gap | Disposition | App |
|---|---|---|---|
| S1 | Design says it replaces live legacy pages; they are already out of the target | No work; recorded in §Idea | iphone |
| S2 | No destination for video, event, lesson, post | Written into SPEC: D9 | iphone |

**N# adds**

| # | Add | Disposition | App |
|---|---|---|---|
| N1 | C1 ranked search + scoring | SPEC: D1, D2 | server |
| N2 | `SearchRecentResult` + C2, C3, C4 | SPEC: D10–D12 | server |
| N3 | C5 filter options | SPEC: D13, D14 | server |
| N4 | Search indexes | SPEC: D23 | server |
| N5 | `search-home` fixture | SPEC: D25 | server |
| N6 | Container, mapper, actions, `AppState` domain | SPEC: D26 | iphone |
| N7 | `.mediaHome` destination | SPEC: D9 | iphone |
