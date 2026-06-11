# iPhone Structural Plan — Progress & Session Handoff

> Companion to [iphone-2026-06-10-plan.md](./iphone-2026-06-10-plan.md) (the phase definitions) and
> [../plans/media-2026-06-10.md](../plans/media-2026-06-10.md) (media-at-scale plan).
> Update this file at every phase/step boundary. Last updated: **2026-06-10 (end of session 2)**.

## Status at a glance

| Phase | Status | Commits |
|---|---|---|
| 0 — Safety net + skills | ✅ Done (session 1) | `22747b1` |
| 1 — Tier 0 quick wins | ✅ Done (session 1) | `89b62a9` |
| 2 — Compiler-enforced state layer (all 8 steps) | ✅ Done, build + 65 tests green, capture-verified | `e5e389a`…`5ca7152`, fallout `9af9e7b`, deprecation fix `2d1afb4` |
| 4 — Media structural pass (all 7 steps) | ✅ Done (ran before Phase 3; plan allows parallel) | `fbe8e69`…`63c3a4d` |
| 3.1 — Motion tokens | ✅ Done (117 sites, machine-verified value-identical) | `bfd0d4c` |
| 3.2 — Completion-based sequencing | ✅ Done (14/17 waits migrated; 3 triaged, see below) | `74cdb8e` |
| 3.3 — SlideStack + EditDay pilot | ⚠️ **Committed but awaiting HAND-FEEL verification** | `7915e95` |
| 3.4 — Migrate remaining sliders | ⬜ Next (blocked on 3.3 hand-feel) | — |
| 3.5–3.10 — Skills, Route enum, NavigationCoordinator, cleanup | ⬜ Not started | — |
| 5 — Enforcement layer | ⬜ Not started | — |
| M0–M3 — Media at scale | ⬜ Planned (`docs/plans/media-2026-06-10.md`); M0.1 is urgent | — |

## ▶ First action on resume

**Hand-feel verify the SlideStack pilot** before any 3.4 work (the remaining sliders copy this pattern):
1. Program → day → tap an activity: edit pane slides in, content fully present during the slide (no pop-in)
2. Cancel and Save: identical slide-out, no flash at unmount
3. Add an exegesis activity: jumps straight into its editor
4. Menu flow (User menu → My Profile): modal appears the instant the menu closes
If anything feels off, `/animation-debug` maps symptom → failure class; the slide must be `Motion.standard` both directions.

## Phase 3.4 worklist (one commit per slider)

Pilot pattern established in `EditDay.swift` (see commit `7915e95`): replace the page's
show-flag + GeometryReader/HStack/offset/`.animation` + asyncAfter unmount with
`SlideStack(item:)`; detail content must build from the **mounted** item the builder
receives, never from page state that nils at dismissal.

Migration order (audit 3.4): `EditEnrollmentDay` (has the same `dismissEditActivity`
asyncAfter, already comment-flagged) → `EnrollmentSchedulePage` → `EditReadActivityPage` →
`CreateProgramPage` → `ProgramHomePage` (nested opacity-swap third screen — may need a
SlideStack variant or configuration) → `GroupHomePage` **last** (inverted screen-0-on-the-left
quirk; preserve via configuration, don't "fix"). Run `/transition-review` on every diff.

## Triage decisions already made (don't re-litigate)

- **3 surviving `asyncAfter(0.35)` sites:** `EditDay`+`EditEnrollmentDay` `dismissEditActivity`
  (absorbed by SlideStack migration — EditDay's is already gone) and `ModalOverlay.swift`,
  which is **dead code** (zero call sites) — delete the whole file + pbxproj entries in 3.10.
- **2.4 deviation:** BibleSearchService/BibleCacheManager/InviteQRCodeView stay on URLSession —
  the server intentionally serves `/api/bible/*`, `/api/search/smart|suggestions`,
  `/api/qrcode/test` without auth, and APIClient hard-requires a session cookie. Documented in
  `iphone/.claude/CLAUDE.md` sanctioned-exceptions list.
- **4.3 deviation:** the media grid keeps full `fetch(url:)` — its `-md` sources are already
  400px and MediaDetailOverlay's instant zoom depends on a warm hit of that exact cache key.
  `fetch(url:maxPixelSize:)` exists; first consumer is VideoLibraryPage (600px cap).
- **Capture baseline:** refreshed at `6d3da4e`; the 27 original diffs were stale-baseline
  artifacts of product commits, not refactor regressions. PNGs drift a few hundred bytes per
  re-record (encoder noise) — visually compare before treating byte-diffs as regressions.
- **Decision Points A–D** (audit plan) remain open: error-surface UI, the 2 fullScreenCover
  forms, Dynamic Type, motion-value consolidation.

## Session learnings (will bite again if forgotten)

- **Builds/commits:** user granted standing "go" for build-verify cycles during phase work;
  every step is an atomic commit (28 commits so far this effort, see `git log`).
- **Swift 5 language mode:** default arguments evaluate *nonisolated* — `state: AppState = .shared`
  on a @MainActor type does NOT compile. Use `state: AppState? = nil` + `stateOverride ?? .shared`
  in a @MainActor computed property (pattern in every Actions struct).
- **SourceKit diagnostics in this repo are false positives** ("No such module UIKit",
  "Cannot find type X") — the LSP lacks project context. `xcodebuild` is the only oracle.
- **New files need manual pbxproj registration** (no synchronized groups): 4 entries —
  PBXBuildFile, PBXFileReference, group child, Sources phase. Pattern: copy an adjacent file's
  entries (done for OrgActions, InviteActions, StubAPIClient, ActionStubTests, Motion, SlideStack).
- **Unit test invocation** (58→65 tests, all green):
  `xcodebuild test … -only-testing:MakeReadyCaptureTests/<EntityStoreTests|RelationshipIndexTests|StatePersistenceRoundTripTests|ModelDecodingTests|BibleVerseContentNormalizerTests|ActionStubTests>`
  (excluding `CaptureRunner`, which records screenshots).
- **Foundation drift:** `.iso8601` now ACCEPTS fractional-second dates on the current
  simulator runtime; `ModelDecodingTests` documents the new reality.
- **Build number auto-increments** on every build (run-script phase) — commit `Info.plist`
  bumps rather than fighting them.

## Media-at-scale (after Phase 3, or interleaved)

`docs/plans/media-2026-06-10.md`: orgs will hold 10k–1M+ items. **M0.1 (cap the persisted
media snapshot at one page) is the urgent guardrail** — Phase 4.1's pagination made the
unbounded `PersistedState` encode reachable by deep scrolling. M1 (server cursor paging) can
run parallel to Phase 3. M2 (local SQLite index + windowed faulting) before the visible
media redesign (M3).
