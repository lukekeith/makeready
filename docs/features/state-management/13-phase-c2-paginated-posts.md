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

- [ ] C2.1 Add the cursor to `AppState`, **keyed by group** — files: `AppState.swift` (beside the
      other non-entity properties, `:339-358`; clear it in `clearInMemory()`, `:736-776`) · spec:
      [06-iphone](06-iphone.md) § Paginated posts · tests: the walk
      - `groupPostsNextCursor: [String: String?]` — posts are per-group, unlike the media library's
        singleton `mediaLibraryNextCursor` (`AppState.swift:158`, cleared `:754`)
- [ ] C2.2 `loadPosts` writes the cursor and stops returning the tuple — files:
      `State/Actions/GroupActions.swift` (`:318-344`) · spec: [06-iphone](06-iphone.md) · tests: the
      walk
      - keep the existing upsert + `add` loop **exactly as is** — ⚠️ if you rewrite it, use
        `add`/`addMany` (`RelationshipIndex.swift:69`), **never `replace`**: `replace` is the
        launch-hydration primitive (`AppState.swift:676`) and would delete earlier pages
- [ ] C2.3 `GroupHomePage` reads through and derives its flags — files:
      `Pages/Manage/Group/GroupHomePage.swift` (2 direct calls `:940`, `:965`; 4 wrapper calls
      `:219`, `:888`, `:929`, `:1222`; the forked assignment `:942-945`) · spec:
      [06-iphone](06-iphone.md) § Call sites · tests: the walk
      - `posts` ← `state.postsFor(groupId:)` (`AppState.swift:540`, already sorts `createdAt`
        descending — matches paginated order, no change needed)
      - `hasMorePosts` ← `groupPostsNextCursor[groupId] != nil` — the page stops owning the flag
      - all six sites are in this one file; the signature change is contained
- [ ] C2.4 Seed posts + the cursor in the capture harness — files:
      `iphone/MakeReadyCaptureTests/CaptureEnvironment.swift` · spec: [07-capture](07-capture.md) ·
      tests: the re-capture below
      - seed `posts` + `groupPostIndex` **and** the cursor, so `hasMorePosts` derives correctly and
        the captured group-home doesn't render a spurious "load more" affordance

## Phase gates (run fresh, record output)

- [ ] `cd iphone && swiftlint` — clean against baseline
- [ ] `npm run ios:build-check`

## Verification checklist

- [ ] **Multi-page append** — open a group with **more than one page** of posts, scroll to trigger
      load-more, confirm each page **appends** rather than replacing
- [ ] **`hasMorePosts` is exact** — it goes false precisely at the end, with no trailing "load more"
      that fetches nothing
- [ ] **Relaunch behavior (G6) — expected, do not "fix"** — relaunch, open the group, load more.
      Cached posts restore without a cursor (`AppState.swift:631`, `:676`), so the first load-more
      refetches page 1. Confirm **no duplicate posts appear** (appends upsert — the same reasoning
      the media exemplar documents at `MediaActions.swift:93-95`). A redundant fetch in the logs
      here is correct behavior
- [ ] Leave and re-enter the group — posts are neither duplicated nor lost
- [ ] Ordering is `createdAt` descending throughout
- [ ] Posting a new post still appears immediately
- [ ] **Re-capture and diff** `group-home` (`ViewRegistry.swift:191`) — any pixel delta explained
- [ ] Spec parity spot-check: no `@State` posts array and no page-owned cursor remain in
      `GroupHomePage.swift`

## VERIFIED

⬜ Not yet — do not open the next phase doc.
<!-- flip to: ✅ YYYY-MM-DD — gates output summarized, walk results, commit sha(s) -->
