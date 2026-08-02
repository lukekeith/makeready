# Phase B — Mode 1: homeless domains  ·  app: iphone

> Part of docs/features/state-management/. Preconditions: Phase A's **VERIFIED** block is signed.
> Do not start tasks here until it is.
>
> ✅ **`O1` cleared (2026-08-01)** — the analytics WIP landed as its own commit `6f79f01`, so every
> file this phase edits is clean and the phase commit needs no hunk filtering.
> See [09](09-gaps-and-decisions.md) § O1.

## Goal

The tag, group-leader, and media-tag domains have a home in `AppState`, their Actions write instead
of returning, and mutations refresh the derived lists in the same call — so editing a program's tags
updates the Library filter with no screen-specific refresh. **This is the fix for monday ticket
12668501065 sub-issue J.**

## Companion skills

None — no new overlays, sub-screens, deep links, or components. This is state + Actions work.

## Tasks

- [x] B.1 Add the three collections to `AppState` as **plain `@Observable` properties, memory-only**
      — files: `iphone/MakeReady/State/AppState.swift` (beside `homeHeatmapData`, `:339-358`) ·
      spec: [06-iphone](06-iphone.md) § AppState changes · tests: none (state decl)
      - `allProgramTags: [String]`, `groupLeaders: [GroupLeader]`, `allMediaTags: [String]`
      - **NOT `EntityStore`** (no identity semantics) and **NOT persisted** — `PersistedState.swift`
        is out of scope (D1)
- [x] B.2 Clear all three **plus `textThemes`** in `clearInMemory()` — files: `AppState.swift`
      (`:736-776`) · spec: [09](09-gaps-and-decisions.md) § G2 + D2 · tests: covered by the
      sign-out walk below
      - `textThemes = []` is the pre-existing leak fix (D2); it is deliberate, not collateral
- [x] B.3 Make the three loaders **write instead of return** — files:
      `State/Actions/ProgramActions.swift` (`:466` `loadAllTags`, `:480` `loadGroupLeaders`),
      `State/Actions/MediaActions.swift` (`:410` `loadAllMediaTags`) · spec:
      [06-iphone](06-iphone.md) § Actions changes · tests: none shippable without a host app —
      verified by the walk
- [x] B.4 `addTags` / `removeTags` / `syncTags` **refresh the derived tag list in the same call** —
      files: `ProgramActions.swift` (the `:402-465` block) · spec: [README](README.md) § The rule ·
      tests: the J repro below
      - this is the invalidation edge; without it the phase fixes nothing
- [x] B.5 `MainLibrary` reads through — **all six call sites** — files:
      `Pages/Main/MainLibrary.swift` (`:109`, `:112` decls; `:475`, `:482`, `:845`, `:852` first-load
      guard; `:1177-1178`, `:1187-1188` refresh path) · spec: [06-iphone](06-iphone.md) § G4 ·
      tests: the walk
      - **consolidate the `if …isEmpty` guard**: once the property is shared it is a *global*
        condition, not a per-screen one. Two load paths writing the same shared property is the bug
        pattern this feature exists to remove
- [x] B.6 `OrgHomePage` reads through — files: `Pages/Manage/Org/OrgHomePage.swift` (`:189` and its
      local `groupLeaders` property) · spec: [06-iphone](06-iphone.md) § G4 · tests: the walk
      - this is the second homeless copy of the leaders domain; skipping it leaves the domain forked
- [x] B.7 Review the leftovers: `getTags(programId:)` and `suggestTags(programId:)` are per-program
      lookups, **not shared collections** — confirm they legitimately stay as returns and note the
      reasoning inline · spec: [06-iphone](06-iphone.md)
      - both kept as returns; the reasoning is now a doc comment on each
- [x] B.8 **`MediaActions`' tag mutators refresh `allMediaTags` the same way** — files:
      `State/Actions/MediaActions.swift` (`addTags`, `removeTags`, `syncTags`) · spec:
      [09](09-gaps-and-decisions.md) § G7 · tests: the media-tag repro below
      - **added during the build (G7)**, not in the original plan: media has the identical mutator
        trio, so program-only invalidation would leave the Media tab reproducing sub-issue J

## Phase gates (run fresh, record output)

- [x] `cd iphone && swiftlint lint --baseline .swiftlint-baseline.json` — **0 violations, 0 serious
      in 267 files (2026-08-01)**. Note the `--baseline` flag: a bare `swiftlint` reports all 981
      grandfathered violations and looks like a failure
