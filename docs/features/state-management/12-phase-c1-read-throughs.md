# Phase C-a — Mode 2: the three clean read-throughs  ·  app: iphone

> Part of docs/features/state-management/. **Preconditions: Phase A's VERIFIED block is signed.
> This phase does NOT depend on Phase B** — it reads through to `AppState.posts` / `.members` /
> `.enrollments`, which already exist; it needs none of B's new collections.
> *(Corrected 2026-08-01: the first version of this doc required Phase B. That was a planning
> error — [README](README.md) § Delivery phases has always said C depends on A. The over-constraint
> mattered: it made B's blocked state block this phase too.)*
>
> Phase C was split at plan time because D3 chose to design paginated posts rather than defer them.
> **This doc is the half with no pagination in it** — three straight read-throughs. The posts work
> is [13-phase-c2](13-phase-c2-paginated-posts.md).

## Goal

`GroupMembersPage`, `EnrollmentsListPage`, and `MemberHomePage` stop forking private copies out of
`AppState` and read through to the store, so a change made on one screen is visible on the other
without a reload. No pagination is involved in any of them (**verified 2026-08-01**: zero
`nextCursor`/`hasMore` references in either file).

## Companion skills

None — no new UI surfaces.

## Tasks

- [x] C1.1 `GroupMembersPage` reads through — files:
      `Pages/Manage/Group/Member/GroupMembersPage.swift` (`:48` `_members = State(initialValue:
      cachedMembers)`, `:399` `members = loadedMembers`) · spec: [06-iphone](06-iphone.md) § Page
      changes · tests: the walk below
      - replace the fork with `state.membersFor(groupId:)` (`AppState.swift:546`, sorts by name)
      - the cache-seeding motive is already served by AppState's cache-first loading — delete the
        seeding, don't reproduce it
- [x] C1.2 `EnrollmentsListPage` reads through — files:
      `Pages/Manage/Group/Enrollment/EnrollmentsListPage.swift` (`:66`, `:282`, `:380`) · spec:
      [06-iphone](06-iphone.md) · tests: the walk
      - `state.enrollmentsFor(groupId:)` (`AppState.swift:414`, sorts by start date)
- [x] C1.3 `MemberHomePage` reads through — files: `MemberHomePage.swift` (`allMembers`) · spec:
      [06-iphone](06-iphone.md) · tests: the walk
- [x] C1.4 ~~Seed members + enrollments in the capture harness~~ → **verified unnecessary; nothing
      seeded.** files: none · spec: [09](09-gaps-and-decisions.md) § G9 · tests: n/a
      - **The task's premise was wrong** (G9). Enrollments are *already* seeded, store + index, at
        `CaptureEnvironment.swift:79-96`. `group-members-page.json` is an explicit **WEB-ONLY**
        comparison — its own note says `GroupMembersPage` is "unreachable by the iPhone harness".
        The one members-touching registry case, `pages.group-members` (`ViewRegistry.swift:268`),
        renders `MemberHomePage`'s Members tab, which snapshots a resting state and **did so before
        this change too** — `state.members` is seeded nowhere, so before and after are both empty.
      - Seeding members for that fixture is real work, but it would **add** content rather than
        restore it — new scope, and a compare-baseline change. Left as the follow-up
        `ViewRegistry.swift:266-267` already calls it.

- [x] C1.5 **Join requests read through too** — files:
      `Pages/Manage/Group/Member/GroupMembersPage.swift` (`joinRequests`),
      `Pages/Manage/Member/MemberHomePage.swift` (`allJoinRequests`) · spec:
      [09](09-gaps-and-decisions.md) § G11 · tests: the walk
      - **added 2026-08-01**, after the integrity check confirmed what [audit.md](audit.md):60-61
        had left as "confirm before acting": the store already exists
        (`AppState.pendingJoinRequestsByGroupId`), `loadJoinRequests` writes it **and** returns, and
        both pages forked the return — the same Mode 2 shape as C1.1–C1.3
      - `MemberHomePage`'s `GroupJoinRequest` wrapper is derived at read time rather than stored
      - fixed here rather than left for Phase D to grandfather

## Phase gates (run fresh, record output)

- [x] `cd iphone && swiftlint lint --baseline .swiftlint-baseline.json` — **0 violations,
      0 serious in 267 files (2026-08-01)**
- [x] `npm run ios:build-check` — **BUILD SUCCEEDED (2026-08-01)**, re-run after C1.5 landed.
      Load-bearing here — converting `@State` arrays to computed properties removes their setters,
      so any missed assignment fails the compile

## Verification checklist

- [x] **Cross-screen freshness** — change a member or an enrollment on one screen; the other screen
      reflects it **without a manual reload**
- [x] **Nothing rendered changed shape** — order, inclusion, and counts match the previous forked
      rendering. `membersFor` sorts alphabetically and `enrollmentsFor` by start date; if the fork
      was in a different order, that is a **finding to surface**, not a diff to accept
- [x] Empty states still render correctly (a group with no members / no enrollments)
- [x] **`/compare` re-capture — attempted 2026-08-01; NOT comparable, for reasons recorded rather
      than glossed.** `group-members-page` has **no iPhone side at all** (`toIphone()` returns
      `null` — it is a web-only comparison, as `G9` established), so no iPhone change can move it.
      `group-members` was re-captured successfully, but the capture DB holds **no prior iPhone
      version of the same variant** to compare against — the only older PNG on disk is an orphan
      whose variant cannot be established. Stated plainly: this comparison is *captured and current*,
      not *verified inert*. It renders the resting state either way (`G9`)
- [x] Spec parity spot-check: no `@State` array of server models remains in the three files —
      all three are computed reads (`membersFor`, `enrollmentsFor`, and the union of `membersFor`
      over `orderedGroups`), confirmed by the compiler accepting the setter removal

### Build notes (2026-08-01)

- **No Action signatures were changed**, unlike Phase B. `loadEnrollments` has **17 call sites**
  including `GroupHomePage.swift` — Phase C-b's file — so re-signaturing it from a C-a task would
  have reached into the next phase's work. The returns are discarded at the three sites instead.
  `loadMembers` and `loadEnrollments` therefore still return collections the rule calls a smell;
  the natural place to revisit that is C-b, which touches `loadPosts` anyway.
- **`EnrollmentsListPage` no longer splices locally on delete** — `deleteEnrollment(id:)` removes
  from `state.enrollments` and both indexes (`EnrollmentActions.swift:319-325`), so the
  read-through drops the row. The old `enrollments.removeAll { … }` was a second truth doing the
  same job.
- **`MemberHomePage.allMembers` is now derived**, not assigned once after loading: the union of
  `membersFor` over `orderedGroups`. Ordering is per-group alphabetical, concatenated in group
  order. The existing de-dup at `:80` still applies (a member can appear in several groups). If the
  live walk shows a different order than before, that is a **finding to surface**, not a diff to
  accept.

## VERIFIED

✅ **2026-08-01**

**Gates:** `ios:build-check` BUILD SUCCEEDED (re-run after C1.5) · `swiftlint lint --baseline` 0
violations, 0 serious, 267 files.

**Walk:** Luke exercised the app and reported *"everything looks good."* That covers the
cross-screen freshness, the ordering watch (`MemberHomePage.allMembers` as a derived union — no
ordering complaint), the empty states, and the C1.5 join-request lists.

**`/compare`:** re-captured 2026-08-01. `group-members-page` is web-only so no iPhone change can
affect it; `group-members` has no same-variant prior to diff against, so it is *current*, not
*proven inert*. Recorded rather than glossed.
<!-- flip to: ✅ YYYY-MM-DD — gates output summarized, walk results, commit sha(s) -->
