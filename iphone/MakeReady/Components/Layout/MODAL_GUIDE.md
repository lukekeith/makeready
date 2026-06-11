# Modal Presentation Guide

## The Rule

**Always present modals and menus through `overlayManager.present(_ route:)` with a
registered `Route` case.** (Phase 3.6 replaced the stringly-typed `OverlayID` API —
`presentModal(id:)`/`presentMenu(id:)` remain only as the underlying implementation
and for dynamic per-entity ids.)

Do NOT use `.fullScreenCover` or `.sheet` unless the content genuinely requires
full-screen hardware access (camera, video recorder, video player, photo picker).

## Why

OverlayManager provides all of these automatically:
- Drag indicator (capsule at top)
- Swipe-to-dismiss
- Dark scrim (tap outside to dismiss, configurable per-route)
- Spring animations (0.4s appear, 0.3s dismiss)
- Proper z-ordering (modals=100, menus=200, topLevel=300)
- Environment keys (`isModalRoot`, `modalProvidesDragIndicator`, `dismissOverlay`, `dismissOverlayThen`)
- Keyboard dismissal on present
- No flickering or z-order conflicts

And `Route` folds the per-surface decisions (chrome, priority, tap-outside behavior)
into the type, so call sites can't get them wrong.

## How to Present

```swift
// 1. Register the surface in Services/Route.swift (case + id string + any
//    non-default priority/chrome/dismissOnTapOutside — see that file's header).
// 2. Present it:
overlayManager.present(.myFeature) {
    MyFeatureContent()
}
```

`Route` decides everything else:
- `chrome` — `.modal` (ManagedModalView), `.menu` (ManagedMenuView), `.page`
  (push-style ManagedPageView), or `.raw` (content owns its chrome, e.g.
  ConfirmationOverlay, AddActivityMenu)
- `priority` — z-index bucket
- `dismissOnTapOutside` — `false` for multi-step flows with explicit Cancel/Done
  (enrollment flows, schedule editors)

Parameterized surfaces use associated values: `present(.stylePicker(blockId: blockId))`.

## How to Dismiss

From inside the modal/menu content (preferred — content stays decoupled):
```swift
@Environment(\.dismissOverlay) private var dismissOverlay

Button("Close") {
    dismissOverlay?()
}
```

From the parent:
```swift
overlayManager.dismiss(.myFeature)
```

Dismiss-then-present (e.g. a menu action that opens a modal) — NEVER `asyncAfter`:
```swift
// From inside the menu content:
@Environment(\.dismissOverlayThen) private var dismissOverlayThen
dismissOverlayThen? {
    overlayManager.present(.editEnrollmentDay) { ... }
}

// From the parent:
overlayManager.dismiss(.lessonActionMenu) {
    overlayManager.present(.editEnrollmentDay) { ... }
}
```

## Content Rules (the bugs these prevent have all shipped before)

- **No chrome in content** — no own scrim, drag indicator, offset animation, or
  background; the Managed wrappers provide it (raw routes excepted).
- **No lazy containers** (`LazyVStack`/`LazyVGrid`/…) in content that animates in —
  see SWIFTUI_TRANSITIONS.md § Lazy Containers and Modal Animations.
- **Content that loads data follows the cache-first detail page contract** — init
  pre-population + guarded spinner/error — see SWIFTUI_TRANSITIONS.md § Pre-loading
  Content. Overlay content animates in; data arriving mid-flight pops.
- **No `AsyncImage`** in animated content — use `CachedAsyncImage`.

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
                    overlayManager.dismiss(.myFeature)
                }
            }
    }
}
```

## Route Registration Convention

Add new surfaces to `enum Route` in `Services/Route.swift`:
1. A case (with associated values if the surface is per-entity)
2. An arm in `var id` returning a unique, stable string
3. Arms in `priority` / `chrome` / `dismissOnTapOutside` ONLY if non-default
   (defaults: `.modal` priority, chrome derived from priority, tap-outside `true`)

Dynamic per-entity surfaces with unbounded identity (e.g. GlobalSearchPage's
lesson/video modals) may stay on the string API — that's the sanctioned exception.

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

1. **Using `.fullScreenCover` for forms/dialogs** - Use `present(.route)` instead
2. **Building custom drag/scrim/dismiss logic** - OverlayManager handles this
3. **Firing dismiss + present simultaneously** - The menu animates above the incoming
   modal. Use `dismiss(_:then:)` / `dismissOverlayThen`, or instant `dismiss(_:)` then present.
4. **Not registering a Route** - Always add the case in `Services/Route.swift`;
   don't invent ad-hoc string ids for fixed surfaces
5. **Choosing chrome/priority/tap-outside at the call site** - They live on `Route`;
   if a surface needs different behavior, change its Route properties
6. **Nesting overlayManager renders** - The `MainView` renders all overlays at the top
   level. Don't add `ForEach(overlayManager.sortedOverlays)` inside modal content
   unless it's a `fullScreenCover` wrapper.
