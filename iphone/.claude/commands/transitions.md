# Page Transitions Reference

Before implementing or modifying ANY page transition, sliding panel, or inline edit flow, you MUST read this document AND `.claude/SWIFTUI_TRANSITIONS.md` in full.

---

## HStack Slide Pattern (Inline Edit Pages)

This is the pattern used by EditDay, GroupHomePage, and similar pages that slide between two "screens" in an HStack.

### Architecture

```swift
GeometryReader { geometry in
    HStack(spacing: 0) {
        // Screen 1: Main content
        mainContent
            .frame(width: geometry.size.width)

        // Screen 2: Edit/detail content
        ZStack {
            if let item = selectedItem {
                EditPage(item: item)
                    .id(item.id)  // CRITICAL: ensures fresh view per item
            }
        }
        .frame(width: geometry.size.width)
    }
    .offset(x: showScreen2 ? -geometry.size.width : 0)
    .animation(.easeInOut(duration: 0.3), value: showScreen2)
}
```

### Two-Step State Change Pattern (CRITICAL)

When transitioning TO Screen 2, you MUST use a two-step state change:

1. **Step 1 (synchronous):** Set the CONTENT state (what to show)
2. **Step 2 (next tick):** Set the VISIBILITY state (trigger the slide)

```swift
// CORRECT - two separate update cycles
Button("Edit") {
    selectedItem = item                    // Step 1: sync - set content
    DispatchQueue.main.async {
        showScreen2 = true                 // Step 2: next tick - trigger slide
    }
}

// WRONG - both in same update cycle (NO animation, just appears)
Button("Edit") {
    DispatchQueue.main.async {
        selectedItem = item                // Both changes batched together
        showScreen2 = true                 // SwiftUI sees no intermediate state to animate
    }
}

// WRONG - both synchronous (can cause "setting value during update" crash)
Button("Edit") {
    selectedItem = item
    showScreen2 = true                     // May crash if triggered during view update
}
```

**Why this works:** SwiftUI needs to:
1. First render Screen 2 with the correct content (from step 1)
2. Then animate the offset change (from step 2)

If both happen in the same update cycle, SwiftUI inserts the content AND changes the offset simultaneously - there's nothing to animate.

### Dismiss Pattern

When transitioning BACK to Screen 1, reverse the order:

1. **Step 1:** Set visibility to false (triggers slide back)
2. **Step 2 (after animation completes):** Clear the content

```swift
private func dismiss() {
    showScreen2 = false                                    // Step 1: slide back
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        selectedItem = nil                                  // Step 2: clear after animation
    }
}
```

### Do NOT Add .opacity() to Screen 2

Screen 2's ZStack should NOT have an opacity modifier tied to the visibility state. The slide animation handles everything.

```swift
// WRONG - causes fade instead of slide
ZStack { ... }
    .frame(width: geometry.size.width)
    .opacity(showScreen2 ? 1 : 0)  // NO! This makes it fade

// CORRECT - no opacity modifier
ZStack { ... }
    .frame(width: geometry.size.width)
```

### The .id() Modifier is Required

Always add `.id(item.id)` to the edit page inside the ZStack. This ensures SwiftUI creates a fresh view when switching between different items.

```swift
ZStack {
    if let activity = editingActivity {
        EditActivityPage(activity: activity)
            .id(activity.id)  // Forces fresh view per activity
    }
}
```

### Keep .animation() on the HStack

The implicit `.animation()` modifier should be on the HStack (or its parent), watching the visibility boolean:

```swift
HStack(spacing: 0) { ... }
    .offset(x: showScreen2 ? -geometry.size.width : 0)
    .animation(.easeInOut(duration: 0.3), value: showScreen2)
```

Do NOT remove this and try to use `withAnimation()` on the buttons instead - the two-step pattern requires the implicit animation to catch the deferred state change.

---

## State Initialization in Edit Pages

### Use .onAppear, NOT .task, for @State Initialization

When an edit page needs to initialize `@State` from its props:

```swift
// CORRECT - simple, synchronous
.onAppear {
    title = activity.title ?? ""
    description = activity.description ?? ""
}

// WRONG - can cause "setting value during update" crash
.task {
    title = activity.title ?? ""
    // Especially dangerous with loops or dictionary mutations
    for block in blocks {
        editableContents[block.id] = block.content ?? ""  // CRASH
    }
}
```

### Batch @State Mutations

If you need to initialize a `@State` dictionary, build it in a local variable first:

