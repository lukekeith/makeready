# 09 — Native iOS Pager (SwiftUI/UIKit) — Leader Edit Canvas + Walkthrough

The iPhone app stays 100% native; WebView is avoided. **Members never take lessons in the app**
(web is the only member runtime), so this pager serves **leaders**: the edit-in-place canvas
(07 §6) and a faithful full-screen walkthrough of exactly what members will see. It renders the
same design — pages, palette, motion (05) — as the Vue member pager, kept honest via `/compare`.
This doc maps the shared contract (03) and motion spec onto SwiftUI/UIKit, choosing UIKit only
where it is genuinely better at the task.

**Walkthrough mode = member rendering with zero member side-effects.** No progress writes, no
analytics events — which is precisely why `PreviewToken`/`PreviewState` need no replacement.

## 1. Presentation & entry

- The pager is a full-screen surface presented through the app's **typed Route/overlay system**
  (present-overlay conventions — no `.fullScreenCover`/`.sheet`, no ad-hoc string ids). New
  route: `.lessonPager(lessonId:, mode: .walkthrough | .edit)`.
- Entry points: the leader flows that today open the WKWebView preview
  (`ReadActivityPreviewModal.swift`, deleted) — EditDay, ProgramHome, activity editors — plus
  the edit-in-place canvas itself (07 §6).
- Content loads via a new `LessonPagerActions` (Actions pattern) fetching the **curriculum/
  scheduled draft** (the same leader endpoints the editors already use) into `AppState`
  normalized stores; disk-cached AppState makes warm entry instant.

## 2. The scroller — one decision, made carefully

Requirement (01 §6.1): snap at page boundaries, free scroll inside taller-than-viewport pages,
native physics, `snap-stop: always` semantics (no fling-skipping).

**Recommendation: SwiftUI `ScrollView` + a custom `ScrollTargetBehavior` (iOS 17+).**

```swift
ScrollView(.vertical) {
  LazyVStack(spacing: 0) {
    ForEach(pages) { page in
      ActivityPageView(page: page)
        .containerRelativeFrame(.vertical, count: 1, span: 1, spacing: 0) // short pages
        // long pages: .frame(minHeight: viewportH) and natural height
    }
  }
  .scrollTargetLayout()
}
.scrollTargetBehavior(PageEdgeSnapping(pageFrames: frames))   // custom
.scrollPosition($position)                                     // current page tracking
```

- `PageEdgeSnapping.updateTarget(_:context:)` implements CSS-snap semantics by hand: given the
  proposed end offset, find the nearest page *edge* within a capture radius; clamp travel to one
  page boundary per gesture (the `snap-stop: always` rule); otherwise leave the target alone so
  long pages scroll freely. This is ~40 lines and fully unit-testable.
- Gated pages (`advanceRule`): not enforced natively (leaders scroll freely; a chip labels the
  rule). The snap behavior's clamp hook stays available should a native member mode ever exist.
- **Fallback if the custom behavior fights us** (only if real-device testing shows it): a
  UIKit `UICollectionView` (compositional layout, one estimated-height item per page) wrapped in
  `UIViewControllerRepresentable`, implementing the same snap in
  `scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)`. Decide at the build gate —
  do not build both.
- The animation-debug/transition-review house rules apply: no `HStack+offset` hand-rolled
  paging, no `asyncAfter` choreography.

## 3. Page lifecycle (native mirror of 03 §3)

- `currentIndex` from `.scrollPosition`; `intraProgress` + settle detection from
  `onScrollGeometryChange` (iOS 18) or a `GeometryReader` preference on the content offset
  (iOS 17) with an 80ms idle debounce — same thresholds as web.
- Lifecycle events drive: rail updates, media warm-up (`approaching` → AVPlayer preroll /
  image decode), entrance choreography (`settled`). The member-progress hooks of 03 §5 have **no
  native implementation** — walkthrough writes nothing; gating (`advanceRule`) is shown as an
  informational chip, not enforced (leaders scroll freely, same rule as edit mode).
- Pager state lives in an `@Observable` `LessonPagerModel` owned by the route — page structs,
  entrance phases — following the AppState/Actions standardization
  (docs/features/state-management).

## 4. Motion implementation (numbers from 05, native techniques)

