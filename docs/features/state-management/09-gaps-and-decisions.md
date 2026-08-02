# 09 — Gaps & decisions

**Audit status: ✅ clean** — 2 passes plus a delta round closed by inspection (see the pass log
below). Two later findings, `G7` and `G8`, were surfaced by the **Phase B build**, not by an audit
pass; both are resolved and neither opened new unaudited spec material.

The 2026-08-01 "sanity check" recorded in [STATUS.md](STATUS.md) is audit-shaped and found a real
spec error, but it is **not** a `/build-spec-audit` pass: it produced no G/D/O/C/X ledger, and it
never checked the client or capture out-of-scope claims. Its findings are seeded below so the first
real pass appends rather than rediscovers.

## Integrity check — 2026-08-01

**Verdict: DEFECTS (2)** — both corrected in place; neither changes scope or cost.

| # | Check | Result |
|---|---|---|
| 1 | Suite completeness | ✅ README + 01–09 present; 04/05/07 carry explicit "Not affected" |
| 2 | Citations (13 checked, opened line by line) | ✅ **every one exact** — `MainLibrary.swift:109` `@State private var allTags`, `:112` `allLeaders`; `ProgramActions.swift:402-495` all 7 tag/leader funcs with **zero** `state.` writes; `ThemeActions.swift:62-66` writes `state.textThemes` + `persist()`; `AppState.swift:142`, `:663`, `:339-358`; `PersistedState.swift:58/123/210/246/291`; `MediaActions.swift:410`; `GroupMembershipModels.swift:89`; `GroupHomePage.swift:942`; `GroupMembersPage.swift:48,399`; `EnrollmentsListPage.swift:66,282,380` |
| 3 | Counts re-run | ⚠️ **defect 1** — see below. `.swiftlint-baseline.json` = **exactly 1,118 entries** ✅ |
| 4 | Commands | ⚠️ **defect 2** — see below. `client/vendor/bin/phpunit` ✅, `swiftlint` installed ✅, `npm run ios:build-check` ✅, `capture/runners/compare/diff.mjs` ✅ |
| 5 | Internal consistency | ✅ all intra-suite links resolve; `02`'s scope table agrees with every other doc; no placeholders |
| 6 | Ledger ↔ artifacts ↔ code | ✅ "nothing built" **re-verified in code**: no state rule in `iphone/.claude/CLAUDE.md`, no `allTags`/`allLeaders` in `AppState.swift`, `custom_rules` holds only `no_print_or_nslog` |
| 7 | Unverifiable claims | ✅ zero `(claimed — unverified)` markers |

