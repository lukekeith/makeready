# iPhone Structural Improvement Plan — companion to Audit 2026-06-10

| | |
|---|---|
| **Based on** | [iphone-2026-06-10.md](./iphone-2026-06-10.md) (baseline scorecard: 2.0/5) |
| **Prime directive** | **Zero functionality loss. Zero design change.** Every step is a behavior-preserving structural refactor. Anything that would visibly change the app is flagged as a ⚠️ Decision Point and excluded until explicitly approved. |
| **Deliverables** | 6 Claude Code skills + Tier 0–4 refactors from the audit, sequenced so a safety net exists before anything is touched |
| **Target scorecard** | 2.0 → ~3.8 without a single visible change (criteria 2, 4, 5, 7, 8 move the most) |

---

## How "structural only" changes the audit recommendations

Most audit items are inherently invisible (Keychain, `@MainActor`, DI, diffable data sources). But five recommendations would change what users see or feel, so they are **modified or deferred** here:

| Audit recommendation | Problem under this constraint | Resolution in this plan |
|---|---|---|
| `ToastManager` user-facing error channel | Toasts are new visible UI | **Split:** build the invisible plumbing (Actions record errors into `AppState.errors`; pages stop swallowing) now. The visible toast component is ⚠️ **Decision Point A** — you design/approve it before it renders anything. Until then, errors are recorded but rendering is a no-op. |
| Move the 2 forbidden `fullScreenCover` forms to `presentModal` | Full-screen → bottom-sheet is a visible presentation change | **Deferred** (⚠️ Decision Point B). Documented as known MODAL_GUIDE violations; not touched. |
| Switch grid thumbnails from `-md` (400px) to `-thumb` (150px) | At 3 columns on a 3x display, cells are ~400px — 150px thumbs would be **visibly blurrier**. (The audit's "7× fewer pixels" framing missed this.) | **Corrected:** keep `-md` at 3 columns. `-thumb` is reserved for future 5+ column zoom levels (a Phase 2 media feature, out of scope here). |
| `Typography.swift` with Dynamic Type | Adopting `relativeTo:` changes layout for users with non-default text size settings | **Split:** create the token set mapping to **current fixed sizes** (pixel-identical at every setting) and migrate call sites mechanically. Turning on Dynamic Type scaling is ⚠️ **Decision Point C**. |
| Media library Phases 2–3 (pinch zoom, pager, date sections) | These ARE the redesign — by definition visible | **Out of scope.** This plan ships only media Phase 1 (pagination, diffable, downsampling, prefetch — all invisible). The Photos-style redesign is its own design-led effort after this plan completes. |

Also constrained: **Motion tokens encode the app's *current* durations and curves**, not idealized ones. Standardizing values (e.g., collapsing 0.25 into 0.3) is ⚠️ **Decision Point D** — the initial token pass is a pure find-and-name, transitions stay frame-identical.

---

## Verification protocol (applies to every phase)

Because the constraint is "nothing changes," proof is the product:

1. **Visual regression via `/capture`** — the monorepo's screenshot tool already supports the iPhone simulator. Phase 0 captures a baseline manifest of every reachable screen; every phase ends with a re-capture and diff against baseline. A structural refactor with a pixel diff is a failed refactor (excluding timestamps/dynamic data masked in fixtures).
2. **Build checkpoints are user-triggered** — per `iphone/.claude/CLAUDE.md`, Claude never builds without permission. Each phase ends with: "ready for build + capture verification." You run it (or say "go").
3. **Unit tests as behavior locks** — Phase 0 writes characterization tests for the State layer *before* it's refactored. Tests document today's behavior, including quirks; refactors must keep them green.
4. **One commit per step** — every numbered step below is an atomic commit so any regression is a one-commit revert.
5. **Transition checklist** — any step touching animation code runs the `/transition-review` skill (built in Phase 0) before commit.

---

## Phase 0 — Safety net + first skills (build BEFORE touching app code)

> Nothing in the app changes in this phase. Effort: ~2–3 sessions.

| # | Step | Notes |
|---|---|---|
| 0.1 | **Capture baseline**: extend `/capture` fixtures to cover the main flows (tabs, group home + its 3 screens, program home/editors, media grid + detail, enrollment flows, Bible reader, profile). Run and commit baseline screenshots. | This is the regression oracle for the entire plan. |
| 0.2 | **Characterization tests** (no production code changes): `EntityStoreTests` (upsert/replaceAll/remove/ordering), `RelationshipIndexTests`, `PersistedState` encode→decode round-trip, JSON decoding fixtures for the highest-traffic models in `State/Models.swift` (captured from real API responses). | Locks current behavior before `@MainActor` / persistence refactors. |
| 0.3 | **Build skill `/animation-debug`**: symptom → failure-class (1–10 from the audit) → known fix decision tree, sourced from `SWIFTUI_TRANSITIONS.md` + `SWIFTUI_ANIMATION_PATTERNS.md`, citing reference implementations. | Buildable today; immediately useful even before migration. |
| 0.4 | **Build skill `/transition-review`**: pre-commit checklist for any diff touching `withAnimation`, `.animation(`, `.transition(`, `offset(`, `DragGesture`, `asyncAfter` — mixed curves, duplicate `.animation` modifiers, `@State` drag tracking, missing `.compositingGroup()`, `@State` mutation in `.task`, conditional always-visible layers, LazyVStack in animated containers. | Protects every later phase. |
| 0.5 | **Fix `.claude/CLAUDE.md`**: ports (3001→3010), prod URL (makeready.app→api.makeready.org), Actions table (4→9), remove the phantom `API_REFERENCE.md` mandate, correct page counts. Add the "connected component" tier definition so the components rule matches reality. | Docs-are-code; prevents every future session from inheriting wrong facts. (Criterion 8) |

**Exit criteria:** baseline captures committed; test target runs green; both skills answer correctly against the 10 documented failure classes.

---

## Phase 1 — Tier 0 quick wins (invisible hardening)

> Each step is hours, independently committable, zero UI impact. Effort: ~1–2 sessions.

| # | Step | Invisibility guarantee |
|---|---|---|
| 1.1 | Remove `NSAllowsArbitraryLoads`; keep scoped localhost exceptions for Debug. | All real traffic is already HTTPS (api.makeready.org); verify Debug local flow still connects. |
| 1.2 | **Keychain migration** for the session cookie — with a one-time migrator: on launch, if cookie exists in UserDefaults, move it to Keychain and delete the UserDefaults copy. | **No one gets logged out.** Migration path is the critical detail. |
| 1.3 | Delete sensitive log lines (cookie prefixes ×4, full APNs token ×1). | Log-only change. |
| 1.4 | `AttributedString.safeMarkdown(_:)` helper replacing all 16 `try!` sites — falls back to plain text on invalid markdown. | Output identical for all currently-valid input; removes the crash for invalid input (strictly additive robustness). |
| 1.5 | `Date+Formatting.swift` with cached static formatters; mechanically migrate the 47 inline `DateFormatter()` sites. **Formats copied verbatim** — same `dateFormat` strings, same locale behavior. | Rendered dates byte-identical; verified by capture diff. |
| 1.6 | `Configuration.defaultLocalIP` → `127.0.0.1` (keep the env-switcher override for LAN testing). | Debug-only behavior. |
| 1.7 | Extract the verbatim-triplicated unenroll confirmation into one helper. | Same component, same strings, three call sites collapse to one source. |

**Exit criteria:** build + capture diff clean; login session survives the Keychain migration on an upgraded install (test upgrade path explicitly, not just fresh install). **Score impact:** criterion 5 (Security) 2→4.

---

## Phase 2 — Compiler-enforced state layer

> The audit's central finding: the spec lives in markdown, not the compiler. This phase moves it. Effort: ~1–2 weeks, strictly ordered.

| # | Step | Risk control |
|---|---|---|
| 2.1 | `@MainActor` on `AppState`, `EntityStore`, `RelationshipIndex`, `LoadingStateManager`; fix call-site fallout; delete now-redundant method-level annotations. | Compiler does the finding. The one real hazard — `VideoActions` upload delegate on a background queue — gets explicit `await MainActor.run` hops. Characterization tests from 0.2 must stay green. |
| 2.2 | Fix `StatePersistence`: latest-snapshot debounce (cancellable work item), drop `.prettyPrinted/.sortedKeys`, encode off-main with `beginBackgroundTask` in `saveImmediately`. | Round-trip test from 0.2 guards the format change (sorted-keys removal alters file bytes but not decoded content — test asserts decoded equality, not byte equality). |
| 2.3 | DI for Actions: `init(api: APIClientProtocol = APIClient.shared, state: AppState = .shared)`. Mechanical; no call-site changes needed thanks to defaults. | Enables stubbed Action tests; zero runtime difference. |
| 2.4 | Rehome the 15 stray `APIClient.shared` calls from Pages into their matching Actions (e.g., `GroupActions.loadInviteCode()`, `OrgActions.loadMembers()`); route `BibleSearchService`/`BibleCacheManager`/`InviteQRCodeView` through `APIClient`. Document `ImageCache`/`LocalPortHealer` as sanctioned exceptions. | Pure code motion — same requests, same parsing, new home. Capture diff verifies affected pages. |
| 2.5 | **Error-channel plumbing (invisible half):** `AppState.errors` queue + Actions catch-and-record at the choke point; replace the 113 log-and-swallow catches in Actions/AppState with record-and-log. Pages keep their current (lack of) error UI. | ⚠️ **Decision Point A** unlocks the visible half: a toast/banner you design. Until approved, recorded errors render nothing. |
| 2.6 | Dissolve `AuthManager` god object: convert to `@Observable`, move invite/QR methods into Actions, make `APIClient` sole owner of the session credential, remove the key-window force-unwraps. | Largest single step — do last in this phase, behind green tests + capture diff of the full auth flow (login, logout, session restore, OAuth callback). |
| 2.7 | First **stubbed Action tests** using 2.3's DI (load/create/delete happy paths + error recording from 2.5). | Coverage beachhead. |

**Exit criteria:** State layer compiles under `@MainActor`; zero `APIClient` references in Pages/; auth flow capture-verified incl. upgrade path. **Score impact:** criterion 2: 2→4, criterion 7: 1→3, criterion 1: 3.5→4.5, criterion 4: 1.5→2.5.

---

## Phase 3 — Navigation consolidation (the transitions fix)

> Goal: ten hand-rolled sliders become one component; timers become completion handlers; strings become types. **Transitions must look and feel frame-identical** — this phase refactors the engine, not the motion. Effort: ~2–4 weeks, each step shippable.

| # | Step | Identity guarantee |
|---|---|---|
| 3.1 | **`Motion` token enum** — a pure *naming* pass: catalog the durations/curves actually in use (`Motion.modalPresent` = spring(0.4), `Motion.pagePush` = easeOut(0.3), `Motion.pageDismiss` = easeIn(0.25), `Motion.micro` = easeInOut(0.2)…) and replace literals with tokens **at identical values**. | ⚠️ **Decision Point D** (later): collapsing near-duplicate values (0.25 vs 0.3) is a feel change — separate approval. |
| 3.2 | **Completion-based sequencing**: replace the 17 `asyncAfter(0.35)` dismiss-then-present waits with iOS 17 `withAnimation(...) { } completion: { }` and an `OverlayManager.dismiss(id:then:)` helper. Remaining 48 `asyncAfter` calls triaged: navigation-choreography ones migrate, genuine UI-timing ones stay (logged for later). | Same visible sequence, now structurally tied to the actual animation instead of a wall-clock guess. |
| 3.3 | **Build `SlideStack`** — the canonical HStack+offset container: two-step insertion handled internally, single `.animation`, `.compositingGroup()`, completion callbacks, optional edge-swipe-back. **Pilot: `EditDay`** (Bool-flag slider, mid-complexity). Verify against `/transition-review` + capture + hand-feel. | Edge-swipe-back is **additive** on pages that lack it — strictly new capability, nothing removed. Per-page quirks (GroupHomePage's inverted screen-0-on-the-left) are preserved via configuration, not "fixed." |
| 3.4 | Migrate the remaining ~9 sliders to `SlideStack`, one commit each: `EditEnrollmentDay`, `EnrollmentSchedulePage`, `EditReadActivityPage`, `CreateProgramPage`, `ProgramHomePage` (incl. its nested opacity-swap third screen), `GroupHomePage` last (most idiosyncratic). | Capture diff per page; each is a one-commit revert. |
| 3.5 | **Build skill `/push-page`** now that the canonical component exists: scaffolds new sub-screens with `SlideStack`, forbids new hand-rolled HStack/offset navigation. | |
| 3.6 | **`Route` enum** replacing stringly-typed `OverlayID`; OverlayManager keyed by route; `OverlayItem` content becomes a lazy `() -> AnyView` closure (built at render time — directly attacks the async-content-pop failure class). | Type-level change; no presentation behavior altered. |
| 3.7 | **Build skill `/present-overlay`**: enforces `presentModal`/`presentMenu` + Route registration + environment dismissal + completion-based dismiss-then-present. | |
| 3.8 | **`NavigationCoordinator` (@Observable)** owning the route stack; pages migrate presentation booleans to `coordinator.push(.editDay(...))` opportunistically (target: 106 flags → <30 genuinely-local toggles). Deep links (`MainView.swift:164-201`) and push-notification routing convert to `coordinator.navigate(to:)`. | Deep-link destinations re-verified one-by-one against current behavior. |
| 3.9 | **Build skill `/nav-route`**: typed Route through the coordinator for any new deep link / notification destination / cross-tab jump; keeps `handleDeepLink` exhaustive. | |
| 3.10 | Cleanup sweep: delete unused `ContentView.swift`; replace the 5 deprecated `NavigationView`s with `NavigationStack` *in place* (same chrome). The 2 forbidden fullScreenCovers stay (⚠️ Decision Point B). | |

**Exit criteria:** zero hand-rolled offset sliders outside `SlideStack`; zero `asyncAfter` in navigation choreography; all overlays route-keyed; capture suite identical to baseline. **Score impact:** criterion 3: 1.5→4.

---

## Phase 4 — Media library structural pass (Phase 1 of the audit's media plan only)

> Everything here is invisible plumbing. The Photos-style redesign (pinch zoom levels, pager, date sections) is **deliberately excluded** — it's a design effort that starts after this plan. Can run in parallel with Phase 2 (UIKit-isolated). Effort: ~1 week.

| # | Step | Invisibility guarantee |
|---|---|---|
| 4.1 | **Pagination**: `MediaActions.loadLibrary(page:)` append semantics; `willDisplay`-near-end triggers next page; remove the 100-item cap. | First 100 items render exactly as today; items 101+ appearing is a **bug fix** (they're silently truncated now), not a design change. |
| 4.2 | `UICollectionViewDiffableDataSource` replacing full `reloadData()`. | Eliminates refresh flashing — strictly less visual disturbance, same layout. |
| 4.3 | `ImageCache.fetch(url:targetSize:)` with `CGImageSourceCreateThumbnailAtIndex` downsampling + in-flight request coalescing; adopt `UICollectionViewDataSourcePrefetching`. **Keep the `-md` 400px variant at 3 columns** (see constraint table — `-thumb` would be visibly blurrier). | Same source images, decoded smaller; visually identical at cell size. |
| 4.4 | Replace the `NotificationCenter` cell-hide/restore handshake between grid and `MediaDetailOverlay` with a direct delegate/closure (`sourceFrame(for: itemID)`). | Same transition, sturdier wiring; prerequisite for the future pager. |
| 4.5 | Cache the sorted `filteredMedia`/`orderedMedia` results instead of re-sorting per render. | Pure perf. |
| 4.6 | Sizing from the layout environment instead of static `Screen.bounds`. | Identical on iPhone today; fixes latent rotation/iPad bugs. |
| 4.7 | Migrate `VideoLibraryPage` thumbnails from raw `AsyncImage` to the shared `ImageCache`. (Full consolidation of the legacy page into the media grid is a **functionality decision** — deferred.) | Same images, now cached. |

**Skipped from the audit on constraint grounds:** pull-to-refresh on the media tab and wiring the "Create New → Media" TODO are *additive features*, not structural — listed in Backlog below for one-line approval.

**Exit criteria:** a library with >100 items fully loads; scroll through 500+ items with no placeholder flashing; capture diff clean.

---

## Phase 5 — Enforcement layer (make regressions impossible)

> Effort: ~1 week. This is what keeps the score from decaying between audits.

| # | Step | Notes |
|---|---|---|
| 5.1 | **SwiftLint** with the audit's conventions as custom rules: no `print`/`NSLog` (new code), no `try!`/`as!`/force-unwrap outside `#Preview`/tests, no `Color(hex:)` outside `Colors.swift`, no raw `.system(size:)` outside `Typography.swift`, no `asyncAfter` in navigation code, formatters must be `static`. Existing violations grandfathered via baseline file — **rules gate new code only**, so this forces no risky mass-edit. | |
| 5.2 | `os.Logger` adoption: add `Log` wrappers per domain (`Log.auth`, `Log.state`, `Log.nav`) with `.private` interpolation; migrate NSLog/print opportunistically (lint blocks new ones). | Criterion 4. |
| 5.3 | **Color token consolidation**: mechanically replace inline `Color(hex:)` **only where the hex exactly matches an existing token** (covers the 208 inline brand purples, `#0d101a`×17, `#252936`×15…). Non-matching hexes are cataloged, not changed. | Byte-identical rendering by construction. |
| 5.4 | `Typography.swift` tokens at **current fixed sizes** (no Dynamic Type yet — ⚠️ Decision Point C); mechanical call-site migration. Update CLAUDE.md's typography guidance to stop teaching raw sizes. | |
| 5.5 | Fixtures + `Pages/Demo/` behind `#if DEBUG`; promote `FixturesManager.ContactFixture` to a real `Contact` model (ContactsManager currently depends on fixture code in production). | Release binary sheds test data; Debug behavior unchanged. |
| 5.6 | **Build skill `/ios-error-surface`** (after Decision Point A resolves): every new `catch` must route to the error channel or carry a justification comment. | |
| 5.7 | Move `StudyModels`/`GroupModels`/`User` into `State/Models/` split by domain; split `ProgramActions` into Program/Lesson/Activity Actions. | Pure code motion, compiler-verified. |

**Score impact:** criterion 6: 2→3.5 (full 5 requires Dynamic Type + accessibility labels — Decision Point C territory), criterion 4: →3.5.

---

## ⚠️ Decision Points (design/behavior changes parked for your approval)

These are the only audit items this plan does NOT execute. Each is a small, separable conversation:

- **A — Error toast UI**: plumbing ships in 2.5; what does the visible surface look like? (Component, placement, duration, retry affordance.)
- **B — The 2 fullScreenCover forms** (`StudyInvitePage`, enrollment schedule): keep full-screen, or align with MODAL_GUIDE's bottom-sheet?
- **C — Dynamic Type**: turn on `relativeTo:` scaling (layout changes for users with non-default text sizes) + accessibility-label pass. Recommended, but visible.
- **D — Motion value consolidation**: collapse near-duplicate durations/curves (0.25 vs 0.3, easeOut vs easeInOut) into a smaller set. Feel change.
- **Backlog (additive features, one-line approvals):** media-tab pull-to-refresh; wire "Create New → Media" upload; consolidate `VideoLibraryPage` into the media grid; media redesign Phases 2–3 (pinch zoom, pager, date sections) as a design-led project.

---

## Skill delivery summary

| Skill | Built in | Depends on |
|---|---|---|
| `/animation-debug` | Phase 0.3 | Nothing — existing docs |
| `/transition-review` | Phase 0.4 | Nothing — existing docs |
| `/push-page` | Phase 3.5 | `SlideStack` |
| `/present-overlay` | Phase 3.7 | `Route` enum |
| `/nav-route` | Phase 3.9 | `NavigationCoordinator` |
| `/ios-error-surface` | Phase 5.6 | Error channel + Decision Point A |

## Sequencing at a glance

```
Phase 0 (safety net + 2 skills)
   └─► Phase 1 (quick wins)
          └─► Phase 2 (state layer)  ──┐
          └─► Phase 4 (media, parallel)─┤
                                        └─► Phase 3 (navigation + 3 skills)
                                               └─► Phase 5 (enforcement + 1 skill)
                                                      └─► Audit #2 (re-score)
```

Phase 3 lands after Phase 2 because `NavigationCoordinator` should be born `@MainActor`-clean and Route-based deep links touch AppState. Phase 4 is parallel-safe (UIKit-isolated).

## Projected scorecard after completion

| # | Criterion | Baseline | Projected | Remaining gap to 5 |
|---|---|---|---|---|
| 1 | State architecture fidelity | 3.5 | **4.5** | Module boundaries (SPM split) — future audit |
| 2 | Thread/concurrency safety | 2 | **4** | Swift 6 strict concurrency mode |
| 3 | Navigation & transitions | 1.5 | **4** | Full boolean→route migration tail |
| 4 | Error handling & observability | 1.5 | **3.5** | Visible error UI (Decision Point A) |
| 5 | Security posture | 2 | **4** | Cert pinning / jailbreak posture if ever needed |
| 6 | Design system adoption | 2 | **3.5** | Dynamic Type + a11y labels (Decision Point C) |
| 7 | Testability & coverage | 1 | **3** | Page-level/snapshot coverage |
| 8 | Documentation accuracy | 2.5 | **4.5** | Sustained by docs-are-code convention |
| | **Overall** | **2.0** | **~3.9** | |
