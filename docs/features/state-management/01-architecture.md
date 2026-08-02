# 01 — Architecture

> Adopted into the `/build-spec` pipeline 2026-08-01. The architecture narrative already lives in
> [README.md](README.md) and is not duplicated here — this doc carries the pipeline's required
> **Decisions table** and points at the rest.

## Overview — where the content lives

| Topic | Where |
|---|---|
| **The rule** (what must live in `AppState`) | [README.md](README.md) § The rule |
| Why this is not a redesign (three proofs the pattern works today) | [README.md](README.md) § Why this is not a redesign |
| The two failure modes — Mode 1 homeless domain, Mode 2 forked copy | [README.md](README.md) § The two failure modes |
| Per-site classification of all 19 local collections | [audit.md](audit.md) |
| Build-vs-buy research (TCA, swift-sharing, SQLiteData, SwiftData) | [library-evaluation.md](library-evaluation.md) |
| Enforcement design (SwiftLint rule, baseline, review checklist) | [enforcement.md](enforcement.md) |
| Delivery phases A–D + the ordering hazard | [README.md](README.md) § Delivery phases |

## Baseline patterns (cited by file:line)

The feature ports an existing in-repo exemplar rather than inventing a pattern:

- **Reference-collection exemplar** — `ThemeActions.loadThemes()` (`ThemeActions.swift:62-66`)
  writes `state.textThemes` and calls `state.persist()`. **verified in code (2026-08-01)**
- **Non-entity server collections already hosted on AppState** — `AppState.swift:339-358`
  (`homeHeatmapData`, `homeWeeklyActivity`, `homeTotalMembers`, `homeTotalGroups`).
  **verified in code (2026-08-01)**
- **The homeless domain being fixed** — `ProgramActions.swift:402-495` (`getTags`, `addTags`,
  `removeTags`, `syncTags`, `loadAllTags`, `loadGroupLeaders`, `suggestTags`) contains zero
  `state.` writes. **verified in code (2026-08-01)**
- **Read-through helpers that Mode 2 will use** — `postsFor`, `membersFor`, `enrollmentsFor`,
  `lessonsFor` all exist. **verified in code (2026-08-01, STATUS.md sanity check)**
- **The persistence wiring Phase B inherits** — `textThemes` is seven sites across
  `AppState.swift` (`:142`, `:663`) and `PersistedState.swift` (`:58`, `:123`, `:210`, `:246`,
  `:291`). **verified in code (2026-08-01)**

## Decisions table

Every settled design question. Open questions are `D#` rows in
[09-gaps-and-decisions.md](09-gaps-and-decisions.md), not here.

| # | Decision | Answer | Decided |
|---|---|---|---|
| 1 | Fix the architecture, or patch the reported bug? | **Fix the architecture.** Monday 12668501065 sub-issue J is fixed as a *consequence* of Phase B, not as a local `.onAppear` refresh — J becomes the first worked example of the new rule | Owner, 2026-08-01 |
| 2 | Build or adopt a library? | **Build.** iOS has no TanStack Query equivalent — the category this bug lives in — so "adopt a library and it goes away" was never available. Only database-as-source-of-truth (SQLiteData) would structurally kill the bug class, and that is a client data-layer re-platform, disproportionate to 8 sites. Revisit triggers in [library-evaluation.md](library-evaluation.md) § Revisit triggers | 2026-08-01 |
| 3 | Phase order | **A → B → C → D, fixed.** D last because the SwiftLint baseline is regenerated wholesale; running it earlier would enshrine the violations B and C delete | 2026-08-01 |
| 4 | How many of the 19 audited sites migrate? | **Not all.** Eight have a demonstrated problem, seven are correct as written, four need a judgment call. Speculative migration is out of scope; dispositions in [audit.md](audit.md) | 2026-08-01 |
| 5 | Is the web in scope? | **No.** Audited and conformant — 14 Pinia stores, zero component API calls. It is a second working exemplar, not a target. Evidence in [05-client.md](05-client.md) | 2026-08-01 |
| 6 | Does the earlier fix sketch for J still apply? | **Superseded.** `docs/monday/tickets/12668501065.md` proposed refreshing `allTags` in `.onAppear`; that treats the symptom | 2026-08-01 |
| 7 | Does the persisted-state format need a cache-bust on upgrade? | **Moot** — decision 8 means the format doesn't change. (Had it changed: no, `PersistedState.swift:291` decodes with `decodeIfPresent(…) ?? []`) | 2026-08-01 |
| 8 | Do the new shared collections persist to disk? | **No — memory-only.** Plain `@Observable` properties following `homeHeatmapData` (`AppState.swift:339-358`); `PersistedState.swift` is untouched. They refetch after launch and sign-out, which is the intended trade | Luke, 2026-08-01 (`D1`) |
| 9 | Fix the pre-existing `textThemes` sign-out leak here? | **Yes.** `clearInMemory()` (`AppState.swift:736-776`) gains `textThemes = []` alongside the new collections — a one-line fix in a file Phase B already edits | Luke, 2026-08-01 (`D2`) |
| 10 | How does Phase C handle the cursor-paginated posts list? | **Design store-backed pagination now** (chosen against the recommendation to defer — this materially enlarges Phase C). Follows the media-library exemplar: cursor in `AppState` keyed by `groupId`, Action writes, `upsertMany` + `RelationshipIndex.addMany` to append. Design in [06-iphone.md](06-iphone.md) § Paginated posts | Luke, 2026-08-01 (`D3`) |
| 11 | Is the capture tool in scope? | **Yes** — originally claimed out of scope; audit pass 1 disproved it (`X1`). `ViewRegistry` renders the modified pages from a seeded `AppState`, so Phase C's read-through changes captured output. Re-capture + diff lives inside Phase C | Luke, 2026-08-01 (`X1`) |

## Permissions / RBAC

**No change.** This feature moves where already-fetched data is held on the client. It introduces
no new endpoint, no new authorization path, and no change to what any role can see.

## Out of scope (deliberate)

Restated from [README.md](README.md) § Non-goals so the cuts are visible:

- Any web/client change — the web is conformant ([05-client.md](05-client.md))
- Migrating every local collection — only sites with a demonstrated sharing or mutation path
- Replacing `EntityStore`, `RelationshipIndex`, or the Actions pattern — they work
- The `APIClient` boundary — already clean on both platforms
- Server-side changes — nothing touches `server/`
- The other nine sub-issues of ticket 12668501065 — only J, and only via Phase B
