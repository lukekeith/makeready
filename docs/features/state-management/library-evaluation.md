# Library evaluation — should we adopt something instead?

Research review, 2026-08-01. **Question:** is there an off-the-shelf iOS library (a MobX/Redux/
TanStack-Query equivalent) that would solve MakeReady's state problem better than the hand-rolled
`AppState` + Actions + `EntityStore` pattern this spec standardizes?

**Verdict: no — proceed with the spec, adopt nothing now.** The reasoning below matters more than
the verdict, because it also identifies the one condition under which that answer flips.

## The finding that settles it

**The iOS ecosystem has no mature TanStack Query equivalent.** That is precisely the category
MakeReady's bug lives in: *server* state — data owned by a remote API, cached locally, needing
invalidation when a mutation makes it stale. On the web that is a solved problem with a dedicated
tool (query keys + `invalidateQueries`). Searching the Swift ecosystem for the counterpart turns up
generic caching helpers, GraphQL clients (Apollo iOS), and networking-layer caches (MoyaCache) —
nothing that manages server-state lifecycle. The ecosystem consensus is a manual, protocol-based
approach composed per app.

So the option "adopt a library and this bug class disappears" **is not on the table**. That reframes
everything below.

## What the available libraries actually are

Everything in the Swift state-management space is a **state container** — a place to put state and a
way to observe it:

