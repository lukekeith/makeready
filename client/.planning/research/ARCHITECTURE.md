# Architecture Research

**Domain:** Vue 3 admin panel — member management v2.1 with virtualized tables and activity history
**Researched:** 2026-03-21
**Confidence:** HIGH (primary source: direct codebase inspection; supplemented with TanStack official docs)

---

## v2.1 Context: Adding to an Existing Architecture

The v2.0 admin panel (groups, programs, enrollments, analytics) is operational. The architecture described in the earlier version of this file is the baseline. v2.1 adds a new top-level route `/admin/members` with cross-group aggregation, virtualized display, tag filtering, and member activity history. **No existing stores, sections, or components change.**

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Laravel Blade Shell                          │
│  (PHP renders HTML, mounts AdminIsland with props)               │
├─────────────────────────────────────────────────────────────────┤
│                      AdminIsland (Vue SPA)                       │
│   Vue Router routes → Section components                         │
│                                                                  │
│   [existing]                        [v2.1 NEW]                   │
│   DashboardSection                  MembersSection               │
│   GroupsSection     ←── kept ───→   (separate route)            │
│   ProgramsSection                                                │
│   ProfileSection                                                 │
├─────────────────────────────────────────────────────────────────┤
│                  Domain Stores (Pinia)                           │
│                                                                  │
│  [existing — unchanged]          [v2.1 NEW]                      │
│  groups.domain                   all-members.domain              │
│  members.domain ◄── reused ──    member-activity.domain          │
│  programs.domain                                                 │
│  enrollments.domain                                              │
├─────────────────────────────────────────────────────────────────┤
│                    UI Stores (Pinia)                             │
│                                                                  │
│  [existing — unchanged]          [v2.1 NEW]                      │
│  groups-list.ui                  members-list.ui                 │
│  group-detail.ui                 member-detail.ui                │
│  members-tab.ui ◄── kept ────                                    │
│  programs-list.ui                                                │
│  program-detail.ui                                               │
├─────────────────────────────────────────────────────────────────┤
│               Admin Components (props/emits, no stores)          │
│                                                                  │
│  [existing]                      [v2.1 NEW]                      │
│  AdminTable                      AdminVirtualTable               │
│  AdminForm                       MemberFilterBar                 │
│  AdminConfirmDialog              ActivityTimeline                │
│  AdminImageUpload                LessonProgressList              │
│  AdminActivityList               MemberProfileDrawer             │
├─────────────────────────────────────────────────────────────────┤
│         API Proxy: /admin/api/{path} → ApiService → External API │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | How Built |
|-----------|----------------|-----------|
| `MembersSection.vue` | Route page: orchestrates stores, handles events | Section file — same pattern as `groups-section.vue` |
| `all-members.domain` | Fan-out: loads all groups → all members; exposes flat array | Domain store, composes `groups.domain` + `members.domain` |
| `member-activity.domain` | Per-member lesson history, on-demand only | Domain store, keyed by memberId |
| `members-list.ui` | Filter state, active tags, computed `filteredMembers` | UI store, consumes `all-members.domain` |
| `member-detail.ui` | Drawer open/close, lesson nav state, activity fetch trigger | UI store, consumes `member-activity.domain` |
| `AdminVirtualTable` | Virtualized row rendering; headless, data-driven | Wraps `@tanstack/vue-table` + `@tanstack/vue-virtual` |
| `MemberFilterBar` | Tag chip UI — name/group/role/status filter strips | Pure display; emits `add-filter`, `remove-filter`, `search` |
| `ActivityTimeline` | Chronological replay of a member's activity responses | Read-only display component |
| `LessonProgressList` | Grid of lesson completion status across an enrollment | Read-only display component |
| `MemberProfileDrawer` | Slide-over detail panel containing above sub-components | Orchestrated by `MembersSection` via `member-detail.ui` |

---

## Recommended Project Structure