| 05 spec | SwiftUI/UIKit technique |
|---|---|
| Entrance groups (fade + 12pt rise + .97 scale, staggered) | One `EntrancePhase` enum per group driven by the settle event; `.opacity/.offset/.scaleEffect` animated with `.timingCurve(0.22,0.61,0.36,1, duration: 0.4)` and per-group `delay` — declarative, no `asyncAfter` |
| Quote rule stub → grow | `Rectangle().scaleEffect(y:, anchor: .top)` in the same phase system |
| Word-by-word reveal | Custom `Layout` (flow of per-word `Text`) with staggered opacity `.35→1`; narration cues via `TimelineView`/`AVPlayer` time observer later; first tap reveals all |
| Checkmark draw (tick 300ms → hold → circle 320ms → spring settle) | `Shape` + `trim(from:to:)` for both strokes; settle via `.spring(response: 0.35, dampingFraction: 0.7)` rotation/scale; replays on every page entry |
| Dot rail capsule morph + inner thumb | `Capsule` height animates on index change (spring); thumb `offset` bound to `intraProgress` (no animation — direct tracking); idle dimming via scroll-idle state |
| Over-scroll dismissal | Over-scroll distance from scroll geometry maps 1:1 to sheet translation until the 80px threshold, then the Route dismisses with the standard 400ms ease-in slide-down — through the overlay system's dismissal path, not a bespoke animation |
| Bottom sheets (prayer save, write input) | The app's existing modal/menu chrome via the Route system (twin geometry to the web sheet) |
| Reduced motion | `@Environment(\.accessibilityReduceMotion)` → 150ms fades, pre-drawn check, instant words |

## 5. Page views by type (06 catalog, native notes)

- **TEXT / BIBLE**: pure SwiftUI. Width-scaled type = font size from container width ×
  `fontScale` (the app already does width-scaled type in the theme-typography work). SCRIPTURE
  role = serif (New York via `.fontDesign(.serif)` or the bundled face the theme names) + left
  rule + small-caps citation.
- **VIDEO**: `AVPlayer` + `AVPlayerLayer` (UIKit-backed `UIViewRepresentable`) playing the
  Cloudflare Stream HLS URL; autoplay is unrestricted natively — narration/sound starts on page
  settle, honoring the mute chrome toggle. Custom bottom bar in SwiftUI (scrubber =
  `Slider`-styled to spec). No progress heartbeats (walkthrough).
- **YOUTUBE**: the one **acknowledged WebView exception** — YouTube's ToS requires the IFrame
  player, so this page embeds a `WKWebView` island for the video surface only (page chrome stays
  native). If that's unacceptable, YOUTUBE pages could be web-member-only — decision in 08 §11.
- **IMAGE**: SwiftUI `AsyncImage`/`CachedAsyncImage` (existing component) full-bleed + overlay
  texts positioned by the normalized `position` anchors.
- **WRITE**: native `TextField`/`TextEditor` in-place with keyboard avoidance; input is
  try-it-out only (never persisted — no member note exists to write).
- **EXEGESIS**: reuse the existing UIKit text stack — `HighlightableTextView` +
  `HighlightRenderer` render the locked passage with tappable highlight spans (it already does
  selection, snapping, and highlight drawing for the editors/Bible reader). The **floating note
  card** is a SwiftUI overlay: draggable via `DragGesture` (direct manipulation, stays where
  dropped, viewport-anchored), internally scrollable markdown, re-targets on highlight tap
  (250ms ease), never blocks the passage's scrolling. No visit reporting (walkthrough).
- **Completion page**: pure SwiftUI (check Shape, streak badge, up-next `CardLesson`-style row,
  pulsing swipe hint) — rendered with sample streak/up-next data in walkthrough/edit mode.

## 6. Theming on native

The server-resolved palette (04) arrives in the lesson payload as tokens; a `LessonPalette`
struct maps them to SwiftUI (`Color`, font descriptors, scale steps, motion preset). One source
of truth, two renderers — the same tokens feed the Vue twin's CSS custom properties. No native
theme "files"; nothing hardcoded per theme.

## 7. Parity discipline (keeping the Vue twin honest)

- Every page type gets a `/compare` comparison (iPhone reference vs Vue twin) with shared
  fixture data — the exact pipeline already used for the leader-app parity project, including
  its known traps (frosted materials invisible in snapshots, AsyncImage initials fallback,
  fixed base epoch for relative times — see the compare-twins memory index).
- The motion spec (05) is the shared contract for animation; pixel parity is verified static
  per-state (settled pages, entrance end-states, rail states), motion parity by timing review
  against 05's table.
- Where platform conventions legitimately diverge (scroll physics feel, keyboard behavior,
  share sheet), native wins and the divergence is recorded in the comparison notes — the twin
  mimics, it does not fight the browser.

## 8. What this deletes on iPhone

- `ReadActivityPreviewModal.swift` (WKWebView preview) and its preview-URL builders
  (`EditDay.swift:1152,1254`, `ProgramHomePage.swift:1070`).
- `ThemedContentView.swift` (dead bundled-HTML renderer).
- "Open Lesson" (Safari handoff, `MainHome.swift:509-517`) survives — it is how a leader opens
  the *real* member web experience — but the native walkthrough becomes the default way to see
  a lesson from the management flows.
