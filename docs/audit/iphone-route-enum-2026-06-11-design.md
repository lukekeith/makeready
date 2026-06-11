# Phase 3.6 — `Route` enum design (typed overlay identity + lazy content)

| | |
|---|---|
| **Phase** | 3.6 of [iphone-2026-06-10-plan.md](./iphone-2026-06-10-plan.md) |
| **Status** | **3.6a + 3.6b SHIPPED** (committed `de2244c`, build + 65 tests green). **3.6c REJECTED — FINAL** (see banner below; its motivating bug class is solved by the cache-first contract instead, commits `8b34f45`/`6023d94`). **3.6d UNBLOCKED** — slider regression closed, device-verified 2026-06-11. |

> ⚠️ **3.6c (lazy `OverlayItem.content`) is REJECTED as written.** It was implemented and
> built green, but on-device it broke **every overlay-hosted `SlideStack` slider**: making
> `OverlayItem.content` a `() -> AnyView` evaluated each `MainView` render rebuilt the whole
> overlay tree on every animation frame, desyncing the slide from its freshly-mounted detail
> content (content appeared at final position while only the primary slid). Reverted. The
> "build at render time" premise backfired — the stored-`AnyView` it replaced was correct.
> If the async-content-pop class needs attacking, do it **per-overlay with cache-first init**
> (the existing B2 pattern), not by globally rebuilding overlay content. 3.6a/3.6b (the typed
> `Route` layer) stand on their own and are unaffected.
>
> **Finalized 2026-06-11:** this is exactly what happened. The slider regression turned out
> to be pre-existing per-page Class 3 (independent of 3.6c), and the async-content-pop class
> is now solved by the **cache-first detail page contract** (SWIFTUI_TRANSITIONS.md
> § Pre-loading Content, enforced by `/push-page` + `/transition-review` B2a–c +
> `/animation-debug` Class 3; applied in commits `8b34f45`/`6023d94`, device-verified).
> **Do not reattempt 3.6c in any form** — "build at render time" cannot work while
> `MainView`'s ForEach re-evaluates per frame during overlay animations; the per-page
> contract achieves the same goal with no render-path risk. 3.6d proceeds with the stored
> `AnyView` as-is.

| **Prime directive (unchanged)** | Zero functionality loss. Zero design change. This is a type-level refactor; presentation behavior stays frame-identical. |
| **Prereqs done** | 3.1 Motion tokens, 3.2 completion sequencing, 3.3 SlideStack, 3.4 sliders migrated. |
| **Unblocks** | 3.7 `/present-overlay` skill (needs Route registration), 3.8 NavigationCoordinator (keyed by Route), 3.9 `/nav-route`. |

## What 3.6 actually is

The plan line: *"`Route` enum replacing stringly-typed `OverlayID`; OverlayManager keyed by route; `OverlayItem` content becomes a lazy `() -> AnyView` closure (built at render time — directly attacks the async-content-pop failure class)."*

Three distinct changes, **separable and independently committable**, in increasing risk:

| Sub-step | What changes | Risk | Build-gate |
|---|---|---|---|
| **3.6a — `Route` type (additive)** | New `Route.swift`. Maps every overlay to a typed case; `route.id` returns the *existing* string. Nothing else touched. | None — pure addition, no call site changes. | Compile only. |
| **3.6b — Route-keyed OverlayManager API (additive)** | `present(_:content:)`, `dismiss(_:)`, `dismiss(_:then:)`, `isPresented(_:)` overloads that delegate to today's string-keyed storage via `route.id`. Old string API still works. | None — old and new APIs coexist. | Compile only. |
| **3.6c — Lazy `OverlayItem.content`** | `content: AnyView` → `content: () -> AnyView`; `present()` stores the closure; `MainView` renders `item.content()`. | **Low but real** — touches the render path for *every* overlay. This is the structural fix (content built at render time, not present time). | **Full build + capture diff of every overlay.** |
| **3.6d — Mechanical call-site migration** | The 96 `OverlayID.x` + `presentModal(id:)` sites move to `present(.x)` / `dismiss(.x)`, one logical group per commit. | Low per-commit; high volume. | Build + capture per group. |