```
resources/js/islands/admin-island/
├── sections/
│   ├── members-section.vue          # NEW — /admin/members route
│   └── [existing sections unchanged]
├── stores/
│   ├── domain/
│   │   ├── members.domain.ts        # EXISTING — per-group member cache (unchanged)
│   │   ├── all-members.domain.ts    # NEW — cross-group aggregation
│   │   └── member-activity.domain.ts # NEW — lesson history + activity detail
│   └── ui/
│       ├── members-tab.ui.ts        # EXISTING — per-group tab (unchanged)
│       ├── members-list.ui.ts       # NEW — top-level list filter/search state
│       └── member-detail.ui.ts      # NEW — drawer open/close, lesson nav
└── components/
    └── [existing components unchanged]

resources/js/components/admin/
├── admin-virtual-table/
│   ├── admin-virtual-table.vue      # NEW — TanStack Table + Virtual wrapper
│   └── admin-virtual-table.scss
├── member-filter-bar/
│   ├── member-filter-bar.vue        # NEW — tag chip filter UI
│   └── member-filter-bar.scss
├── activity-timeline/
│   ├── activity-timeline.vue        # NEW — chronological activity replay
│   └── activity-timeline.scss
├── lesson-progress-list/
│   ├── lesson-progress-list.vue     # NEW — lesson completion per member
│   └── lesson-progress-list.scss
└── member-profile-drawer/
    ├── member-profile-drawer.vue    # NEW — slide-over detail container
    └── member-profile-drawer.scss
```

### Structure Rationale

- **`sections/members-section.vue`:** Follows the established section convention exactly. Contains all store imports, event handlers, and `onMounted` data loading. Comparable line count to `groups-section.vue`.
- **`stores/domain/all-members.domain.ts`:** Kept separate from `members.domain.ts` because it has fundamentally different caching semantics — it aggregates across all group IDs. It reuses `members.domain` as a sub-dependency rather than duplicating API calls.
- **`stores/domain/member-activity.domain.ts`:** Activity history is high-volume and per-member on demand. Not co-located with the group member list domain to keep each domain store focused.
- **Admin components:** Each new component follows the existing pattern: folder containing `.vue` + `.scss`, no store imports, props/emits only.

---

## Architectural Patterns

### Pattern 1: Cross-Group Aggregation via Store Composition

**What:** `all-members.domain` calls `groupsDomain.loadGroups()` first, then fans out to `membersDomain.loadMembers(groupId)` for each group. The flat result is a reactive `computed` from the existing `membersByGroup` cache.

**When to use:** Required for the top-level `/admin/members` route. The existing per-group `members.domain` already handles individual group loads — `all-members.domain` reuses that cache (no duplicate API calls on subsequent navigations).

**Trade-offs:** N+1 API calls on first load (one per group). For 5–20 groups this is fine — Promise.all parallelizes them. The `loadedGroupIds` cache in `members.domain` means navigating back to `/admin/members` is instant.

**Example:**
```typescript
// stores/domain/all-members.domain.ts
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useGroupsDomain } from './groups.domain'
import { useMembersDomain } from './members.domain'

export const useAllMembersDomain = defineStore('all-members-domain', () => {
  const groupsDomain = useGroupsDomain()
  const membersDomain = useMembersDomain()
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  // Flat list derived from per-group caches — reactive computed
  const allMembers = computed(() =>
    Object.values(membersDomain.membersByGroup).flat()
  )

  async function loadAllMembers(force = false): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      await groupsDomain.loadGroups()
      await Promise.all(
        groupsDomain.groups.map(g => membersDomain.loadMembers(g.id, force))
      )
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load members'
    } finally {
      isLoading.value = false
    }
  }

  return { allMembers, isLoading, error, loadAllMembers }
})
```

---

### Pattern 2: TanStack Table + TanStack Virtual for Virtualized Rows

**What:** `AdminVirtualTable` wraps `@tanstack/vue-table` for headless column management and `@tanstack/vue-virtual` for DOM-efficient rendering. The component is purely presentational — it receives `columns` and `data` props; the section page passes pre-filtered data from the UI store.

**When to use:** Any list that may exceed ~50 rows. Member lists with 200+ records need this to avoid rendering all rows in the DOM simultaneously.

