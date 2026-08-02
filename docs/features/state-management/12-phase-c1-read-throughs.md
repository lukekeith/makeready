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

## Phase gates (run fresh, record output)

- [x] `cd iphone && swiftlint lint --baseline .swiftlint-baseline.json` — **0 violations,
      0 serious in 267 files (2026-08-01)**
- [ ] `npm run ios:build-check` — needs the owner's go-ahead (O2)

## Verification checklist

- [ ] **Cross-screen freshness** — change a member or an enrollment on one screen; the other screen
      reflects it **without a manual reload**
- [ ] **Nothing rendered changed shape** — order, inclusion, and counts match the previous forked
      rendering. `membersFor` sorts alphabetically and `enrollmentsFor` by start date; if the fork
      was in a different order, that is a **finding to surface**, not a diff to accept
- [ ] Empty states still render correctly (a group with no members / no enrollments)
- [ ] **Re-capture and diff** `group-members-page` and the group Members/Enrolled tab cases
      (`ViewRegistry.swift:201`) — any pixel delta must be **explained**, not accepted
      ([07-capture](07-capture.md))
- [ ] Spec parity spot-check: no `@State` array of server models remains in the three files

## VERIFIED

⬜ Not yet — do not open the next phase doc.
<!-- flip to: ✅ YYYY-MM-DD — gates output summarized, walk results, commit sha(s) -->
