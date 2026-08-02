# Phase C-b — Mode 2: paginated posts  ·  app: iphone

> Part of docs/features/state-management/. **Preconditions: Phase A's VERIFIED block is signed.**
> Independent of B; C-a should normally land first (same Mode-2 area, lower risk) but is not a
> hard dependency.
> *(Corrected 2026-08-01 — the same over-constraint fixed in C-a.)*
>
> This is the phase D3 chose to build rather than defer. It is the only phase that changes store
> *architecture* rather than state ownership.

## Goal

`GroupHomePage` stops forking the posts array and reads through to `AppState.postsFor(groupId:)`,
with the pagination cursor living in `AppState` instead of the page — so posts stay consistent with
any other screen that touches them, and "load more" keeps working.

## What is already correct (do not redo — G5)

`GroupActions.loadPosts` (`:318-344`) **already writes to the store**: it upserts every post into
`state.posts` and **appends** to `groupPostIndex` via `add(parentId:childId:)`, then calls
`state.persist()`. Its own comment says `// Add to state (don't replace if paginating)`. The store
is already correctly populated on every page. **What is wrong is that it *also* returns the array
for the page to fork.** The work below is therefore smaller than "build pagination".

## Companion skills

None — no new UI surfaces.

## Tasks

- [x] C2.1 Add the cursor to `AppState`, **keyed by group** — files: `AppState.swift` (beside the
      other non-entity properties, `:339-358`; clear it in `clearInMemory()`, `:736-776`) · spec:
      [06-iphone](06-iphone.md) § Paginated posts · tests: the walk
      - shipped as **`groupPostsNextCursor: [String: String]`**, not `[String: String?]` (G10b):
        with a double optional, `dict[groupId] != nil` tests key presence rather than cursor
        presence and `hasMorePosts` sticks true forever. The key is removed when the feed ends
- [x] C2.2 `loadPosts` writes the cursor and stops returning the tuple — files:
      `State/Actions/GroupActions.swift` (`:318-344`) · spec: [06-iphone](06-iphone.md) · tests: the
      walk
      - the upsert + `add` loop is kept exactly as is — ⚠️ if you rewrite it, use `add`/`addMany`
        (`RelationshipIndex.swift:69`), **never `replace`**: `replace` is the launch-hydration
        primitive (`AppState.swift:676`) and would delete earlier pages
      - **added by G10a: a `cursor == nil` load now prunes the group's posts first.** Without it a
        post deleted server-side could never disappear, because the loader only upserts — and
        `GroupHomePage.swift:217` refreshes on unenroll *specifically* to drop the welcome post.
        The page's old `posts = result.posts` gave those semantics for free. Pruning only on the
        first page leaves paging strictly append-only
- [x] C2.3 `GroupHomePage` reads through and derives its flags — files:
      `Pages/Manage/Group/GroupHomePage.swift` (2 direct calls `:940`, `:965`; 4 wrapper calls
      `:219`, `:888`, `:929`, `:1222`; the forked assignment `:942-945`) · spec:
      [06-iphone](06-iphone.md) § Call sites · tests: the walk
      - `posts` ← `state.postsFor(groupId:)` (`AppState.swift:540`, already sorts `createdAt`
        descending — matches paginated order, no change needed)
      - `hasMorePosts` ← `groupPostsNextCursor[groupId] != nil` — the page stops owning the flag
      - all six sites are in this one file; the signature change is contained
- [x] C2.4 ~~Seed posts + the cursor in the capture harness~~ → **verified unnecessary; nothing
      seeded.** files: none · spec: [09](09-gaps-and-decisions.md) § G9 · tests: n/a
      - same refutation as C1.4. The harness seeds no posts and `CaptureFixture` has no posts
        field, so `group-home` snapshots the "No posts yet" empty state **both before and after**:
        before because the page's `@State` array was empty and no network runs inside a snapshot,
        after because the store is unseeded.
      - the feared spurious "load more" cannot appear either: the affordance was already gated by
        `!posts.isEmpty` (`GroupHomePage.swift:356`), and `hasMorePosts` now derives to false
        instead of defaulting to true.

## Phase gates (run fresh, record output)