**Trade-offs:** Virtualization and pagination are mutually exclusive — do not combine `getPaginatedRowModel()` with `useVirtualizer`. The virtualizer must receive the full row array from `getCoreRowModel()`. The scroll container must have a fixed pixel height (cannot use natural page scroll). Filtering is done before rows reach the table — in the UI store computed.

**Critical install note:** Two packages required:

```bash
# from client/ directory
npm install @tanstack/vue-table @tanstack/vue-virtual
```

**Example (component skeleton):**
```typescript
// admin-virtual-table.vue
import { useVueTable, getCoreRowModel, type ColumnDef } from '@tanstack/vue-table'
import { useVirtualizer } from '@tanstack/vue-virtual'
import { ref, computed } from 'vue'

const props = defineProps<{
  columns: ColumnDef<any>[]
  data: any[]
  rowHeight?: number
}>()

const emit = defineEmits<{
  (e: 'row-click', id: string): void
}>()

const tableContainerRef = ref<HTMLDivElement | null>(null)

const table = useVueTable({
  get data() { return props.data },
  columns: props.columns,
  getCoreRowModel: getCoreRowModel(),
})

const rows = computed(() => table.getRowModel().rows)

const rowVirtualizer = useVirtualizer({
  get count() { return rows.value.length },
  getScrollElement: () => tableContainerRef.value,
  estimateSize: () => props.rowHeight ?? 52,
  overscan: 10,
})
```

---

### Pattern 3: Tag Filter State Lives in the UI Store

**What:** Filter state (active tag objects, search text) lives in `members-list.ui`. The UI store exposes a `filteredMembers` computed that applies all active filters against the domain's flat member array. `MemberFilterBar` emits filter change events; `MembersSection` calls UI store setters.

**When to use:** All filtering for v2.1. The admin proxy is a thin pass-through — there is no server-side member search endpoint to use. Client-side filtering over the pre-loaded member set is correct.

**Trade-offs:** Filtering recomputes on every keystroke for the full flat array. Mitigate with a ~200ms debounce on the search input and keep filter logic in a `computed` (not a `watch`) so Vue batches updates correctly.

**Example:**
```typescript
// stores/ui/members-list.ui.ts
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useAllMembersDomain } from '../domain/all-members.domain'
import { useGroupsDomain } from '../domain/groups.domain'

export interface FilterTag {
  type: 'name' | 'group' | 'role'
  label: string
  value: string
}

export const useMembersListUI = defineStore('members-list-ui', () => {
  const allMembersDomain = useAllMembersDomain()
  const groupsDomain = useGroupsDomain()

  const activeFilters = ref<FilterTag[]>([])
  const searchText = ref('')

  const filteredMembers = computed(() => {
    let result = allMembersDomain.allMembers

    if (searchText.value) {
      const q = searchText.value.toLowerCase()
      result = result.filter(m => m.name?.toLowerCase().includes(q))
    }

    for (const f of activeFilters.value) {
      if (f.type === 'group') result = result.filter(m => m.groupId === f.value)
      if (f.type === 'role') result = result.filter(m => m.role === f.value)
    }

    return result
  })

  const groupOptions = computed(() =>
    groupsDomain.groups.map(g => ({ label: g.name, value: g.id }))
  )

  function addFilter(tag: FilterTag) {
    if (!activeFilters.value.find(f => f.type === tag.type && f.value === tag.value)) {
      activeFilters.value.push(tag)
    }
  }

  function removeFilter(tag: FilterTag) {
    activeFilters.value = activeFilters.value.filter(
      f => !(f.type === tag.type && f.value === tag.value)
    )
  }

  function setSearch(text: string) {
    searchText.value = text
  }

  function clearAll() {
    activeFilters.value = []
    searchText.value = ''
  }

  return {
    activeFilters,
    searchText,
    filteredMembers,
    groupOptions,
    addFilter,
    removeFilter,
    setSearch,
    clearAll,
  }
})
```

---

### Pattern 4: On-Demand Activity History Fetch

**What:** `member-activity.domain` fetches per-member lesson history only when `openDetail(memberId)` is called. Results keyed by memberId. The domain exposes `historyByMember[memberId]` and `isLoadingActivity`.

