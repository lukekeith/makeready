# highlighting — one text-highlighting service across every text surface

**Status:** `spec complete` · integrity SOUND · audit pass 1 partial · **decisions gate open**

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
| audit | 🔄 pass 1 partial — X-c confirmed, X-d closed; per-app sweeps owed |
| decisions | 🔄 open — see 09 |
| plan | ⬜ |
| build | ⬜ |
| verify | ⬜ |
| sign-off | ⬜ |

## Phase status

Not planned yet — the plan step writes `10+-phase-N-*.md` after the audit is clean.

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
