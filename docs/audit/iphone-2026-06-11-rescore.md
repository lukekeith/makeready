# iPhone App Architecture Audit — Re-Score 2026-06-11

| | |
|---|---|
| **Date run** | June 11, 2026 |
| **Audit #** | 2 (first re-score against the 2026-06-10 baseline) |
| **Scope** | `/iphone/MakeReady` — same 8 criteria, same 1–5 scale (1 = ad-hoc / 3 = inconsistent / 5 = enforced & healthy) |
| **Method** | 6 parallel read-only evidence agents (state+concurrency, navigation, errors, security, design system, tests+docs), fresh grep counts and file reads — progress-doc claims verified independently, not trusted. SwiftLint baseline re-measured directly: **1,118** (matches docs exactly; was 2,449 at gate creation). |
| **Plan context** | [iphone-2026-06-10-plan.md](./iphone-2026-06-10-plan.md) projected ~3.8–3.9 with everything except Decision Points A–D landed. A was later resolved (error banner shipped); B, C, D remain parked. Media M0.1/M0.3/M0.5 + M1 shipped; M2/M3 not. |

---

## Scorecard

| # | Criterion | Baseline | Plan target | **Current** | Evidence |
|---|---|---|---|---|---|
| 1 | State architecture fidelity | 3.5 | 4.5 | **4.0** | `APIClient.shared` in Pages/Components: **15+ → 0**. DI `init(api:state:)` on all Actions (`GroupActions.swift:15-29`). `GETCoalescer` actor dedups in-flight GETs (`APIClient.swift:415-447`). `ProgramActions` split 579+104+752 lines; `State/Models/` split into 9 domain files. Caps: ~18 `@State` mirrors persist (`GroupMembersPage.swift:21-22`, `MainHome.swift:33`); `StudyModels.swift` (1,034 lines) still in `Pages/Manage/Program/Models/`; AuthManager downsized to 406-line `@Observable` but not dissolved. |
| 2 | Thread/concurrency safety | 2 | 4 | **4.0** | Type-level `@MainActor` on all four core types: `AppState.swift:53`, `EntityStore.swift`, `RelationshipIndex.swift`, `LoadingStateManager.swift:79`. StatePersistence: latest-snapshot debounce w/ lock + work-item cancel (`StatePersistence.swift:90-115`), off-main encode + `beginBackgroundTask` (`:129-144`), no `.prettyPrinted/.sortedKeys`. VideoActions delegate callbacks hop via `Task { @MainActor in }` (`VideoActions.swift:301-308`). Gap to 5: Swift 6 strict concurrency mode. |
| 3 | Navigation & transitions | 1.5 | 4 | **3.5** | Hand-rolled sliders **~10 → 0** (SlideStack canonical; `EnrollmentFlowModal` wizard + `VideoPlayerPage` swipe-dismiss are documented non-stack exceptions). `asyncAfter` **65 → 42**, **zero** at 0.35s; survivors are toast timers, not nav choreography. `Route.swift` (40 cases) keys OverlayManager; only 7 string-id calls, all documented dynamic exceptions. `NavigationCoordinator` `@Observable @MainActor` with exhaustive `handle(deepLink:)` (no default). Motion: 11 tokens + 3 documented decorative literals. 18 iOS 17 `} completion:` sites. NavigationView **5 → 0**; ContentView deleted; `OverlayItem.content` stored `AnyView` (3.6c rejection holds). Caps: presentation booleans **~106 → 88** (target <30, opportunistic by design); Decision Points B (1 forbidden fullScreenCover remains, `EnrollmentSchedulePage.swift:102`) and D parked. |
| 4 | Error handling & observability | 1.5 | 3.5 | **2.5** | Plumbing complete: `AppState.recordError(surface:retry:)` + capped error queue (`AppState.swift:227-270`); `ErrorBanner`/`ErrorBannerHost` shipped with 4s auto-dismiss, swipe-up, retry (`Components/Feedback/ErrorBanner.swift`), mounted above all overlays (`MainView.swift:147`). Adoption thin: **25** `recordError` sites total, only **3** `surface: true` (all GroupHomePage); **141 of 215** catch blocks still NSLog/print-and-swallow. `Log.<domain>` wrappers exist (8 domains, `Utilities/Log.swift:27-46`) with **0 production call sites**; NSLog 544→518, print 289→180. Lint bans new NSLog/print (`.swiftlint.yml:32-37`). |
| 5 | Security posture | 2 | 4 | **4.0** | `NSAllowsArbitraryLoads` removed; localhost/127.0.0.1-only ATS exceptions (`Info.plist:67-88`). Session cookie in Keychain (`SessionCredentialStore.swift`, `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock`) with one-time UserDefaults migrator (`:52-58`); APIClient sole owner. No cookie/token values logged (length/4-char-suffix only). `try!` **16 → 0** in production (`AttributedString.safeMarkdown` helper, 12 call sites). LAN IP `#if DEBUG`-gated, Release → 127.0.0.1 (`Configuration.swift:44-54`). Key-window force-unwrap replaced with `??` fallback chain (`AuthManager.swift:388-400`). |
| 6 | Design system adoption | 2 | 3.5 | **3.0** | `Color(hex:)` outside Colors.swift: **428 → 140** (brand purple via token 243× vs 1 inline). `.system(size:)` outside Typography.swift: **1,031 → 24** (98% migrated; `Typography.swift` 63 tokens at fixed sizes, no `relativeTo:` — parked). Both gated by SwiftLint custom rules + 1,118-violation baseline. Motion tokens at original values (D parked). Fixtures + 4 `Pages/Demo` pages behind `#if DEBUG`; `Contact` promoted to `State/Models/Contact.swift`; mockContacts confined to `#Preview` structs. Caps: accessibility modifiers still **7** (baseline-unchanged), 0 localization, no Dynamic Type — all Decision Point C; ~60 distinct unmatched hexes lack a design catalog. |
| 7 | Testability & coverage | 1 | 3 | **3.0** | **66 test methods** across 7 files (EntityStore 17, RelationshipIndex 14, ModelDecoding 16, ActionStub 7, PersistenceRoundTrip 5, BibleNormalizer 6, CaptureRunner 1). `APIClientProtocol` (`APIClient.swift:403`) + `StubAPIClient` with call recording; all Actions injectable. Snapshot capture runner + decoding fixtures. Gap to 4: page-level coverage breadth; most Actions beyond Group lack stubbed tests. |
| 8 | Documentation accuracy | 2.5 | 4.5 | **4.0** | Port 3010 + api.makeready.org correct throughout (`iphone/.claude/CLAUDE.md:130`); phantom `API_REFERENCE.md` mandate gone (replaced by makeready-api MCP guidance); connected-component tier, sanctioned URLSession exceptions (`:1118-1140`), Route/overlay conventions, SwiftLint gate all documented; cache-first contract codified (`SWIFTUI_TRANSITIONS.md:143-252`). New drift found: CLAUDE.md `:415` lists `BackgroundPickerModal.swift` as a connected component — **deleted in 3.10**; `InviteActions`/`OrgActions` missing from the Actions table (11 of 13 documented). |
| | **Overall** | **2.0** | **~3.9** | **3.5** | |