**When to use:** Activity history is expensive to fetch for all members upfront. Fetch on demand when a row is clicked to open the profile drawer.

**API endpoints (via admin proxy):**
- `GET /admin/api/members/:memberId/profile` — exists; returns profile with groups array
- `GET /admin/api/members/:memberId/lessons` — verify existence; server has `GET /member/lessons` behind member auth; needs separate admin-scoped endpoint or query param `?memberId=`
- Individual lesson detail: `GET /admin/api/member/lessons/:lessonScheduleId?memberId=:memberId`

**Trade-offs:** Introduces a loading state visible in the drawer. Use the same skeleton-then-populate pattern already in `members-tab.ui.ts`: open the drawer immediately, show "Loading..." text, then populate once the fetch resolves.

**Example:**
```typescript
// stores/domain/member-activity.domain.ts
import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

export interface LessonHistoryItem {
  lessonScheduleId: string
  lessonId: string
  title: string
  scheduledDate: string
  completionStatus: 'not_started' | 'in_progress' | 'completed'
  completedAt?: string
}

export const useMemberActivityDomain = defineStore('member-activity-domain', () => {
  const historyByMember = ref<Record<string, LessonHistoryItem[]>>({})
  const loadedMemberIds = ref(new Set<string>())
  const isLoadingActivity = ref(false)
  const error = ref<string | null>(null)

  async function loadHistory(memberId: string, force = false): Promise<void> {
    if (loadedMemberIds.value.has(memberId) && !force) return
    isLoadingActivity.value = true
    error.value = null
    try {
      const res = await axios.get(`/admin/api/members/${memberId}/lessons`)
      historyByMember.value[memberId] = res.data.lessons ?? []
      loadedMemberIds.value.add(memberId)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load activity history'
    } finally {
      isLoadingActivity.value = false
    }
  }

  return { historyByMember, isLoadingActivity, error, loadHistory }
})
```

---

## Data Flow

### Cross-Group Member Aggregation

```
MembersSection.vue onMounted()
    ↓
allMembersDomain.loadAllMembers()
    ├── groupsDomain.loadGroups()       → groups[] cached in groups.domain
    └── Promise.all: membersDomain.loadMembers(id) for each group
              → membersByGroup[id][] cached per group

allMembersDomain.allMembers           ← computed: flat array from all groups
    ↓
membersListUI.filteredMembers         ← computed: filtered/searched subset
    ↓
AdminVirtualTable :data="filteredMembers"
    ↓
useVirtualizer renders only visible rows (DOM stays small regardless of list size)
```

### Tag Filter State Flow

```
User types in MemberFilterBar search input
    ↓ debounced 200ms
    ↓ emits 'update-search' with text
MembersSection.vue handler → membersListUI.setSearch(text)
    ↓
membersListUI.filteredMembers computed reacts automatically
    ↓
AdminVirtualTable :data prop receives new array reference
    ↓
TanStack Table's getCoreRowModel reprocesses rows
    ↓
Virtualizer re-renders visible window
```

### Member Activity Drill-Down

```
User clicks row in AdminVirtualTable
    ↓ emits 'row-click' with memberId
MembersSection.vue → memberDetailUI.openDetail(memberId)
    ↓ sets selectedMemberId, isDrawerOpen = true (drawer appears immediately)
    ↓ calls memberActivityDomain.loadHistory(memberId)
        → GET /admin/api/members/:memberId/lessons
        → caches in historyByMember[memberId]
    ↓ memberDetailUI.lessonHistory computed from domain cache
MemberProfileDrawer receives all props from memberDetailUI
ActivityTimeline + LessonProgressList render from received props
```

---

## Integration Points

### Existing Architecture Touch Points

| Touch Point | What Changes | Notes |
|-------------|-------------|-------|
| `router.ts` | Add `/admin/members` route | Single line — points to `MembersSection` |
| `admin-sidebar.vue` | Add Members nav link | Follow existing link pattern with `router-link` |
| `members.domain.ts` | No changes | `all-members.domain` calls its existing functions |
| `groups.domain.ts` | No changes | `all-members.domain` calls `loadGroups()` |
| `groups-section.vue` Members tab | No changes | Existing per-group tab preserved exactly as-is |
| `admin-island.vue` | No changes | Router handles new route transparently |

