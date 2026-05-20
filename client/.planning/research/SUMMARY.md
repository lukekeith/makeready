# Project Research Summary

**Project:** MakeReady Admin Panel — v2.1 Unified Member Management + Activity History
**Domain:** Vue 3 admin island extending an existing Laravel Blade + Pinia app
**Researched:** 2026-03-21
**Confidence:** HIGH for stack, features, and architecture. LOW for activity history API shape (unconfirmed endpoint).

## Executive Summary

MakeReady v2.1 adds a new top-level `/admin/members` section to an already-operational admin panel (v2.0). The scope is cross-group member aggregation, tag-based client-side filtering, a virtualized table for large member sets, member profile drill-down, and leader-scoped activity history replay. The iPhone app is the authoritative reference implementation: it deduplicates members by `userId` across groups, loads all groups in parallel, and filters client-side on the pre-loaded dataset. The web admin must replicate this pattern using TanStack Table + TanStack Virtual (two new packages) while leaving every existing v2.0 store, component, and section unchanged.

The recommended approach is to build in strict dependency order: install packages and register the route first (to make the feature navigable immediately), then build domain stores (cross-group aggregation, activity domain), then pure display components (AdminVirtualTable, MemberFilterBar, MemberProfileDrawer, ActivityTimeline), then UI stores that compose the domain, and finally wire everything together in the section file. All filter state must live exclusively in Pinia — not split between TanStack's column filter model and Pinia — and TanStack Table must receive a `computed` returning a new array reference, not a mutated `ref`, to avoid stale reactivity.

The primary risk is the activity history API: the endpoints required for lesson completion and written-response replay (`GET /admin/api/members/:memberId/lessons` and lesson detail) have no iPhone reference implementation and are unconfirmed. Every activity history UI and store task must be gated on an API verification step. If the endpoints do not exist or require server work outside this milestone, the entire activity history phase is blocked. The cross-group member list, tag filtering, and profile drawer are fully de-risked — all required API endpoints are confirmed.

## Key Findings

### Recommended Stack

The existing stack (Laravel 12, Vue 3.5, Pinia 3, reka-ui 2.9, hls.js, sass) requires only two new packages: `@tanstack/vue-table@8.21.3` and `@tanstack/vue-virtual@3.13.23`. Both are headless — they produce zero CSS output, integrate with BEM SCSS without conflicts, and work via composables (`useVueTable`, `useVirtualizer`) imported directly inside Vue islands. No global component registration. No Tailwind. No additional type packages required.

**Core technologies:**
- `@tanstack/vue-table 8.21.3`: Headless table logic (sorting, filtering, column defs, row model) — the only Vue-native headless table that pairs officially with TanStack Virtual; `manualFiltering: true` mode lets Pinia own all filter state
- `@tanstack/vue-virtual 3.13.23`: Row virtualization — renders only visible rows; integrates with `table.getRowModel().rows` directly; must use `getCoreRowModel()` only (incompatible with `getPaginatedRowModel()`)
- `reka-ui 2.9.2` (already installed): TagsInput + Combobox — provides the chip/tag filter UI with full keyboard nav and ARIA at no additional dependency cost
- `hls.js 1.6.15` (already installed): Activity history video seek — `videoElement.currentTime = event.timestamp` on timeline click; no new library needed

See `.planning/research/STACK.md` for version compatibility table, rationale, and alternatives considered.

### Expected Features

The iPhone app is the specification. Features not in the iPhone app should not be built. The cross-group member list is the prerequisite for everything else — all other v2.1 features are navigated from a row selection in that list.

**Must have (v2.1 table stakes):**
- Cross-group member list (all groups, deduplicated by `userId`, TanStack Table + Virtual)
- Name search and group chip filter (client-side on pre-loaded dataset — matches iPhone UX)
- Member profile drawer (reuse existing profile endpoint + drawer pattern; show all groups)
- Lesson completion list per member (requires leader-scoped `/api/member/lessons?memberId=X`)
- Lesson detail activity replay (SOAP notes, USER_INPUT responses, video completion status)
- Enrollment progress summary (% complete per study program)

**Should have (v2.1.x, after validation):**
- Activity log timeline per member (AUTH/JOIN/ACCESS events from `/api/activity-logs?memberId=X`)
- Multi-group assignment (add/remove member from groups; must invalidate per-group member cache)
- Per-enrollment day-by-day timeline

**Defer (v2.2+):**
- Searchable activity history by lesson title
- Member tags/labels (requires new API data model)
- Leader annotations on member activity (requires consent/privacy considerations)
- Real-time presence, bulk exports, messaging from admin panel — all explicitly excluded

All P1 features are backed by confirmed API endpoints. Activity history endpoints are unconfirmed — see Gaps section.