> **Why split 3.6c out:** the lazy-content change is the only part that alters runtime
> behavior (it's a *fix* — see "The bug it fixes" below). Keep it isolated so its capture
> diff is interpretable and it's a one-commit revert. 3.6a/3.6b are zero-risk scaffolding
> that can land first and sit harmlessly even if 3.6c/3.6d slip.

## The bug 3.6c fixes (why lazy content matters)

Today `present(id:content:)` does `AnyView(content())` — it **evaluates the content
closure at presentation time** and stores the resulting view. For overlays whose body
reads async/`AppState` data that isn't loaded yet at the moment of presentation, the view
is captured in its empty state and the later data arrival is a structural change that lands
*outside* the present animation's transaction → the async-content-pop failure class
(Class 3 / B2 in `SWIFTUI_TRANSITIONS.md`, the same family SlideStack's two-step insertion
defeats for sliders).

Making `OverlayItem.content` a `() -> AnyView` that `MainView` evaluates **inside its
`ForEach` render pass** means SwiftUI owns the content's lifetime and dependency tracking —
the body re-evaluates with the data present, animating correctly. It also makes content
construction lazy (not built until actually rendered).

This is behavior-changing in the strict sense, so it is its own commit with its own capture
diff. Expected diff: **none** for overlays that were already cache-warm; **fewer pop-ins**
for the data-dependent ones (a fix, not a regression).

## Proposed `Route.swift` (3.6a)

The enum carries associated values exactly where today's `OverlayID` has parameterized
factory funcs (`backgroundSourceMenu(blockId:)`, `mediaLibraryPicker(blockId:)`,
`stylePicker(blockId:)`). `id` returns the **same string today's code uses**, so a
route-keyed `present` and a legacy string `dismiss` interoperate during migration.

```swift
//  Route.swift — Phase 3.6
//  Typed identity for every OverlayManager-presented surface. Replaces the
//  stringly-typed OverlayID. `id` bridges to the legacy string ids so the
//  migration can proceed one call site at a time without a flag day.

import SwiftUI

enum Route: Equatable, Hashable {
    // Menus (raw chrome handled by the menu views themselves)
    case userMenu, addMenu, hamburgerMenu, addActivityMenu, lessonActionMenu
    case librarySortMenu, libraryAddMenu, groupsAddMenu, groupsInviteMenu
    case bibleVersionMenu, exegesisHighlightActionMenu
    case backgroundSourceMenu(blockId: String)

    // Page / detail modals
    case profilePage, createProgram, componentsPage, globalSearch, studyCardsDemoPage
    case studyProgramHome, programHome, biblePage, bibleReader
    case inviteContacts, shareInvite, notificationFeed
    case exegesisHighlightModal
    case mediaLibraryPicker(blockId: String)
    case stylePicker(blockId: String)

    // Group / org / member modals
    case createGroup, groupHome, editGroup, orgHome
    case enrollmentFlow, programEnrollmentFlow, enrollmentSchedule, editEnrollmentDay
    case memberProfile, memberRequestProfile, memberRequests

    // Feedback / unenroll
    case confirmationOverlay, unenrollOptions

    /// Bridges to the legacy string id (must stay byte-identical to the old
    /// OverlayID values until 3.6d removes the last string call site).
    var id: String {
        switch self {
        case .userMenu: return "userMenu"
        case .addMenu: return "addMenu"
        // …one arm per case; parameterized arms interpolate, e.g.:
        case .backgroundSourceMenu(let blockId): return "backgroundSourceMenu_\(blockId)"
        case .mediaLibraryPicker(let blockId): return "mediaLibraryPicker_\(blockId)"
        case .stylePicker(let blockId): return "stylePicker_\(blockId)"
        // …
        }
    }

    /// The z-index bucket this surface presents in — folds the priority that
    /// was previously passed positionally at each call site into the type.
    var priority: OverlayPriority {
        switch self {
        case .addActivityMenu, .confirmationOverlay: return .topLevel
        case .userMenu, .addMenu, .hamburgerMenu, .lessonActionMenu,
             .librarySortMenu, .libraryAddMenu, .groupsAddMenu, .groupsInviteMenu,
             .bibleVersionMenu, .exegesisHighlightActionMenu, .backgroundSourceMenu,
             .unenrollOptions:
            return .menu
        default:
            return .modal
        }
    }

    /// Which chrome wrapper this route uses — lets `present(_:content:)` pick
    /// presentModal vs presentMenu vs presentPage so call sites stop choosing.
    enum Chrome { case modal, menu, page, raw }
    var chrome: Chrome {
        switch self.priority {
        case .menu: return .menu
        default:    return .modal   // refine per-route during 3.6d as needed
        }
    }
}
```

> **Note on `backgroundPicker(blockId:)`:** the old `OverlayID.backgroundPicker` is already
> retired (it's now the third slide pane of EditReadActivityPage, not an overlay — see the
> comment in `OverlayManager.swift:127`). It is intentionally **omitted** from `Route`.

## Proposed OverlayManager route API (3.6b)

Additive overloads — they delegate to the existing string-keyed storage, so the legacy
string methods keep working through the whole migration:

```swift
extension OverlayManager {
    func present<V: View>(_ route: Route, @ViewBuilder content: @escaping () -> V) {
        switch route.chrome {
        case .modal: presentModal(id: route.id, priority: route.priority, content: content)
        case .menu:  presentMenu(id: route.id, priority: route.priority, content: content)
        case .page:  presentPage(id: route.id, priority: route.priority, content: content)
        case .raw:   present(id: route.id, priority: route.priority, content: content)
        }
    }
    func dismiss(_ route: Route)                              { dismiss(id: route.id) }
    func dismiss(_ route: Route, then c: @escaping () -> Void){ dismiss(id: route.id, then: c) }
    func isPresented(_ route: Route) -> Bool                 { isPresented(id: route.id) }
}
```

## Lazy content change (3.6c) — exact edits

```swift
// OverlayManager.swift
struct OverlayItem: Identifiable {
    let id: String
    let priority: OverlayPriority
    let content: () -> AnyView          // was: let content: AnyView
}

// present(id:priority:content:) — store the closure, don't evaluate it:
let item = OverlayItem(id: id, priority: priority, content: { AnyView(content()) })

// MainView.swift:141 — evaluate at render time:
ForEach(overlayManager.sortedOverlays) { item in
    item.content()                      // was: item.content
}
```

That is the entire 3.6c change. `presentModal/presentMenu/presentPage` already funnel
through `present(id:priority:content:)`, so they inherit laziness for free.

## Migration sequence (each line = one commit)

1. **3.6a** add `Route.swift` (+ pbxproj: PBXBuildFile, PBXFileReference, group child,
   Sources phase — copy an adjacent file's 4 entries, per session-learnings).
2. **3.6b** add the OverlayManager route extension. Build.
3. **3.6c** lazy `OverlayItem.content`. Build + **capture diff every overlay** (the 6
   hand-feel flows from the progress doc plus: confirmation overlays, all menus, bible
   reader, share-invite, notification feed).
4. **3.6d** migrate call sites in dependency order, one group per commit, capture per group:
   - leaf menus first (userMenu, addMenu, sort/add menus) — lowest blast radius
   - confirmation/unenroll overlays (22 + 9 sites — highest count, very uniform)
   - page modals (programHome, groupHome, enrollmentSchedule, createProgram/Group …)
   - the parameterized block pickers last (associated-value cases)
5. Delete `enum OverlayID` once grep shows zero `OverlayID.` references. Build.

## Verification

- Per the plan's protocol: build is **user-triggered** (`iphone/.claude/CLAUDE.md` —
  absolute ask-first). Each commit ends "ready for build + capture."
- `/transition-review` on 3.6c and any 3.6d commit that touches a `presentModal`/
  `presentMenu` site (rule D2 — registered identity; rules B2/E1 unaffected by id typing).
- Characterization tests (Phase 0.2) stay green — none touch OverlayManager directly, but
  run the suite after 3.6c as a regression guard.

## Out of scope for 3.6 (belongs to 3.8 NavigationCoordinator)

- `handleDeepLink` (`MainView.swift:164-201`) and push-notification routing converting to
  `coordinator.navigate(to:)`. 3.6 only gives them a typed `Route` to navigate *to*; the
  coordinator that owns the stack and the boolean→route page migration is 3.8.
- The 106 presentation booleans across pages → `coordinator.push(...)`. 3.8.

## Score impact

Contributes to criterion 3 (Navigation & transitions, 1.5 → 4 target). 3.6 is the
"strings become types" third of that line; 3.3–3.5 were the slider engine, 3.8 is the
boolean→route stack.
