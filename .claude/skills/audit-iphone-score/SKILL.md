---
name: audit-iphone-score
description: Re-score the iPhone app against the 2026-06-10 architecture audit's criteria and produce an updated scorecard. Use when asked for the latest/current audit score, to verify the audit-plan work landed, or to re-audit the iPhone app. Designed to run in a FRESH session with no prior context.
---

# iPhone Audit Re-Score

You are re-scoring `/iphone/MakeReady` against the baseline audit. Produce a
new scorecard with evidence, comparing baseline → target → current.

## Inputs (read these first, in order)

1. `docs/audit/iphone-2026-06-10.md` — the ORIGINAL audit: the **Audit
   Criteria** section defines the criteria and scoring scale; **Scorecard
   (baseline)** has the original scores; **For the Next Audit** has the
   auditor's own re-check notes. Score against THESE criteria, unchanged.
2. `docs/audit/iphone-2026-06-10-plan.md` — the executed plan; its target
   scorecard says what each phase was supposed to move (~2.0 → ~3.8 overall).
3. `docs/audit/iphone-2026-06-10-progress.md` — what actually shipped, with
   commits, deviations, and the deliberately-parked Decision Points.
4. `docs/plans/media-2026-06-10.md` — the media-at-scale work (M0/M1 shipped,
   M2/M3 not).

## Method — verify, don't trust

The progress doc CLAIMS completion; your job is independent evidence from the
CODebase. For each criterion, gather fresh proof (grep counts, file reads,
spot-checks) — examples of evidence that distinguishes scores:

- Navigation: zero hand-rolled `HStack`+`offset` sliders (`SlideStack` only);
  zero `OverlayID`/string presentation ids except documented dynamic ones;
  `NavigationCoordinator` routes deep links (exhaustive `handle(deepLink:)`).
- State: pages read `AppState.shared` / mutate via Actions; cache-first
  detail-page contract adoption; error channel + `ErrorBanner` exist.
- Code quality: `.swiftlint.yml` + baseline count (`cd iphone && swiftlint
  lint --quiet | wc -l` — was 2,449 at gate creation, ~1,118 after
  migrations); tokens (`Color(hex:` outside Colors.swift, `.system(size:`
  outside Typography.swift — compare against the audit's counts); dead code
  named in the audit actually deleted; fixtures/`Pages/Demo` behind
  `#if DEBUG`; `Log` wrappers exist (NSLog migration is opportunistic — score
  accordingly).
- Media: M0.1/M0.3/M0.5 + M1 cursor paging shipped (see media plan doc for
  benchmark results); M0.2/M0.4 folded into M2 (NOT shipped); M2/M3 not done
  — criterion 3 (Photos-target UI) should NOT score as if they were.

To keep context lean, fan out per-criterion evidence gathering to parallel
Explore agents and synthesize their findings.

## Known NOT-done (don't let the docs' completeness oversell)

Decision Points B (fullScreenCover forms), C (Dynamic Type + accessibility),
D (motion consolidation); 49 cataloged unmatched hexes; ~800 baselined NSLog
sites; 106→<30 presentation-boolean migration is opportunistic and mostly
NOT done; media M2/M3; `mockContacts` wiring in InviteContacts/SearchContacts
pages. Cap affected criteria accordingly (the plan itself says full marks on
criterion 6 need Decision Point C).

## Output

Write `docs/audit/iphone-<today>-rescore.md`:
1. Scorecard table: # | Criterion | Baseline | Plan target | **Current** |
   Evidence (file:line / grep counts) — same criteria and scale as the
   original.
2. Per-criterion notes: what moved the score, what caps it.
3. "To reach the next half-point" list per criterion (should largely be the
   parked Decision Points / M2).
4. Honest overall score (the plan projected ~3.8–3.9 with everything except
   Decision Points landed).

Report the scorecard table and overall to the user in chat. Do not build or
run the simulator (project rule: builds need explicit user permission).
