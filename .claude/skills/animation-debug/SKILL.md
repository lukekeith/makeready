---
name: animation-debug
description: Diagnose iPhone app (SwiftUI) transition/animation bugs — element pops in instead of sliding, doesn't animate with modal, flickers, jitters during drag, appears at final position, animates differently than siblings, or crashes with "setting value during update". Maps the symptom to a known failure class and its proven fix. Use BEFORE attempting any ad-hoc fix to a transition bug in /iphone.
---

# iPhone Animation Debugger

You are diagnosing a SwiftUI transition/animation bug in `/iphone/MakeReady`. This app uses a **custom navigation system** (OverlayManager modals/menus + hand-rolled HStack-offset page sliders), and nearly every transition bug here is a *known, named* failure class with a proven fix. Do NOT invent a novel fix until you have ruled out all ten classes below.

## Step 1 — Identify the failure class from the symptom

Ask (or determine from the report/code) these questions in order:

1. **Is it a crash** with `precondition failure: setting value during update`? → **Class 5**
2. **Does only the tapped element misbehave** (semi-transparent, doesn't move with siblings)? → **Class 1**
3. **Is it jitter/lag during a drag gesture** (finger tracking, swipe-to-dismiss)? → **Class 6**
4. **Does content pop to its final position instead of riding an in-flight slide/modal animation?** This is the big family — narrow it down:
   - Content is inside a `LazyVStack`/`LazyHStack`? → **Class 2**
   - Content arrives from `.task`/async load after the animation starts (`if let` / `if !items.isEmpty` branch flips mid-flight)? → **Class 3**
   - The whole pane appears instantly when a slide-in was expected (HStack slider)? → **Class 4**
   - It's text that *intermittently* appears at final position in a menu/modal? → **Class 8**
   - It's a background layer (gradient, photo, scrim) popping when data loads? → **Class 9**
5. **Two animations fighting** (stutter at start/end, double-motion)? → **Class 7**
6. **A menu/overlay animates on top of an incoming modal** during a dismiss-then-present flow? → **Class 10**
7. None of the above → check the **Additional patterns** section, then read both source docs in full before inventing anything.

## Step 2 — Apply the known fix

> **Unifying root cause for classes 2, 3, 4, 8, 9:** this codebase animates container offsets *manually*. Any **structural view change** (lazy item realization, `if/else` branch flip, un-laid-out text) that happens after the animation transaction starts is inserted OUTSIDE the transaction and lands at its final position. Every fix below works by ensuring content exists and is laid out *before* the animation begins.

### Class 1 — Tapped button animates differently than siblings
- **Cause:** implicit `.animation()` + the button's own pressed-state transaction.
- **Fix:** drive the transition with explicit `withAnimation { ... }` (remove the implicit `.animation()` for this state), and add `.buttonStyle(.plain)` to the triggering button.
- **Exception:** HStack sliders using the two-step pattern (Class 4) *require* the implicit `.animation(value:)` — there, keep it and just add `.buttonStyle(.plain)`.
- Doc: `iphone/.claude/SWIFTUI_TRANSITIONS.md` § Button Animation Conflicts.

### Class 2 — LazyVStack children don't ride the modal slide-up
- **Fix:** use plain `VStack` for modal content that animates in (acceptable < ~50 items). For long lists, keep Lazy and accept/defer the animation instead.
- Doc: SWIFTUI_TRANSITIONS.md § LazyVStack and Modal Animations.

### Class 3 — Async-loaded content pops instead of sliding
- **Diagnostic signature:** dismiss animates correctly but present doesn't; the pane's background/chrome rides while the data-driven content pops; sync-content sibling screens (e.g. a settings pane built from already-loaded state) ride fine. Each affected screen is its own independent Class 3 instance — "all sliders broken" can be N per-page bugs, not one systemic one (this is what the Phase 3.4 group-slider regression turned out to be).
- **Fix — apply the FULL cache-first detail page contract, not just rule 1:**
  1. Pre-populate `@State` synchronously in `init` from the AppState/ImageCache cache via `State(initialValue:)` (`isLoading` starts true only when cache was empty), so content renders from frame 1.
  2. Guard the load function: set `isLoading = true` / assign the error state ONLY when there is nothing to display — otherwise the `.task` refresh flips the body back to the spinner branch mid-slide and the pop returns even with a warm cache.
  3. If the data has no AppState cache, create one: in-memory dict on AppState + write-through in the Action + (ideally) prefetch in the parent page so the first tap is warm.
- For images: use `CachedAsyncImage` (it pre-populates from `ImageCache.shared.cachedImage(for:)` in init).
- Reference implementations: `GroupMembersPage.swift` (rules 1+2), `GroupInvitePage.swift` (rule 3 — `groupInvitesByGroupId`), `EnrollmentsListPage.swift`, `GroupHomePage.swift` (parent prefetching), `ProgramHomePage.swift`, `SelectStudyProgramPage.swift`, `Utilities/CachedAsyncImage.swift`.
- Docs: SWIFTUI_TRANSITIONS.md § Pre-loading Content; SWIFTUI_ANIMATION_PATTERNS.md § Synchronous Cache Pre-Population.

### Class 4 — Slide-in appears instantly (HStack slider)
- **Cause:** content state + visibility state changed in the same update cycle — view is inserted already at its final offset.
- **Fix (two-step pattern):** set content synchronously, flip visibility on the next tick:
  ```swift
  editingItem = item                      // step 1: content (sync)
  DispatchQueue.main.async { showEditPage = true }  // step 2: slide (next tick)
  ```
  Dismiss is the reverse: flip visibility first, clear content after the animation completes (prefer `withAnimation(...) { } completion: { }` over `asyncAfter(0.35)`).
- **Requirements:** keep `.animation(.easeInOut(duration: 0.3), value: showEditPage)` on the HStack; do NOT add `.opacity()` to the sliding pane; add `.id(item.id)` to the edit pane.
- Reference: `EditDay.swift`. Doc: SWIFTUI_TRANSITIONS.md § HStack Slide Transitions.

### Class 5 — "setting value during update" crash
- **Fix:** initialize `@State` in `.onAppear` (not `.task`); build the value in a local variable and assign once; wrap `.onPreferenceChange` mutations in `DispatchQueue.main.async`.
- Doc: SWIFTUI_TRANSITIONS.md § State Initialization Crashes.

### Class 6 — Jitter/lag during drag
- **Fix checklist (all five):** `@GestureState` not `@State`; `coordinateSpace: .global`; `transaction.animation = nil` inside `.updating`; no `DispatchQueue.main.async` in gesture handlers; `.compositingGroup()` applied immediately before `.offset()`.
- Reference: `SwipeableCard.swift`, `ManagedModalView` in `OverlayManager.swift`. Doc: SWIFTUI_ANIMATION_PATTERNS.md § Gesture Handling.

### Class 7 — Mixed/competing animation curves
- **Fix:** one animation block per transition. Modal/menu chrome must go through the `ModalAnimations` utility (`Utilities/ModalAnimations.swift`); never run parallel `withAnimation` blocks with different curves (easeOut + spring); consolidate duplicate `.animation(value:)` modifiers watching the same value into ONE at container level.
- Doc: SWIFTUI_ANIMATION_PATTERNS.md § Animation Curves, § Consolidate `.animation()` Modifiers.

### Class 8 — Text intermittently appears at final position in menus/modals
- **Cause:** animation starts in `.onAppear` before the text's layout pass completes.
- **Fix:** defer the animation start by one run loop (`DispatchQueue.main.async` inside `.onAppear`). Already applied in `ManagedModalView`/`ManagedMenuView` — if you see this in a custom overlay, it's missing the deferral.
- Doc: SWIFTUI_ANIMATION_PATTERNS.md § Deferred Animation Start.

### Class 9 — Background layer pops mid-animation when data loads
- **Fix:** decompose backgrounds by lifecycle. Unconditional layers (base color, gradient, scrim) must live OUTSIDE any `if/else` so they render from frame 1; only the data-dependent layer (photo, initials) stays conditional — and it pops in *behind* the gradient, so it's invisible.
- Doc: SWIFTUI_ANIMATION_PATTERNS.md § Decompose Background Layers in Modals.

### Class 10 — Menu animates above the incoming modal
- **Cause:** dismiss + present fired simultaneously.
- **Fix:** `overlayManager.dismiss(id:)` (instant), then present. Prefer sequencing via animation completion handlers over `asyncAfter(0.35)` wall-clock waits.
- Doc: `MakeReady/Components/Layout/MODAL_GUIDE.md` § Common Mistakes #3.

## Additional patterns (not in the 10 classes)

- **matchedGeometryEffect stutter:** never wrap its state change in `withAnimation` (use a container-level `.animation(value:)`); never put `.shadow` inside the matched view — hoist it to the static container.
- **Expensive shadows on animated views:** use `.optimizedShadow(...)` (`Utilities/OptimizedShadow.swift`) instead of `.shadow`.
- **Cards inside `SwipeableCard`:** no `.animation()`/`.transition()` modifiers on card content — they animate independently during swipe.
- **Preview won't type-check while debugging:** see `iphone/.claude/SWIFTUI_PREVIEW_ERRORS.md`.

## Step 3 — Verify and record

1. State which class you diagnosed and why, citing the matching doc section.
2. Apply the fix; run the `/transition-review` skill on your diff before committing.
3. **If you discovered a genuinely new failure pattern** (none of the 10 classes + additional patterns matched): after fixing it, append it to `iphone/.claude/SWIFTUI_TRANSITIONS.md` or `SWIFTUI_ANIMATION_PATTERNS.md` (whichever fits) AND add it to this skill — the docs and this skill must stay in sync.
