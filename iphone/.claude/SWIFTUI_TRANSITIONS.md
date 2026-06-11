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

## Lazy Containers (LazyVStack/LazyVGrid) and Modal Animations

### Problem: Content inside ANY lazy container doesn't animate with modal/menu slide-up

**This applies to ALL four lazy containers: `LazyVStack`, `LazyHStack`, `LazyVGrid`,
`LazyHGrid`.** Earlier versions of this section (and the review rules built on it) named
only the stacks — which is exactly how the block-style color picker shipped a `LazyVGrid`
of 24 swatches inside an animated menu: greps for "LazyVStack" walked right past it.
If you're auditing, grep `LazyV\|LazyH`, not a specific type name.

**Symptoms:**
- Modal/menu slides up with animation
- Some elements (like headers, search bars) animate correctly
- Items inside the lazy container stay fixed or pop in without animation
  ("the picker appears fixed in place while the menu slides under it")

**Root Cause:**
Lazy containers render items only as they become visible. When a modal starts sliding up
from below the screen, the lazy items haven't been rendered yet. As the modal slides up
and items become visible, they get rendered but don't participate in the ongoing
animation because they weren't in the view hierarchy when the animation started.

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

**Good Pattern (list):**
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

**Good Pattern (grid):** replace `LazyVGrid` with a `VStack` of `HStack` rows chunked by
column count — identical layout for fixed palettes, fully eager:
```swift
// 6-column grid, eager — rides the menu slide (was LazyVGrid, which popped)
VStack(spacing: 2) {
    ForEach(Array(stride(from: 0, to: Self.colorPalette.count, by: 6)), id: \.self) { rowStart in
        HStack(spacing: 2) {
            ForEach(Self.colorPalette[rowStart..<min(rowStart + 6, Self.colorPalette.count)], id: \.self) { hex in
                swatch(hex)   // each cell .frame(maxWidth: .infinity) for equal widths
            }
        }
    }
}
```
Reference implementation: `BlockStyleColorPickerContent` in `BlockStyleEditor.swift`.

**Sanctioned exception (masked-by-design):** lazy cells that start at opacity 0 behind an
`appeared` flag and fade in only AFTER the menu settles (e.g. `AddActivityMenu`'s
staggered tiles) are fine — the lazy realization happens while invisible.

**Trap:** before fixing a lazy grid you found by grep, confirm it's the LIVE one — check
its enclosing property/struct for references. `BlockStyleEditor` contains a dead inline
copy of the color picker (`colorPickerGrid`, marked ⚠️ DEAD CODE) right above the real one.

**Trade-off:**
Regular `VStack` renders all items upfront, which uses more memory for long lists. Only use this pattern for modal content with reasonable item counts (< 50 items). For very long lists, keep the lazy container and accept/defer the animation instead (the media library and video grids do this deliberately).

---

## Pre-loading Content for Animated Containers (Modals & SlideStack details)

### Problem: Content loaded asynchronously doesn't animate with the container

**Symptoms:**
- Modal slides up / SlideStack detail slides in correctly, but the content inside
  pops to its final position mid-flight ("everything appeared except the background")
- Dismissal animates correctly (content already mounted) — only presentation breaks
- Only pages that load data in `.task {}` are affected; sync-content siblings ride fine

**Root Cause:**
Any structural view change that happens after the animation transaction starts (an
`if isLoading` branch flipping, items arriving from `.task`) is inserted OUTSIDE the
transaction and renders at the final offset immediately, while already-mounted views
keep interpolating. SlideStack's two-step insertion guarantees the *pane* is laid out
before the slide — it cannot guarantee the page's *data* exists. That is the page's
contract, below. (This is how the Phase 3.4 slider regression shipped: the migration
diffs touched slider mechanics, but the hosted pages still loaded in `.task`.)

### The cache-first detail page contract (all three rules — rule 1 alone is NOT enough)

Every page hosted in an animated container (overlay modal or SlideStack detail) must:

1. **Render its first frame from cache.** `init` pre-populates ALL display state
   synchronously via `State(initialValue:)` from AppState; `isLoading` starts `true`
   only when the cache is empty.
2. **Never regress the UI on refresh.** The load function shows the spinner only when
   there is nothing to display, and surfaces the error branch only when there is
   nothing to display. `.task` is a background refresh, never the primary render path.
   (Without this rule, the `.task` refresh flips the body back to the spinner branch
   mid-slide and the pop returns even with a warm cache.)
3. **If no cache exists, create one.** Add an in-memory dictionary to AppState, write
   it through in the Action, and — when the parent can afford the request — prefetch
   in the parent so even the first tap is warm.

**Good Pattern (complete contract):**
```swift
struct MyDetailPage: View {
    let groupId: String

    @State private var items: [Item]
    @State private var isLoading: Bool
    @State private var error: String?

    init(groupId: String, ...) {
        self.groupId = groupId
        // Rule 1: first frame from cache, synchronously
        let cached = AppState.shared.itemsFor(groupId: groupId)
        _items = State(initialValue: cached)
        _isLoading = State(initialValue: cached.isEmpty)
    }

    var body: some View {
        // if isLoading { spinner } else if let error { ... } else { content }
    }
    // .task { await load() }

    private func load() async {
        // Rule 2: spinner only when there's nothing to display
        if items.isEmpty {
            isLoading = true
        }
        error = nil
        do {
            let loaded = try await ItemActions().loadItems(groupId: groupId)
            await MainActor.run {
                items = loaded
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // Rule 2: keep cached content on a background refresh failure
                if items.isEmpty {
                    self.error = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
}
```

**Rule 3 recipe (data with no AppState cache yet)** — what GroupInvitePage needed:
1. AppState: `var fooByGroupId: [String: Foo] = [:]` — in-memory only is fine; skip
   PersistedState for large or cheap-to-refetch payloads (mirror
   `pendingJoinRequestsByGroupId` / `groupInvitesByGroupId`).
2. The Action writes through before returning: `state.fooByGroupId[id] = foo`.
3. Parent prefetch (ideal): `_ = try? await FooActions().loadFoo(...)` in the parent's
   `loadInitialData()` — see GroupHomePage, which prefetches enrollments, join
   requests, and the group invite for exactly this reason.

**Residual cold-cache behavior (accepted):** on the very first visit ever, with
nothing cached anywhere, the spinner rides the slide and content appears when the
load lands. That's data genuinely not existing yet — do NOT "fix" it with wall-clock
waits or by delaying the slide.

**Why it works:**
Content is initialized from cache in `init()`, which runs synchronously before the
container's animation transaction starts. The first frame already contains the real
content, so it rides as one unit; the background refresh then updates rows in place
(stable identities) without structural swaps.

**Files using this pattern:**
- `GroupMembersPage.swift`, `EnrollmentsListPage.swift` - full contract (rules 1+2)
- `GroupInvitePage.swift` - full contract incl. rule 3 (new AppState invite cache)
- `GroupHomePage.swift` - parent-side prefetching + cache-first `group` in init
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
