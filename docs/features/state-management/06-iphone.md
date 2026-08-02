# 06 — iPhone

The only app in scope. The detailed content already lives in the sibling docs and is not duplicated
here — this doc is the pipeline's per-app index plus the state/Actions plan.

| Topic | Where |
|---|---|
| Per-site classification of all 19 local collections, with dispositions | [audit.md](audit.md) |
| The rule being enforced | [README.md](README.md) § The rule |
| Mode 1 / Mode 2 failure analysis | [README.md](README.md) § The two failure modes |
| SwiftLint rule, baseline procedure, review checklist | [enforcement.md](enforcement.md) |
| Why not a library instead | [library-evaluation.md](library-evaluation.md) |

## AppState changes (Phase B — Mode 1, homeless domains)

New collections, hosted the way `AppState.swift:339-358` already hosts non-entity server
collections (`homeHeatmapData` and friends) — plain `@Observable` properties, **not** `EntityStore`,
because they are reference lists without identity semantics:

**D1 DECIDED (2026-08-01): memory-only.** These are plain `@Observable` properties following
`homeHeatmapData` (`AppState.swift:339-358`) — **not** `EntityStore` (no identity semantics) and
**not** persisted. `PersistedState.swift` is now entirely **out of scope**, and G1's seven-site
wiring with it.

| Property | Source Action | Every call site today (G4 — all 7, verified 2026-08-01) |
|---|---|---|
| `allProgramTags` | `loadAllTags` (`ProgramActions.swift:466`) | `MainLibrary.swift:475` (first-load guard), `:1177-1178` (refresh path) |
| `groupLeaders` | `loadGroupLeaders` (`ProgramActions.swift:480`) | `MainLibrary.swift:482`, `:852`, `:1187-1188`, **and `OrgHomePage.swift:189`, which keeps its own separate copy** |
| `allMediaTags` | `loadAllMediaTags` (`MediaActions.swift:410`) | `MainLibrary.swift:845` |

**G4 — the surface is 7 call sites across 2 files, not the 1–2 the earlier draft implied.**
`MainLibrary` has **two distinct load paths**: an `if …isEmpty` first-load guard (`:475`, `:482`,
`:845`, `:852`) and a separate refresh path that writes the same variables again (`:1177-1188`).
Consolidating the `isEmpty` guard — which becomes a *global* condition once the property is shared,
not a per-screen one — is its own task, not a side effect. `OrgHomePage.swift:189` is a second
homeless copy of the leaders domain and must read through too; the earlier "no consumers outside
`MainLibrary`" note was true of the *variables*, not of the *domain*.

**Every new collection must be cleared in `AppState.clearInMemory()` (`AppState.swift:736-776`).**
That function clears `homeHeatmapData`, `homeWeeklyActivity`, `homeTotalMembers`, `homeTotalGroups`,
`organizationId`, `userOrganizations` — **but not `textThemes`** (G2). Tags and leaders are
org-scoped, so an uncleared collection leaves the previous user's data in the Library filter
dropdowns after sign-out. **D2 DECIDED (2026-08-01): `textThemes = []` is added to the same
function in this phase**, fixing the pre-existing leak next to the code that documents the rule.

## Paginated posts (Phase C — D3 DECIDED: design it now)

`GroupHomePage.swift:942-945` sets `posts = result.posts` alongside `nextCursor` and
`hasMorePosts` — a cursor-paginated list whose machinery assumes the page owns the array. A naive
read-through to `postsFor(groupId:)` returns the whole store re-sorted and orphans the pagination
(G3). **Chosen against the recommendation to defer; this enlarges Phase C.**

**The in-repo exemplar is the media library**, which already does exactly this — cursor held in
`AppState`, Action writes, page appends:

> **Corrected by the delta audit, 2026-08-01 (G5).** The first version of this design said
> `loadPosts` "stops returning and writes instead". **It already writes** — see the table. The
> remaining work is smaller than it first appeared.

**What `GroupActions.loadPosts` (`:318-344`) already does correctly:** upserts every post into
`state.posts` and **appends** to `groupPostIndex` via `add(parentId:childId:)` per post, then
`state.persist()`. Its own comment says `// Add to state (don't replace if paginating)`. The store
is therefore **already correctly populated on every page**. What it *also* does — return
`(posts, nextCursor)` for the page to fork — is the entire problem.

