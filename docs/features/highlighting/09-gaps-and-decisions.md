# Gaps & decisions ledger

> Seeded by `/build-spec-draft`, **owned by** `/build-spec-audit`. OPEN rows block the plan step.
> Row types: **G** gap in the spec · **D** open design decision · **O** open question for the user ·
> **C** convention/pattern violation · **X** cross-app risk.

## Integrity check — 2026-08-04

**Verdict: SOUND** — 3 defects, all corrected in place; none changes scope, cost or a decision.

| # | Check | Result |
|---|---|---|
| 1 | Suite completeness | ✅ README + 01–09 present; every app has an owner doc with content (no ⬜ apps in this feature) |
| 2 | Citations (31 checked, all opened) | ✅ after correction — 4 had drifted and were fixed during the draft's self-review (`ReadActivityActionProvider` :14 not :20 · `ExegesisActivityActionProvider` :22 not :21 · the `activityType` gate is at **four** sites 2968/3020/3105/3151, not two · `canManageOrgContent` at 2964/3016/3101/3147). All `programs.ts`, `StudyModels.swift`, `schema.yaml`, `ViewRegistry.swift` and capture-fixture paths re-opened and confirmed |
| 3 | Counts re-run | ❌→✅ **"SwipeableCard shared by 14 screens"** was both stale and silently scoped — 13 files reference it, of which 10 are production screens, 2 demo pages and 1 a layout wrapper. Corrected in 06. Verified correct: 2,165 lines (`BibleReaderOverlay`), 8 Action methods, ~10 scroll-lock state vars (10 of 22 lifecycle vars), 3 `ExegesisVerseView` consumers, 2 `SelectableLockedBlockView` consumers, **zero** callers of `snapToWordBoundaries`, 5 compare fixtures |
| 4 | Commands exist & invoke correctly | ✅ all 11 verified by existence, not execution: `ios:build-check` (root), client `build`/`guard`/`vendor/bin/phpunit`, server `lint`/`test:run`/`schema:validate`/`schema:diff`/`migrate:status`, `swiftlint` on PATH (must run from `iphone/`), `capture/runners/compare/diff.mjs` |
| 5 | Internal consistency | ❌→✅ all 9 intra-suite links and 3 ticket links resolve; 05/06 invent no fields. **`blockIds[]` was defined in 03 with no consumer doc explaining who reads it** — 06 now states the Read editor is the multi-block consumer and must not read the deprecated singular `readBlockId`. `D-a` was listed OPEN while 03 presented it as decided; now marked provisionally-decided-pending-ratification |
| 6 | Ledger ↔ artifacts ↔ code | ✅ ledger step statuses match disk; README snapshot matches the ledger; progress recomputes to 10% (recon 1 + design 3 + 10 files × 0.6) exactly as recorded; OPEN rows are consistent with "nothing planned, nothing built" |
| 7 | Unverifiable claims | ✅ no `(claimed — unverified)` markers. The one hedged claim — that `lesson-content-hash.ts` *may* include `selections` — is correctly hedged and already carried as `X-c` |

**Not verified (flagged, not silently skipped):** no command was executed, per the skill's read-only
rule — existence and invocation directory were established by reading. Whether the content hash
actually includes `selections` needs the audit or a running stack (`X-c`).

## Audit pass log

| Date | Pass | Findings | Notes |
|---|---|---|---|
| 2026-08-04 | 3 — **gap hunt + client component coverage → AUDIT COMPLETE** | 3 gaps (G-a, G-b), 1 closed (G-c) | The adversarial pass. **G-a**: the server work is 8 routes across **2 files** (`enrollments.ts:4267-4456` was hidden behind "and its scheduled-activity counterpart"), and the two contexts gate on differently-named fields (`activityType` vs `type`). **G-b**: `style: "bold"` was in the contract with no rendering rule — now defined as weight-only, no wash. **G-c** closed: the readBlock FK is `onDelete: Cascade`, so a passage change already destroys highlights today and Read's `selections` die with the block identically — convergence adds no new loss. **Client component coverage verified**: `read-step.vue:160/193-239` already renders spans (with offset remapping at `:217`), so 05's "no new components" holds. |
| 2026-08-04 | 2 — delta + owed sweeps | 0 new findings | Delta over the six decisions. **D2/X-c feasibility confirmed in code**: `ReadBlockSelection` encodes exactly `start`/`end`/`style` (`id` is computed, not encoded) — identical to the projection's output — and `mergeSelection` returns `kept + [new]`, i.e. insertion order. So assigning `orderNumber` = array index at backfill makes the projection byte-identical. Owed per-app sweeps run: iPhone `clearInMemory` + `EntityStore` conventions present (`AppState.swift`); all four client stores named in 05 exist; server route conventions unchanged (generalising preserves the zod + try/catch + `{success}` envelope). **Still not run:** adversarial gap hunt and client component-coverage-by-view. |
| 2026-08-04 | 1 — **PARTIAL** | 1 confirmed risk (X-c), 1 closed (X-d) | **Scoped to the cross-app contract and the two unresolved X-rows**, which were the highest-value unknowns. **Not yet done:** per-app pattern compliance sweeps (server route/service conventions, client island/store conventions, iPhone AppState/Actions conventions), component-coverage verification for the client, and the adversarial gap hunt. A full pass is still required before the plan step. |