**Defect 1 — the web-conformance count was silently scoped.** "Zero of **31** components make API
calls" is exactly the `components/` subdirectory; the LeaderApp has **44** `.vue` files, so the
sweep excluded `views/` (6) and `overlay/` (6) — and `views/` is where the `admin/api` references
live. Re-swept across all 44: the conclusion **holds** (the three `views/` hits are comments; the
only real hits are an axios *config* import at `leader-app.vue:7,54` setting `X-CSRF-TOKEN`, and
`share-invite-sheet.vue:69`'s `fetch(dataUrl)` blob conversion). Also, `stores/` holds 14 *files* —
13 stores plus `activity-editor-actions.ts`, a factory seam. **Corrected in
[05-client.md](05-client.md)** with the full denominator and a dated correction note.

**Defect 2 — a gate command that would not have run.** `08-testing.md` specified
`swiftlint --config iphone/.swiftlint.yml` from the repo root; the config's `included:` paths are
relative, so it must run as `cd iphone && swiftlint` (the config file says so in its own header).
**Corrected in [08-testing.md](08-testing.md)** and in the pipeline's own gate list.

*Note:* the citation markers in [01-architecture.md](01-architecture.md) were originally stamped
`**verified in code (2026-08-01)**` on the strength of the pre-pipeline docs rather than a fresh
read. Check 2 above re-verified all of them independently, so the markers now stand on their own
evidence.

## Audit pass log

| Pass | Date | Findings | Verdict |
|---|---|---|---|
| — (pre-pipeline sanity check) | 2026-08-01 | 1 real error (G1), 6 prerequisites confirmed | not a pipeline pass |
| **1** | 2026-08-01 | **4 new: G2, G3, G4, X1** — plus 3 claims confirmed and cleared | findings — resolved at the decisions gate |
| **2 (delta)** | 2026-08-01 | **2 new: G5, G6** — triggered by *D3's pagination design + X1's capture scope*, the material the decisions themselves added | **findings, both corrected in place; no new decisions needed** |

### Pass 2 notes — delta (2026-08-01)

Scope: only the material the decisions added (REFERENCE.md §3b — new material is audited in the
same session it is created). Both findings are in **the design written hours earlier**, which is
exactly the risk the delta pass exists for: a design arrives with the confidence of a decision just
made and no adversarial reading behind it.

- **G5** — the design described work that was already done. Reading `GroupActions.loadPosts`'s body
  (rather than the page that calls it) showed the Action already upserts and appends into the store;
  only the *returning* is wrong. Phase C's posts work shrank.
- **G6** — attacking the design's second call surfaced the relaunch case: cached posts restore
  without a cursor, so the first load-more refetches page 1. Harmless (appends upsert) but
  undocumented, and an implementer would have "fixed" it.

**Round 3 — closed by inspection, not skipped.** The invariant says a delta's own consequences are
delta-audited. G5's and G6's corrections *reduced* scope (the posts work shrank) and documented
behavior that already exists; every claim in them was verified in code as it was written — the
`loadPosts` body (`:318-344`), all 6 call sites, launch hydration (`AppState.swift:631`, `:676`),
and the media exemplar's upsert comment (`MediaActions.swift:93-95`). **No new unverified material
was introduced, so the loop terminates here** — which is the property §3b promised: each round is
strictly smaller.

**Capture scope (X1) re-checked:** no further findings. `CaptureEnvironment.swift:18-25` seeds via
`replaceAll`, which is the correct primitive for a fresh snapshot state (the append rule applies to
*pagination*, not to seeding), and `07-capture.md`'s scope matches the ViewRegistry cases verified
in pass 1.

### Pass 1 notes (2026-08-01)

Run directly rather than via parallel agents — the feature is single-app and small enough that
delegation would lose fidelity.

**Confirmed and cleared (do not re-derive):**

- **Server is genuinely unaffected.** Both endpoints return the **complete, org-scoped,
  unpaginated** collection the new `AppState` properties will claim to hold:
  `/api/programs/tags` (`server/src/routes/programs.ts:546`) groups by tag over active programs
  scoped `OR: [{ organizationId: userOrgId }, { creatorId: userId }]`, no `take`/`skip`;
  `/api/group-leaders` (`server/src/routes/programs.ts:593`) likewise. **[04-server.md](04-server.md)'s
  open audit question is answered: no server change.** **verified in code (2026-08-01)**
- **No in-app org switching exists.** `AppState.loadOrganization()` (`AppState.swift:828-842`) sets
  `userOrganizations = [org]` from `/api/organizations/my/organization` — a single org per session.
  So the new collections need **no org-switch invalidation**, only logout clearing (see G2).
- **Only one Mode 2 fork is paginated.** `GroupMembersPage` and `EnrollmentsListPage` contain zero
  `nextCursor`/`hasMore` references; only `GroupHomePage` does (see G3).

## G# — gaps

| # | Gap | Resolution |
|---|---|---|
| **G7** | **The invalidation edge was specced for program tags only — media tags need the identical one.** B.4 named `ProgramActions.addTags/removeTags/syncTags`. `MediaActions` has the **same trio** (`MediaActions.swift:252`, `:266`, `:281`, verified in code 2026-08-01) mutating the tags that `allMediaTags` is derived from. Shipping B.4 for programs alone would have left the Library **Media** tab reproducing sub-issue J on its own tab — the exact bug this feature exists to remove, one tab over. Found during the Phase B build | **RESOLVED in the build (2026-08-01)** — `MediaActions` gained `refreshAllMediaTags()` and the same `postTags`/`deleteTags` primitive split, so all three media mutators refresh once. Phase B task **B.8** added for it. Delta-audit note: the finding is symmetric to an already-audited design (B.4) and every claim was verified in code at write time, so it opens no new unexamined material |
| **G8** | **The analytics WIP that landed in `6f79f01` already violates the rule Phase A shipped.** `AppState.programAnalyticsById` (`AppState.swift:352`) is org-scoped server data and is **not cleared in `clearInMemory()`** — the same defect class as G2's `textThemes` leak, introduced the same day the rule was written. Found while editing the adjacent lines for B.2. **verified in code (2026-08-01)** | **RESOLVED (Luke, 2026-08-01)** — asked rather than assumed, because the property belongs to the in-flight analytics feature and REFERENCE.md §3 forbids editing outside a phase's named scope. Luke approved the one-line fix: `programAnalyticsById = [:]` now sits in `clearInMemory()` beside the three added by B.2. **This is the first real-world catch for Phase D's SwiftLint rule** — worth citing in [enforcement.md](enforcement.md) as evidence the rule earns its keep |
| **G9** | **Task C1.4's premise does not hold — no capture seeding is needed, and adding it would be new scope.** C1.4 said the read-through would leave "an empty screen where the fixture previously showed content", so members + enrollments must be seeded in `CaptureEnvironment.swift`. Checked against the harness and the fixtures (2026-08-01): **(a)** enrollments are **already** seeded, store + `groupEnrollmentIndex`, at `CaptureEnvironment.swift:79-96`; **(b)** `group-members-page.json` is an explicit **WEB-ONLY** comparison — its own note says `GroupMembersPage` is "unreachable by the iPhone harness", so no iPhone snapshot renders it; **(c)** the one registry case that touches members, `pages.group-members` (`ViewRegistry.swift:268`), renders `MemberHomePage`'s Members tab, and its own comment already records that org-member content "needs its own seeding (follow-up)" — it snapshots the resting state today and did so **before** this change. `state.members` is seeded nowhere, so the before and after renderings are both empty | **RESOLVED by not doing it (2026-08-01).** C1.4 is reframed from implementation to verification: confirmed no seeding gap was opened. Seeding members for `pages.group-members` remains the **pre-existing follow-up it already was** — real work, but it would *add* content to a fixture rather than restore it, which is new scope and a compare-baseline change. Recorded here so it is a decision rather than an omission |
| G1 | "Mirror `textThemes`" was specced as a 1-file change; it is **7 sites across 2 files** (`AppState.swift:142`, `:663`; `PersistedState.swift:58`, `:123`, `:210`, `:246`, `:291`). An implementer adding only the `AppState` property finds it does not survive relaunch | **Fixed in the spec (2026-08-01)** — documented in [README.md](README.md) § "Phase B is wider than one file", [06-iphone.md](06-iphone.md), and [03-data-and-api.md](03-data-and-api.md) |
| **G2** *(RESOLVED via D2)* | **The exemplar the spec says to mirror has a logout leak.** `AppState.clearInMemory()` (`AppState.swift:736-776`) clears `homeHeatmapData`, `homeWeeklyActivity`, `homeTotalMembers`, `homeTotalGroups`, `organizationId`, `userOrganizations` — but **does NOT clear `textThemes`**. Program tags and group leaders are **org-scoped data**; mirroring `textThemes` literally would leave the previous user's tag and leader lists populating the Library filter dropdowns after sign-out. **verified in code (2026-08-01)** | **RESOLVED (2026-08-01, via D1 + D2)** — memory-only (`homeHeatmapData` pattern) *and* `textThemes = []` added to `clearInMemory()`. Folded into [06-iphone.md](06-iphone.md) § AppState changes and [08-testing.md](08-testing.md) Phase B step 2 (the sign-out walk) |
| **G3** | **Phase C's read-through is not a drop-in for the one paginated fork.** `GroupHomePage.swift:942-945` sets `posts = result.posts` **alongside `nextCursor` and `hasMorePosts`** — a cursor-paginated list whose machinery assumes the page owns the array. `AppState.postsFor(groupId:)` (`AppState.swift:540-543`) returns **everything the store holds**, re-sorted `createdAt` descending. Swapping one for the other changes what renders and orphans the pagination state. **verified in code (2026-08-01)** | **RESOLVED (2026-08-01, via D3)** — designed, not deferred. Phase C splits: the three clean read-throughs first, then store-backed pagination for posts following the media-library exemplar. Design in [06-iphone.md](06-iphone.md) § Paginated posts; verification in [08-testing.md](08-testing.md) |
| **G5** | **The paginated-posts design (added by D3) misstates the current code — caught by the delta audit in the same session the design was written.** [06-iphone.md](06-iphone.md) said "`GroupActions.loadPosts` stops returning `(posts, nextCursor)` and writes instead". **It already writes.** `GroupActions.swift:340-344` upserts each post into `state.posts` **and appends to `groupPostIndex` via `add(parentId:childId:)`**, then calls `state.persist()` — and *also* returns the array, which the page forks. The design was written from the page's side without reading the Action body. **verified in code (2026-08-01)** | **RESOLVED (2026-08-01)** — [06-iphone.md](06-iphone.md) corrected. Three consequences: (1) the work is **smaller** than specced — the store is already correctly populated on every page, so Phase C only has to stop returning/forking, move the cursor into `AppState`, and read `postsFor`; (2) the "`addMany` vs `replace`" trap is **already handled** by the existing per-post `add` loop — a warning for anyone rewriting it, not an active defect; (3) `loadPosts` has **2 direct call sites** (`GroupHomePage.swift:940`, `:965`) plus 4 wrapper calls, all in one file — the signature change is contained |
| **G6** | **Launch hydration and the cursor disagree.** `AppState.swift:631` (`posts.replaceAll`) and `:676` (`groupPostIndex.replace`) restore cached posts at launch, but **no cursor is restored** — so after relaunch `postsFor(groupId:)` returns cached posts while `groupPostsNextCursor[groupId]` is nil, and "load more" refetches page 1. Per the media exemplar's own comment (`MediaActions.swift:93-95`) that is **harmless because appends upsert** — but the spec never said so, and an implementer seeing a duplicate-looking fetch would "fix" it wrongly. **verified in code (2026-08-01)** | **RESOLVED (2026-08-01)** — documented in [06-iphone.md](06-iphone.md) as expected behavior with the upsert rationale, plus a relaunch verification step in [08-testing.md](08-testing.md) |
| **G4** | **Phase B's surface is 7 call sites across 2 files, not the 1–2 the spec implies.** `MainLibrary.swift` calls the three Actions at **:475, :482, :845, :852, :1177, :1187** — two distinct paths (an `if …isEmpty` first-load guard *and* a separate refresh path writing `allTags`/`allLeaders` again at :1178/:1188) — plus `OrgHomePage.swift:189`, which keeps its **own** `groupLeaders` copy. The README's "no consumers outside `MainLibrary`" is true of the *variables* but not of the *domain*. **verified in code (2026-08-01)** | **RESOLVED (2026-08-01)** — [06-iphone.md](06-iphone.md)'s consumer table now enumerates all seven sites and calls out both the two-load-path problem and the `isEmpty` guard consolidation as their own tasks; `OrgHomePage` is named as a second read-through target |

## D# — decisions

| # | Decision | Options | State |
|---|---|---|---|
| **D1** | Do `allProgramTags` / `groupLeaders` (/ `allMediaTags`) **persist to disk**, or stay memory-only? | (a) Memory-only · (b) Persist, mirroring `textThemes` | **DECIDED (Luke, 2026-08-01): (a) memory-only.** Plain `@Observable` properties following `homeHeatmapData` (`AppState.swift:339-358`). **No `PersistedState.swift` change at all** — G1's 7-site wiring is now out of scope, and Phase B is a 1-file change plus its call sites |
| **D2** | `textThemes` itself leaks across logout (G2). Fix it here, or log it separately? | (a) Fix in Phase B · (b) Separate ticket | **DECIDED (Luke, 2026-08-01): (a) fix now.** `clearInMemory()` gains `textThemes = []` alongside the new collections |
| **D3** | `GroupHomePage.posts` is cursor-paginated (G3) — how does Phase C handle it? | (a) Defer · (b) Design store-backed pagination now | **DECIDED (Luke, 2026-08-01): (b) fix now** — chosen against the recommendation, deliberately. Design is in [06-iphone.md](06-iphone.md) § Paginated posts; it follows the **media-library exemplar**, which already does exactly this. **This materially enlarges Phase C** |

Settled decisions live in [01-architecture.md](01-architecture.md) § Decisions table, not here.

## O# — open non-technical items

| # | Item | State |
|---|---|---|
| O1 | **The analytics WIP overlaps this feature far more than first recorded.** The original row named only `AppState.swift`. Re-checked against `git status` at the start of the build (2026-08-01), the in-flight analytics work has **four of the files this feature must edit** dirty, spanning three of the four remaining phases — plus `AnalyticsModels.swift` still untracked, so the `AppState` hunk referencing `ProgramAnalytics` cannot compile in isolation. Full overlap table below | **RESOLVED (Luke, 2026-08-01)** — chose *commit the analytics WIP as one focused commit* over parking it or hunk-filtering. Landed as `6f79f01 feat(analytics): program analytics tab WIP + capture harness support` — 13 files incl. the previously-untracked `AnalyticsModels.swift`. All 19 remaining tasks are now on clean files; per-phase commits need no partial staging. See § below |
| O2 | Every live verification in [08-testing.md](08-testing.md) needs a simulator build, which requires the owner's explicit go-ahead each time | **ACKNOWLEDGED (2026-08-01) — a standing constraint, not a blocker.** Deliberately not left OPEN: it can never be "resolved", and an unclosable row would stall the decisions gate forever. Consequence: every phase sign-off states plainly what is static-only |

### O1 — the analytics-WIP overlap, measured (2026-08-01)

`git status` at build start. **✅ = safe to edit now · ❌ = collides with in-flight analytics work.**

| File this feature must edit | Needed by | State |
|---|---|---|
| `State/AppState.swift` | B.1, B.2, C2.1 | ❌ dirty (`programAnalyticsById` hunk) |
| `State/Actions/ProgramActions.swift` | B.3, B.4, B.7 | ❌ **dirty — never mentioned in the original O1** |
| `Pages/Manage/Member/MemberHomePage.swift` | C1.3 | ❌ **dirty** |
| `MakeReadyCaptureTests/CaptureEnvironment.swift` | C1.4, C2.4 | ❌ **dirty** |
| `MakeReadyCaptureTests/ViewRegistry.swift` | capture verification (B, C-a, C-b) | ❌ dirty |
| `Pages/…/GroupMembersPage.swift` | C1.1 | ✅ clean |
| `Pages/…/EnrollmentsListPage.swift` | C1.2 | ✅ clean |
| `Pages/Manage/Group/GroupHomePage.swift` | C2.2, C2.3 | ✅ clean |
| `.swiftlint.yml`, `.swiftlint-baseline.json` | D | ✅ clean |

Also dirty (analytics, not ours): `VerticalBarChart.swift`, `Kpi.swift`, `ProgramHomePage.swift`,
`CaptureFixture.swift`, `CaptureRunner.swift`, `project.pbxproj`, `Info.plist`.

**Only 2 of 20 tasks (C1.1, C1.2) are fully clear of the overlap.** Hunk-filtered commits — the
original plan — would mean partial-file staging across 4 files, in 3 separate phases, on files the
user is concurrently editing. That is where mis-staged, non-compiling commits come from.

### O1 — how it was resolved (2026-08-01)

Luke chose to **land the analytics WIP as one commit** rather than park it or hunk-filter. The
deciding evidence: `HeatmapBucket` / `HeatmapResponse` had been *moved out of* `MemberHomePage.swift`
into the untracked `AnalyticsModels.swift`, so the set only compiles together — hunk-filtering could
not have produced a compiling commit from it, and parking it would have interrupted active work.

Committed as `6f79f01` (13 files: `AnalyticsModels.swift` new, `AppState.programAnalyticsById`,
`ProgramActions.getProgramAnalytics`, the `ProgramHomePage` Analytics tab, `Kpi.expand`,
`VerticalBarChart.xAxisValues`, four capture-harness files, `project.pbxproj`, `Info.plist`
342→349). **Not compile-verified** — no build was run (O2 standing constraint). Deliberately
excluded: this feature's docs and Phase A's `iphone/.claude/CLAUDE.md` change.

**No delta audit triggered** (REFERENCE.md §3b): resolving O1 added no spec material — no new
design, no scope change, no changed approach. It was a working-tree logistics decision only.

Every ❌ in the table above is now ✅.

## C# — component-coverage holes

**None, and none possible** — the feature adds no view. See [06-iphone.md](06-iphone.md) § Not in
scope on iPhone.

## X# — cross-app contract risks

| # | Risk | State |
|---|---|---|
| **X1** *(DECIDED)* | **`capture` is claimed out of scope, and it is not.** `MakeReadyCaptureTests/ViewRegistry.swift` instantiates the exact pages Phases B and C modify — `MainLibrary` twice (`:227` Programs tab, `:254` Media tab), `GroupHomePage` (`:191`), the group Members/Enrolled tabs (`:201`), and `MemberHomePage` Members (`:266`) — and `CaptureEnvironment.swift:18-25` builds a **fresh `AppState`** and seeds stores through it (`state.templates.replaceAll([…])`). Phase C changes those pages from forked arrays to store read-throughs, so what the existing captures render stops depending on the page's own load and starts depending on **what `setupCaptureState` seeds — re-sorted by `postsFor`/`membersFor`**. Existing compare fixtures (`group-home.json`, `group-members-page.json`) can shift. **verified in code (2026-08-01)** | **RESOLVED (Luke, 2026-08-01) — accepted into scope.** `capture` is ✅ in [02-app-impact.md](02-app-impact.md); [07-capture.md](07-capture.md) rewritten from "Not affected" to real work (seed the stores + posts cursor in `CaptureEnvironment`, re-capture, diff). Phase B is expected capture-inert but is still diffed; **Phase C is the exposure** and owns the work |

**Cleared this pass:** the web claim ([05-client.md](05-client.md)) was re-swept across the full
44-file denominator during the integrity check and holds; the server claim
([04-server.md](04-server.md)) is confirmed above — both endpoints return complete, org-scoped,
unpaginated collections.
