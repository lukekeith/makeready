# highlighting — one text-highlighting service across every text surface

**Status:** `SHIPPED — verified READY and signed off by Luke, 2026-08-05` · **all 7 phases VERIFIED,
all four apps' gates green, human-walked.**

Three native highlight implementations are now one service. Along the way the feature fixed the
data-loss bug that motivated it (notes erased when highlights merged), found a defect that had
already reached members (blank notes in the web player), and turned up a fourth word-snapper nobody
knew the web had. It also re-created its own original bug — the Exegesis editor committing a
highlight before the finger lifts — because the refactor moved the code but not the call; sweeping
for that pattern found two more of exactly the same shape (09 §X-p/p2/p3, method at §C-d).

The central claim is **measured, not asserted**: brand purple `#6C47FF` → lime `#F4FF76 @0.35`, a
one-for-one 23,319-px swap confined to the highlighted span, with every other web shot
byte-identical. The live `@0.55` colour got its first visual test anywhere.

**Two things a reader should know before trusting this:** no pre-feature *binary* was ever pointed
at the current server — build 374 turned out to be unreconstructible, so that backward-compat check
was **accepted on contract-level proof rather than executed** (09 §G-ad) — and the human walk was a
blanket "everything works, I tested it" rather than a per-step report. Both are recorded as such in
09 §Verify verdict. **Not yet committed or pushed.**

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
| decisions | ✅ 7 decided, 4 resolved, 3 acknowledged — D-d (injectable highlight colour) decided 2026-08-05 and **deferred to a follow-up spec**, so it does not block; G-ab remains an open finding |
| plan | ✅ 7 phases, 64 tasks (the Phase status column sums to 64; "56" was a miscount, corrected 2026-08-04) |
| build | ✅ **7 of 7 — every phase VERIFIED.** Phase 6 turned the colour claim from an assertion into a measurement: purple `#6C47FF` → lime `#F4FF76 @0.35`, one-for-one, in the web pixels |
| verify | ✅ **READY 2026-08-05** — all 7 phases VERIFIED, zero blocking rows, four-app gates green (server tsc 0 · 476 tests · client build 0 · 33 vitest · 235 phpunit · **guard delta ZERO** · iPhone BUILD SUCCEEDED, zero new SwiftLint · capture up). Caveats named in 09 §Verify verdict |
| sign-off | ✅ **2026-08-05 (Luke): "everything works, I tested it, let's wrap this spec"** — a blanket affirmative, recorded as such |

## Phase status

| # | App | Doc | Tasks | Status |
|---|---|---|---|---|
| 1 | iphone | [10-phase-1-prerequisite-note-loss.md](10-phase-1-prerequisite-note-loss.md) | 5 | ✅ **VERIFIED 2026-08-04** — notes survive a merge (`6e349b5`); narrow fix, real one at 4.8b |
| 2 | server | [11-phase-2-server-schema-and-routes.md](11-phase-2-server-schema-and-routes.md) | 11 | ✅ **VERIFIED 2026-08-04** — schema, migration, 8 routes, 18 tests; **`03` now FROZEN** |
| 3 | server | [12-phase-3-server-backfill.md](12-phase-3-server-backfill.md) | 12 | ✅ **VERIFIED 2026-08-04** — 67 spans → rows, 4 hash baselines re-stamped, rollback rehearsed |
| 4 | iphone | [13-phase-4-iphone-service.md](13-phase-4-iphone-service.md) | 15 | ✅ **RE-VERIFIED 2026-08-04, HUMAN-CONFIRMED** — three dropped-call regressions (§X-p/p2/p3) found and fixed; Luke used it on a device |
| 5 | client | [14-phase-5-client-consumers.md](14-phase-5-client-consumers.md) | 8 | ✅ **VERIFIED 2026-08-04** — fixed X-n (members saw blank notes), found G-v/G-w/X-o; client gained a test runner + 29 tests. **The "lime unseen by any human" caveat is CLOSED** — measured in pixels by 6.4 and walked by Luke 2026-08-05 |
| 6 | capture | [15-phase-6-capture.md](15-phase-6-capture.md) | 8 | ✅ **VERIFIED 2026-08-05** — **the purple→lime swap proven in pixels** (23,553→234 px purple, 0→23,319 lime, one-for-one); the live `@0.55` value gets its first visual test anywhere; 9 re-baselines accepted and 18 reverted via a two-run determinism test; §G-aa ratified, §G-ab reframed as harness state, §G-ac open for web |
| 7 | cross-app | [16-phase-7-cross-app-e2e.md](16-phase-7-cross-app-e2e.md) | 8 | ✅ **VERIFIED 2026-08-05** — 7.5 (**both notes survive a merge**, restored byte-identically) + 7.8 (per-block consumer parity) run against the live stack; 7.1–7.4/7.6 human-walked. **7.7 accepted, not executed** — build 374 is unreconstructible (§G-ad) |

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