| Piece | Media exemplar | Posts — what actually changes |
|---|---|---|
| Cursor in state | `AppState.mediaLibraryNextCursor` (`:158`), cleared at `:754` | **add** `groupPostsNextCursor`, **keyed by `groupId`** (posts are per-group; the media library is a singleton). Clear it in `clearInMemory()` |
| Action writes the page | `MediaActions.swift:88-166` | **already done** (`:340-343`). Change: stop returning the tuple; write the cursor to state instead |
| Append, don't replace | upserts | **already correct** — the per-post `add` loop appends. ⚠️ Anyone rewriting that loop must use `add`/`addMany` (`RelationshipIndex.swift:69`), **never `replace`** — `replace` is what launch hydration uses (`AppState.swift:676`) and it would delete earlier pages |
| Read | — | `postsFor(groupId:)` (`AppState.swift:540-543`) already sorts `createdAt` descending, matching paginated order — no change |
| `hasMorePosts` | derived from cursor | derived: `groupPostsNextCursor[groupId] != nil` — the page stops owning the flag |

**Call sites:** `loadPosts` has **2 direct callers** (`GroupHomePage.swift:940`, `:965`) plus 4
wrapper calls to a local `loadPosts()` (`:219`, `:888`, `:929`, `:1222`) — **all inside
`GroupHomePage.swift`**, so the signature change is contained to one file.
**verified in code (2026-08-01)**

**Expected behavior after relaunch (G6 — do not "fix" this).** Launch hydration restores cached
posts (`AppState.swift:631`, `:676`) but **no cursor**. So after a relaunch the group renders cached
posts immediately (the intended cache-first behavior) while the cursor is nil, and the first
"load more" refetches page 1. That is **harmless because appends upsert** — the same reasoning the
media exemplar documents at `MediaActions.swift:93-95`. It will look like a redundant fetch in the
logs; it is not a defect.

## Actions changes (Phase B)

`ProgramActions.swift:402-495` currently contains **zero** `state.` writes — every function is a
pass-through API wrapper returning values for callers to cache. Each becomes a writer:

- `loadAllTags`, `loadGroupLeaders`, `loadAllMediaTags` → write `AppState`, return nothing
- `addTags`, `removeTags`, `syncTags` → after mutating, **refresh the derived list in the same
  call** (the invalidation edge the rule requires — this is what makes sub-issue J unable to recur)
- `getTags`, `suggestTags` → reviewed against the rule; a per-program lookup is not a shared
  collection and may legitimately stay a return

## Page changes (Phase C — Mode 2, forked copies)

Read through to the store instead of copying out of it. The read-through helpers all exist —
`postsFor`, `membersFor`, `enrollmentsFor`, `lessonsFor` (verified 2026-08-01):

| Page | Site | Store | Shape |
|---|---|---|---|
| `GroupMembersPage.swift` | `:48`, `:399` | `AppState.members` | **clean** — zero pagination; `membersFor` sorts by name |
| `EnrollmentsListPage.swift` | `:66`, `:282`, `:380` | `AppState.enrollments` | **clean** — zero pagination; `enrollmentsFor` sorts by start date |
| `MemberHomePage.swift` | `allMembers` | `AppState.members` | **clean** |
| `GroupHomePage.swift` | `:942-945` — `posts = result.posts` + `nextCursor` + `hasMorePosts` | `AppState.posts` | **paginated** — needs the cursor design above (D3) |

The cache-seeding motive these forks serve is already covered by AppState's own cache-first loading.
Only `GroupHomePage` carries pagination — `GroupMembersPage` and `EnrollmentsListPage` contain zero
`nextCursor`/`hasMore` references (**verified 2026-08-01**), so those three are straight
read-throughs and should land first within the phase.

## Not in scope on iPhone

- **No new views, components, overlays, or routes.** Nothing to scaffold with `/present-overlay`,
  `/push-page`, or `/nav-route`; no Motion-token or transition work, so `/transition-review` has no
  diff to review. **Component coverage: N/A.**
- Genuinely screen-local state stays local — an in-flight edit buffer (`ProgramHomePage.editTags`)
  or pure UI state (`Dragula.draggedItems`) is correct as `@State` and **must not be migrated**.
- The `APIClient` boundary is already clean: `grep -rl "APIClient.shared" iphone/MakeReady/Pages
  iphone/MakeReady/Components` returns zero files.

## Standing constraint for every phase

**Never run a build, `xcodebuild`, or any simulator command without asking first** — an absolute
rule in `iphone/.claude/CLAUDE.md`. Verify with SwiftLint and code review, and state plainly what
remains unverified. Phase B's live repro (and Phase C's) needs a simulator build: **ask.**