## Build findings

| Date | Phase | Finding |
|---|---|---|
| 2026-08-04 | 1 | **Task 1.2 answered with evidence: the merge does NOT lose notes.** API-level repro on the local stack — a highlight spanning two noted highlights produced a merged row containing **all four** notes concatenated in document order. Production-synced data on another block independently shows the same concatenation signature (a note split mid-word across `\n\n` joins). **monday#12708759849 sub-issue A is therefore a client-side defect**, and the fix is 1.3a: re-key the note dictionary by highlight id instead of by range. The server path stays untouched, and Phase 3's backfill is cleared to write into it once 1.3a lands. |

## G — gaps

| # | Status | Gap | Where |
|---|---|---|---|
| G-a | **OPEN — affects effort, not design** | **04 under-counts the server work.** It says the routes live in `programs.ts` "and its scheduled-activity counterpart" without naming it. The counterpart is a **different file** — `server/src/routes/enrollments.ts:4267` (GET), `:4312` (POST), `:4403` (PATCH), `:4456` (DELETE). The server phase is therefore **8 routes across 2 files**, plus 8 legacy aliases, not 4 in 1. Corrected in 04; recorded because it roughly doubles the route work an implementer would have budgeted. **Second asymmetry found in the same sweep:** the two contexts gate on *differently named fields* — `activity.activityType` (programs) vs **`activity.type`** (`enrollments.ts:4277`) — so relaxing the gate is not a copy-paste. Both corrected in 03 §2 and 04. | 04 §Route work · 03 §2 |
| G-b | **OPEN — contract gap** | **`bold` has no defined rendering.** `style` is `highlight \| bold` in 03 §1.1/§2.2, and `read-step.vue:63` already documents both values — but 03 §5's normative rules define colours only for highlight/live/active/used. Nothing says how `bold` renders. Two consumers implementing it independently is precisely the divergence this feature exists to end. Needs a rule in 03 §5 before the consumer phases. | 03 §5 |
| G-c | **CLOSED 2026-08-04 — no gap, recorded because it looks like one** | **"Does changing the passage destroy highlights?" Yes — and it already does.** The `readBlock` FK carries `onDelete: Cascade` (`schema.yaml`, Highlight relation), so highlights die with their block today; Read's `selections` live *on* the block and die with it identically. Reset (`programs.ts:2589`) and delete-source-reference (`:2864`) both drop blocks and rely on that cascade. Convergence changes nothing here. | 04, X-d |

## D — open design decisions

| # | Status | Decision needed | Context |
|---|---|---|---|
| D-a | **DECIDED (Luke, 2026-08-04): incoming style wins** — ratifies 03 §2.2 as written | **Style precedence on merge.** 03 commits to an answer so consumers have something to code against; nobody has ratified it. Alternatives: highest-priority style wins, or merge refuses across differing styles. | 03 §2.2 |
| D-b | **DECIDED (Luke, 2026-08-04): carry the scroll-lock machinery into the shared controller** | **Does the shared controller carry `ExegesisVerseView`'s scroll-lock machinery, or drop it?** ~10 state vars exist to stop the enclosing ScrollView jumping during native selection. Carrying it makes the controller heavier; dropping it risks reintroducing scroll jump that is not currently reported. | 06 §Selection lifecycle |
| D-c | **DECIDED (Luke, 2026-08-04): wrap first, replace later** | **Wrapper or replacement** for `SelectableLockedBlockView` / `ExegesisVerseView`. Wrapping keeps the capture ViewRegistry cases resolving; replacing is cleaner but touches the harness in the same task. | 06, 07 |

