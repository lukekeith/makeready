# Gaps & decisions ledger

> Seeded by `/build-spec-draft`, **owned by** `/build-spec-audit`. OPEN rows block the plan step.
> Row types: **G** gap in the spec · **D** open design decision · **O** open question for the user ·
> **C** convention/pattern violation · **X** cross-app risk.

## Audit pass log

| Date | Pass | Findings | Notes |
|---|---|---|---|
| — | — | — | not yet audited |

## G — gaps

| # | Status | Gap | Where |
|---|---|---|---|
| — | — | none recorded yet | — |

## D — open design decisions

| # | Status | Decision needed | Context |
|---|---|---|---|
| D-a | OPEN | **Style precedence on merge.** 03 §2.2 decides "incoming style wins" so consumers can rely on something. Nobody has ratified it. Alternative: highest-priority style wins, or merge refuses across differing styles. | 03 §2.2 |
| D-b | OPEN | **Does the shared controller carry `ExegesisVerseView`'s scroll-lock machinery, or drop it?** ~10 state vars exist to stop the enclosing ScrollView jumping during native selection. Carrying it makes the controller heavier; dropping it risks reintroducing scroll jump that is not currently reported. | 06 §Selection lifecycle |
| D-c | OPEN | **Wrapper or replacement** for `SelectableLockedBlockView` / `ExegesisVerseView`. Wrapping keeps the capture ViewRegistry cases resolving; replacing is cleaner but touches the harness in the same task. | 06, 07 |

## O — open questions for the user

| # | Status | Question | Why it matters |
|---|---|---|---|
| O-a | OPEN | The lime colour change is visible to **members on already-published lessons**. Is a coordinated announcement or a staged rollout wanted, or is deploying it silently acceptable? | 05, 08 §human script |
| O-b | OPEN | How long do the `…/exegesis-highlights` aliases and the `selections` projection stay? 03 says "at least one release" and defers the drop to a separate gated change — that gate has no owner or trigger yet. | 03 §2.5, §3 |

## C — convention / pattern violations

| # | Status | Violation | Fix |
|---|---|---|---|
| C-a | OPEN | `ExegesisVerseView.snappedToWordBoundaries` (added by `c8a0311`, 2026-08-03) is a third copy of word snapping alongside the dead `VerseSelectionLogic.snapToWordBoundaries` and the inline copy in `BibleReaderOverlay`. This spec's own D9 resolves it; recorded so the cleanup is not lost if the feature is descoped. | 06 §Snapping |

## X — cross-app risks

| # | Status | Risk | Mitigation |
|---|---|---|---|
| X-a | OPEN | **Build 374 is in testers' hands now** and reads `selections[]` + `…/exegesis-highlights`. Any slip in the projection or the aliases silently empties their Read highlights. | 03 §2.5/§3, tested by 08 E2E step 7 |
| X-b | OPEN | **The backfill writes into the merge path that has an open data-loss report** (monday#12708759849 sub-issue A). | D8 makes the fix a prerequisite; 04 §Prerequisite gates M3 |
| X-c | OPEN | `services/lesson-content-hash.ts` may include `selections` in the lesson content hash. Rebuilding the projection could spuriously invalidate lesson versions and trigger `enrollment-sync` for enrolled groups. | 03 §3 audit item; verify before M3 |
| X-d | OPEN | `programs.ts:2746` deletes highlights for a set of blocks. After convergence that path deletes **Read** highlights too — scope must be re-verified. | 04 §Route work |
| X-e | OPEN | The exegesis endpoints assume **one locked block per activity** (`findFirst`). READ activities have many. Any consumer still reading the singular `readBlockId` will silently address only the first block. | 03 §2.1 introduces `blockIds[]`; consumers must migrate off `readBlockId` |
| X-f | OPEN | iPhone disk cache holds the old entity shape; an in-place upgrade must not fail the decode. | 06 §Disk cache |