```swift
// CORRECT - single @State mutation
.onAppear {
    var contents: [String: String] = [:]
    for block in blocks {
        contents[block.id] = block.content ?? ""
    }
    editableBlockContents = contents  // One mutation
}

// WRONG - mutating @State in a loop
.onAppear {
    for block in blocks {
        editableBlockContents[block.id] = block.content ?? ""  // Multiple mutations
    }
}
```

---

## .onPreferenceChange and State Updates

Wrap `.onPreferenceChange` state mutations in `DispatchQueue.main.async` to avoid "setting value during update":

```swift
// CORRECT
.onPreferenceChange(MyPreferenceKey.self) { values in
    DispatchQueue.main.async {
        storedValues.merge(values) { _, new in new }
    }
}

// WRONG - can crash
.onPreferenceChange(MyPreferenceKey.self) { values in
    storedValues.merge(values) { _, new in new }  // Setting value during update!
}
```

---

## Common Mistakes That Break Slide Animations

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Both state changes in same `DispatchQueue.main.async` | Page appears without sliding | Use two-step: sync content, async visibility |
| Both state changes synchronous | Crash or no animation | Use two-step pattern |
| Adding `.opacity()` to Screen 2 | Page fades instead of slides | Remove opacity modifier |
| Missing `.id(item.id)` on edit page | Stale content when switching items | Add .id() modifier |
| Removing implicit `.animation()` | No animation at all | Keep `.animation()` on HStack |
| Using `.task` for @State init | "setting value during update" crash | Use `.onAppear` instead |
| Mutating @State dict in loop | "setting value during update" crash | Build local var, assign once |

---

## Files Using HStack Slide Pattern

- `EditDay.swift` - Day editing with inline activity editors
- `GroupHomePage.swift` - Group home with inline edit views
- `ProgramHomePage.swift` - Program management with inline editors

---

## Quick Checklist

Before modifying any slide transition:

- [ ] Content state set synchronously, visibility state set in `DispatchQueue.main.async`
- [ ] Dismiss reverses: visibility first, content cleared after delay
- [ ] No `.opacity()` modifier on Screen 2
- [ ] `.id(item.id)` on the edit page view
- [ ] `.animation(.easeInOut(duration: 0.3), value: showBool)` on the HStack
- [ ] Edit page uses `.onAppear` (not `.task`) for @State initialization
- [ ] @State dictionary mutations are batched (build local var, assign once)
- [ ] `.onPreferenceChange` mutations wrapped in `DispatchQueue.main.async`

---

## VStack Panel Transition Pattern (Full-Screen Swipe Between Panels)

This is the pattern used by `VideoActivityPicker` — two full-screen panels stacked vertically in a VStack, where drag gestures slide between them.

### Architecture

```swift
struct PanelSwitcher: View {
    @State private var showingPanel2 = false
    @State private var measuredHeight: CGFloat = 0

    // Jitter-free drag via @GestureState (bypasses SwiftUI render pipeline)
    @GestureState private var panelDrag: CGFloat = 0

    // Receives drag value on release for smooth animated settle
    @State private var committedDrag: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height

            VStack(spacing: 0) {
                panel1
                    .frame(height: screenHeight)
                    .gesture(swipeUpGesture)     // Gesture on Panel 1 only

                panel2
                    .frame(height: screenHeight)
            }
            .offset(y: (showingPanel2 ? -measuredHeight : 0) + panelDrag + committedDrag)
            .onAppear { measuredHeight = screenHeight }
        }
        .ignoresSafeArea()
    }
}
```

### CRITICAL: Use `coordinateSpace: .global` on DragGestures

**This is the #1 cause of jitter in VStack panel transitions.**

When a DragGesture is on a child view and that gesture updates an offset on the parent, the child physically moves. `DragGesture` defaults to `coordinateSpace: .local`, which means `translation` is computed relative to the gesture view's local coordinate space. As the parent moves, the child's coordinate space shifts, corrupting the translation value. This creates a feedback loop:

1. Finger moves 10pt → translation reports 10pt → parent offsets 10pt → child moves 10pt
2. Child moved, so local coordinates shifted → translation now reports ~0pt → parent snaps back
3. Repeat = visible jitter/oscillation at ~half speed

```swift
// ❌ WRONG - causes jitter when gesture view moves with parent
DragGesture(minimumDistance: 20)

// ✅ CORRECT - stable translation regardless of view movement
DragGesture(minimumDistance: 20, coordinateSpace: .global)
```

**Rule: ANY time a DragGesture on a child view updates an offset on a parent/ancestor, you MUST use `coordinateSpace: .global`.**

### Jitter-Free Drag + Smooth Release (The Handoff Pattern)

