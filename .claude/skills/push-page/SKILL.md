---
name: push-page
description: Scaffold a new horizontal slide sub-screen (primary → detail push navigation) in the iPhone app (SwiftUI). Use whenever adding an in-page "tap a row → slide to an editor/detail and back" flow in /iphone — it generates the SlideStack wiring correctly and FORBIDS new hand-rolled HStack+offset sliders. Use BEFORE writing any HStack/offset/asyncAfter slide navigation.
---

# iPhone Push-Page Scaffolder

You are adding a horizontal **slide sub-screen** to a page in `/iphone/MakeReady` —
the "tap a row, the detail slides in from the right, back-tap slides it out" pattern.

This app has exactly **one** sanctioned mechanism for this:
`MakeReady/Components/Layout/SlideStack.swift` (Phase 3.3). Every page that used
to hand-roll an `HStack { primary; detail }.offset(x:)` slider — with its own copy
of the two-step insertion pattern, an `asyncAfter(0.35)` unmount wait, and an
`.animation` modifier — has been migrated to it. **Do not reintroduce that pattern.**

## Step 0 — Is SlideStack even the right tool?

| You want… | Use | Not this skill |
|---|---|---|
| In-page primary→detail push (row → editor, back) | **`SlideStack`** (this skill) | |
| A bottom action menu (Edit / Delete / Share) | `overlayManager.presentMenu` | see MODAL_GUIDE |
| A form/detail presented OVER the whole app | `overlayManager.presentModal` / `presentPage` | see MODAL_GUIDE |
| A multi-step wizard (N panels, next/back) | **neither** — `panelIndex` over conditional panels (see `EnrollmentFlowModal`). If a *second* wizard ever appears, that's the trigger to build a `SlideFlow` container; don't force it into SlideStack. | |
| Camera / video / photo picker | `.fullScreenCover` (hardware-access exception) | |

If the answer isn't "in-page primary→detail push," stop and use the right mechanism.

## Step 1 — Pick the SlideStack form

**Item-driven** (the detail's content depends on *which* row was tapped — most cases):

```swift
@State private var editingActivityId: String?   // page navigation state

SlideStack(item: $editingActivityId) {
    dayContent                                   // primary pane
} detail: { activityId in
    inlineEditPane(activityId: activityId)       // built from the MOUNTED id
}
```

**Bool-driven** (one fixed second screen, no identity — e.g. a theme editor):

```swift
@State private var showThemeEditor = false

SlideStack(isPresented: $showThemeEditor) {
    readContent
} detail: {
    ThemeEditorPane(...)
}
```

`item` (or `isPresented`) IS the navigation state: non-nil/true presents, nil/false
dismisses. Drive it from a button: `Button { editingActivityId = activity.id }`.

## Step 2 — The non-negotiable rules (these are the bugs SlideStack exists to prevent)

1. **Build detail content from the MOUNTED item the closure hands you, NEVER from
   page state.** The detail builder receives the item that stays mounted through the
   slide-OUT; `editingActivityId` itself nils out the instant you dismiss, so reading
   it inside the detail makes content vanish mid-animation. Pattern (from `EditDay`):
   ```swift
   detail: { activityId in inlineEditPane(activityId: activityId) }   // ✅ uses the arg
   // NOT: detail: { _ in inlineEditPane(activityId: editingActivityId!) }  // ❌ nils mid-slide
   ```
2. **Detail content must be present and laid out BEFORE the slide starts** (this is
   the whole point of SlideStack's two-step insertion). So inside the detail:
   - **No `LazyVStack`/`LazyHStack`** — use plain `VStack` (`< ~50` items). Lazy
     children realize *after* the offset animation begins and land at final position.
   - **Async-loaded data must be cache-first**: pre-populate from `AppState`/cache in
     `init` via `State(initialValue:)`; let `.task` only fetch when the cache was
     empty. Images use `CachedAsyncImage`, never raw `AsyncImage`. (Failure class B2 /
     Class 3 — run `/animation-debug` if content pops in.)
   - **No `if let`/`if !items.isEmpty` branch that flips when data arrives mid-slide.**
3. **Never put `.opacity()` on the sliding detail pane**, and never add your own
   `.offset`, `.animation`, or `.transition` to it — SlideStack owns all motion. The
   old per-page opacity-swap third screens (e.g. ProgramHomePage) were *replaced* by a
   proper detail item; don't bring them back.
4. **Post-dismiss work goes in `onDismissComplete:`, NOT `asyncAfter`.** If you need to
   run something after the pane has finished sliding out and unmounted:
   ```swift
   SlideStack(item: $editing, onDismissComplete: { cleanUp() }) { ... } detail: { ... }
   ```
   Adding any `asyncAfter` for dismiss-then-present choreography is a FAIL.
5. **Inverted (detail-on-the-left) layouts use `detailEdge: .leading`** — don't
   re-implement the inversion by hand. (Only GroupHomePage's settings screen needs
   this; the primary slides right, the detail enters from the left. Edge-swipe-back is
   trailing-only and silently ignored for leading details.)
6. **Edge-swipe-back is opt-in and additive**: `edgeSwipeBack: true`. Adding it to a
   page that lacked it is fine (new capability, nothing removed); it's `.trailing`-only.

## Step 3 — Scaffold

For an item-driven push from a list:

```swift
struct MyListPage: View {
    private var state: AppState { AppState.shared }
    @State private var editingId: String?          // 1. navigation state

    var body: some View {
        SlideStack(item: $editingId) {             // 2. canonical container
            listPane                               //    primary
        } detail: { id in
            detailPane(id: id)                     //    detail from MOUNTED id
        }
    }

    private var listPane: some View {
        ScrollView {
            VStack { /* rows */                    // plain VStack, not Lazy, inside slides
                ForEach(state.orderedThings) { thing in
                    Button { editingId = thing.id } label: { ThingRow(thing) }
                        .buttonStyle(.plain)        // 3. transitions buttons need .plain
                }
            }
        }
    }

    @ViewBuilder
    private func detailPane(id: String) -> some View {
        if let thing = state.things[id] {           // 4. read from the arg, cache-first
            EditThingPage(thing: thing, onCancel: { editingId = nil })
                .id(thing.id)
        }
    }
}
```

Nested SlideStacks are supported (CreateProgramPage and the
EnrollmentsList → Schedule → EditEnrollmentDay path each stack three deep) — just nest
the detail of one inside the primary/detail of another; each owns its own state binding.

## Step 4 — Before commit

- The detail's dismiss button sets the binding to `nil`/`false` (no manual animation).
- No `asyncAfter`, no hand-rolled `HStack { }.offset(x:)`, no `.opacity` on the pane,
  no `LazyVStack` in animated content, no `AsyncImage` in animated content.
- **Run `/transition-review` on the diff** (rules B1–B4, E1, A2/A3 catch every mistake
  above). If anything pops/flickers when you test, run `/animation-debug`.
- Reference: `SlideStack.swift` header, `EditDay.swift` (pilot), `SWIFTUI_TRANSITIONS.md`.