| Library | Shape | Relevance here |
|---|---|---|
| [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) | Redux-like, reducers + effects, deep SwiftUI navigation integration | Most capable, most invasive. Adopting it in a 190-page app is a rebuild, not a migration, and it does not by itself supply the missing rule. |
| [swift-sharing](https://github.com/pointfreeco/swift-sharing) (`@Shared`) | Property wrapper for sharing + persisting state, usable outside TCA | Closest targeted fit for Mode 1. See below. |
| [Verge](https://github.com/VergeGroup/swift-verge), [OneWay](https://github.com/DevYeom/OneWay), Bloc-for-iOS, [AtomObjects](https://github.com/kzlekk/AtomObjects) | Unidirectional-flow containers of varying weight | Same category as what MakeReady already has. |
| SwiftUI `@Observable` / Observation | Apple-native | **Already in use.** `AppState` is `@Observable`. |

**MakeReady already has a state container**, and a reasonable one: `AppState` (`@Observable`), 13
`EntityStore`s, `RelationshipIndex`, `LoadingStateManager`, disk persistence. The audit found the
container is not the problem — [audit.md](audit.md) shows 7 of 19 sites are already correct, the
`APIClient` boundary holds app-wide, and the web client using the same philosophy (Pinia stores) is
fully conformant.

**Adding a second container would give a second mechanism without supplying the missing rule.** For
a discipline problem, that is a net negative: two right ways to do something is how you get a third,
wrong way.

## The one exception: database-as-source-of-truth

There is a category that would **structurally eliminate** both failure modes rather than merely
discourage them — where views live-query a local database instead of holding fetched arrays:

- **[SQLiteData](https://github.com/pointfreeco/sqlite-data)** (Point-Free; formerly SharingGRDB,
  built on GRDB, now 1.0 with CloudKit sync). `@Table` + `@FetchAll`/`@FetchOne` are analogous to
  SwiftData's `@Model`/`@Query` but sit directly on SQLite — joins, aggregates, CTEs, and usable
  from `@Observable` models and UIKit, not just SwiftUI views.
- **SwiftData** — Apple-native, iOS 17+.

Why this category is different: **there is no fetched array to fork.** A view declares a query; the
store pushes updates. That kills Mode 2 (forked copies) outright, and Mode 1 (homeless domains)
cannot arise because every domain is a table by construction. This is the only option that makes the
bug *inexpressible* rather than *discouraged*.

**Why not now, regardless:**

- It is a **re-platform of the entire client data layer**, not a refactor. MakeReady's data arrives
  from a REST API and is cached via `StatePersistence`/`PersistedState`; moving to a local database
  as the source of truth changes loading, caching, offline behaviour, and every Action. That is
  wildly disproportionate to **8 problem sites**.
- **SwiftData specifically is not compelling in 2026.** WWDC26 added sectioned fetching,
  `@Attribute(.codable)`, `ResultsObserver`, and `HistoryObserver` — useful gap-filling, but the
  community read is that it "feels more like filling key gaps rather than making a leap significant
  enough to fundamentally change confidence in it," with cloud syncing for shared data still absent.
- SQLiteData is credible and actively developed, but adopting it is a strategic bet on the
  Point-Free stack, not a bug fix.

## swift-sharing (`@Shared`) — the closest near-miss

Worth naming explicitly because it is the one library aimed squarely at MakeReady's Mode 1:
"instantly share state among your app's features and external persistence layers." Multiple models
referencing the same `@Shared` value see each other's changes immediately, with `appStorage` /
`fileStorage` / `inMemory` strategies, and it works without adopting TCA.

**Why the spec still wins for this codebase:**

1. It solves a problem MakeReady **already has a solution for** — `AppState` is exactly "one place
   multiple screens observe." Phase B is ~3 properties mirroring the existing `textThemes` pattern.
2. **Friction with the current design:** `@Shared` inside an `@Observable` model must be annotated
   `@ObservationIgnored`. `AppState` is `@Observable`. That is a papercut on every property.
3. It would live **alongside** `AppState`, not replace it — reintroducing the "which mechanism?"
   ambiguity this spec exists to remove.
4. **It does not enforce anything.** Nothing stops a developer writing
   `@State private var members: [Member] = []` next to it. Only Phase D does that.

Reasonable to revisit if MakeReady ever needs cross-device sync or richer persistence strategies,
where `@Shared`'s strategy system earns its keep.

## Independent corroboration of the spec's rule

Alexey Naumov's [state management guide](https://nalexn.github.io/state-management-guide-ios), a
long-standing reference, lands on the same rule this spec writes down:

- Single Source of Truth — "you don't need to worry about outdated data" — versus caching in
  multiple places. That is Mode 2 stated as a principle.
- **Local screen state stays in the screen module; state shared across screens is unified centrally.**
  That is this spec's rule almost verbatim, and it validates the audit's refusal to migrate
  legitimately-local buffers like `ProgramHomePage.editTags`.
- It prescribes *patterns* (Single Source of Truth, Restricted Mutation, Unidirectional Data Flow)
  rather than mandating a library — naming Redux/ReSwift only as examples that comply.

**One fair criticism it raises against the current design:** it advises avoiding singletons for
state access in favour of dependency injection. `AppState.shared` is a singleton. This is a real
architectural note — logged as a deferred item below, not something to fix while fixing a bug.

## Decision

**Proceed with the spec as written. Adopt no library.**

1. The defect is a missing **rule** plus a missing **invalidation edge**, not a missing mechanism.
   No container library supplies either.
2. The only family that would structurally fix it (SQLiteData/SwiftData) is a client data-layer
   re-platform — disproportionate to 8 sites, and SwiftData is not compelling in 2026 anyway.
3. MakeReady's existing pattern is validated by an independent reference and is already working on
   the web side of the same product.
4. Phase D (enforcement) delivers the thing no library provides: making the wrong shape fail the
   build.

### Revisit triggers

Re-open this evaluation if any of these become true:

- **The same bug class recurs after Phases B–D.** That would mean enforcement is insufficient and
  the structural fix (live queries) is warranted.
- **Offline-first or cross-device sync becomes a product requirement.** SQLiteData's CloudKit
  support would then be doing real work rather than being incidental.
- **A genuine server-state library appears for Swift.** Nothing today occupies the TanStack Query
  niche; that could change.
- **`AppState.shared`'s singleton access becomes a testing obstacle.** The DI critique is valid;
  `ThemeActions` already accepts a `stateOverride`, which is the seam to generalize if needed.

### Deferred, explicitly not in this spec

- Dependency-injecting `AppState` instead of `.shared` (Naumov's critique).
- Any evaluation of TCA. If MakeReady ever rebuilds the iPhone client, revisit then — not before.

## Sources

- [swift-sharing](https://github.com/pointfreeco/swift-sharing) · [Simple state sharing and persistence in Swift](https://www.pointfree.co/blog/posts/159-simple-state-sharing-and-persistence-in-swift)
- [SQLiteData](https://github.com/pointfreeco/sqlite-data) · [SQLiteData 1.0](https://www.pointfree.co/blog/posts/184-sqlitedata-1-0-an-alternative-to-swiftdata-with-cloudkit-sync-and-sharing)
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [What's New in SwiftData — WWDC26](https://dev.to/arshtechpro/wwdc-2026-whats-new-in-swiftdata-sectioned-queries-codable-attributes-and-observers-2ao5) · [First Impressions of WWDC 2026 — Fatbobman](https://fatbobman.com/en/weekly/issue-139/)
- [The Complete Guide to State Management in iOS — Alexey Naumov](https://nalexn.github.io/state-management-guide-ios)
- [Verge](https://github.com/VergeGroup/swift-verge) · [OneWay](https://github.com/DevYeom/OneWay) · [Swift Package Index: state-management](https://swiftpackageindex.com/keywords/state-management)
