# Audit — local server-data collections (iPhone)

Every `@State private var <name>: [<Model>] = []` in `iphone/MakeReady/Pages` and
`iphone/MakeReady/Components`, as of 2026-08-01. **17 sites across 11 files in `Pages/`, plus 2 in
`Components/` = 19 total.**

Regenerate this list with:

```bash
grep -rnE "@State private var [a-zA-Z]+: \[[A-Z][a-zA-Z]*\] = \[\]" \
  --include="*.swift" iphone/MakeReady/Pages iphone/MakeReady/Components
```

## The classification test

For each site, in order:

1. **Is it server data at all?** Pure UI state (drag offsets, selection) is not — leave it.
2. **Can another screen read the same data?** If yes → must live in `AppState`.
3. **Can any screen mutate it?** If yes → must live in `AppState`, and the mutating Action must
   refresh it.
4. **Does a store for it already exist?** If yes and the page keeps its own array, it is a
   **Mode 2 forked copy** — read through instead.
5. Otherwise it is **legitimately screen-local**: an in-flight edit buffer, or a one-screen
   read-only view. Leave it and do not migrate speculatively.

## Dispositions

### Migrate — Mode 1 (homeless domain, no store exists)

| Site | Var | Why |
|---|---|---|
| `Pages/Main/MainLibrary.swift:109` | `allTags` | **This is sub-issue J.** Only copy of the program tag list in the app; mutated from `ProgramHomePage` via `syncTags`, which has nowhere to publish. |
| `Pages/Main/MainLibrary.swift` | `allMediaTags` | Same class as `allTags` for the Media tab — mutated by media editors, same missing invalidation edge. Latent J. |
| `Pages/Main/MainLibrary.swift` | `allLeaders` | Org-wide leader list, no store. |
| `Pages/Manage/Org/OrgHomePage.swift` | `groupLeaders` | **Second private copy of the same leader data** as `MainLibrary.allLeaders`. Two independent caches of one server list — they can already disagree. |

**Fix:** add `allProgramTags`, `allMediaTags`, `groupLeaders` to `AppState` mirroring
`textThemes` (`ThemeActions.swift:62-66`); `loadAllTags` / `loadAllMediaTags` /
`loadGroupLeaders` write them instead of returning; `addTags` / `removeTags` / `syncTags` refresh
the derived list on success.

### Migrate — Mode 2 (forked copy, store already exists)

| Site | Var | Existing store | Evidence of fork |
|---|---|---|---|
| `Pages/Manage/Group/GroupHomePage.swift:942` | `posts` | `AppState.posts` | `posts = result.posts` |
| `Pages/Manage/Group/Member/GroupMembersPage.swift:48,399` | `members` | `AppState.members` | `_members = State(initialValue: cachedMembers)` then `members = loadedMembers` |
| `Pages/Manage/Group/Enrollment/EnrollmentsListPage.swift:66,282,380` | `enrollments` | `AppState.enrollments` | seeds from cache, then reassigns twice |
| `Pages/Manage/Member/MemberHomePage.swift` | `allMembers` | `AppState.members` | second copy of member data, org-scoped |

**Fix:** read through to the store (`state.postsFor(groupId:)`, `state.membersFor(...)`,
`state.enrollmentsFor(groupId:)`). The cache-seeding motive these forks serve is already provided
by AppState's cache-first loading contract.

### Assess before migrating (needs a judgment call)

| Site | Var | Question |
|---|---|---|
| `Pages/Manage/Group/Member/GroupMembersPage.swift` | `joinRequests` | Also read by `MemberHomePage.allJoinRequests` → two screens, no store. Probably Mode 1, but confirm both render the same server list before adding a store. |
| `Pages/Manage/Member/MemberHomePage.swift` | `allJoinRequests` | Pair of the above. |
| `Pages/Main/MainHome.swift` | `activityLogs` | Read-only dashboard feed. Migrate only if a second screen shows it or something mutates it; otherwise leave. |
| `Pages/Manage/Program/ProgramHomePage.swift` | `orderedLessons` | Derived ordering over `AppState.lessons`. If it is a *view* of the store, it is fine as a computed property — but as `@State` it can go stale. Prefer converting to `var orderedLessons: [Lesson] { … }` over adding a store. |

### Leave alone — legitimately screen-local

| Site | Var | Why |
|---|---|---|
| `Pages/Manage/Program/ProgramHomePage.swift` | `editTags`, `originalEditTags` | **In-flight edit buffer** + its original for dirty-checking. Textbook correct `@State`. Migrating these would be a mistake. |
| `Pages/Manage/Program/CreateProgramPage.swift` | `tags` | Form buffer for a program that does not exist yet. |
| `Pages/Manage/Program/EditReadActivityPage.swift` | `orderedBlocks` | Editor working set for one activity, reordered locally before save. |
| `Pages/Manage/Program/EditExegesisActivityPage.swift` | `exegesisHighlights` | Editor working set for one activity. Note it *does* have a known sync defect (ticket 12668501065 sub-issue B) — but that is a note-keying bug, not a state-location bug. **Do not conflate them.** |
| `Components/Input/TagInput.swift` | `suggestions` | Transient autocomplete list. Should be *fed from* `AppState.allProgramTags` after Phase B, but the component holding a filtered suggestion list is correct. |
| `Components/Layout/Dragula.swift` | `draggedItems` | Pure UI drag state. Not server data. |

## Summary

| Disposition | Count |
|---|---|
| Migrate — Mode 1 | 4 |
| Migrate — Mode 2 | 4 |
| Assess first | 4 |
| Leave alone | 7 |
| **Total** | **19** |

**Eight sites have a demonstrated problem. Seven are correct as written.** The headline is that
this is a contained, well-understood migration — not a rewrite. Anyone proposing to migrate all 19
has skipped the test.