### New vs Modified Files

| File | Status | Notes |
|------|--------|-------|
| `sections/members-section.vue` | NEW | Top-level route page, ~300–400 lines |
| `stores/domain/all-members.domain.ts` | NEW | Cross-group aggregation |
| `stores/domain/member-activity.domain.ts` | NEW | Activity history, on-demand fetch |
| `stores/ui/members-list.ui.ts` | NEW | Filter/search state, filteredMembers computed |
| `stores/ui/member-detail.ui.ts` | NEW | Drawer open/close, profile data, lesson nav |
| `components/admin/admin-virtual-table/` | NEW | `@tanstack/vue-table` + `@tanstack/vue-virtual` |
| `components/admin/member-filter-bar/` | NEW | Tag chip filter UI |
| `components/admin/activity-timeline/` | NEW | Activity replay display |
| `components/admin/lesson-progress-list/` | NEW | Per-member lesson completion |
| `components/admin/member-profile-drawer/` | NEW | Slide-over container |
| `router.ts` | MODIFY | Add `/admin/members` and `/admin/members/:id` routes |
| `components/admin-sidebar.vue` | MODIFY | Add Members nav link |
| `package.json` | MODIFY | Add `@tanstack/vue-table` and `@tanstack/vue-virtual` |

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| External REST API | Unchanged — admin proxy pass-through | `/admin/api/members/:id/lessons` may need verification; server-side `member-lessons.ts` exists but behind member auth |
| Laravel admin proxy | Handles all `/admin/api/*` already | No PHP changes needed for members profile; activity history may need a dedicated proxy route |

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1–5 groups, <200 members | Fan-out load on mount, client-side filter, no changes needed |
| 5–20 groups, 200–2000 members | Add TTL cache per group (skip re-fetch within 5 min); debounce filter input (already recommended) |
| 20+ groups, 2000+ members | Move to server-side search: add `GET /admin/api/members?q=...` endpoint; replace fan-out with single paginated request |

### Scaling Priorities

1. **First bottleneck:** Fan-out API calls for 20+ groups on mount. Fix: add TTL per group in `members.domain`, lazy-load groups only when the group filter tag is selected.
2. **Second bottleneck:** Client-side filter recompute on every keystroke for 2000+ rows. Fix: 200ms debounce on input (already in pattern 3 above).

---

## Anti-Patterns

### Anti-Pattern 1: Store Import Inside an Admin Component

**What people do:** Import `useAllMembersDomain()` inside `AdminVirtualTable.vue` or `MemberFilterBar.vue`.

**Why it's wrong:** Breaks the established contract — admin components are pure view components that receive data via props. This makes them untestable in Histoire and creates hidden dependencies.

**Do this instead:** All store access stays in section files or UI stores. Components receive computed arrays and emit events.

---

### Anti-Pattern 2: Combining Virtualization with Pagination

**What people do:** Add `getPaginatedRowModel()` to the TanStack Table config alongside the virtualizer.

**Why it's wrong:** Pagination limits the row array the virtualizer sees. The virtualizer only virtualizes the current page (~20 rows), not the full dataset. The whole point of virtualization is eliminated.

**Do this instead:** Pass the full filtered array to TanStack Table with only `getCoreRowModel()`. Client-side filtering (in the UI store) replaces pagination for display control.

---

### Anti-Pattern 3: Fetching Activity History for All Members Upfront

**What people do:** In `loadAllMembers()`, also call `loadHistory(memberId)` for every member in the flat list.

**Why it's wrong:** With 200 members this is 200 parallel API calls on mount, hammering the external API and blocking the table from rendering.

**Do this instead:** Activity history is on-demand only — fetch when `openDetail(memberId)` is called, never before.

---

### Anti-Pattern 4: Keying the Virtual Table Container to Filter State

**What people do:** Add `:key="filteredMembers.length"` to the virtual table container to force remount on filter change.

**Why it's wrong:** Destroys the virtualizer's scroll position and remounts the DOM on every filter change, causing flicker and lost state.

