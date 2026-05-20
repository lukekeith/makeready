# SwiftUI Transitions & Animations Reference

This document captures patterns and fixes for SwiftUI elements that behave unexpectedly during page transitions, modal presentations, and animations.

---

## Button Animation Conflicts

### Problem: Button that triggers page transition animates differently than siblings

**Symptoms:**
- The tapped button becomes semi-transparent
- The tapped button doesn't move with sibling elements during the transition
- Only the button that triggered the state change is affected

**Root Cause:**
When using the implicit `.animation()` modifier, SwiftUI creates an animation transaction based on where views are in the hierarchy. The button being tapped has its own pressed-state animation transaction, which can conflict with or override the parent's animation. The tapped button is treated as the "source" of the state change and receives different animation treatment.

**Bad Pattern:**
```swift
HStack {
    // Screen 1
    // Screen 2
}
.offset(x: showSecondScreen ? -geometry.size.width : 0)
.animation(.easeInOut(duration: 0.3), value: showSecondScreen)

// Button action:
Button("Settings") {
    showSecondScreen = true  // Animation applied implicitly
}
```

**Good Pattern:**
```swift
HStack {
    // Screen 1
    // Screen 2
}
.offset(x: showSecondScreen ? -geometry.size.width : 0)
// No .animation() modifier here

// Button action:
Button("Settings") {
    withAnimation(.easeInOut(duration: 0.3)) {
        showSecondScreen = true  // Animation applied explicitly
    }
}
```

**Why it works:**
`withAnimation()` creates a fresh animation transaction at the moment of state change. All views see the same transaction uniformly—there's no special treatment for the button that triggered it.

**Additional fix:**
Add `.buttonStyle(.plain)` to buttons involved in page transitions to prevent the default button press opacity animation from interfering:

```swift
Button(action: { ... }) {
    Image(systemName: "gearshape")
}
.buttonStyle(.plain)
```

---

## LazyVStack and Modal Animations

### Problem: Content inside LazyVStack doesn't animate with modal slide-up

**Symptoms:**
- Modal slides up with animation
- Some elements (like headers, search bars) animate correctly
- List items inside LazyVStack stay fixed or pop in without animation

**Root Cause:**
`LazyVStack` renders items lazily as they become visible. When a modal starts sliding up from below the screen, the lazy items haven't been rendered yet. As the modal slides up and items become visible, they get rendered but don't participate in the ongoing animation because they weren't in the view hierarchy when the animation started.

**Bad Pattern:**
```swift
// Modal content with LazyVStack
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(items) { item in
            ItemCard(item: item)  // These won't animate with modal
        }
    }
}
```

**Good Pattern:**
```swift
// Modal content with regular VStack
ScrollView {
    // NOTE: Using VStack instead of LazyVStack so cards are rendered
    // before the modal slide animation starts (fixes animation sync)
    VStack(spacing: 12) {
        ForEach(items) { item in
            ItemCard(item: item)  // These animate with modal
        }
    }
}
```

**Trade-off:**
Regular `VStack` renders all items upfront, which uses more memory for long lists. Only use this pattern for modal content with reasonable item counts (< 50 items). For very long lists, consider alternative approaches like delaying the animation start.

---

## Pre-loading Content for Modal Animations

### Problem: Content loaded asynchronously doesn't animate with modal slide-up

**Symptoms:**
- Modal container slides up correctly
- Content loaded via `.task {}` appears but doesn't animate with modal
- Swipe-to-dismiss works (content animates down)
- Only the initial appearance animation is broken

**Root Cause:**
When content is loaded asynchronously in `.task {}`, the modal animation starts BEFORE the content is rendered. By the time content loads, the animation transaction has completed, so the new content just appears in place.

**Bad Pattern:**
```swift
struct MyModalPage: View {
    @State private var items: [Item] = []  // Empty initially
    @State private var isLoading = true

    var body: some View {
        // Content based on items...
    }
    .task {
        items = await loadItems()  // Loads AFTER animation starts
    }
}
```

**Good Pattern:**
```swift
struct MyModalPage: View {
    @State private var items: [Item]
    @State private var isLoading: Bool

    init(...) {
        // Pre-load from cache synchronously so content is ready BEFORE animation
        let cachedItems = ItemManager.shared.items
        _items = State(initialValue: cachedItems)
        _isLoading = State(initialValue: cachedItems.isEmpty)
    }

    var body: some View {
        // Content based on items...
    }
    .task {
        // Only fetch from API if cache was empty
        if items.isEmpty {
            items = await loadItems()
        }
    }
}
```

**Why it works:**
Content is initialized from cache in `init()`, which runs synchronously before the view is presented. When the modal animation starts, the content is already rendered and animates as a unit with the modal container.

**Files using this pattern:**
- `ProgramHomePage.swift` - Pre-loads program from cache in init
- `SelectStudyProgramPage.swift` - Pre-loads programs from cache in init

---

## Using SearchableList for Modal Content

### Problem: Custom scroll/search implementations don't animate correctly with modals

**Solution:**
Use the `SearchableList` component which handles search animations, gradient masking, and proper modal integration.