- [x] `npm run ios:build-check` — **BUILD SUCCEEDED (2026-08-01)**, run with the owner's go-ahead.
      Confirms the call-site sweep: three changed Action signatures and four `@State` → computed
      conversions all resolve. The build's own `SwiftLint (audit conventions)` phase passed inside
      it, so the gate above is confirmed twice.
      *Side effect to expect: the `Auto Increment Build Number` phase bumped `Info.plist`
      `CFBundleVersion` 349 → 356. Not an edit — every build does this.*

## Verification checklist

- [x] **The J repro** — edit a program's tags → return to Library → Programs → open `All tags` →
      the new tag is listed **without toggling a filter**. *Exercised by Luke in the running app,
      2026-08-01: "everything seems to work in the app and it built successfully."*
- [~] **The sign-out walk (G2/D2)** — sign out, sign in as a **different user in a different org**,
      open the Library filters: tag and leader dropdowns are empty or repopulated for the new org,
      **never showing the previous user's values**. Repeat for themes (the D2 fix).
      **Carried to the final verify step** — Luke's pass covered normal use, and this one needs two
      accounts in two orgs, so it is NOT claimed as done. The code path is traced and static-verified
      (`clearInMemory()` assigns `[]` to all four; `clearAllData()` also wipes the disk snapshot)
- [x] `OrgHomePage` still renders its leaders list correctly (B.6) — covered by Luke's pass
- [x] Media tab tag filter still populates (B.3's third loader) — covered by Luke's pass
- [~] Re-capture the two `MainLibrary` ViewRegistry cases (`ViewRegistry.swift:227`, `:254`) and
      diff — **expected inert**. **Carried to the final verify step**, where the capture work for
      C-a and C-b runs anyway; batching all the re-captures into one pass avoids three separate
      simulator runs ([07-capture](07-capture.md))
- [~] Media tab: add a tag to a media item → the Media tags filter lists it without a reload
      (B.8/G7) — **carried to the final verify step**; the symmetric program-tag path (the J repro)
      is confirmed working, and the media code is its literal twin
- [x] Spec parity spot-check: the three properties are memory-only and cleared — traced in the
      shipped code (2026-08-01). `AppState.swift`: the three declarations sit in a new
      `// MARK: - Reference Collections` block with **no `PersistedState` wiring** (D1 honored — a
      repo-wide grep for the three names outside `AppState`/Actions/pages returns nothing), and all
      three plus `textThemes` are assigned `[]` in `clearInMemory()`, whose only callers are
      `clearAllData()` (logout — also wipes the disk snapshot) and `reloadForEnvironmentSwitch()`
- [x] **Call-site sweep** (2026-08-01) — the three loaders have exactly 9 call sites app-wide, all
      migrated: `MainLibrary.swift` ×8, `OrgHomePage.swift` ×1. Zero assignments to the former
      `@State` copies remain in either file; every remaining reference is a read. **Confirmed by
      the compiler** — BUILD SUCCEEDED with the new Void-returning signatures.

## Live verification — done, with three items carried forward

Luke ran the app on 2026-08-01 and confirmed it works. Three `[~]` items above were **not**
individually exercised and are carried to `/build-spec-verify` rather than assumed: the cross-org
sign-out walk, the media-tag repro, and the `/compare` re-capture. They are recorded in the ledger
so the verify step cannot quietly skip them.

### Also fixed here, outside the original scope (approved by Luke, 2026-08-01)

`programAnalyticsById = [:]` added to `clearInMemory()` — the `G8` leak in the analytics WIP that
landed in `6f79f01`. One line, taken with explicit approval because it is the same defect class as
the `textThemes` leak this phase fixes. Include it in the Phase B commit message.

## VERIFIED

✅ **2026-08-01**

**Gates:** `npm run ios:build-check` → BUILD SUCCEEDED. `swiftlint lint --baseline
.swiftlint-baseline.json` → 0 violations, 0 serious, 267 files (and again inside the build's own
lint phase).

**Walk:** Luke ran the app and reported *"everything seems to work in the app and it built
successfully."* That covers the J repro — the reason this phase exists — plus OrgHome's leaders and
the Media tab filter.

**Honest residue (3 items, marked `[~]` above, carried to `/build-spec-verify`, not silently
dropped):** the cross-org sign-out walk (needs two accounts in two orgs), the media-tag repro (the
program-tag twin is confirmed), and the `/compare` re-capture (batched with C-a's and C-b's captures
so the simulator runs once). None of these gate the next phase; all three are logged in the ledger.

**Commits:** none yet — iPhone commits need explicit approval, still to be offered.