**Overall: 3.5 / 5** (mean of the eight criteria, = 28/8). Up 1.5 points from baseline in two days of execution; short of the plan's ~3.9 projection mainly because criterion 4's adoption never followed its plumbing, and because the boolean-migration tail (criterion 3) and `@State`-mirror tail (criterion 1) were deliberately left opportunistic.

---

## Per-criterion notes

### 1. State architecture (3.5 → 4.0)
**What moved it:** the headline violation — pages doing their own networking — is at zero, and the pattern is now compiler-assisted (DI on every Action, `GETCoalescer` after the rate-limit incident, model/Action file splits landed as committed in 5.7).
**What caps it:** ~18 pages still mirror AppState data into local `@State`. Note this is now partially *sanctioned* — the cache-first contract (SWIFTUI_TRANSITIONS.md) codifies init-time `@State(initialValue:)` pre-population to fix the Class-3 slide regression — but it still duplicates source of truth rather than reading accessors with local-ID-order-only state, which is what the audit prescribed. `StudyModels.swift` (1,034 lines) remains in `Pages/` (plan 5.7 named it; only `Models.swift` was split). AuthManager kept OAuth + sanctioned QR methods. `ErrorBanner` reads `AppState.shared` but isn't on CLAUDE.md's connected-components list.

### 2. Thread/concurrency (2 → 4.0)
**What moved it:** everything the plan promised, verified in code — all four core state types are type-level `@MainActor`, both StatePersistence bugs (stale-write debounce, main-thread encode) are demonstrably fixed, and the one known hazard (VideoActions background delegate) hops explicitly.
**What caps it:** Swift 5 language mode; ~152 method-level `@MainActor` annotations remain (harmless but noisy). Exactly the plan's stated gap.