Use `@GestureState` for jitter-free tracking during drag, then hand off to `@State` for animated release:

```swift
@GestureState private var liveDrag: CGFloat = 0
@State private var committedDrag: CGFloat = 0

// Both contribute to offset:
.offset(y: baseOffset + liveDrag + committedDrag)

private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 20, coordinateSpace: .global)  // MUST be .global
        .updating($liveDrag) { value, state, transaction in
            transaction.animation = nil   // No animation during drag
            let drag = value.translation.height
            if drag > 0 { state = drag }  // Only allow downward
        }
        .onEnded { value in
            let drag = value.translation.height
            guard drag > 0 else { return }

            // Hand off: @GestureState resets to 0, @State takes over at same value
            // Net visual offset stays the same — no jump
            committedDrag = drag

            let velocity = value.predictedEndTranslation.height - drag

            if drag > 80 || velocity > 300 {
                // Commit transition
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showingPanel2 = false
                    committedDrag = 0
                }
            } else {
                // Snap back
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    committedDrag = 0
                }
            }
        }
}
```

**Why this works:**
- `@GestureState` bypasses SwiftUI's render pipeline → no jitter during drag
- `@GestureState` auto-resets to 0 when gesture ends
- In `.onEnded`, `committedDrag = drag` compensates for the reset (same frame, same net offset)
- `withAnimation` then smoothly animates `committedDrag` to 0

**Why `@State` alone causes jitter:** Every `@State` update triggers a full SwiftUI view update cycle. At 120Hz touch input, this means 120 re-renders per second. `@GestureState` uses a lower-level pipeline that avoids this overhead.

### Avoid DragGesture on ScrollView Parents

**NEVER** put a `DragGesture` (even via `.simultaneousGesture`) on a view that contains a `ScrollView`. The gestures will conflict:

```swift
// ❌ WRONG - DragGesture fights with ScrollView scrolling
VStack {
    header
    ScrollView { grid }   // ScrollView can't scroll properly
}
.simultaneousGesture(DragGesture(...))

// ✅ CORRECT - Gesture on non-scrolling areas only
VStack {
    header
        .gesture(pullDownGesture)   // Header doesn't scroll
    ScrollView { grid }             // ScrollView works independently
}
```

If you need pull-down-to-return from a ScrollView, put the gesture on a fixed header above it, not on the ScrollView's parent.

### Safe Area in `.ignoresSafeArea()` Context

When using `.ignoresSafeArea()`, `GeometryReader.safeAreaInsets` reports 0. Read safe area from UIKit:

```swift
private var topSafeArea: CGFloat {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return 59 }
    return window.safeAreaInsets.top
}
```

**Do NOT** add safe area to `geometry.size.height` — with `.ignoresSafeArea()`, it already includes full screen height. Adding safe area double-counts and makes panels taller than the screen.

### Common Mistakes in VStack Panel Transitions

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Missing `coordinateSpace: .global` | Jitter/oscillation during drag | Add `coordinateSpace: .global` to DragGesture |
| Using `@State` for drag tracking | Jitter during drag | Use `@GestureState` with `.updating()` |
| Using `@GestureState` without handoff | Jump/snap on release | Transfer value to `@State` in `.onEnded` |
| `DragGesture` on ScrollView parent | ScrollView can't scroll, or drag fires unexpectedly | Put gesture on non-scrolling views only |
| Adding safe area to `geometry.size.height` | Gap between panels, content pushed off-screen | Don't add — `.ignoresSafeArea()` already includes full height |
| Implicit `.animation()` on VStack | Spring applies to drag updates, causing jitter | Use explicit `withAnimation()` in `.onEnded` only |

### Files Using VStack Panel Pattern

- `VideoActivityPicker.swift` - Recorder + library grid vertical panel transition

### Quick Checklist

Before implementing a VStack panel transition:

- [ ] `DragGesture` uses `coordinateSpace: .global`
- [ ] `@GestureState` for drag tracking with `transaction.animation = nil`
- [ ] `@State committedDrag` receives value in `.onEnded` (handoff pattern)
- [ ] `withAnimation(.spring(...))` in `.onEnded` only — no implicit `.animation()`
- [ ] DragGesture is NOT on a ScrollView parent
- [ ] Panel height is just `geometry.size.height` (no safe area addition)
- [ ] `.ignoresSafeArea()` on the outermost container
- [ ] Safe area read from UIKit window, not GeometryReader

---

*Last updated: 2026-02-22*
*Update this document whenever a new transition issue is discovered and fixed.*