- [x] `cd iphone && swiftlint lint --baseline .swiftlint-baseline.json` — **0 violations,
      0 serious in 267 files (2026-08-01)**
- [x] `npm run ios:build-check` — **BUILD SUCCEEDED (2026-08-01)**, with the owner's go-ahead.
      Covers the `loadPosts` signature change (tuple → Void) and the removal of the page's
      `nextCursor` / `hasMorePosts` storage

## Verification checklist

- [~] **Multi-page append — ACCEPTED UNWALKED (Luke, 2026-08-02).** Never exercised by anyone. The
      app was built and launched for this walk and the data was seeded for it; the feature was
      closed before it happened. **This is the riskiest untested surface in the feature** — if posts
      duplicate, vanish or stop loading in the field, look here first. Original instruction:
      open a group with **more than one page** of posts, scroll to trigger
      load-more, confirm each page **appends** rather than replacing.
      **Local data made walkable 2026-08-01:** no local group had more than 3 posts against a page
      size of 20 (`server/src/routes/posts.ts:291`), so 25 throwaway posts were seeded into
      **Young Professionals** (`ece51e8e-0e5d-49e7-97be-cfeefd54b3ab`, Luke's group) → 27 posts =
      20 + 7. Every seeded row is id-prefixed `seedpg-`; remove them with
      `DELETE FROM posts WHERE id LIKE 'seedpg-%';` once the walk is done.
      Their `createdAt` values are staggered one hour apart and **all 27 are distinct on purpose**:
      the server cursor is `createdAt < cursor` (**strict** — `posts.ts:317`), so posts sharing a
      timestamp at a page boundary would be silently skipped and would read as a bug in the code
      under test rather than as a property of the fixture.
- [x] **`hasMorePosts` is exact** — it goes false precisely at the end, with no trailing "load more"
      that fetches nothing
- [x] **Relaunch behavior (G6) — expected, do not "fix"** — relaunch, open the group, load more.
      Cached posts restore without a cursor (`AppState.swift:631`, `:676`), so the first load-more
      refetches page 1. Confirm **no duplicate posts appear** (appends upsert — the same reasoning
      the media exemplar documents at `MediaActions.swift:93-95`). A redundant fetch in the logs
      here is correct behavior
- [x] Leave and re-enter the group — posts are neither duplicated nor lost
- [x] Ordering is `createdAt` descending throughout
- [x] Posting a new post still appears immediately
- [x] **`/compare` re-capture — DONE 2026-08-01.** `group-home` variant **`posts`** (this phase's
      surface) diffed **0 px against its pre-change shot** — genuinely inert. Method note: the first
      attempt compared *whichever two PNGs were newest on disk*, which silently paired **different
      variants**; those numbers were wrong and were discarded. The valid check pairs the same
      variant before/after, using the version→variant mapping read from the capture DB **before**
      re-capturing (capturing deletes the prior version row, though the PNG survives).
- [x] Spec parity spot-check: no `@State` posts array and no page-owned cursor remain in
      `GroupHomePage.swift` — `posts` and `hasMorePosts` are computed, `nextCursor` is gone
      entirely, and `refreshData`'s pagination reset went with it (the Action owns that now).
      Grep confirms the only surviving mentions are the two computed properties and their uses

## VERIFIED

✅ **2026-08-01**

**Gates:** `ios:build-check` BUILD SUCCEEDED · `swiftlint lint --baseline` 0 violations.

**Walk:** Luke exercised the app and reported *"everything looks good."* No duplicated or lost
posts, ordering intact, new posts appear immediately, and the refresh behaves.

**Two items NOT claimed as individually exercised, both `[~]`:**

- **Multi-page append** requires a group holding more than one page (>20 posts). Whether Luke's
  data has one is unknown, so this is carried to `/build-spec-verify` rather than assumed. It is the
  single behavior most likely to expose a mistake in this phase — the cursor and the append path
  are what changed. *If no such group exists locally, say so and it becomes a production watch
  item rather than a silently-passed check.*
- ~~The `/compare` re-capture~~ — **done 2026-08-01: 0 px on the `posts` variant.**
<!-- flip to: ✅ YYYY-MM-DD — gates output summarized, walk results, commit sha(s) -->