### 3. Navigation & transitions (1.5 → 3.5)
**What moved it:** the five-engine mess is structurally gone — one SlideStack, typed Routes, an exhaustive deep-link coordinator, motion tokens, completion handlers instead of every 0.35s wall-clock wait, zero deprecated NavigationViews, and the whole thing fenced by SwiftLint's `async_after_choreography` rule plus four skills.
**What caps it (half-point below target):** 88 presentation booleans vs the <30 target — the migration was declared opportunistic and has barely started (106 → 88). Decision Point B (the remaining forbidden fullScreenCover) and D (motion value consolidation) are parked. The architecture is healthy; the *state sprawl* the booleans represent is the remaining inconsistency.

### 4. Error handling & observability (1.5 → 2.5) — biggest miss vs target (3.5)
**What moved it:** the entire plumbing stack shipped and is device-verified — error queue, `recordError` choke point, ErrorBanner with retry, lint gate on new NSLog/print, 8 `os.Logger` domains.
**What caps it:** adoption. Only 3 `surface: true` sites exist (all in GroupHomePage — the two exemplars plus one); 141 of 215 catch blocks still log-and-swallow; `Log.<domain>` has **zero** production call sites, so logging remains unstructured/unleveled in practice (518 NSLog + 180 print). The plan's own framing ("opportunistic migration") predicted this, but the criterion measures reality, not infrastructure. The `/ios-error-surface` skill exists but isn't referenced from `iphone/.claude/CLAUDE.md`, which slows organic adoption.

### 5. Security posture (2 → 4.0)
**What moved it:** every baseline finding independently verified fixed — ATS, Keychain (with the login-preserving migrator), sensitive-log deletion, all 16 `try!` sites, DEBUG-gated LAN IP, key-window force-unwrap. No new secrets found in UserDefaults or hardcoded.
**What caps it:** plan's own gap — cert pinning / deeper hardening only if ever warranted. APNs device token still in UserDefaults (not a secret; consistency nicety). One stale comment references the old UserDefaults cookie (`ReadActivityPreviewModal.swift`).

### 6. Design system (2 → 3.0)
**What moved it:** the two mechanical migrations are real and enforced — 98% of raw font sizes and 67% of inline hexes are gone, with lint rules + baseline preventing regression; fixtures/demo pages are out of the Release binary; Motion/Typography/Colors token files all exist.
**What caps it (half-point below target):** the criterion explicitly includes Dynamic Type and accessibility, and both sit at baseline (7 accessibility modifiers, 0 localization, no `relativeTo:`) — all Decision Point C, parked by design. The ~49–60 cataloged unmatched hexes await their design pass. Scoring at the 3.5 target would require crediting the parked work; 3.0 reflects token adoption done, human-facing adaptivity untouched.

### 7. Testability & coverage (1 → 3.0)
**What moved it:** from one test file to 66 tests with a real seam — protocol, stub with call recording, injectable Actions, decoding fixtures, persistence round-trip, snapshot runner. Hit the target exactly.
**What caps it:** breadth — `ActionStubTests` covers Group flows; the other 12 Actions structs have no stubbed tests; no page-level unit coverage beyond the capture runner.

### 8. Documentation accuracy (2.5 → 4.0)
**What moved it:** every baseline error fixed and verified (ports, URLs, phantom mandate, counts), plus the docs grew teeth: connected-component tier, sanctioned-exception list, Route conventions, lint-gate documentation, and the cache-first contract written into the scar-tissue doc the same day the bug class was diagnosed.
**What caps it:** drift has already restarted — `BackgroundPickerModal.swift` is cited as a live connected component but was deleted in cleanup 3.10, and 2 of 13 Actions (`InviteActions`, `OrgActions`) are missing from the Actions table. Small, but this criterion is precisely about catching that.

