# iPhone Structural Plan — Progress & Session Handoff

> Companion to [iphone-2026-06-10-plan.md](./iphone-2026-06-10-plan.md) (the phase definitions) and
> [../plans/media-2026-06-10.md](../plans/media-2026-06-10.md) (media-at-scale plan).
> Update this file at every phase/step boundary. Last updated: **2026-06-11 (session 5 —
> slider regression root-caused as per-page Class 3 and fixed everywhere [cache-first
> contract, codified in skills]; 3.6d/3.7/3.8/3.9/3.10 shipped and device-verified.
> PHASE 3 COMPLETE; media M0+M1 SHIPPED (M0.2/M0.4 folded into M2); Phase 5 enforcement
> layer LIVE (5.1–5.4, 5.6 done; baseline 2,449→1,172); Decision Point A RESOLVED (error
> banner shipped). Remaining: 5.5 fixtures, 5.7 model splits, formatter pass, Decision
> Points B–D, hex-catalog design pass, media M2/M3, 250k cursor benchmark)**.

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
| 3.4 — Migrate remaining sliders (7 pages, incl. 1 audit miss) | ✅ **Done — regression resolved, full hand-feel checklist verified on device.** Root cause was per-page Class 3 (NOT SlideStack): detail pages loaded in `.task` popped mid-slide once 3.4 made them mount on demand. Fixed with the cache-first contract on GroupMembersPage/GroupInvitePage/EnrollmentsListPage/EnrollmentSchedulePage; all other slider-hosted pages audited clean. | `9b8dfe0`…`fa0f64e`, fixes `8b34f45`+`6023d94`, contract codified `4159876` |
| 3.5 — `/push-page` skill | ✅ Done, **committed** | `8c65369` |
| 3.6a+3.6b — Route enum + route-keyed OverlayManager API (additive) | ✅ Done, **committed**, build + 65 tests green. Zero behavior change (legacy `OverlayID` + string API untouched). Design: [iphone-route-enum-2026-06-11-design.md](./iphone-route-enum-2026-06-11-design.md) | `de2244c` |
| 3.6c — lazy `OverlayItem.content` | ❌ **REJECTED** — implemented + built green, but caused the slider regression (rebuilt overlay content every render). **Reverted; do not reattempt as written.** See ACTIVE PROBLEM. | reverted (was uncommitted) |
| 3.6d — migrate 96 call sites to Route | ✅ **Done — user build green, overlay flows spot-checked on device** (menus, confirmation overlay, member-requests push, schedule-modal tap-outside, block pickers). Capture suite not re-run (overlay changes are capture-blind anyway — see session learnings). Prep commit corrected Route's chrome/priority to match live call sites (unenrollOptions=modal, stylePicker=menu, addActivityMenu+confirmationOverlay=raw, memberRequests=page) and folded `dismissOnTapOutside` into Route. Dynamic per-entity ids (GlobalSearchPage lesson/video modals, blockStyleColorPicker, shareInviteDemo) stay on the string API by design. | `71f3aee`, `2a49833`, `1dda16b`, `bdaee28`, `eee75cd`, `37dec9d` |
| 3.7 — `/present-overlay` skill | ✅ Done (skill + MODAL_GUIDE rewritten for Route; /transition-review D1/D2 + iphone CLAUDE.md synced) | `4db862b` |
| 3.8 — NavigationCoordinator | ✅ **Done — build green, deep links + KPI jumps device-verified.** Typed NavDestination + exhaustive handle(deepLink:); MainView tab state migrated; coordinator in environment. The 106-flag presentation-boolean migration happens opportunistically with future page work (by design, see NavigationCoordinator.swift header). | `dfc5438` |
| 3.9 — `/nav-route` skill | ✅ Done | `cd2bdbf` |
| 3.10 — Cleanup sweep | ✅ **Done — build green, sheets/pickers device-verified post-NavigationStack.** Deleted ContentView/ModalOverlay/BackgroundPickerModal/InlineColorPalette + BlockStyleEditor dead grid. 2 forbidden fullScreenCovers stay (Decision Point B). **Phase 3 (3.1–3.10) is COMPLETE.** | `488afcd` |
| 5.1 — SwiftLint gate | ✅ **Done — build green, lint phase runs in Xcode** (sandboxing did not block it). Baseline now 1,172 after the 5.3/5.4 burn-down; gate fails builds only on NEW violations. | `4074c1a` |
| 5.2 — os.Logger wrappers | ✅ Done — build green. `Log.<domain>` (auth/state/nav/media/api/push/ui/bible); NSLog migration is opportunistic. | `443b975` |
| 5.3 — Color token consolidation | ✅ Done — build green, screens visually identical. 278 sites → existing Colors.swift tokens (exact-value match only). **Cataloged, unchanged (no matching token — needs a design pass):** 146 sites / 49 distinct hexes, top: #47d4ff×16, #ff4444×10, #ff6b9d×9, #ffd93d×7, #ef4444×6, #4ade80×6, #3b82f6×5, #dc2626×5, #ffaa00×5, #7c7cff×5, #485470×4, #234d2e×4. | (with 5.4 commit) |
| 5.4 — Typography tokens | ✅ Done — build green, screens visually identical. Generated `Typography.swift` (61 tokens, systematic size+weight names at current fixed sizes); 999 literal sites migrated; 24 dynamic-form sites (computed sizes / conditional weights) stay baselined. Formatters (54) deferred — need per-file static+`Self.` surgery, not regex-safe. Baseline: 2,449 → 1,172. CLAUDE.md teaches tokens now. | — |
| 5.5, 5.7 — fixtures behind #if DEBUG, model splits | ⬜ Not started | — |
| 5.6 — Error surface + `/ios-error-surface` skill | ✅ **Done — build green, banner verified on device.** Decision Point A RESOLVED (top banner, user-initiated only, 4s auto-dismiss + swipe-up, optional retry). ErrorBanner/ErrorBannerHost shipped + 2 exemplar adoptions in GroupHomePage (save failure with retry, enrollment-create failure — was a TODO). Remaining catch blocks adopt opportunistically via the skill. | — |
| M0–M3 — Media at scale | ⬜ Planned (`docs/plans/media-2026-06-10.md`); M0.1 is urgent | — |

