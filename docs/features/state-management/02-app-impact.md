# 02 — App impact

> Written at pipeline adoption, 2026-08-01. The out-of-scope claims below are **as claimed by the
> spec**; `/build-spec-audit` Phase A checks them and turns any wrong one into an `X#` row.

## Scope per app

| App | In scope | What changes | Owner doc |
|---|---|---|---|
| server | ⬜ | **Nothing.** This feature changes where the client holds data it already fetches. No schema, no endpoint, no service, no permission change | [04-server.md](04-server.md) |
| client | ⬜ | **Nothing.** Audited 2026-08-01 and conformant — 14 Pinia domain stores, zero of 31 LeaderApp components make their own API calls. A second working exemplar, not a target | [05-client.md](05-client.md) |
| iphone | ✅ | `AppState` gains `allProgramTags` + `groupLeaders` (+ `allMediaTags`); tag/leader Actions write instead of return; four pages read through to existing stores instead of forking; SwiftLint custom rule + baseline; the rule documented in `iphone/.claude/CLAUDE.md` | [06-iphone.md](06-iphone.md) |
| capture | ✅ | **Added by `X1`, DECIDED 2026-08-01** (originally claimed out of scope; audit pass 1 disproved it). `CaptureEnvironment` seeds the stores + posts cursor the read-throughs now read; the affected `ViewRegistry` cases are re-captured and diffed as part of Phase C | [07-capture.md](07-capture.md) |

Cross-checked against the root `.claude/CLAUDE.md` § Cross-App Impact Guide: no row in that table
matches this change type (no schema change, no new endpoint, no auth-flow change, no content-model
change, no push change, no media change). The guide's closest analog would be a UI-component change
— **client only** in that table — and this is its iPhone mirror.

## The contract (who produces, who consumes)

**None.** No producer/consumer contract changes. The endpoints behind the affected Actions
(`loadAllTags`, `loadGroupLeaders`, `getTags`, `addTags`, `removeTags`, `syncTags`, `suggestTags`)
keep their current request and response shapes; only what the client does with the response
changes. See [03-data-and-api.md](03-data-and-api.md).

## Cross-app sequencing

The pipeline's contract → server → consumers ordering **collapses to a single consumer**: there is
no contract phase and no server phase, so the whole feature is one app's phase sequence.

1. ~~contract~~ — n/a
2. ~~server~~ — n/a
3. **iphone** — A → B → C → D, in that order (the ordering hazard in
   [README.md](README.md) § Ordering hazard is binding: D last, always)
4. **capture** — **not a separate phase.** The re-capture + diff work belongs *inside* Phase C,
   because it verifies that phase's change; a capture phase running after D would be checking
   screens two phases later than the change that moved them ([07-capture.md](07-capture.md))
5. verification — SwiftLint + the per-phase live walks in [08-testing.md](08-testing.md)

## Backward compatibility

- **Server:** unaffected — no API surface changes, so iPhone builds already in the field are
  untouched by this work.
- **On-disk state:** `PersistedState.swift:291` decodes with `decodeIfPresent(…) ?? []`, so adding
  persisted fields cannot invalidate an existing snapshot. **No cache-bust needed on upgrade.**
  (Whether these collections persist at all is `D1` — still open.)
- **Web:** unaffected.

## Blast radius (what else reads this data)

- `AppState.swift` is edited by Phase B and is **also carrying a foreign uncommitted hunk**
  (`programAnalyticsById`, from in-flight analytics work, referencing the untracked
  `AnalyticsModels.swift`). Staging it wholesale produces a non-compiling commit — stage hunks
  surgically. This is the single largest practical hazard in the feature.
- `allTags` / `allLeaders` have **no consumers outside `MainLibrary`** (verified 2026-08-01), so
  Phase B's blast radius is contained.
- Mode 2's targets read through to stores that already exist (`AppState.posts`, `.members`,
  `.enrollments`), so Phase C adds no new state — it removes forks.
- Phase D regenerates the SwiftLint baseline **wholesale** (currently 1,118 entries). That touches
  every file with a grandfathered violation, unrelated to this feature — which is exactly why it
  must run last, and why it needs its own commit.