See `.planning/research/FEATURES.md` for the full feature prioritization matrix and API surface summary.

### Architecture Approach

v2.1 is purely additive to the existing architecture. Two new domain stores (`all-members.domain`, `member-activity.domain`), two new UI stores (`members-list.ui`, `member-detail.ui`), five new admin components, one new section file, and two modified files (`router.ts`, `admin-sidebar.vue`). No existing stores or sections change. The `all-members.domain` fans out to the existing `members.domain` (which already caches per-group), uses `Promise.allSettled` for resilience, and exposes a `computed` flat array deduplicated by `userId` with `groupIds: string[]` on each row. The `AdminVirtualTable` component is purely presentational — stores live in the section file only.

**Major components:**
1. `MembersSection.vue` — route page; orchestrates all stores, handles events, owns `onMounted` data load
2. `all-members.domain` — fan-out cross-group aggregation; composes existing `groups.domain` + `members.domain`; exposes `allMembers` computed (deduplicated)
3. `AdminVirtualTable` — wraps `useVueTable` + `useVirtualizer`; pure display, props/emits, no stores; fixed row heights required
4. `members-list.ui` — filter state (`activeFilters: FilterTag[]`, `searchText`); exposes `filteredMembers` computed; single source of truth for all filter logic
5. `member-activity.domain` — on-demand per-member lesson history; keyed by `memberId`; never loaded upfront for all members
6. `MemberProfileDrawer` — slide-over containing `LessonProgressList` and `ActivityTimeline`; opens immediately, populates on fetch

See `.planning/research/ARCHITECTURE.md` for complete data flow diagrams, store code examples, build order, and anti-patterns.

### Critical Pitfalls

1. **N+1 fan-out with `Promise.all` causes empty list on any group failure** — use `Promise.allSettled`; track per-group error state; surface a warning banner listing failed groups; never silently omit members from a failed group

2. **TanStack Table data stale after mutations (shallowRef)** — always pass a `computed(() => [...store.allMembers])` as the `data` prop; domain store mutations must replace array references, not mutate by index

3. **Deduplication in the wrong layer breaks group filter chips** — deduplicate in `all-members.domain` (not in the UI store or component); each deduplicated row must carry `groupIds: string[]` so group filter chips match on `groupIds.includes(filterGroupId)`; test with a member in 3 groups

4. **Activity history API shape is unconfirmed — entire phase blocked without it** — the first task of the activity history phase must be a direct API call to confirm endpoint existence and response shape; do not write any store or UI code until actual response is inspected

