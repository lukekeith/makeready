# iPhone Structural Plan — Progress & Session Handoff

> Companion to [iphone-2026-06-10-plan.md](./iphone-2026-06-10-plan.md) (the phase definitions) and
> [../plans/media-2026-06-10.md](../plans/media-2026-06-10.md) (media-at-scale plan).
> Update this file at every phase/step boundary. Last updated: **2026-06-10 (session 3, after 3.4)**.

## Status at a glance

| Phase | Status | Commits |
|---|---|---|
| 0 — Safety net + skills | ✅ Done (session 1) | `22747b1` |
| 1 — Tier 0 quick wins | ✅ Done (session 1) | `89b62a9` |
| 2 — Compiler-enforced state layer (all 8 steps) | ✅ Done, build + 65 tests green, capture-verified | `e5e389a`…`5ca7152`, fallout `9af9e7b`, deprecation fix `2d1afb4` |
| 4 — Media structural pass (all 7 steps) | ✅ Done (ran before Phase 3; plan allows parallel) | `fbe8e69`…`63c3a4d` |
| 3.1 — Motion tokens | ✅ Done (117 sites, machine-verified value-identical) | `bfd0d4c` |
| 3.2 — Completion-based sequencing | ✅ Done (14/17 waits migrated; 3 triaged, see below) | `74cdb8e` |
| 3.3 — SlideStack + EditDay pilot | ✅ Done, hand-feel verified | `7915e95` |
| 3.4 — Migrate remaining sliders (7 pages, incl. 1 audit miss) | ⚠️ **Committed, build + 65 tests green; awaiting hand-feel** | `9b8dfe0`…`fa0f64e` |
| 3.5–3.10 — Skills, Route enum, NavigationCoordinator, cleanup | ⬜ Not started | — |
| 5 — Enforcement layer | ⬜ Not started | — |
| M0–M3 — Media at scale | ⬜ Planned (`docs/plans/media-2026-06-10.md`); M0.1 is urgent | — |

## ▶ First action on resume

**Hand-feel verify the 3.4 migrations** before 3.5+ (every flow below, slide must be
`Motion.standard` both directions; `/animation-debug` maps any symptom → failure class):
1. Group → enrollments (book icon) → tap enrollment → tap a day in the schedule → edit a
   READ/USER_INPUT activity → Cancel and Save. That one path exercises **three nested
   SlideStacks** (EnrollmentsListPage → EnrollmentSchedulePage → EditEnrollmentDay).
2. EnrollmentSchedulePage as **modal** (lesson action menu → Edit activities): content must
   still ride the open slide — `cachedWidth` was dropped; watch for any width jump.
3. Edit READ activity → Edit Themes (now mounts on demand instead of always-mounted).
4. Create program → lands on program home → tap a day (nested SlideStacks; EditDay pane
   previously mounted+slid same-tick — should now slide with content present).
5. Program home → gear (Edit Program) and → tap a day (enum-item SlideStack; the old
   opacity swap is gone).
6. Group home → gear/settings (**enters from the LEFT** — `detailEdge: .leading`), and
   paperplane/person.2/book right screens. These panes were always-mounted before and now
   mount on demand — if any content pops in mid-slide, fix is B2 (cache-first init) in that
   page, not in SlideStack.

## Phase 3.4 — DONE (7 sliders, one commit each)

All hand-rolled sliders are gone; `SlideStack` is the only slide-navigation mechanism:

| Page | Commit | Notes |
|---|---|---|
| EditEnrollmentDay | `9b8dfe0` | absorbed its `dismissEditActivity` asyncAfter(0.35) |
| EnrollmentSchedulePage | `de5c701` | dropped `cachedWidth` (pre-monorepo, no rationale) |
| EditReadActivityPage | `b98e374` | added `SlideStack(isPresented:)` Bool convenience |
| CreateProgramPage | `9d151f6` | nested SlideStacks (form → home → EditDay) |
| ProgramHomePage | `c271241` | `DetailScreen` enum item replaced opacity swap; no variant needed |
| GroupHomePage | `81396ab` | added `detailEdge: .leading` to preserve inverted layout; edge-swipe-back is trailing-only |
| EnrollmentsListPage | `fa0f64e` | **audit miss** found by sweep; had an asyncAfter(**0.3**) the 0.35-grep missed |

**EnrollmentFlowModal: deliberately NOT migrated.** It's a 4-step wizard (`panelIndex`
over conditionally-present panels, bidirectional) — not a primary/detail stack. No unmount
waits. If a second wizard ever appears, that's the trigger for a `SlideFlow` container.

## Triage decisions already made (don't re-litigate)

- **Surviving `asyncAfter` choreography sites after 3.4:** only `ModalOverlay.swift` (0.35),
  which is **dead code** (zero call sites) — delete the whole file + pbxproj entries in 3.10.
  The EditDay/EditEnrollmentDay/EnrollmentsListPage waits were all absorbed by SlideStack.
  (`EnrollmentSchedulePage` keeps its 0.5s modal-open settle wait — that's modal-open gating,
  not slider choreography; candidate for Decision Point work.)
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