**Do this instead:** Pass the updated `filteredMembers` array as a reactive prop. TanStack Table's `getCoreRowModel()` recomputes automatically when the data ref changes; the virtualizer repositions without remounting.

---

### Anti-Pattern 5: Multi-Group Assignment via Local State Mutation

**What people do:** When reassigning a member to a new group, update the `allMembers` array locally before the API responds.

**Why it's wrong:** The member list is a derived computed from `membersByGroup` — local mutation is overwritten on next recompute. Additionally, cross-group membership changes require re-fetching affected groups.

**Do this instead:** Call the appropriate domain store action (add/remove from group), then call `membersDomain.loadMembers(groupId, true)` with `force=true` for all affected groups to refresh the cache. The flat computed updates automatically.

---

## Build Order (Dependency Graph)

Dependencies dictate this order:

```
Step 1: Install packages
  npm install @tanstack/vue-table @tanstack/vue-virtual
  → No code dependencies; do first

Step 2: Router update + sidebar link
  → Add /admin/members route to router.ts
  → Add nav link to admin-sidebar.vue
  → Can be done before the section exists (route will 404 until step 7)

Step 3: all-members.domain.ts
  → Depends on: groups.domain (existing), members.domain (existing)
  → Standalone; no UI dependencies

Step 4: member-activity.domain.ts
  → Standalone; no dependencies on step 3

Step 5: AdminVirtualTable component
  → Depends on: step 1 (packages)
  → No store dependencies — pure display

Step 6: MemberFilterBar component
  → No package or store dependencies
  → Pure display component

Step 7: ActivityTimeline, LessonProgressList, MemberProfileDrawer
  → No package or store dependencies
  → Pure display components; can build in parallel with step 6

Step 8: members-list.ui.ts
  → Depends on: step 3 (all-members.domain)

Step 9: member-detail.ui.ts
  → Depends on: members.domain (existing), step 4 (member-activity.domain)

Step 10: members-section.vue
  → Depends on: steps 3, 4, 5, 6, 7, 8, 9 (all stores + all components)
  → Final integration; completes the feature
```

---

## Sources

- Verified from codebase: `islands/admin-island/stores/domain/members.domain.ts` — `membersByGroup` keyed cache, `loadedGroupIds` Set, `loadMembers(groupId, force)` signature
- Verified from codebase: `islands/admin-island/stores/ui/members-tab.ui.ts` — UI store composing domain store, `loadData()` pattern, profile drawer approach
- Verified from codebase: `islands/admin-island/sections/groups-section.vue` — section file conventions, store usage, `onMounted` trigger, event handler patterns
- Verified from codebase: `components/admin/admin-table/admin-table.vue` — pure props/emits component; row/column interfaces; no store imports
- Verified from codebase: `islands/admin-island/router.ts` — existing route shape; `createWebHistory`, section-level routes
- Verified from codebase: `server/src/routes/member-lessons.ts` — `GET /member/lessons` and `GET /member/lessons/:lessonScheduleId` endpoints confirmed (behind `requireMemberAuth`; admin access uses `memberId` query param override)
- Verified from codebase: `server/src/routes/members.ts` — `GET /:memberId/profile` behind `requireAuth` (Google OAuth)
- Verified from codebase: `client/package.json` — confirmed `@tanstack/vue-table` and `@tanstack/vue-virtual` are NOT yet installed
- [TanStack Table Vue Virtualized Rows Example](https://tanstack.com/table/latest/docs/framework/vue/examples/virtualized-rows) — MEDIUM confidence; official docs confirm pagination + virtualization are mutually exclusive
- [TanStack Virtual Vue Table Example](https://tanstack.com/virtual/v3/docs/framework/vue/examples/table) — MEDIUM confidence; official docs
- [Pinia Composing Stores](https://pinia.vuejs.org/cookbook/composing-stores.html) — HIGH confidence; official docs; confirms cross-store composition via `useStore()` inside actions/getters

---
*Architecture research for: MakeReady admin — member management v2.1 (virtualized table + activity history)*
*Researched: 2026-03-21*