**Pattern (from SearchableListDemoPage):**
```swift
var body: some View {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        SearchableList(
            items: items,
            filterPredicate: { item, query in
                item.name.localizedCaseInsensitiveContains(query)
            },
            placeholder: "Search",
            showAlphabetScrubber: false,
            autoFocusSearch: false
        ) { item in
            itemRow(item)
        } header: {
            PageTitle.iconTitle(
                title: "My Page",
                icon: "xmark",
                onIconTap: { overlayManager.dismiss(id: OverlayID.myPage) }
            )
        }
    }
}
```

**Why it works:**
`SearchableList` handles all the complex animation coordination internally - search field animations, header fade-out when searching, gradient masking, and proper list rendering.

---

## HStack Slide Transitions (Two-Step Pattern)

### Problem: Edit page appears instantly without sliding from the right

**Symptoms:**
- Tapping a list item should slide an edit page in from the right
- Instead, the edit page fades in or appears instantly
- The slide-back animation on dismiss may still work

**Root Cause:**
The HStack slide pattern uses an offset controlled by a boolean. For the animation to work, SwiftUI needs TWO separate update cycles:
1. First: render the content (so there's something to slide)
2. Second: change the offset (triggering the slide animation)

If both the content state and visibility state change in the same update cycle, SwiftUI inserts the content at the final position — there's nothing to animate.

**Bad Pattern:**
```swift
// Both state changes in same async block — NO animation
Button("Edit") {
    DispatchQueue.main.async {
        editingItem = item        // Content + visibility in same cycle
        showEditPage = true       // SwiftUI batches both, no intermediate state
    }
}
```

**Good Pattern:**
```swift
// Two-step: sync content, then async visibility
Button("Edit") {
    editingItem = item                    // Step 1: set content (sync)
    DispatchQueue.main.async {
        showEditPage = true               // Step 2: trigger slide (next tick)
    }
}
```

**Dismiss pattern (reverse order):**
```swift
private func dismiss() {
    showEditPage = false                                    // Step 1: slide back
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        editingItem = nil                                    // Step 2: clear after animation
    }
}
```

**Additional requirements:**
- Keep `.animation(.easeInOut(duration: 0.3), value: showEditPage)` on the HStack — do NOT remove it
- Do NOT add `.opacity()` to Screen 2 — it causes fade instead of slide
- Always add `.id(item.id)` to the edit page view for fresh rendering per item

**See:** `.claude/commands/transitions.md` for the complete reference

---

## State Initialization Crashes

### Problem: "precondition failure: setting value during update" when opening edit pages

**Symptoms:**
- App crashes with `precondition failure: setting value during update`
- Crash happens when a view appears and initializes `@State` properties
- Especially common with `.task` blocks that mutate `@State` dictionaries in loops

**Root Cause:**
`.task` runs during the view update cycle. Mutating `@State` properties (especially in loops) during this cycle triggers SwiftUI's runtime assertion.

**Bad Pattern:**
```swift
.task {
    for block in blocks {
        editableContents[block.id] = block.content ?? ""  // CRASH: mutating during update
    }
}
```

**Good Pattern:**
```swift
.onAppear {
    var contents: [String: String] = [:]
    for block in blocks {
        contents[block.id] = block.content ?? ""
    }
    editableBlockContents = contents  // Single mutation, after view update
}
```

**Rules:**
1. Use `.onAppear` instead of `.task` for `@State` initialization
2. Build values in local variables, assign to `@State` once
3. Wrap `.onPreferenceChange` mutations in `DispatchQueue.main.async`

---

## General Rules

1. **Prefer explicit `withAnimation()` over implicit `.animation()` modifier** when the animation is triggered by a button tap or user interaction — EXCEPT for HStack slide patterns, which need the implicit `.animation()` to catch the deferred state change from the two-step pattern.

2. **Use `.buttonStyle(.plain)` on icon buttons** in navigation headers to prevent pressed-state animations from conflicting with page transitions.

3. **Keep animation duration consistent** across all places that change the same state variable (e.g., both forward and back navigation should use the same duration).

4. **Use `SearchableList` component** for modal content that needs search functionality - it handles animations correctly.

5. **Use regular `VStack` instead of `LazyVStack`** for list content inside modals that need to animate with the modal slide-up transition.

6. **Use the two-step state change pattern** for HStack slide transitions: sync content, then async visibility. See the "HStack Slide Transitions" section above.

7. **Use `.onAppear` instead of `.task`** for `@State` initialization to avoid "setting value during update" crashes.

---

## Files Using These Patterns

- `EditDay.swift` - HStack slide to inline activity editors (two-step pattern)
- `GroupHomePage.swift` - Horizontal page slide between main view and edit view
- `ProgramHomePage.swift` - Program management with inline editors
- `PageTitle.swift` - Navigation header with icon buttons
- `SelectStudyProgramPage.swift` - Uses SearchableList for modal animation
- `SearchableListDemoPage.swift` - Reference implementation for searchable lists in modals
- `CardStudySelectable.swift` - No implicit .animation() to avoid transition conflicts

---

*Last updated: 2026-02-18*
*Add new patterns here as issues are discovered and fixed.*
