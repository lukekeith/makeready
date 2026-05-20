# Modal Presentation Guide

## The Rule

**Always use `overlayManager.presentModal()` or `overlayManager.presentMenu()` for modals and menus.**

Do NOT use `.fullScreenCover` or `.sheet` unless the content genuinely requires full-screen hardware access (camera, video recorder, video player, photo picker).

## Why

OverlayManager provides all of these automatically:
- Drag indicator (capsule at top)
- Swipe-to-dismiss
- Dark scrim (tap outside to dismiss, configurable)
- Spring animations (0.4s appear, 0.3s dismiss)
- Proper z-ordering (modals=100, menus=200, topLevel=300)
- Environment keys (`isModalRoot`, `modalProvidesDragIndicator`, `dismissOverlay`)
- Keyboard dismissal on present
- No flickering or z-order conflicts

Using `.fullScreenCover` or custom wrappers means you have to manually implement all of this every time.

## How to Present a Modal

```swift
// In your view that has overlayManager
overlayManager.presentModal(id: OverlayID.myModal) {
    MyModalContent()
}

// With options
overlayManager.presentModal(
    id: OverlayID.myModal,
    dismissOnTapOutside: false,  // For critical workflows
    showDragIndicator: true      // Default: true
) {
    MyModalContent()
}
```

## How to Present a Menu

```swift
overlayManager.presentMenu(id: OverlayID.myMenu) {
    MyMenuContent()
}

// Above other overlays
overlayManager.presentMenu(id: OverlayID.myMenu, priority: .topLevel) {
    MyMenuContent()
}
```

## How to Dismiss

From inside the modal/menu content:
```swift
@Environment(\.dismissOverlay) private var dismissOverlay

Button("Close") {
    dismissOverlay?()
}
```

From the parent:
```swift
overlayManager.dismiss(id: OverlayID.myModal)
```

Instant dismiss (no animation, use when another modal opens immediately):
```swift
overlayManager.dismiss(id: OverlayID.myMenu)  // This is already instant
```

## Bridging isPresented-based Views

If the content view uses `@Binding var isPresented: Bool` to dismiss, create a thin wrapper:

```swift
struct MyWrapper: View {
    let overlayManager: OverlayManager
    @State private var isPresented = true

    var body: some View {
        MyExistingView(isPresented: $isPresented)
            .onChange(of: isPresented) { _, newValue in
                if !newValue {
                    overlayManager.dismiss(id: OverlayID.myModal)
                }
            }
    }
}
```

## OverlayID Convention

Add new IDs to `OverlayID` in `OverlayManager.swift`:
```swift
static let myFeature = "myFeature"
```

## Priority Levels

| Priority | Value | Use For |
|----------|-------|---------|
| `.modal` | 100 | Standard modals (forms, pages, detail views) |
| `.menu` | 200 | Bottom menus (action menus, user menu, add menu) |
| `.topLevel` | 300 | Always-on-top (alerts, confirmations, sub-menus inside modals) |

## When to Keep fullScreenCover

Only for these cases:
- Video recording (needs camera hardware access)
- Video playback (immersive full-screen experience)
- Photo/media picker (UIKit picker wrappers)
- Any UIKit view controller that must be presented modally

## Common Mistakes

1. **Using `.fullScreenCover` for forms/dialogs** - Use `presentModal()` instead
2. **Building custom drag/scrim/dismiss logic** - OverlayManager handles this
3. **Firing dismiss + present simultaneously** - The menu animates above the incoming modal. Use `overlayManager.dismiss(id:)` for instant removal, then present.
4. **Not adding OverlayID** - Always register a static ID in `OverlayManager.swift`
5. **Nesting overlayManager renders** - The `MainView` renders all overlays at the top level. Don't add `ForEach(overlayManager.sortedOverlays)` inside modal content unless it's a `fullScreenCover` wrapper.
