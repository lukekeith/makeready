# SwiftUI Animation Patterns

Best practices for avoiding jitter, lagging subviews, and ghosting in SwiftUI animations.

## Table of Contents

1. [Gesture Handling](#gesture-handling)
2. [Animation Curves](#animation-curves)
3. [Centralized Menu System](#centralized-menu-system)
4. [matchedGeometryEffect](#matchedgeometryeffect)
5. [Shadows](#shadows)
6. [AsyncImage](#asyncimage)
7. [Deferred Animation Start for Overlay Content](#deferred-animation-start-for-overlay-content)
8. [Code Review Checklist](#code-review-checklist)
9. [Utility Reference](#utility-reference)

---

## Gesture Handling

### Use `@GestureState` for Drag Tracking

**Problem:** `@State` is not optimized for high-frequency gesture updates, causing jitter during drag.

**Solution:** Use `@GestureState` with `.updating()` modifier.

```swift
// WRONG
@State private var dragOffset: CGFloat = 0

.gesture(
    DragGesture()
        .onChanged { value in
            dragOffset = value.translation.height  // Jitter!
        }
)

// CORRECT
@GestureState private var dragOffset: CGFloat = 0

.gesture(
    DragGesture(minimumDistance: 5, coordinateSpace: .global)
        .updating($dragOffset) { value, state, transaction in
            transaction.animation = nil  // Disable animation during drag
            state = value.translation.height
        }
        .onEnded { value in
            // GestureState auto-resets with spring animation
        }
)
```

### Use `coordinateSpace: .global` for 1:1 Tracking

Without global coordinate space, the drag offset may not match finger movement exactly.

### Use `transaction.animation = nil` During Drag

Prevents SwiftUI from applying implicit animations during rapid state updates.

### Add `.compositingGroup()` Before `.offset()`

Flattens the view hierarchy into a single offscreen buffer before applying offset.

```swift
VStack { ... }
    .compositingGroup()  // Add this
    .offset(y: dragOffset)
```

### Remove `DispatchQueue.main.async` from Gesture Handlers

Gesture handlers already run on the main thread. Adding async introduces frame delays.

---

## Animation Curves

### Never Mix Animation Curves

**Problem:** Running separate `withAnimation` blocks with different curves (e.g., easeOut + spring) causes jitter.

```swift
// WRONG - competing animations
.onAppear {
    withAnimation(.easeOut(duration: 0.3)) {
        overlayOpacity = 0.5
    }
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        offset = 0
    }
}

// CORRECT - single animation block
.onAppear {
    ModalAnimations.animateAppear(offset: $offset, overlayOpacity: $overlayOpacity)
}
```

### Use `ModalAnimations` Utility

See [Utility Reference](#utility-reference) for the `ModalAnimations` API.

---

## Centralized Menu System

All bottom-sliding menus should use the centralized `presentMenu()` system for consistent behavior.

### Use `presentMenu()` Instead of `present()`

**Problem:** Menus that handle their own animation have inconsistent behavior, animation curve conflicts, and no swipe-to-dismiss.

**Solution:** Use `overlayManager.presentMenu()` which wraps content in `ManagedMenuView`.

```swift
// WRONG - menu handles its own animation
overlayManager.present(id: OverlayID.addMenu, priority: .menu) {
    AddMenu()  // Has its own ZStack, offset, overlayOpacity, onAppear animation
}

// CORRECT - centralized menu management
overlayManager.presentMenu(id: OverlayID.addMenu) {
    AddMenu()  // Just content, no animation handling
}
```

### What `ManagedMenuView` Provides

When you use `presentMenu()`, `ManagedMenuView` automatically provides:

1. **Dark overlay background** with tap-to-dismiss
2. **Slide-up animation** using `ModalAnimations` (prevents curve conflicts)
3. **Swipe-to-dismiss** via drag indicator with jitter-free `@GestureState` tracking
4. **Consistent styling** (rounded corners, background color #252936)
5. **`dismissOverlay` environment action** for content to trigger animated dismissal

### Menu Content Pattern

Menu content should be simple - no animation handling, no dark overlay, no offset:

```swift
struct MyMenu: View {
    @Environment(\.dismissOverlay) private var dismissOverlay

    var body: some View {
        // Just the content - ManagedMenuView handles chrome
        VStack(spacing: 0) {
            // Menu items...
            Button("Action") {
                dismissMenu()
                // Do something after dismiss animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    overlayManager.presentModal(id: OverlayID.nextPage) {
                        NextPage()
                    }
                }
            }
        }
        // No .background() needed - ManagedMenuView provides it
    }

    private func dismissMenu() {
        dismissOverlay?()  // Triggers animated dismissal
    }
}
```

### Menus Using This Pattern

- `AddMenu` - Main add action menu
- `AddActivityMenu` - Activity type selection menu
- `UserMenu` - User profile menu
- `HamburgerMenu` - Navigation menu

### Consolidate `.animation()` Modifiers

**Problem:** Multiple `.animation()` modifiers watching the same state value cause duplicate animations.

```swift
// WRONG - 5 animation modifiers watching isSearchActive
Color.clear.animation(.easeInOut, value: isSearchActive)
VStack { }.animation(.easeInOut, value: isSearchActive)
// etc...

// CORRECT - single animation at container level
ZStack { ... }
    .animation(.easeInOut(duration: 0.5), value: isSearchActive)
```

---

## Swipeable Cards

### No Implicit `.animation()` on Card Content

**Problem:** Cards inside `SwipeableCard` with `.animation()` or `.transition()` modifiers cause child elements to animate independently during swipe gestures.

```swift
// WRONG - metadata animates independently during swipe
HStack(spacing: 16) {
    ForEach(data.metadata) { item in
        DataComponent(item: item)
            .transition(.opacity)  // Causes jitter!
    }
}
.animation(.easeInOut(duration: 0.3), value: data.metadata.map { $0.type })

// CORRECT - no implicit animations on card content
HStack(spacing: 16) {
    ForEach(data.metadata) { item in
        DataComponent(item: item)
    }
}
```

### SwipeableCard Uses `.compositingGroup()`

`SwipeableCard` applies `.compositingGroup()` before `.offset()` to flatten the view hierarchy:

```swift
content
    .compositingGroup()  // Flattens child views into single buffer
    .offset(x: offset)   // Moves entire flattened view as one unit
```

This prevents child views from animating independently during swipe gestures.

### Cards Fixed for This Pattern

- `CardStudy` - Removed `.transition(.opacity)` and `.animation()` from metadata row
- `CardEvent` - Already correct (no animation modifiers on metadata)
- `CardVideo` - Already correct (no animation modifiers on metadata)
- `CardGroup` - Animation only on selection overlay (intentional, doesn't affect swipe)

---

## matchedGeometryEffect

### Don't Wrap State Changes in `withAnimation`

`matchedGeometryEffect` has built-in animation. Wrapping in `withAnimation` creates conflicting curves.

```swift
// WRONG
Button {
    withAnimation(.spring()) {  // Conflicts with matchedGeometryEffect
        selectedIndex = index
    }
}

// CORRECT
Button {
    selectedIndex = index  // Let matchedGeometryEffect handle animation
}
// Apply animation modifier to container
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
```

### Never Put Shadows Inside matchedGeometryEffect

Shadows are computationally expensive. Putting them inside `matchedGeometryEffect` causes severe jitter.

```swift
// WRONG - shadow inside matchedGeometryEffect
.background(
    if selected {
        Capsule()
            .shadow(radius: 8)  // Jitter!
            .matchedGeometryEffect(id: "bg", in: animation)
    }
)

// CORRECT - shadow outside, on static container
.background(
    if selected {
        Capsule()
            .matchedGeometryEffect(id: "bg", in: animation)
    }
)
.shadow(color: selected ? .black.opacity(0.2) : .clear, radius: 8)
```

---

## Shadows

### Use `OptimizedShadow` for Animated Views

Standard `.shadow()` forces GPU to compute shadow path from alpha channel every frame.

```swift
// WRONG - expensive shadow on animated view
.shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)

// CORRECT - pre-computed path
.optimizedShadow(color: .black.opacity(0.3), radius: 20, y: -5, cornerRadius: 24)
```

See [Utility Reference](#utility-reference) for the `optimizedShadow` API.

---

## AsyncImage

### Use `CachedAsyncImage` in Animated Containers

**Problem:** Standard `AsyncImage` may reload during view updates, causing jitter in animated headers/menus.

**Solution:** Use `CachedAsyncImage` which caches the loaded image in `@State`.

```swift
// WRONG - may reload during animation
AsyncImage(url: avatarURL) { image in ... }

// CORRECT - cached, stable during animation
CachedAsyncImage(urlString: avatarURL, size: 32)
```

### Synchronous Cache Pre-Population for Animated Panels

**Problem:** Even `CachedAsyncImage` can fail inside animated containers (slide-up menus, modals). The image starts as `nil` and loads asynchronously via `.task`. Even with a memory cache hit, the actor-isolated `ImageCache.fetch()` requires an async hop. When the `@State` update occurs mid-animation, SwiftUI inserts the `Image` view as a **structural change** (different branch of `if/else`), which doesn't inherit the in-progress offset animation. The image appears fixed at its final position while the rest of the panel animates.

**Root cause:** Structural view changes (`if cachedImage != nil` going from `false` to `true`) during an animation don't participate in that animation — the new view appears at its destination immediately.

**Solution:** Pre-populate `@State` from memory cache synchronously in `init` using `State(initialValue:)`. This ensures the image is present from the first render, eliminating the structural change.

```swift
// ImageCache exposes a nonisolated synchronous lookup (NSCache is thread-safe)
nonisolated func cachedImage(for url: URL) -> UIImage? {
    let key = url.absoluteString as NSString
    return memoryCache.object(forKey: key)
}

// CachedAsyncImage pre-populates in init
init(url: URL?, size: CGFloat, ...) {
    self.url = url
    // ... other properties ...

    // Pre-populate so image is present from first render
    if let url = url, let cached = ImageCache.shared.cachedImage(for: url) {
        _cachedImage = State(initialValue: cached)
        _lastLoadedURL = State(initialValue: url)
    }
}
```

**General rule:** Any async-loaded content inside an animated container (menus, modals, sheets that slide/scale in) should be synchronously initialized from cache when possible. If the content isn't cached yet, it will still load asynchronously — but the common case (image already shown elsewhere on screen) will be instant.

See [Utility Reference](#utility-reference) for the `CachedAsyncImage` API.

### Decompose Background Layers in Modals

**Problem:** A modal has layered backgrounds (base color + photo + gradient overlay) wrapped in a single `if/else` conditional. When data loads mid-animation, the entire background (including the gradient) appears at a random position — it doesn't inherit the in-progress slide-up animation.

```swift
// WRONG - gradient is inside the conditional, appears mid-animation
ZStack {
    if hasPhoto {
        photoBackground(size: geometry.size)  // Contains image + gradient
    } else {
        initialsBackground(height: geometry.size.height)  // Contains color + circle
    }
    ScrollView { ... }
}
```

When `hasPhoto` switches from `false` to `true` (profile loads), the entire `photoBackground` — including the gradient overlay — is a structural change that appears at its final position, not where the modal currently is during animation.

**Solution:** Decompose the background into unconditional layers (always rendered from frame 1) and conditional layers (data-dependent). Gradients, base colors, and other always-visible elements must be outside any `if/else`.

```swift
// CORRECT - gradient always present from frame 1
ZStack {
    // Always present (unconditional)
    Color.appBackground

    // Conditional: only the data-dependent part
    if hasPhoto, let url = URL(string: profile?.avatarUrl ?? "") {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
    }

    // Always present (unconditional) - animates with the modal
    LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color.appBackground.opacity(0.2), location: 0),
            .init(color: Color.appBackground.opacity(0.6), location: 0.5),
            .init(color: Color.appBackground, location: 0.75)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    // Conditional: initials circle when no photo
    if !hasPhoto {
        Circle()
            .fill(Color.white.opacity(0.05))
            .frame(width: 240, height: 240)
    }

    ScrollView { ... }
}
```

**Key principle:** Split backgrounds into independent layers by their lifecycle:
- **Unconditional** (base color, gradient overlay, darkening effects) → always rendered
- **Conditional** (photo image, initials, data-dependent content) → appears when data loads

The unconditional layers animate correctly with the modal from frame 1. The conditional layers may pop in, but they appear *behind* the gradient, so the visual impact is minimal.

---

## Deferred Animation Start for Overlay Content

### Problem: Menu/Modal Text Not Sliding Up

**Problem:** When presenting a menu or modal via `presentMenu()`/`presentModal()`, text elements (titles, descriptions) sometimes appear at their final position immediately instead of sliding up with the container. This is intermittent.

**Root cause:** `.onAppear` fires and starts the animation before SwiftUI has completed the content's layout pass. Text views that haven't been measured yet don't participate in the animation transaction — they appear at their final position when layout completes.

**Solution:** Defer the animation start by one run loop iteration using `DispatchQueue.main.async` inside `.onAppear`. This ensures the content layout pass completes before the animation begins. Since the view starts off-screen (offset = Screen.bounds.height) and transparent (overlayOpacity = 0), the one-frame delay is invisible.

```swift
// WRONG — animation may start before layout is complete
.onAppear {
    ModalAnimations.animateAppear(offset: $offset, overlayOpacity: $overlayOpacity)
}

// CORRECT — layout completes first, then animation starts
.onAppear {
    DispatchQueue.main.async {
        ModalAnimations.animateAppear(offset: $offset, overlayOpacity: $overlayOpacity)
    }
}
```

**Applied to:** Both `ManagedModalView` and `ManagedMenuView` in `OverlayManager.swift`.

**General rule:** When animating a container's position (offset/scale) from off-screen to on-screen, defer the animation start by one run loop iteration if the content includes dynamic text or layout that may need multiple layout passes.

---

## Code Review Checklist

Use this checklist when reviewing SwiftUI code for animation issues:

### Gestures
- [ ] Drag gestures use `@GestureState`, not `@State`
- [ ] Drag gestures use `coordinateSpace: .global`
- [ ] Gesture `.updating()` has `transaction.animation = nil`
- [ ] No `DispatchQueue.main.async` in gesture handlers
- [ ] `.compositingGroup()` applied before `.offset()` on draggable views

### Animations
- [ ] No mixed animation curves in same transition (easeOut + spring)
- [ ] Modal appear/dismiss uses `ModalAnimations` utility
- [ ] Single `.animation()` modifier at container level, not duplicates on children
- [ ] No `withAnimation` wrapping state changes when using `matchedGeometryEffect`
- [ ] No `.animation()` or `.transition()` on content inside `SwipeableCard`

### Shadows
- [ ] Shadows not inside `matchedGeometryEffect`
- [ ] Animated views use `optimizedShadow()` modifier
- [ ] Large shadows (radius > 10) use pre-computed paths

### Images
- [ ] `CachedAsyncImage` used in animated headers/menus
- [ ] Standard `AsyncImage` only in static content areas
- [ ] Async-loaded content in animated panels pre-populated from cache in `init`

---

## Utility Reference

### ModalAnimations

Location: `MakeReady/Utilities/ModalAnimations.swift`

```swift
// Modal appear (slide up + fade in background)
ModalAnimations.animateAppear(
    offset: $offset,
    overlayOpacity: $overlayOpacity
)

// Modal dismiss (slide down + fade out background)
ModalAnimations.animateDismiss(
    offset: $offset,
    overlayOpacity: $overlayOpacity,
    screenHeight: UIScreen.main.bounds.height
) {
    overlayManager.dismiss(id: id)
}

// Content appear (scale + opacity, for overlays like ConfirmationOverlay)
ModalAnimations.animateContentAppear(
    scale: $contentScale,
    opacity: $contentOpacity,
    blurOpacity: $blurOpacity
)

// Content dismiss
ModalAnimations.animateContentDismiss(
    scale: $contentScale,
    opacity: $contentOpacity,
    blurOpacity: $blurOpacity,
    targetScale: 0.9
) {
    onDismiss()
}
```

### OptimizedShadow

Location: `MakeReady/Utilities/OptimizedShadow.swift`

```swift
// Apply optimized shadow with pre-computed rectangular path
.optimizedShadow(
    color: .black.opacity(0.3),
    radius: 20,
    x: 0,
    y: -5,
    cornerRadius: 24
)
```

### CachedAsyncImage

Location: `MakeReady/Utilities/CachedAsyncImage.swift`

```swift
// Basic usage
CachedAsyncImage(url: url, size: 80)

// With string URL
CachedAsyncImage(urlString: user.avatarURL, size: 32)

// With initials fallback
CachedAsyncImage(
    urlString: user.avatarURL,
    size: 80,
    fallbackInitials: String(user.name.prefix(1))
)

// With icon fallback
CachedAsyncImage(
    url: nil,
    size: 40,
    fallbackIcon: "person.fill"
)
```

---

## Files Modified in Animation Audit

This document was created as part of a comprehensive animation audit. Files modified:

**Utilities Created:**
- `MakeReady/Utilities/ModalAnimations.swift`
- `MakeReady/Utilities/OptimizedShadow.swift`
- `MakeReady/Utilities/CachedAsyncImage.swift`

**Components Fixed:**
- `MakeReady/Pages/Video/VideoPlayerPage.swift` - @GestureState fix
- `MakeReady/Components/Card/CardGestureCoordinator.swift` - Removed async
- `MakeReady/Components/Card/SwipeableCard.swift` - Added .compositingGroup() before offset
- `MakeReady/Components/Card/CardStudy.swift` - Removed .animation() and .transition() from metadata
- `MakeReady/Services/OverlayManager.swift` - ModalAnimations integration
- `MakeReady/Components/Navigation/HamburgerMenu.swift` - ModalAnimations integration
- `MakeReady/Components/Feedback/ConfirmationOverlay.swift` - ModalAnimations integration
- `MakeReady/Components/Layout/SearchableList.swift` - Consolidated animations
- `MakeReady/Components/Navigation/TabSlider.swift` - matchedGeometryEffect fix
- `MakeReady/Components/Input/SelectionModeToggle.swift` - Shadow + matchedGeometryEffect fix
- `MakeReady/Components/Navigation/UserMenu.swift` - CachedAsyncImage + ModalAnimations
- `MakeReady/Components/Navigation/PageHeader.swift` - CachedAsyncImage fix
