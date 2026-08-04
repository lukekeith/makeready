# highlighting — one text-highlighting service across every text surface

**Status:** `building` · phases 1-3 of 7 **VERIFIED** · note-loss fixed and human-confirmed; schema,
routes and projection in with the contract **frozen**; Read highlights **migrated** (local only) with
a rehearsed rollback. Next: the two consumer phases, which can run in parallel.

One way to create, store, render and persist a text highlight — replacing three native
implementations that disagree on granularity, colour, coordinates and when a selection commits.

## Why

Three tickets in one week were the same defect wearing different clothes, each fixed in a different
place because each surface had its own implementation:

| Ticket | Surface | Defect |
|---|---|---|
| [12668695071](../../monday/tickets/12668695071.md) | Read editor | stray UIKit selection handles, no visible span |
| [12701776858](../../monday/tickets/12701776858.md) | Read editor | card corners squared by the fix above |
| [12708759849](../../monday/tickets/12708759849.md) | Exegesis editor | commit on a timer mid-gesture · letter-level selection · **notes erased on merge** |

The word-snapping the Exegesis editor lacked already existed **twice** in the repo, and the
canonical copy (`VerseSelectionLogic.snapToWordBoundaries`) had **zero callers**.

## Pipeline status (snapshot)

| Step | Status |
|---|---|
| spec | ✅ suite written (README + 01–09) |
| integrity check | ✅ SOUND (3 defects corrected) |
| audit | ✅ 3 passes — 2 gaps found + corrected, 2 risks closed with evidence |
| decisions | ✅ 6 decided, 3 resolved, 3 acknowledged — no OPEN rows |
| plan | ✅ 7 phases, 64 tasks (the Phase status column sums to 64; "56" was a miscount, corrected 2026-08-04) |
| build | 🔄 3 of 7 phases done — phases 1 + 2 + 3 ✅ VERIFIED 2026-08-04 · **contract frozen · data migrated** |
| verify | ⬜ |
| sign-off | ⬜ |

## Phase status

| # | App | Doc | Tasks | Status |
|---|---|---|---|---|
| 1 | iphone | [10-phase-1-prerequisite-note-loss.md](10-phase-1-prerequisite-note-loss.md) | 5 | ✅ **VERIFIED 2026-08-04** — notes survive a merge (`6e349b5`); narrow fix, real one at 4.8b |
| 2 | server | [11-phase-2-server-schema-and-routes.md](11-phase-2-server-schema-and-routes.md) | 11 | ✅ **VERIFIED 2026-08-04** — schema, migration, 8 routes, 18 tests; **`03` now FROZEN** |
| 3 | server | [12-phase-3-server-backfill.md](12-phase-3-server-backfill.md) | 12 | ✅ **VERIFIED 2026-08-04** — 67 spans → rows, 4 hash baselines re-stamped, rollback rehearsed |
| 4 | iphone | [13-phase-4-iphone-service.md](13-phase-4-iphone-service.md) | 15 | ⬜ ∥ with 5 |
| 5 | client | [14-phase-5-client-consumers.md](14-phase-5-client-consumers.md) | 8 | ⬜ ∥ with 4 · member-visible |
| 6 | capture | [15-phase-6-capture.md](15-phase-6-capture.md) | 8 | ⬜ |
| 7 | cross-app | [16-phase-7-cross-app-e2e.md](16-phase-7-cross-app-e2e.md) | 8 | ⬜ |

## Docs

| Doc | Contents |
|---|---|
| [01-architecture.md](01-architecture.md) | Decisions table, baseline patterns, the five service layers, out of scope |
| [02-app-impact.md](02-app-impact.md) | Per-app scope, contract ownership, sequencing, backward compatibility, blast radius |
| [03-data-and-api.md](03-data-and-api.md) | **The contract** — schema change, migration list, endpoint table, and the normative cross-app highlight rules |
| [04-server.md](04-server.md) | Routes, migration + backfill, merge semantics, the prerequisite data-loss fix |
| [05-client.md](05-client.md) | Member lesson player + LeaderApp panes/stores |
| [06-iphone.md](06-iphone.md) | The service, the three adopting surfaces, AppState/Actions |
| [07-capture.md](07-capture.md) | The five affected fixtures |
| [08-testing.md](08-testing.md) | Per-app tests, gates, E2E walk, human-verification script |
| [09-gaps-and-decisions.md](09-gaps-and-decisions.md) | G/D/O/C/X ledger — owned by the audit |
| `10`–`16` | the per-phase build guides — see Phase status above |

## Governing rules

1. **No existing highlight may be lost or altered.** The migration is additive-only.
   `ActivityReadBlock.selections` is never dropped by this feature — it becomes a server-derived
   projection so shipped iPhone builds keep working unchanged. Dropping it is a separate, later,
   explicitly-gated change.
2. **Sub-issue A of monday#12708759849 is a prerequisite**, not a follow-up. Read highlights must
   not be migrated into a table whose write path has an open data-loss report.
3. **Contract-first.** No consumer code is written against an endpoint whose shape isn't in `03`.
   `03` freezes when the server phase verifies.
4. **One service, granularity injected.** Every native surface uses the same gesture lifecycle,
   snapping engine and renderer; only the granularity policy differs per surface.
5. **Additive-only for `/compare` twins** — new props default to the captured rendering.

## Resume

```
/build-spec highlighting
```

The orchestrator detects the pipeline state and dispatches to the right step.