### Media status (audit §3 — informational, not a scorecard criterion)
M0.1 (persist cap), M0.3 (LRU disk cache), M0.5 (telemetry) and all of M1 (cursor paging, EXPLAIN-verified flat at 250k rows: 0.023→0.038ms vs offset's 23.8ms at page 2,500) are shipped. M0.2/M0.4 (eviction + gap tolerance) folded into M2; **M2 (SQLite index + windowed faulting) and M3 (visible Photos-style redesign) are not built** — the in-memory EntityStore still accumulates unboundedly past ~50–100k items, and the grid remains flat/3-column. Nothing here was scored as if M2/M3 existed.

---

## To reach the next half-point, per criterion

1. **State (4.0 → 4.5):** convert the ~18 `@State` mirrors to AppState-accessor reads (keep only ID-order locally where drag needs it) — reconcile with the cache-first contract rather than around it; move `StudyModels.swift` into `State/Models/`; add `ErrorBanner` to the connected-components list.
2. **Concurrency (4.0 → 4.5):** adopt Swift 6 strict concurrency (or `-strict-concurrency=complete` in Swift 5 mode); delete redundant method-level annotations.
3. **Navigation (3.5 → 4.0):** burn the boolean count 88 → <50 by routing the highest-traffic pages through `coordinator.push(...)`; Decision Points B + D get it to 4.5+.
4. **Errors (2.5 → 3.0):** run `/ios-error-surface` across the 141 swallowing catches in Pages (route, recover, or justify); add 2–3 `surface: true` adoptions outside GroupHomePage (delete/upload/send paths); start real `Log.<domain>` usage (even just Actions); ~~reference the skill from `iphone/.claude/CLAUDE.md`~~ ✅ *done 2026-06-11: CLAUDE.md gained an "Error Handling — the Error Channel" section, its canonical page example now teaches `recordError` (it previously taught NSLog-and-swallow), and the old "### Logging" section that taught NSLog/print now teaches `Log.<domain>`.* → 3.5 needs the catch-block sweep substantially done.
5. **Security (4.0 → 4.5):** ~~delete the stale UserDefaults-cookie comment~~ ✅ *done 2026-06-11 — the `ReadActivityPreviewModal` header was stale twice over: the implementation uses a short-lived preview token, not cookie planting; comment rewritten to match.* Remaining: move the APNs token to Keychain for consistency; document SessionCredentialStore as the sole Keychain owner.
6. **Design (3.0 → 3.5):** the hex-catalog design pass (49–60 unmatched values → tokens or documented exceptions). → 4+ requires Decision Point C (Dynamic Type + accessibility labels).
7. **Tests (3.0 → 3.5):** stubbed tests for 3–4 more Actions (Enrollment, Media, Video — the mutation-heavy ones); a MediaActions pagination/cursor test.
8. **Docs (4.0 → 4.5):** ✅ *done 2026-06-11, same day:* removed the `BackgroundPickerModal` reference (added `ErrorBanner` to the connected-components list in its place); added `InviteActions`/`OrgActions` to the Actions table; also fixed drift found while editing — `ContentView.swift` still listed in the project tree (deleted in 3.10), `Models.swift` shown as a monolith (split into `State/Models/` in 5.7), the `ProgramActions` split files missing, "use Log wrappers once 5.2 lands" (5.2 landed), and the "~2,400 grandfathered violations" figure (now ~1,100). The criterion now rests on the docs-are-code habit holding.

---

## For the next audit

- Violation-count trendline: APIClient-in-Pages **0** · `@State` mirrors **~18** · presentation booleans **88** · `asyncAfter` **42** (0 at 0.35s) · hand-rolled sliders **0** · `Color(hex:)` outside tokens **140** · log-and-swallow **141/215** · `try!` **0** · accessibility modifiers **7** · test files **7** (66 methods) · SwiftLint baseline **1,118** · `surface: true` sites **3** · `Log.` production sites **0**.
- The real health signal: do *new* pages use SlideStack/Route/recordError without being told, and does the SwiftLint baseline number only ever go down.