5. **Virtualization + pagination are mutually exclusive** — use only `getCoreRowModel()` with the virtualizer; use fixed row heights (`estimateSize: () => 56`) not `measureElement` (dynamic mode causes scroll jitter in the Vue adapter per tracked GitHub issue #622)

Additional pitfalls documented: tag filter state split between TanStack and Pinia (never split), multi-group assignment mutating the wrong record, activity content rendered as raw Lexical JSON, route missing for `/admin/members` (catch-all wildcard redirect). See `.planning/research/PITFALLS.md`.

## Implications for Roadmap

Based on the dependency graph from FEATURES.md and the build order from ARCHITECTURE.md, the following phase structure is recommended. The route registration is the unlocking step — the feature must be navigable before any store or component work begins.

### Phase 1: Foundation — Route, Packages, and Navigation

**Rationale:** The catch-all wildcard in `router.ts` silently redirects any unregistered path to the dashboard. Unless `/admin/members` is registered first, the entire feature is unreachable during development. Installing packages and wiring the route is a zero-risk, two-file change that unblocks all subsequent work.
**Delivers:** Navigable `/admin/members` route (placeholder component acceptable); `@tanstack/vue-table` and `@tanstack/vue-virtual` installed; Members link in admin sidebar
**Addresses:** Pitfall 10 (route not registered — catch-all redirect)
**Avoids:** Days of development on components that cannot be reached for manual testing

### Phase 2: Cross-Group Member Aggregation (Domain Stores)

**Rationale:** The flat member list is the prerequisite for all other v2.1 features. Filtering, virtualization, profile drill-down, and multi-group assignment all depend on a correct, deduplicated, reactive member dataset. Get the data layer right before touching the UI.
**Delivers:** `all-members.domain.ts` with `Promise.allSettled` fan-out, per-group error tracking, and `allMembers` computed (deduplicated by `userId`, with `groupIds: string[]`); `member-activity.domain.ts` shell (store structure with `loadHistory` — no API calls implemented yet, to be completed in Phase 5)
**Addresses:** Pitfall 1 (N+1 fan-out with `Promise.all`), Pitfall 5 (deduplication in wrong layer)
**Research flag:** Standard Pinia patterns — codebase verification already complete in ARCHITECTURE.md research; no per-phase research needed

### Phase 3: Virtualized Member Table + Tag Filter UI

**Rationale:** Once the domain store delivers a correct flat array, the table and filter bar can be built as pure display components. Building them before the domain store exists forces reliance on mock data that masks deduplication and filter bugs.
**Delivers:** `AdminVirtualTable` component (TanStack Table + Virtual, fixed row heights, `getCoreRowModel()` only); `MemberFilterBar` component (reka-ui TagsInput + Combobox chips); `members-list.ui` store (filter state in Pinia only, `filteredMembers` computed); `MembersSection.vue` wired with aggregation, filtering, and virtual table rendering
**Uses:** `@tanstack/vue-table`, `@tanstack/vue-virtual`, `reka-ui TagsInput/Combobox`
**Addresses:** Pitfall 2 (shallowRef reactivity — computed data prop), Pitfall 3 (scroll jitter — fixed row height), Pitfall 4 (pagination + virtualizer conflict), Pitfall 7 (filter state split)
**Research flag:** Standard TanStack patterns — official docs already consulted in STACK.md and ARCHITECTURE.md; no additional research needed

### Phase 4: Member Profile Drawer

**Rationale:** The profile drawer reuses the existing member profile endpoint (`GET /admin/api/members/:memberId/profile`). It requires the member list (Phase 3) as the entry point (row click) but has no dependency on the unconfirmed activity history API. Completing the drawer without activity content delivers the core leader workflow — tap any member to see profile, groups, and contact info — and validates the section before the riskier Phase 5.
**Delivers:** `MemberProfileDrawer` component (slide-over container); `member-detail.ui` store (drawer open/close, selected member state); member profile data (name, groups, contact info, joined dates) loaded on row click; enrollment progress summary (% complete from `/api/member/enrollments`)
**Addresses:** P1 features: member profile drawer, enrollment progress summary
**Research flag:** No research needed — all API endpoints confirmed; reuses existing drawer pattern from codebase

### Phase 5: Activity History (API Verification Gated)

**Rationale:** This phase must not begin until the activity history API endpoints are confirmed to exist and the response shape is documented. The iPhone app has no equivalent feature, providing no reference implementation. If endpoints are missing this phase is blocked and requires server work — it should be explicitly deferred rather than built on assumptions.
**Delivers:** `member-activity.domain.ts` fully implemented; `LessonProgressList` component (lesson completion per member, status chips); `ActivityTimeline` component (activity replay with SOAP/USER_INPUT rendered correctly based on confirmed content format); lesson detail with written responses in the correct format (not raw Lexical JSON)
**Addresses:** Pitfall 6 (activity history API unknown), Pitfall 9 (rich text rendered as raw JSON)
**Research flag: NEEDS per-phase research** — first task is API verification: call candidate endpoints, document actual response shape and auth pattern (`isGroupLeader` bypass through Laravel proxy), confirm content format for written responses (Lexical JSON, HTML, or plain text) before any store or UI code is written

### Phase 6: Multi-Group Assignment (Optional v2.1.x)

**Rationale:** Multi-group assignment is a P2 feature — valuable but not required for v2.1 launch. It depends on the cross-group member list (Phase 3) being stable and introduces a cache-invalidation concern (must force-reload affected groups after membership changes). Deferring to post-validation prevents cache-invalidation bugs from blocking the core v2.1 launch.
**Delivers:** Add/remove member from group actions; "add to group" modal pre-filtered to exclude groups the member already belongs to; forced cache refresh (`loadMembers(groupId, force: true)`) after mutations; deduplicated table row group chips update reactively
**Addresses:** Pitfall 8 (multi-group assignment mutating wrong record)
**Research flag:** No research needed — all API endpoints confirmed (`POST /api/groups/:id/members`, `DELETE /api/groups/:id/members/:id`)

### Phase Ordering Rationale

- **Route first (Phase 1):** The catch-all wildcard is a documented blocker. Registering the route before any component exists prevents an entire class of "it's done but unreachable" bugs throughout development.
- **Domain stores before UI (Phase 2 before Phase 3):** Deduplication correctness and aggregation resilience cannot be tested if the UI is built first with mock data. Building stores first enables unit-testable computed logic before any rendering.
- **Profile drawer before activity history (Phase 4 before Phase 5):** The drawer delivers the most-used leader workflow (view member profile, see groups, contact info) without any API risk. Activity history is entirely blocked by the unconfirmed endpoint and must not delay the core launch.
- **Multi-group assignment last (Phase 6):** Cache-invalidation complexity should not risk the core launch. Explicitly P2 — defer until v2.1 core is validated in production.

### Research Flags

Phases needing `/gsd:research-phase` during planning:
- **Phase 5 (Activity History):** First task must verify that `GET /api/members/:memberId/lessons` (or equivalent admin-scoped path) exists and returns data through the Laravel proxy. Must also confirm `isGroupLeader` bypass works for the admin proxy session, and inspect a real SOAP journal API response to determine content format before selecting the renderer. Do not proceed past task 1 of Phase 5 without this confirmation.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** Two-line router change + `npm install`; no research needed
- **Phase 2 (Aggregation):** Pinia store composition is fully documented; existing codebase patterns already verified
- **Phase 3 (Virtual Table + Filter):** TanStack Table + Virtual official docs already consulted in STACK.md and ARCHITECTURE.md research
- **Phase 4 (Profile Drawer):** All API endpoints confirmed; existing drawer pattern in codebase to follow
- **Phase 6 (Multi-Group Assignment):** All API endpoints confirmed; cache-invalidation pattern documented in ARCHITECTURE.md

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Both new packages verified against npm registry (versions confirmed Feb 2026); TanStack docs consulted for Vue adapter specifics; all existing package versions confirmed from `package.json` |
| Features | HIGH | Derived directly from iPhone app (authoritative reference) and confirmed API endpoint audit against server source; MVP vs. defer split is well-reasoned against project constraints |
| Architecture | HIGH | Primary source is direct codebase inspection of existing stores, sections, components, and router; build order derived from verified dependency graph; anti-patterns confirmed against TanStack tracked GitHub issues |
| Pitfalls | HIGH (aggregation, Pinia, virtualization) / LOW (activity history) | Aggregation, virtualization, Pinia, and deduplication pitfalls all verified against codebase and official docs; activity history pitfalls are inferred because the API shape is unconfirmed |

**Overall confidence:** HIGH for Phases 1–4 and 6. LOW for Phase 5 until activity history API is verified.

### Gaps to Address

- **Activity history API endpoints (CRITICAL):** `GET /api/members/:memberId/lessons` and lesson detail with activity progress are not confirmed to exist in an admin-scoped form. This is the single largest risk in v2.1. Gate Phase 5 entirely on API verification. If the endpoint requires server-side changes, escalate as a cross-repo blocker before any client work begins.
- **`isGroupLeader` bypass through Laravel proxy (HIGH):** The member lesson endpoints use `requireMemberAuth` with a `memberId` query param override that works only when `isGroupLeader` is true server-side. Whether the Laravel admin proxy correctly satisfies both the Google OAuth session and the member auth requirement is unverified. Needs a prototype request in Phase 5 before the domain store is built.
- **Activity response content format (HIGH):** Written responses (SOAP journals, OIA reflections, USER_INPUT) may be stored as Lexical JSON, HTML, or plain text. The correct renderer cannot be selected without inspecting an actual API response from a real member submission. Address as Phase 5 task 1.
- **Per-group member API pagination (LOW):** If `GET /api/groups/:id/members` is cursor-paginated for large groups, the fan-out strategy in `all-members.domain` must handle append-on-scroll. Inspect the API response envelope during Phase 2 implementation.

## Sources

### Primary (HIGH confidence)
- MakeReady iPhone codebase (`MemberHomePage.swift`, `GroupActions.swift`, `GroupModels.swift`) — cross-group fan-out pattern, deduplication by `userId`, confirmed member profile shape
- MakeReady server source (`member-lessons.ts`, `activity-logs.ts`, `group-members.ts`, `members.ts`) — confirmed endpoint paths and auth requirements
- MakeReady admin island codebase (`members.domain.ts`, `members-tab.ui.ts`, `groups-section.vue`, `admin-table.vue`, `router.ts`) — verified existing patterns, confirmed packages NOT yet installed
- npm registry — `@tanstack/vue-table@8.21.3` and `@tanstack/vue-virtual@3.13.23` version confirmation (Feb 2026)
- TanStack Table Vue docs — `useVueTable`, `manualFiltering`, `getCoreRowModel`, pagination incompatibility with virtualization
- TanStack Virtual Vue docs — `useVirtualizer`, `Ref<Virtualizer>`, `measureElement` vs. fixed-height tradeoffs
- Pinia composing stores docs — cross-store composition pattern confirmed

### Secondary (MEDIUM confidence)
- TanStack Table Vue virtualized rows example — integration pattern for `table.getRowModel().rows` + `useVirtualizer`
- TanStack Virtual GitHub issue #622 — dynamic height scroll jitter in Vue adapter; fixed-height workaround confirmed

### Tertiary (LOW confidence)
- Activity history endpoint shape — inferred from `member-lessons.ts` server route; admin-scoped variant unconfirmed; needs verification before Phase 5
- `isGroupLeader` proxy bypass — confirmed server-side check exists in source; Laravel proxy forwarding behavior unverified

---
*Research completed: 2026-03-21*
*Ready for roadmap: yes*
