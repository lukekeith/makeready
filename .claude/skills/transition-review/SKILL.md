---
name: transition-review
description: Pre-commit review for iPhone app (SwiftUI) animation/transition code. Run on any /iphone diff that touches withAnimation, .animation(, .transition(, offset(, DragGesture, matchedGeometryEffect, fullScreenCover, sheet, presentModal/presentMenu, or DispatchQueue asyncAfter. Checks the diff against the codebase's known animation failure classes and modal conventions, and reports PASS/FAIL per rule with file:line.
---

# iPhone Transition Review

You are reviewing a diff in `/iphone/MakeReady` for animation/transition correctness. This codebase has ten documented, recurring animation failure classes (see `iphone/.claude/SWIFTUI_TRANSITIONS.md`, `iphone/.claude/SWIFTUI_ANIMATION_PATTERNS.md`, `MakeReady/Components/Layout/MODAL_GUIDE.md`). Your job is to catch violations BEFORE they ship — every rule below exists because the bug it prevents has already happened in this app.

## Step 1 — Scope the review

Get the changed Swift files (`git diff` / `git diff --staged`, or the files the current session edited). Only review files under `iphone/`. If none of the trigger patterns below appear in the diff, report "no transition-relevant changes" and stop.

Trigger patterns: `withAnimation`, `.animation(`, `.transition(`, `.offset(`, `DragGesture`, `@GestureState`, `matchedGeometryEffect`, `.fullScreenCover`, `.sheet(`, `presentModal`, `presentMenu`, `present(.`, `asyncAfter`, `.shadow(`, any lazy container (`LazyVStack`, `LazyHStack`, `LazyVGrid`, `LazyHGrid` — grep `LazyV\|LazyH`), `.task {`.

## Step 2 — Check every applicable rule

For each rule: inspect the diff (and enough surrounding file context to judge), then record PASS / FAIL / N/A with `file:line` evidence. **Read the surrounding code — several rules depend on context the diff alone won't show** (e.g., whether a container animates in, whether a duplicate `.animation` exists elsewhere in the file).

### A. Animation drivers
- **A1 — No mixed curves in one transition.** Parallel `withAnimation` blocks (or `withAnimation` + implicit `.animation`) with different curves (e.g., easeOut + spring) on the same visual transition. Modal/menu chrome must use `ModalAnimations` (`Utilities/ModalAnimations.swift`).
- **A2 — No duplicate `.animation(value:)` modifiers watching the same value** in one hierarchy. One, at container level.
- **A3 — User-triggered transitions use explicit `withAnimation`** — EXCEPTION: HStack slide panes using the two-step pattern keep their single implicit `.animation(value:)` on the HStack (it must catch the deferred state change). Flag removal of that modifier as a FAIL too.
- **A4 — Buttons that trigger transitions have `.buttonStyle(.plain)`.**
- **A5 — No `withAnimation` wrapping state changes for `matchedGeometryEffect`** (container-level `.animation(value:)` instead).

### B. Structural-identity hazards (content must exist before the animation starts)
- **B1 — No lazy containers (`LazyVStack`/`LazyHStack`/`LazyVGrid`/`LazyHGrid`) inside content that animates in** with a modal/menu/slider. Plain `VStack` for < ~50 items; for grids, a `VStack` of `HStack` rows chunked by column count (reference: `BlockStyleColorPickerContent`). Grep `LazyV\|LazyH` — checking only "LazyVStack" is how a `LazyVGrid` color picker shipped broken. Sanctioned exception: cells opacity-gated behind an `appeared` flag that fade in after the menu settles (`AddActivityMenu`). Before flagging, confirm the container is live code (referenced), not a dead duplicate.
- **B2 — Pages inside an animated container follow the cache-first detail page contract** (SWIFTUI_TRANSITIONS.md § Pre-loading Content). Three independent checks, each a FAIL on its own:
  - **B2a** — display state is pre-populated from cache in `init` via `State(initialValue:)`, with `isLoading` starting true only when the cache was empty.
  - **B2b** — the load function never sets `isLoading = true` or assigns the error state *unconditionally*; both are guarded by "is there nothing to display?" (an unguarded `isLoading = true` at the top of a load function re-pops the content even with a warm cache; an unguarded error assignment replaces displayed content with the error screen on a background refresh failure).
  - **B2c** — data that has no AppState cache gets one (in-memory dict + Action write-through, optionally parent prefetch — `GroupInvitePage`/`groupInvitesByGroupId` is the reference), rather than a bare fetch-and-return.
  Images in animated containers use `CachedAsyncImage`, not `AsyncImage`.
  **Scope expansion (mandatory):** if the diff newly hosts a page inside a SlideStack detail / overlay — even by only changing the call site or wiring — review THAT PAGE's loading pattern against B2a/B2b too, even though the page file isn't in the diff. The hazard lives in the hosted page; reviewing only the wiring is how the Phase 3.4 regression shipped review-green.
- **B3 — HStack sliders use the two-step pattern** (content set sync, visibility flipped next tick; reverse on dismiss) and the sliding pane has `.id(item.id)`. No `.opacity()` on a sliding pane.
- **B4 — Always-visible background layers (base color, gradient, scrim) are NOT inside `if/else`** conditionals that flip when data loads.
- **B5 — No `@State` mutation inside `.task`** for initialization (use `.onAppear`, build locally, assign once).

### C. Gestures
- **C1 — Drag tracking uses `@GestureState`** (not `@State`), with `transaction.animation = nil` in `.updating` and `coordinateSpace: .global`.
- **C2 — No `DispatchQueue.main.async` inside gesture handlers.**
- **C3 — `.compositingGroup()` applied before `.offset()`** on composite views that drag or slide.
- **C4 — No `.animation()`/`.transition()` on content inside `SwipeableCard`.**

### D. Presentation conventions (MODAL_GUIDE)
- **D1 — New modals/menus use `overlayManager.present(.route)`**, not `.fullScreenCover`/`.sheet` (the string-keyed `presentModal(id:)`/`presentMenu(id:)` API is reserved for dynamic per-entity ids). Allowed exceptions ONLY: camera/video recording, video playback, photo/media pickers, UIKit VCs that must present modally.
- **D2 — New overlay has a registered `Route` case** in `Services/Route.swift` (id arm + only-if-non-default priority/chrome/dismissOnTapOutside arms — never passed at the call site), and content dismisses via the `dismissOverlay`/`dismissOverlayThen` environment actions (or a documented wrapper for `isPresented`-based views). The `/present-overlay` skill scaffolds this.
- **D3 — No simultaneous dismiss + present.** Sequenced via instant `dismiss(id:)` then present, or an animation completion handler.
- **D4 — Menu/modal content contains no chrome** (no own dark overlay, offset animation, or background — `ManagedMenuView`/`ManagedModalView` provide it).

### E. Choreography & motion values
- **E1 — No NEW `asyncAfter` for navigation choreography** (dismiss-then-present waits, post-animation cleanup). Use `withAnimation(_:) { } completion: { }` (iOS 17+) instead. Pre-existing `asyncAfter(0.35)` sites are grandfathered — flag only additions.
- **E2 — No new magic durations that must match a duration defined elsewhere** (e.g., a hand-rolled `0.35` that mirrors `ModalAnimations` dismiss). Once a `Motion` token enum exists in the codebase, all new durations/curves must use it — check for it before flagging.
- **E3 — Forward and back navigation of the same state use the same duration/curve.**

### F. Performance on animated views
- **F1 — No raw `.shadow` on views that animate** (use `.optimizedShadow`); never a shadow inside a `matchedGeometryEffect` view.

### G. New navigation surface (architecture guard)
- **G1 — No NEW hand-rolled HStack + `offset(x:)` page slider.** If the diff introduces a new multi-pane slide navigation, it must reuse an existing canonical container (`SlideStack` once it exists; until then, copy the `EditDay.swift` pattern exactly and note it for future migration). New one-off navigation mechanisms are a FAIL.

## Step 3 — Report

Output a table: Rule | Verdict | Evidence (file:line) | Fix. Then a verdict line:

- **BLOCK** — any FAIL in sections A–D or G (these are the documented recurring bugs). State the exact fix per failure, citing the doc section (the `/animation-debug` skill maps each rule to its failure class and fix recipe).
- **WARN** — FAILs only in E/F. List them; committing is acceptable with justification.
- **PASS** — everything green or N/A.

If you find a violation pattern that none of these rules covers but that caused a visible animation bug, add the rule to this skill and the matching doc (`SWIFTUI_TRANSITIONS.md` / `SWIFTUI_ANIMATION_PATTERNS.md`) as part of the fix.
