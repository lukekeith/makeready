# Pitfalls Research

**Domain:** Virtualized member management + activity history — TanStack Table + TanStack Virtual, cross-group aggregation, tag-based filtering, multi-group assignment, activity replay (Laravel Blade + Vue 3 + Pinia admin island)
**Researched:** 2026-03-21
**Confidence:** HIGH for aggregation, Pinia, and existing-stack pitfalls (verified against codebase). MEDIUM for TanStack Table/Virtual Vue 3 specifics (verified against official docs and tracked GitHub issues). LOW for activity history API shape (endpoint not present in iPhone app — shape is unconfirmed).

---

## Critical Pitfalls

Mistakes that cause rewrites, broken data, or missing features.

---

### Pitfall 1: N+1 API Calls for Cross-Group Member Aggregation With No Rate Awareness

**What goes wrong:** The new top-level `/admin/members` page must aggregate members from all of a leader's groups into one list. There is no "all members across all groups" API endpoint — the iPhone app (the reference implementation) uses `GET /api/groups/:id/members` per group and fans out concurrently with Swift's `withTaskGroup`. Replicating this fan-out in the Vue store works fine for leaders with 3–5 groups, but a leader with 15 groups fires 15 simultaneous requests. Without error handling per-group, one failed request cancels `Promise.allSettled` if written as `Promise.all`, leaving the entire list empty. With `Promise.allSettled`, partial failures are silent — some groups' members are missing and the leader has no idea.

**Why it happens:** The existing `members.domain.ts` loads one group at a time (`loadMembers(groupId)`). When building the all-members view, developers reach for `Promise.all(groups.map(g => loadMembers(g.id)))` — it looks correct and matches the iPhone pattern. The problems (partial failure, stale data for already-loaded groups, no per-group error state) only surface with real data.

**How to avoid:**
- Use `Promise.allSettled` for the fan-out, not `Promise.all`. Collect per-group errors separately.
- Track which groups loaded successfully and which failed. Surface a warning banner: "Members from 2 groups could not be loaded" — don't silently omit them.
- Reuse the already-loaded `membersByGroup` cache in `members.domain.ts` for groups that were loaded during the per-group Members tab. Only fetch groups that have not been loaded or are stale.
- The aggregated list is derived data — compute it in the domain store as a computed property that flattens `membersByGroup` across all known group IDs, deduplicated by `userId` (same deduplication logic the iPhone uses).

**Warning signs:**
- `loadAllMembers()` calling `Promise.all` instead of `Promise.allSettled`
- A failed group request causing the entire members list to render empty
- Groups with already-loaded members being re-fetched when navigating to `/admin/members`

**Phase to address:** Members page foundation phase. Define the aggregation strategy before any rendering work.

---

### Pitfall 2: TanStack Table's `shallowRef` Breaking Vue Reactivity When Members Data Changes