## O — open questions for the user

| # | Status | Question | Why it matters |
|---|---|---|---|
| O-a | **DECIDED (Luke, 2026-08-04): ship the colour change silently** — no staged rollout, no announcement | The lime colour change is visible to **members on already-published lessons**. Is a coordinated announcement or a staged rollout wanted, or is deploying it silently acceptable? | 05, 08 §human script |
| O-b | **DECIDED (Luke, 2026-08-04): revisit one release after ship** — the cleanup gets an owner then | How long do the `…/exegesis-highlights` aliases and the `selections` projection stay? 03 says "at least one release" and defers the drop to a separate gated change — that gate has no owner or trigger yet. | 03 §2.5, §3 |

## C — convention / pattern violations

| # | Status | Violation | Fix |
|---|---|---|---|
| C-a | **RESOLVED by this spec** (D9 folds all three snappers into one; the build phase deletes the duplicates) | `ExegesisVerseView.snappedToWordBoundaries` (added by `c8a0311`, 2026-08-03) is a third copy of word snapping alongside the dead `VerseSelectionLogic.snapToWordBoundaries` and the inline copy in `BibleReaderOverlay`. This spec's own D9 resolves it; recorded so the cleanup is not lost if the feature is descoped. | 06 §Snapping |

## X — cross-app risks

| # | Status | Risk | Mitigation |
|---|---|---|---|
| X-a | **ACKNOWLEDGED** — standing constraint, mitigated by 03 §2.5/§3 and proven by 08 E2E step 7 | **Build 374 is in testers' hands now** and reads `selections[]` + `…/exegesis-highlights`. Any slip in the projection or the aliases silently empties their Read highlights. | 03 §2.5/§3, tested by 08 E2E step 7 |
| X-b | **ACKNOWLEDGED** — gated: D8 makes the fix a prerequisite; 04 §Prerequisite blocks M3 until verified | **The backfill writes into the merge path that has an open data-loss report** (monday#12708759849 sub-issue A). | D8 makes the fix a prerequisite; 04 §Prerequisite gates M3 |
| X-c | **DECIDED (Luke, 2026-08-04): normalise the projection to reproduce existing bytes** (option A — hash-neutral). CONFIRMED 2026-08-04 | `lesson-content-hash.ts:180` **does** hash `selections` (`selections: block.selections ?? null`), and `enrollment-sync.ts:322` compares `schedule.currentVersion?.sourceContentHash === lesson.contentHash` to decide whether an enrolled group's scheduled lesson is stale. So the projection is *already* the mechanism by which a highlight edit invalidates a lesson version — and any change to how it serialises re-hashes **every** block that has highlights. Narrowed by inspection: style **values** should not change (exegesis rows are all `'highlight'`; Read's spans already carry real styles), so the exposure is **ordering and JSON shape** — the projection sorts by `orderNumber` and emits exactly `{start,end,style}`, whereas today's Read `selections` is whatever the client wrote. | The backfill must either reproduce each block's existing serialisation byte-for-byte, or be accompanied by a deliberate, announced hash re-baseline. **04 gains a required pre-flight**: diff old vs regenerated `selections` JSON across all blocks in the dry run and report every block whose hash would move. Consumers: `enrollment-sync`, `enrollment-edit`, `enrollment-sync-changes`, `study-program-publish`, `routes/enrollments.ts` |
| X-d | **RESOLVED 2026-08-04 — no new risk** | `programs.ts:2740-2748` scopes the delete to one activity's own blocks (`lessonActivityId: id`) and deletes those blocks on the next line, so the highlights were going away with their blocks regardless. After convergence it also removes Read highlights — but those live on the same doomed blocks, and today's `selections` column dies with them identically. Behaviour is equivalent; no data becomes newly reachable or newly lost. | none — closed with evidence |
| X-e | **RESOLVED 2026-08-04** — 03 §2.1 adds `blockIds[]` and deprecates the singular; 06 names the Read editor as the multi-block consumer | The exegesis endpoints assume **one locked block per activity** (`findFirst`). READ activities have many. Any consumer still reading the singular `readBlockId` will silently address only the first block. | 03 §2.1 introduces `blockIds[]`; consumers must migrate off `readBlockId` |
| X-f | **ACKNOWLEDGED** — mitigation specified in 06 §Disk cache (version bump or optional `style` with a default) | iPhone disk cache holds the old entity shape; an in-place upgrade must not fail the decode. | 06 §Disk cache |