## ✅ CLOSED — slider regression (fixed, device-verified, committed `8b34f45`+`6023d94`)

> **Resolution (2026-06-11, Fable session):** Device retest WITHOUT 3.6c still showed the
> bug → not 3.6c. Dismiss animated correctly while present didn't → not SlideStack's
> two-step timing either. Root cause: **independent Class 3 instances in each detail
> page** — GroupMembersPage / GroupInvitePage / EnrollmentsListPage all loaded in
> `.task` with an `if isLoading` branch, so content was structurally inserted
> mid-slide at final position (3.4 made them mount-on-demand; they were always-mounted
> before). Fix (uncommitted, 5 files): full cache-first contract per page (init
> pre-population + guarded spinner/error), new in-memory `groupInvitesByGroupId`
> AppState cache written by `loadGroupInvite`, invite prefetch in GroupHomePage.
> **User-verified on device: all group-page sliders ride correctly.** 3.6c remains
> rejected (its revert was necessary but unrelated to this bug — it had its own
> rebuild-every-render breakage). The contract is now codified in
> SWIFTUI_TRANSITIONS.md § Pre-loading Content and enforced by `/push-page` (rule 2),
> `/transition-review` (B2a/B2b/B2c + diff-scope expansion), `/animation-debug` (Class 3).
> Remaining: run the 3.4 hand-feel checklist below (nested flows unaudited), update the
> route-enum design doc to mark 3.6c rejected-with-rationale, then commit (ask first).

### Original handoff (kept for context)

> Use the `/animation-debug` and `/transition-review`
> skills. **Build/commit require explicit user permission** (`iphone/.claude/CLAUDE.md`,
> absolute rule — ask before any `xcodebuild`/simulator/`git commit`).

### The bug (user report, verbatim intent)
On a physical iPhone (built from Xcode), opening the **Group modal** then tapping the
**members icon** at the top: the members screen does **not** slide in. Its elements
**suddenly appear at their final positions** while only the **current (primary) view slides
left underneath them**. User confirmed this is **consistent for ALL sliding views**, not
just GroupHomePage. Expectation: *all elements of both the incoming and outgoing screens
must move together with their containers* (the whole pane rides the slide).

This is the **content-doesn't-ride-the-slide** family (`/animation-debug` Class 3/4): the
detail pane is not laid out before the offset animation starts, so its content materializes
mid-flight at final position while the container offset animates.

### Git state RIGHT NOW
- Last **app-code** commit = `de2244c` (3.6a+3.6b). There are **no uncommitted app-code
  changes** — the only commits after it are this handoff's doc updates. `git status` should
  show a clean tree (or only `docs/` if not yet committed).
- **3.6c was reverted** before this handoff. `MainView.swift:142` is back to `item.content`
  (stored `AnyView`), `OverlayItem.content` is back to a stored `AnyView` (not a closure).
  Confirm with: `git diff 7915e95 HEAD -- iphone/MakeReady/Services/OverlayManager.swift`
  (there should be NO `() -> AnyView` in `OverlayItem`).
- So the build the user is about to make does **NOT** contain 3.6c.

### Leading hypothesis (~80%): 3.6c was the cause — now reverted
3.6c changed `OverlayItem.content` from a stored `AnyView` to `() -> AnyView` evaluated by
`MainView`'s `ForEach` **every render pass**. Every slider page is presented as an
OverlayManager modal, so during a slide the whole overlay tree (incl. the `SlideStack`)
was being rebuilt each frame → broke the two-step insertion's layout-before-slide timing →
content lands at final position. Evidence it's 3.6c and not SlideStack:
1. `git diff 7915e95 HEAD -- …/SlideStack.swift` shows the two-step mechanism is **unchanged**
   since the 3.3 pilot — only `detailEdge`/Bool-convenience were added.