**What goes wrong:** TanStack Table for Vue 3 stores table data in a `shallowRef` for performance. This means mutations to nested properties (e.g., changing a member's role after a PATCH) do not trigger reactive updates — only replacing the entire `.value` triggers re-renders. Developers used to Vue's deep reactivity (`ref()`) assume the table will update automatically when `membersByGroup.value[groupId].role = 'ADMIN'` is mutated. The table stays stale.

**Why it happens:** `shallowRef` is documented but counter-intuitive for Vue developers who default to `ref()`. TanStack Table's Vue adapter explicitly uses `shallowRef` internally, and the integration requires passing data as a `ref` or `computed` that returns a new array reference on change, not a mutated array.

**Consequences:** Member role changes, removals, or newly approved members do not appear in the virtualized table without a page reload. The leader performs an action and sees no feedback.

**How to avoid:**
- Always pass a `computed` (not a `ref`) as the `data` prop to `useVueTable`. The computed should derive from the Pinia domain store: `computed(() => [...membersStore.allMembers])`. Spreading into a new array ensures TanStack Table detects the change.
- When the domain store mutates members (role change, removal), ensure it replaces the array reference, not mutates in place: `membersByGroup.value[groupId] = [...updated]` not `membersByGroup.value[groupId][idx].role = 'ADMIN'`.
- Test the reactivity loop explicitly: perform a role change, verify the table row updates without a full re-fetch.

**Warning signs:**
- Domain store actions using `membersByGroup.value[groupId][idx].role = newRole` (index mutation)
- Table data prop is a plain `ref([])` rather than a computed from the domain store
- Member changes only appear after manually navigating away and back

**Phase to address:** Members table setup phase. Establish the computed-data-prop pattern before any CRUD actions are wired up.

---

### Pitfall 3: TanStack Virtual Dynamic Row Heights Causing Scroll Jitter

**What goes wrong:** Member rows with variable-length tag lists, multi-line names, or different group badge counts have inconsistent heights. TanStack Virtual with dynamic (`measureElement`) mode has a documented issue where scrolling up causes jitter and position resets — the virtualizer corrects its estimated total height as new measurements come in, causing visible jumps. This is a tracked open issue affecting the Vue adapter specifically.

**Why it happens:** TanStack Virtual estimates row heights before measuring them. When scrolling up through already-measured rows, height corrections ripple upward and shift the scroll position. The issue is more pronounced in Vue because of how Vue batches DOM updates relative to scroll events.

**Consequences:** The member list feels broken to users. The leader scrolls up through 200 members and the list jumps or resets. This looks like a crash.

**How to avoid:**
- Use fixed row heights for the member table. Member rows are a consistent card format (avatar, name, role badge, group chips). Design all rows to the same height — a fixed-height approach eliminates all dynamic measurement jitter entirely.
- The activity history list inside a member detail panel may have variable-height items (written SOAP journal responses can be long). For activity history, use a `ScrollView` with a fixed-height virtualization window and `overscan: 5` to pre-render items above/below the viewport. If jitter appears, fall back to non-virtualized rendering for the activity list (it will be per-member, so max ~50 items — pagination handles the rest).
- Pin `@tanstack/vue-virtual` to a known stable version and freeze it in `package-lock.json`. Do not auto-upgrade during this milestone.

**Warning signs:**
- Member rows with inconsistent heights (variable badge counts, two-line vs. one-line names)
- Using `measureElement` dynamic mode instead of `estimateSize` with a fixed pixel value
- Visible scroll position jumps when scrolling up through 100+ members

**Phase to address:** Members table setup phase. Fix row height in the design before implementing virtualization.

---

### Pitfall 4: Virtualization Disabled by Pagination Model — Table Shows Only First 20 Members

**What goes wrong:** TanStack Table's `getPaginatedRowModel()` and virtualization are mutually exclusive. If a developer adds `getPaginatedRowModel()` to the table config to handle the 500+ member dataset (a reasonable instinct), TanStack Virtual only sees the current page's rows — not the full dataset — and virtualization provides no benefit. The table effectively shows 20 items no matter how many members exist.

**Why it happens:** The documentation makes pagination and virtualization look like complementary features. They are not — pagination discards rows that virtualization needs in the virtual DOM. The correct model for virtualization is to load all data (or load-more on scroll) and let the virtualizer handle which rows render, not a pagination model.

**Consequences:** The 500-member cross-group view can't be scrolled through. The leader sees only 20 members and may think the rest haven't loaded. Loading indicators become meaningless.

**How to avoid:**
- Do not use `getPaginatedRowModel()` in the virtualized table. Use `getCoreRowModel()` only, and pass the full (aggregated, deduplicated) member array.
- For the initial load of 500+ members across 10+ groups, fan out the group fetches concurrently. The total data size is small (member cards are <1KB each) — loading all 500 members client-side is appropriate.
- TanStack Virtual with `overscan: 3` and a container of fixed height will render only the visible rows. Memory usage is fine for 500 records.
- If the API does paginate `/api/groups/:id/members` responses (cursor-based), implement load-more-on-scroll for individual group fetches, appending to the domain store. The virtualizer still receives the full accumulated array.

**Warning signs:**
- `getPaginatedRowModel()` in the table config alongside `useVirtualizer`
- A page size selector or prev/next pagination controls appearing on a virtualized table
- `table.getRowModel().rows` returning fewer rows than the total member count

**Phase to address:** Members table setup phase. Confirm the row model configuration before implementing any filtering or sorting.

---

### Pitfall 5: Deduplication Logic Applied in the Wrong Layer — Same Member Appears Multiple Times

**What goes wrong:** A member who belongs to 3 of a leader's groups will appear as 3 separate `GroupMember` records from the fan-out API calls (each call returns a record with a different `groupId` but the same `userId`). If deduplication is done only in the UI store computed property (not the domain store), filtering by group will break — the deduplicated row has only one `groupId` associated, so "filter by Group B" will not match a member who was deduplicated to their Group A record.

**Why it happens:** The iPhone app deduplicates by `userId` for display in the flat Members tab, but keeps the raw multi-group records for `groupNamesForUser()` lookups. This two-layer approach — raw records in state, deduplicated for display, grouped lookup for metadata — is not obvious when porting to a Pinia store.

**Consequences:** Group filter chips return wrong results. "Show members of Group B" may miss members who are also in Group A and were deduplicated to their Group A record. Multi-group assignment actions (add to group, remove from group) are called with the wrong `groupId` because the row only carries one `groupId`.

**How to avoid:**
- Maintain two data structures in the domain store: `membersByGroup` (raw, keyed by groupId, used for per-group actions) and `allMemberProfiles` (deduplicated by `userId`, enriched with an array of all their `groupIds`). The flat table binds to `allMemberProfiles`; CRUD actions (add to group, remove from group) use `membersByGroup` for the correct `groupId` target.
- The deduplication shape for each table row should be: `{ userId, name, avatarUrl, joinedAt: earliest, groupIds: string[], roles: Record<groupId, role> }`. This allows group filter chips to match on `groupIds.includes(filterGroupId)`.
- Test the group filter explicitly with a member who is in 3 groups — verify they appear once and match all three group filter chips.

**Warning signs:**
- A member appearing 3 times in the table because they're in 3 groups
- Group filter showing no results for members known to be in that group
- Remove-from-group action using `row.groupId` where `groupId` is undefined or only the first group

**Phase to address:** Cross-group aggregation phase, before tag filtering is built.

---

### Pitfall 6: Activity History API Shape Is Unknown — No iPhone Reference

**What goes wrong:** The iPhone app has no activity history feature for leaders. `GET /api/members/:memberId/profile` returns only `{ id, name, phone, groups }` — no lesson completion, no written responses, no video progress timestamps. The activity history endpoints needed for v2.1 (`GET /api/members/:memberId/lessons`, `GET /api/members/:memberId/lessons/:lessonScheduleId/activities`, etc.) are **unconfirmed** — they may not exist, may have a different URL structure, or may require a different auth role scope.

**Why it happens:** This feature is described in the v2.1 requirements as a target capability, but there is no prior implementation on any platform to reference. The endpoints are greenfield for this milestone.

**Consequences:** Building the activity history UI assuming API endpoints that do not exist. The entire phase must be revisited when the actual API shape is discovered. If the API returns activity data nested under enrollment (group + enrollment + lessonSchedule) rather than flat under a member ID, the traversal path through the data is completely different.

**How to avoid:**
- Before writing any activity history UI or store code, make an authenticated request to likely endpoint patterns and document the actual response shape:
  - `GET /api/members/:memberId/lessons`
  - `GET /api/groups/:groupId/members/:memberId/activity`
  - `GET /api/members/:memberId/activity`
- The member lesson view (`GET /api/member/lessons/:lessonScheduleId?memberId=:id`) is the member-facing endpoint — check if the leader-facing variant exists with an admin scope.
- If no activity history endpoint exists, document this as a blocker and defer the feature. Do not build mock data UI around an unconfirmed API.
- Pin the activity history feature to its own phase with an explicit API verification step as the first task.

**Warning signs:**
- Activity history store code written before the API response shape is confirmed
- Mock data hardcoded in the store to simulate a "working" feature during development
- Axios requests to `/api/members/:id/activity` returning 404 in the browser network tab

**Phase to address:** Activity history phase. Must begin with API verification before any code.

---

### Pitfall 7: Tag Filter Chips Applied Client-Side Against the Wrong Data Layer

**What goes wrong:** Tag-based filtering (by name, group, lesson status, activity type) is applied client-side against the aggregated member list. If filters are applied to the `table.getRowModel().rows` output instead of the source data array in the Pinia store, TanStack Table's internal sort/filter state can conflict with manual chip-based filtering — rows are filtered twice by incompatible logic, or the filter state is lost when the user sorts a column.

**Why it happens:** There are two ways to implement filtering with TanStack Table: (a) use TanStack Table's built-in `columnFilters` state and `getFilteredRowModel()`, or (b) pre-filter the data array before passing it to `useVueTable`. Mixing both — partial chip state managed in TanStack, partial in Pinia — creates a filter state split across two systems that drift out of sync.

**Consequences:** Filters appear to apply but show wrong results. Sorting a column resets one filter but not another. The active filter chip badge count mismatches the visible rows.

**How to avoid:**
- Use a single source of truth: manage all filter state in Pinia (`activeFilters: FilterChip[]`). Apply filters as a computed property in the domain/UI store that returns the pre-filtered member array. Pass this filtered array to `useVueTable` as the `data` prop. Do not use TanStack Table's `columnFilters` for chip-based filtering.
- TanStack Table's built-in filters are for column-level type-ahead (e.g., a text input within a column header). Chip-based multi-category filtering is better modeled as pre-filter + pass filtered data.
- The filter state in Pinia should be serializable so it survives tab switches (Vue Router `keep-alive`). Avoid storing filter state in component `data()` or `setup()` locals.

**Warning signs:**
- `columnFilters` state in the TanStack table config alongside chip state in a Pinia store
- Active filter badge count not matching the visible row count
- Sorting a column clears or ignores active filter chips

**Phase to address:** Tag filtering phase. Design the filter state architecture before implementing any chip UI.

---

### Pitfall 8: Multi-Group Assignment Mutating the Wrong Member Record

**What goes wrong:** "Add member to group" and "remove member from group" are CRUD actions. The member row in the virtualized table is a deduplicated record with `groupIds: string[]`. When a leader adds a member to a new group via the table action, the correct API call is `POST /api/groups/:newGroupId/join-requests/approve` or a direct membership endpoint. The member row's `groupIds` array must be updated reactively. If the store updates only `membersByGroup[targetGroupId]` but not the deduplicated `allMemberProfiles` entry, the table row's group chip list stays stale.

**Why it happens:** The domain store has two data structures (raw per-group records + deduplicated profile records). An action that adds a member to a group updates the raw records but the developer forgets to also update the deduplicated profile entry's `groupIds` array.

**Consequences:** A member is added to Group C. The table row still shows only Groups A and B. The leader adds them again thinking it failed. They are now enrolled twice (or the API returns a 409 conflict).

**How to avoid:**
- After any membership mutation (add to group, remove from group, role change), re-derive the deduplicated profile from the updated raw records rather than patching it in place. Use a `computedAllMembers` that derives from `membersByGroup` — the mutation automatically propagates.
- Alternatively: after a successful multi-group mutation, call `loadMembers(affectedGroupId, force: true)` to refresh the raw records for that group, then let the computed deduplication re-derive the profile.
- Write an integration test (in Phase tests): add member to group → verify table row shows the new group chip → remove member from group → verify group chip is gone.

**Warning signs:**
- Domain store has separate `updateAllMemberProfiles()` function called after mutations (manual sync = drift risk)
- Table row group chip count does not match what `membersByGroup` shows for a known member
- API returns 409 when leader tries to add a member to a group they were already added to in this session

**Phase to address:** Multi-group assignment phase.

---

### Pitfall 9: Activity History Replay Rendering Rich Text as Raw JSON String

**What goes wrong:** Written activity responses (SOAP journal, OIA reflection, user-input) are stored by the API as rich text content. The member experience uses Lexical-rendered content. If the activity history replay UI renders these as plain text strings, JSON blobs like `{"root":{"children":[...]}}` will be displayed verbatim instead of the formatted response. This is not a crash — it is silent data corruption that makes the feature useless.

**Why it happens:** The activity history page fetches responses from the API and binds them to a `<p>` or `<pre>` tag. Until someone opens a SOAP response from a real member and sees raw JSON, this is invisible during development (developer test data uses short strings).

**Consequences:** Leaders see `{"root":{"children":[{"children":[{"detail":0,"format":0,"mode":...}]}}` instead of the member's written reflection. The activity history replay feature is functionally broken for its primary use case.

**How to avoid:**
- Before building the activity history replay UI, establish what format the API returns for written responses. The member-facing `POST /api/member/activities/:id/submit` sends `{ note: { type, content } }` — determine if the stored `content` is Lexical JSON, HTML, or plain text.
- If content is Lexical JSON: use `@lexical/vue` (or a read-only HTML serializer from Lexical) to render it. Do not use a `<p>` binding.
- If content is HTML: render with `v-html` inside a sandboxed container with scoped styles to prevent admin CSS from bleeding into the rendered content.
- If content is plain text: `<pre>` or `<p>` is sufficient.
- Verify the content format by inspecting an actual API response for a submitted SOAP activity before writing the replay renderer.

**Warning signs:**
- Activity response content bound with `{{ activity.note }}` or `:innerHTML="activity.note"` without format inspection
- SOAP response displays as `{&quot;root&quot;:...` in the browser
- Activity renderer passes all tests with developer-created test data but fails with real member submissions

**Phase to address:** Activity history replay phase. Confirm content format before building the renderer.

---

### Pitfall 10: Vue Router Route Missing for `/admin/members` — Wildcard Redirects to Dashboard

**What goes wrong:** The current `router.ts` has a catch-all `{ path: '/admin/:pathMatch(.*)*', redirect: '/admin' }`. The new `/admin/members` route does not exist in the router. Navigating to `/admin/members` (from a sidebar link, direct URL, or redirect after action) silently redirects to `/admin` instead of showing the members section. The sidebar link appears broken and the feature appears unimplemented.

**Why it happens:** Adding a new section requires both a new Vue component and a new route entry. The catch-all redirect hides the missing route — there is no 404, just a silent redirect to dashboard.

**Consequences:** The `/admin/members` page is unreachable. Testing the feature requires temporarily hardcoding a route or removing the catch-all. The feature appears to regress in QA.

**How to avoid:**
- Add the route to `router.ts` as the first task of the members section phase, before the component exists. Use a placeholder component so the route is resolvable immediately.
- Routes to add: `{ path: '/admin/members', component: MembersSection }` and `{ path: '/admin/members/:id', component: MembersSection }`.
- Verify routing before writing any store or table code — visit `/admin/members` and confirm the placeholder renders.

**Warning signs:**
- Navigating to `/admin/members` redirects to the dashboard
- `router.ts` has no entry for `/admin/members` after the feature is described as "done"
- Sidebar link for Members uses a hard-coded `<a href>` instead of `<router-link to="/admin/members">`

**Phase to address:** Members section setup phase, as the first step.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Loading all groups' members on page open | Simple code | 15+ concurrent requests, slow for orgs with many groups | Never — load on demand, reuse cache |
| Keeping deduplication only in the UI layer | Easier to understand | Filter/sort/action logic breaks; must be repeated in every consuming component | Never — deduplicate in domain store |
| Skipping TanStack Table, using `v-for` + CSS transform for virtualization | Avoids new dependency | Reimplements virtualizer incorrectly; scroll jitter; no sort/filter integration | Never — use TanStack Virtual properly or not at all |
| Using `@tanstack/vue-table` column filter state for chip filters | One system | Chip state resets on column sort; not serializable to router/Pinia | Never — use Pinia for chip state, pass pre-filtered data to table |
| Rendering activity content as plain text | No renderer needed | Lexical JSON displayed verbatim to leaders; feature is unusable | Never — verify format and build appropriate renderer |
| Hardcoding mock activity history data before API is confirmed | Build UI in parallel | Entire feature must be rebuilt when real API shape differs | Never — confirm API before building |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `GET /api/groups/:id/members` for all groups | Using `Promise.all` — one failure empties entire list | Use `Promise.allSettled`, track per-group success/failure, surface partial-failure warning |
| TanStack Table `data` prop | Passing a `ref([])` directly | Pass a `computed(() => [...store.flatMembers])` — new array reference triggers table update |
| TanStack Virtual + fixed row heights | Using `measureElement` (dynamic mode) | Use `estimateSize: () => ROW_HEIGHT_PX` with a fixed design height |
| TanStack Table pagination + virtual | Adding `getPaginatedRowModel()` alongside virtualizer | Use only `getCoreRowModel()` with virtualization; pagination is incompatible |
| Multi-group member deduplication + group filter | Deduplicating to first group only | Preserve `groupIds: string[]` on deduplicated record; filter matches any group in the array |
| Activity written response rendering | Binding response to `{{ content }}` without format check | Inspect actual API response format; use appropriate renderer (Lexical, v-html, or plain text) |
| `/admin/members` route not registered | Silent redirect to dashboard via catch-all | Add explicit routes to `router.ts` before building the component |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-fetching all group members on every `/admin/members` mount | Slow navigation to members page after first load | Cache loaded groups in `loadedGroupIds` set; only fetch missing groups | Every navigation for orgs with 10+ groups |
| Computing deduplication in a component `computed`, not domain store | Deduplication runs on every re-render, not once on data change | Move to Pinia store computed; runs only when `membersByGroup` changes | With 500+ raw member records across 10+ groups |
| Activity history fetching all lessons for all enrollments on member detail open | Slow member detail; many parallel requests | Fetch lesson list lazily (on expand per enrollment), not eagerly for all | Members with 5+ active enrollments |
| Virtualizer `overscan` set too high | Renders 50+ rows outside viewport; defeats virtualization | `overscan: 3–5`; profile render performance with Chrome DevTools | Immediately on tables with complex row templates |
| Filter/sort computation on every `getRowModel()` call | Sluggish table interaction | Pre-filter in Pinia computed, pass filtered array; TanStack only sorts pre-filtered data | Tables with 500+ rows and complex filter predicates |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Rendering member phone numbers in the virtualized table HTML | Phone numbers in page source visible to anyone with DevTools | Column rendering should format numbers for display only; never embed raw E.164 in a `data-*` attribute |
| Activity history responses containing PII rendered in `v-html` | XSS if content is HTML-encoded from API (unlikely but possible) | Sanitize with DOMPurify before `v-html`; or use Lexical read-only renderer which never executes scripts |
| Multi-group assignment not checking whether the requesting leader owns the target group | Leader could add a member to another leader's group via a crafted request | Laravel route handler must verify leader owns `targetGroupId` before proxying the enrollment request to the external API |
| Member profile data (phone, email) passed as island props in HTML | PII visible in page source | Member profile is loaded on-demand by the Vue island via API, not embedded in Blade props |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Filter chip applied immediately on selection (live filter during search) | Jarring mid-type refiltration; list jumps | Tag-based filters are applied on chip add/remove (discrete actions), not on every keystroke. Name search is real-time only within already-active filters. |
| Virtual scroll not restoring position after navigating to member detail and back | Leader loses place in 500-member list | Store `scrollOffset` in the members UI store; restore it on mount with `virtualizer.scrollToOffset()` |
| "Loading all members" spinner with no progress indication | Leader thinks page is broken when 15 groups load concurrently | Show per-group loading progress: "Loading members from 12 of 15 groups…" or skeleton rows that fill in as groups load |
| Multi-group assignment showing all of the leader's groups as options | Leader sees groups where the member is already a member | Pre-filter "add to group" options to exclude groups the member is already in (`currentGroupIds`) |
| Activity history showing only activity type labels without context | Leader cannot tell what lesson or enrollment an activity belongs to | Always show enrollment name + lesson name above activity entries; never show activity in isolation |
| Virtualized table scroll position resetting on tab switch | Leader applies filters, switches to group detail, returns, filters are gone | Store active filters in Pinia (not component state); use Vue Router `keep-alive` on the members section |

---

## "Looks Done But Isn't" Checklist

- [ ] **Cross-group members list:** Often missing partial-failure state — verify that if one group's members API fails, the table shows the other groups' members with a warning, not an empty state.
- [ ] **Deduplication correctness:** Often only tested with a member in one group — verify a member in 3 groups appears exactly once with all 3 group chips showing.
- [ ] **Group filter chip:** Often only tested filtering-in — verify that removing the last filter chip restores the full list without a reload.
- [ ] **Scroll restoration:** Often skipped — verify that after opening a member detail and pressing Back, the virtualizer returns to the same scroll position.
- [ ] **Role changes in virtualized table:** Often only tested in the per-group Members tab — verify the role change also reflects in the cross-group `/admin/members` table without a full re-fetch.
- [ ] **Activity history content format:** Often only tested with developer-entered plain text — verify a real SOAP journal response submitted by a member through the member experience renders correctly in the history replay view.
- [ ] **Multi-group assignment:** Often only tested adding, not removing — verify removing a member from one of their groups leaves them visible in the cross-group table (still in other groups) and removes the correct group chip.
- [ ] **Activity history API existence:** Often assumed — verify `GET /api/members/:id/activity` (or equivalent) returns data before building any UI for it.
- [ ] **Route registration:** Often skipped until late — verify `/admin/members` is not caught by the catch-all wildcard redirect.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| N+1 fan-out with Promise.all causing silent empty state | LOW | Replace `Promise.all` with `Promise.allSettled`; add per-group error tracking; no data model changes |
| TanStack Table data not reactive after role change | LOW | Switch domain store mutations to replace array reference instead of mutating index; verify computed prop passes new array |
| Deduplication logic in wrong layer (component vs. domain store) | MEDIUM | Move deduplication to domain store computed; update all consumers; retest group filter chips |
| Activity history API does not exist or has unexpected shape | HIGH | Block the feature; do not ship partial UI; document confirmed endpoints before resuming; may require API work outside this milestone |
| Virtual scroll jitter with dynamic row heights | MEDIUM | Standardize row height to a fixed value by constraining tag chip overflow (max 2 lines, overflow hidden); switch to `estimateSize` mode |
| Pagination model conflicting with virtualizer | LOW | Remove `getPaginatedRowModel()` from table config; pass full data array to `getCoreRowModel()`; re-test scroll performance |
| `/admin/members` route missing (catch-all redirect) | LOW | Add two lines to `router.ts`; redirect issue disappears immediately |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| N+1 fan-out with Promise.all | Members aggregation phase | `Promise.allSettled` used; partial failure shows warning banner, not empty state |
| TanStack Table shallowRef reactivity | Members table setup | Role change → table row updates without re-fetch |
| Dynamic row height scroll jitter | Members table setup | All rows same fixed height; no jitter on scroll-up through 200 items |
| Pagination + virtualizer conflict | Members table setup | `getCoreRowModel()` only; full 500+ member array passed to table |
| Deduplication in wrong layer | Cross-group aggregation | Member in 3 groups appears once; group filter returns correct results |
| Activity history API shape unknown | Activity history phase | API endpoint confirmed before any store/UI code written |
| Tag filter chip state split between TanStack + Pinia | Tag filtering phase | Chip state in Pinia only; `data` prop to table is pre-filtered computed |
| Multi-group assignment stale row | Multi-group assignment phase | Add member to group → table row group chips update immediately |
| Activity content rendered as raw JSON | Activity replay phase | Real SOAP journal response renders as formatted text, not JSON blob |
| Route missing for `/admin/members` | Members section setup | Visit `/admin/members` in browser; members section renders (not dashboard redirect) |
| Multi-group assignment wrong groupId | Multi-group assignment phase | Remove-from-group uses correct `groupId`; member remains in other groups |

---

## Sources

- MakeReady iPhone codebase `MemberHomePage.swift` — confirmed cross-group fan-out pattern with `withTaskGroup`; confirmed deduplication by `userId` required
- MakeReady iPhone codebase `GroupActions.swift` — confirmed `GET /api/groups/:id/members` is the only member list endpoint; no cross-group aggregate endpoint exists
- MakeReady iPhone codebase `GroupModels.swift` — confirmed `MemberProfile` from `GET /api/members/:id/profile` contains only `groups: [MemberProfileGroup]`, no activity history
- MakeReady admin island `members.domain.ts` — confirmed per-group loading model; no aggregation or deduplication exists yet
- MakeReady admin island `router.ts` — confirmed `/admin/members` route does not exist; catch-all wildcard redirect present
- MakeReady `package.json` — confirmed `@tanstack/vue-table` and `@tanstack/vue-virtual` are NOT installed; must be added
- TanStack Table Vue 3 docs — confirmed `shallowRef` usage for table data; `getPaginatedRowModel()` incompatible with virtualizer
- TanStack Virtual GitHub issue #622 — confirmed dynamic height scroll jitter in Vue adapter; fixed-height rows recommended workaround
- TanStack Virtual GitHub issue #685 — confirmed rendering lag when virtualizing both rows and columns
- TanStack Table docs (global-filtering.md) — confirmed column filter model vs. pre-filtered data tradeoffs
- MakeReady `LessonController.php` API audit — confirmed written response format is `{ note: { type, content } }` but storage format at API side is unknown

---
*Pitfalls research for: Virtualized member management + activity history — Vue 3 + Pinia + TanStack Table + cross-group aggregation*
*Researched: 2026-03-21*
