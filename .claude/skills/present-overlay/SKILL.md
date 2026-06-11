---
name: present-overlay
description: Scaffold a new modal, menu, or overlay surface in the iPhone app (SwiftUI). Use whenever adding ANY new overlay-presented UI in /iphone — a form modal, bottom action menu, confirmation, or push-style page. It registers the typed Route correctly, picks the right chrome, and FORBIDS .fullScreenCover/.sheet, ad-hoc string ids, and asyncAfter choreography. Use BEFORE writing any presentModal/presentMenu/fullScreenCover call.
---

# iPhone Overlay Scaffolder

You are adding an overlay-presented surface (modal / menu / confirmation / push page)
to `/iphone/MakeReady`. This app has exactly **one** sanctioned mechanism:
`OverlayManager` + the typed `Route` enum (`Services/Route.swift`, Phase 3.6).
Source of truth: `MakeReady/Components/Layout/MODAL_GUIDE.md`.

## Step 0 — Is an overlay even the right tool?

| You want… | Use | Not this skill |
|---|---|---|
| A form / detail / editor presented OVER the app | **`present(.route)`** with `.modal` chrome (this skill) | |
| A bottom action menu (Edit / Delete / Share) | **`present(.route)`** with `.menu` chrome (this skill) | |
| A confirmation / alert-style overlay above everything | **`present(.route)`** with `.raw` chrome + `.topLevel` priority (this skill) | |
| In-page primary→detail push (row → editor, back) | `SlideStack` | `/push-page` |
| Camera / video recording / video playback / photo picker | `.fullScreenCover` (hardware/immersive exception) | |
| A wizard with N panels | `panelIndex` over conditional panels (see `EnrollmentFlowModal`) | |

## Step 1 — Register the Route (one place, not the call site)

In `Services/Route.swift`:

1. **Add a case.** Parameterize only if the surface is per-entity:
   ```swift
   case myFeature                          // fixed surface
   case myPicker(blockId: String)          // per-entity surface
   ```
2. **Add the `id` arm** — unique, stable string (interpolate associated values):
   ```swift
   case .myFeature: return "myFeature"
   case .myPicker(let blockId): return "myPicker_\(blockId)"
   ```
3. **Add `priority` / `chrome` / `dismissOnTapOutside` arms ONLY if non-default.**
   Defaults: priority `.modal`, chrome derived from priority, tap-outside `true`.
   - Bottom menu → add to the `.menu` priority list (chrome follows automatically)
   - Confirmation/alert above everything → `.topLevel` priority + `.raw` chrome
     (your content then owns its own chrome — copy `ConfirmationOverlay`'s pattern)
   - Multi-step flow with Cancel/Done → `dismissOnTapOutside: false` arm
   - Push-style page → `.page` chrome

**Never** invent an ad-hoc string id for a fixed surface, and **never** pass
priority/chrome/tap-outside at a call site — they live on the type. (Sanctioned
exception: unbounded per-entity ids like GlobalSearchPage's lesson modals stay on
the legacy string API.)

## Step 2 — Present

```swift
overlayManager.present(.myFeature) {
    MyFeatureContent()
}
```

## Step 3 — Content rules (each one is a shipped bug)

1. **No chrome in content** (D4): no scrim, drag indicator, background, or offset
   animation — `ManagedModalView`/`ManagedMenuView` provide it. Exception: `.raw`
   routes own their chrome by definition.
2. **Content that loads data follows the cache-first detail page contract** (B2):
   pre-populate from AppState in `init` via `State(initialValue:)`; the load function
   shows spinner/error ONLY when there's nothing to display; no cache → create one.
   See SWIFTUI_TRANSITIONS.md § Pre-loading Content. Overlay content animates in —
   data arriving mid-flight pops to final position.
3. **No lazy containers** (B1): no `LazyVStack`/`LazyHStack`/`LazyVGrid`/`LazyHGrid`
   in content that animates in. Plain `VStack`; for grids, `VStack` of chunked
   `HStack` rows (see `BlockStyleColorPickerContent`).
4. **No `AsyncImage`** — use `CachedAsyncImage`.
5. **Buttons that trigger the presentation get `.buttonStyle(.plain)`** (A4).

## Step 4 — Dismissal

- **From inside content** (preferred — keeps content decoupled):
  ```swift
  @Environment(\.dismissOverlay) private var dismissOverlay
  Button("Close") { dismissOverlay?() }
  ```
- **From the parent:** `overlayManager.dismiss(.myFeature)`
- **Dismiss-then-present** (menu action opens a modal) — NEVER `asyncAfter` (E1/D3):
  ```swift
  // inside content:
  @Environment(\.dismissOverlayThen) private var dismissOverlayThen
  dismissOverlayThen? { overlayManager.present(.nextThing) { ... } }
  // from the parent:
  overlayManager.dismiss(.myMenu) { overlayManager.present(.nextThing) { ... } }
  ```
- **`isPresented`-based existing views:** thin wrapper with
  `.onChange(of: isPresented)` → `overlayManager.dismiss(.myFeature)` —
  see MODAL_GUIDE § Bridging.

## Step 5 — Before commit

- Route case + id + (only-if-non-default) priority/chrome/tap-outside arms added.
- No `.fullScreenCover`/`.sheet` (unless hardware exception), no ad-hoc string id,
  no `asyncAfter`, no chrome in content, no lazy containers, no `AsyncImage`.
- **Run `/transition-review` on the diff** (D1–D4, B1/B2, E1 catch every mistake
  above). If anything pops/flickers when you test, run `/animation-debug`.
- Reference: `MODAL_GUIDE.md`, `Services/Route.swift` header, `ConfirmationOverlay`
  (raw chrome), `UnenrollOptionsModal` (standard modal), `LessonActionMenu` (menu).