2. The 3.3 EditDay pilot (a SlideStack **inside the ProgramHome modal**) was hand-feel
   verified working — so overlay-hosted SlideStack worked *before* 3.6c.
3. 3.6c is the only change since 3.3 that touches the overlay render path, and it hits
   every overlay uniformly → matches "all sliding views."

### → FIRST ACTION: confirm the hypothesis
Ask the user to **rebuild from Xcode (current clean tree, no 3.6c)** and retest:
group → members icon, **and** program-home → tap a day. Then branch:

- **Sliders now ride correctly** → 3.6c confirmed as the culprit. It's already reverted.
  **Recommendation: drop 3.6c permanently** (its lazy-content premise backfired; 3.6a/3.6b
  stand alone). Update `iphone-route-enum-2026-06-11-design.md` to mark 3.6c
  *rejected-with-rationale*, set the 3.6c table row here to ❌ final, then proceed to the
  remaining 3.4 hand-feel checklist below, then 3.6d / 3.7+.

- **Still broken with 3.6c gone** → it's a **pre-existing 3.4 bug** (those 7 sliders were
  committed build-green but NEVER hand-feel verified — only the 3.3 EditDay pilot was). Root
  cause is then in `SlideStack`'s two-step insertion
  (`iphone/MakeReady/Components/Layout/SlideStack.swift`, the `.onChange(of: item)` block):
  the single `DispatchQueue.main.async` hop fires `withAnimation { slid = true }` before the
  freshly-mounted `detailPane` has completed layout, so heavy detail content isn't laid out
  when the offset animates. Fix options to evaluate (run `/animation-debug` Class 4 first):
  (a) wait for the detail's first layout before sliding (e.g. trigger the slide from the
  detail pane's `.onAppear`/a geometry-confirmed signal rather than a blind one-runloop hop);
  (b) double-hop the deferral as a stopgap (fragile — last resort);
  (c) keep the detail pane mounted at a fixed offscreen frame so it's always pre-laid-out,
  and animate only the offset. Whatever the fix, it lives in `SlideStack` (systemic), NOT
  per-page. Verify against the full 3.4 hand-feel checklist + `/transition-review` before commit.
  Note: `EnrollmentSchedulePage` already hand-rolls a related guard (`readyToShowContent`,
  0.5s `isModalRoot` gate) for "loaded content pops in clipped during modal open" — reference
  it, don't duplicate it.

### Key files
- `iphone/MakeReady/Components/Layout/SlideStack.swift` — the canonical slider; two-step
  insertion is in `body`'s `.onChange(of: item)` (mount `mountedItem`, then async
  `withAnimation { slid = true }`). `detailPane(width:)` renders the mounted detail.
- `iphone/MakeReady/MainView.swift:140-144` — overlay render loop (`item.content`).
- `iphone/MakeReady/Services/OverlayManager.swift` — `OverlayItem` (stored `AnyView`),
  `present/presentModal/presentMenu/presentPage`. (3.6c had changed `OverlayItem.content` to
  a closure here — reverted.)
- Slider call sites (all overlay-hosted): `GroupHomePage`, `ProgramHomePage`,
  `EnrollmentSchedulePage`, `EnrollmentsListPage`, `EditEnrollmentDay`, `EditReadActivityPage`,
  `CreateProgramPage`, `EditDay` (pilot). See the Phase 3.4 table below for commits.

---

## ▶ Remaining 3.4 hand-feel checklist (run after the slider bug is resolved)

Every flow below, slide must be `Motion.standard` both directions; `/animation-debug` maps
any symptom → failure class:
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
- **Dead code from the LazyVGrid sweep: DELETED in 3.10** (`488afcd`): `BackgroundPickerModal.swift`
  (its `EditBlockBackgroundPage` had zero construction sites — absorbed by inline
  BlockStyleEditor), `InlineColorPalette.swift`, `ModalOverlay.swift`, `ContentView.swift`,
  and `BlockStyleEditor.colorPickerGrid` + its exclusive helpers.
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

- **Builds/commits REQUIRE explicit per-request permission** (`iphone/.claude/CLAUDE.md` —
  absolute, zero-exceptions rule for any `xcodebuild`/simulator/`git commit`). Earlier
  sessions had an informal "standing go"; **do not assume it** — ask each time. Every step is
  an atomic commit (30 commits so far this effort, see `git log`).
- **3.6c lesson (capture is blind to overlays):** the `/capture` suite renders `ViewRegistry`
  views directly and never goes through `OverlayManager`, so `sortedOverlays` is empty during
  capture and any change to the overlay render path (like 3.6c) shows a CLEAN capture diff
  while still being broken on device. Overlay/slider changes can ONLY be verified by
  interactive hand-feel, never by capture. Build-green + tests-green + capture-clean did NOT
  catch the 3.6c regression — a human on a device did.
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
