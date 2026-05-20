# Phase 12: Virtualized Member Table + Tag Filters - Research

**Researched:** 2026-03-21
**Domain:** TanStack Table v8 (Vue 3) + TanStack Virtual v3 (Vue 3) + reka-ui TagsInput/Combobox
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Row Layout:**
- Fixed-height rows (56px) — required for TanStack Virtual `estimateSize`
- Each row: avatar (32px circle), member name (primary text), group chips (small colored pills with group names), last active date (muted secondary text, right-aligned)
- Row is clickable — click opens member profile drawer (Phase 13 wires this; Phase 12 emits the event)
- Hover state: subtle background highlight matching existing AdminTable row hover
- No action buttons per row

**Filter Interaction:**
- Filter bar sits above the table, below the page title
- Search input with placeholder "Search members..." — pressing Enter (or clicking Add) creates a name filter tag
- Dropdown suggestions for group, status, and activity type filters — use reka-ui Combobox for typeahead suggestions
- Each filter renders as a chip/tag below the search input (reka-ui TagsInput pattern)
- Chips show category + value: "Group: Bible Study", "Status: Completed", "Type: SOAP"
- Individual chip removal via X button
- "Clear all" button appears when any filters are active
- Filters are AND (intersection)
- All filtering is client-side on the loaded `allMembers` array
- Filter state lives in `members-list.ui` Pinia store (never in TanStack column filter model)

**Empty/Loading States:**
- Loading: Skeleton rows (8 placeholder rows with shimmer animation)
- No results (filters active): "No members match your filters" with a "Clear filters" link
- No members at all (empty org): "No members yet" with a brief description
- Failed groups: Yellow warning banner at the top of the table, dismissible

**Table Component Architecture:**
- New `AdminVirtualTable` component — NOT extending the existing `AdminTable`
- `AdminVirtualTable` uses `useVueTable` + `useVirtualizer` composables
- `getCoreRowModel()` only — no pagination model
- `manualFiltering: true` — Pinia UI store owns all filter logic
- Column definitions passed as props, data as props
- BEM class: `AdminVirtualTable`, `AdminVirtualTable__row`, `AdminVirtualTable__cell`, etc.

**UI Store (members-list.ui):**
- Owns: `filterTags` (array of `{ category, value }`), `searchQuery`, computed `filteredMembers`
- Reads from `all-members.domain.allMembers`
- `filteredMembers` is a computed that applies all active filter tags as AND conditions
- Exposes `addFilter(category, value)`, `removeFilter(index)`, `clearFilters()`, `setSearchQuery(query)`

### Claude's Discretion
- Exact chip color per category (group = one color, status = another, etc.)
- Whether Combobox dropdown appears on focus or after typing 1+ characters
- Skeleton row exact animation (shimmer or pulse)
- Exact column widths and responsive behavior
- Whether "last active" shows relative time ("2d ago") or absolute date

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MLIST-02 | Leader can search members by name via a search input that adds filter tags (not live filtering) | Enter-key in `MemberFilterBar` search input calls `addFilter('name', query)` on `members-list.ui` store; `filteredMembers` computed applies name match |
| MLIST-03 | Leader can filter the member list by group via tag chips | reka-ui Combobox populates group suggestions from `groupsDomain.groups`; selecting adds `addFilter('group', groupName)` tag chip |
| MLIST-04 | Leader can filter the member list by lesson completion status via tag chips | Combobox with hardcoded status options (Completed, In Progress, Upcoming); adds `addFilter('status', value)` |
| MLIST-05 | Leader can filter the member list by activity type via tag chips | Combobox with hardcoded activity type options (SOAP, VIDEO, etc.); adds `addFilter('type', value)` |
| MLIST-06 | Leader can remove individual filter tags or clear all filters at once | TagsInputItemDelete on each chip calls `removeFilter(index)`; clear-all button calls `clearFilters()` |
| MLIST-07 | Member list displays name, avatar, groups, and last active date per row | `AdminVirtualTable` column definitions render avatar `<img>`, name text, group pill chips, and formatted lastActive |
| MLIST-09 | Member list supports infinite scroll for 500+ members without performance degradation | TanStack Virtual `useVirtualizer` with `estimateSize: () => 56`, `overscan: 5`, spacer-row tbody pattern |
</phase_requirements>

---

## Summary

This phase introduces three new artifacts: the `AdminVirtualTable` Vue component (TanStack Table + TanStack Virtual), the `MemberFilterBar` Vue component (reka-ui TagsInput + Combobox), and the `members-list.ui` Pinia store. All three are composed inside an updated `members-section.vue`.

The critical architectural constraint is the strict separation between rendering and filtering: TanStack Table receives `manualFiltering: true` and is only responsible for rendering the rows it is given. All filter logic lives exclusively in the Pinia `members-list.ui` store via a `filteredMembers` computed. The table's `data` prop is always bound to `filteredMembers`, not the raw `allMembers` array.

For virtualization, the spacer-row tbody pattern is the correct and safe approach — not the absolute-position + `translateY` approach. Using `position: absolute; transform: translateY()` on `<tr>` elements causes `<tr>` borders to disappear in Chrome and Firefox when rows leave the table bounds. The spacer pattern inserts two dummy `<tr>` elements (one above, one below visible rows) whose heights equal `paddingTop` and `paddingBottom` derived from the virtualizer, keeping all rows in normal table document flow.

**Primary recommendation:** Use the spacer-row tbody pattern for virtualization, bind `useVueTable.data` to a getter returning `filteredMembers.value`, and keep all filter mutation logic in the Pinia store's actions.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@tanstack/vue-table` | ^8.21.3 (installed) | Table state, column definitions, row model | Already installed; Vue 3 adapter for TanStack Table v8 |
| `@tanstack/vue-virtual` | ^3.13.23 (installed) | Row virtualization | Already installed; Vue 3 adapter for TanStack Virtual v3 |
| `reka-ui` | ^2.9.2 (installed) | TagsInput chips + Combobox typeahead | Already installed; used for all accessible UI primitives in this project |
| `pinia` | ^3.0.4 (installed) | `members-list.ui` store | Already installed; established pattern in this codebase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `lucide-vue-next` | ^0.577.0 (installed) | X icon for chip delete, Search icon | Already used throughout admin components |
| `sass` | ^1.98.0 (installed) | SCSS for BEM component styles | All component styles in this project use SCSS |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@tanstack/vue-virtual` | `vue-virtual-scroller` | vue-virtual-scroller is simpler but less maintained; TanStack Virtual is already installed |
| `reka-ui TagsInput` | Custom chip implementation | Custom would require building keyboard navigation from scratch; reka-ui is already installed and handles accessibility |

**Installation:** No new packages needed — all dependencies already installed.

---

## Architecture Patterns

### Recommended Project Structure

New files for Phase 12:

```
resources/js/islands/admin-island/
├── stores/ui/
│   └── members-list.ui.ts          ← NEW: filter state + filteredMembers computed
├── sections/
│   └── members-section.vue         ← MODIFY: add AdminVirtualTable + MemberFilterBar
resources/js/components/admin/
├── admin-virtual-table/
│   └── admin-virtual-table.vue     ← NEW: TanStack Table + Virtual component
├── member-filter-bar/
│   └── member-filter-bar.vue       ← NEW: reka-ui TagsInput + Combobox filter bar
resources/css/components/admin/
├── admin-virtual-table.scss        ← NEW: BEM styles for virtualized table
└── member-filter-bar.scss          ← NEW: BEM styles for filter bar + chips
```

### Pattern 1: useVueTable with manualFiltering + Pinia data binding

**What:** The table instance uses `manualFiltering: true` and binds its `data` option to a getter that reads `filteredMembers.value` from the Pinia store. This is the correct TanStack pattern for external filter state — the table never calls `getFilteredRowModel()`, it only calls `getCoreRowModel()`.

**When to use:** Any time filter logic lives outside TanStack Table (server-side or Pinia-owned client-side).

**Example:**
```typescript
// Source: TanStack Table v8 docs — Column Filtering Guide (manualFiltering)
// https://tanstack.com/table/v8/docs/guide/column-filtering

// In admin-virtual-table.vue <script setup>
import {
  useVueTable,
  getCoreRowModel,
  createColumnHelper,
  FlexRender,
  type ColumnDef,
} from '@tanstack/vue-table'
import type { UnifiedMember } from '../../islands/admin-island/stores/domain/all-members.domain'

const props = defineProps<{
  data: UnifiedMember[]
  columns: ColumnDef<UnifiedMember>[]
}>()

const emit = defineEmits<{
  (e: 'row-click', userId: string): void
}>()

const table = useVueTable({
  get data() { return props.data },    // getter ensures reactivity when prop changes
  get columns() { return props.columns },
  getCoreRowModel: getCoreRowModel(),
  manualFiltering: true,               // disables all internal filter processing
})
```

### Pattern 2: useVirtualizer with spacer-row tbody pattern

**What:** The virtualizer runs on the `tbody`'s scroll container. The `<tbody>` renders two spacer `<tr>` rows (height = paddingTop and paddingBottom respectively), with the visible virtual rows between them. This keeps rows in normal document flow — avoiding the Chrome/Firefox `<tr>` border rendering bug that breaks with `position: absolute`.

**When to use:** Virtualizing a semantic HTML `<table>` element. Do NOT use absolute positioning + translateY for `<tr>` elements.

**Example:**
```typescript
// Source: TanStack Virtual discussions #284, #476, verified in TanStack/table virtualization guide
// https://github.com/TanStack/virtual/discussions/284

import { useVirtualizer } from '@tanstack/vue-virtual'
import { ref, computed } from 'vue'

const tableContainerRef = ref<HTMLDivElement | null>(null)

const rowVirtualizerOptions = computed(() => ({
  count: table.getRowModel().rows.length,
  estimateSize: () => 56,       // locked to 56px per CONTEXT.md decision
  getScrollElement: () => tableContainerRef.value,
  overscan: 5,
}))

const rowVirtualizer = useVirtualizer(rowVirtualizerOptions)

// CRITICAL: wrap in computed to maintain Vue reactivity
const virtualRows = computed(() => rowVirtualizer.value.getVirtualItems())
const totalSize = computed(() => rowVirtualizer.value.getTotalSize())

// Spacer heights derived from first/last virtual item positions
const paddingTop = computed(() =>
  virtualRows.value.length > 0 ? virtualRows.value[0].start : 0
)
const paddingBottom = computed(() =>
  virtualRows.value.length > 0
    ? totalSize.value - virtualRows.value[virtualRows.value.length - 1].end
    : 0
)
```

**Template (spacer-row pattern):**
```vue
<!-- Source: TanStack Virtual discussions #284 — spacer tr pattern -->
<div ref="tableContainerRef" class="AdminVirtualTable__scroll-container">
  <table class="AdminVirtualTable__table">
    <thead class="AdminVirtualTable__thead"><!-- headers --></thead>
    <tbody class="AdminVirtualTable__tbody">
      <!-- Top spacer row -->
      <tr v-if="paddingTop > 0" :style="{ height: paddingTop + 'px' }">
        <td :colspan="columns.length" />
      </tr>

      <!-- Visible rows only -->
      <tr
        v-for="virtualRow in virtualRows"
        :key="virtualRow.key"
        class="AdminVirtualTable__row"
        @click="emit('row-click', table.getRowModel().rows[virtualRow.index].original.userId)"
      >
        <td
          v-for="cell in table.getRowModel().rows[virtualRow.index].getVisibleCells()"
          :key="cell.id"
          class="AdminVirtualTable__cell"
        >
          <FlexRender :render="cell.column.columnDef.cell" :props="cell.getContext()" />
        </td>
      </tr>

      <!-- Bottom spacer row -->
      <tr v-if="paddingBottom > 0" :style="{ height: paddingBottom + 'px' }">
        <td :colspan="columns.length" />
      </tr>
    </tbody>
  </table>
</div>
```

### Pattern 3: Pinia members-list.ui store with filteredMembers computed

**What:** The store owns `filterTags`, `searchQuery`, and `filteredMembers`. The `filteredMembers` computed applies all active tags as AND conditions, reading directly from `useAllMembersDomain().allMembers`.

**When to use:** Always — filter state must never be split between this store and TanStack column filter model.

**Example:**
```typescript
// Source: Established Pinia pattern in this codebase (groups-list.ui.ts reference)
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useAllMembersDomain, type UnifiedMember } from '../domain/all-members.domain'

export interface FilterTag {
  category: 'name' | 'group' | 'status' | 'type'
  value: string
}

export const useMembersListUI = defineStore('members-list-ui', () => {
  const domain = useAllMembersDomain()

  const filterTags = ref<FilterTag[]>([])
  const searchQuery = ref('')
  const dismissedFailedGroups = ref(false)

  const filteredMembers = computed<UnifiedMember[]>(() => {
    if (filterTags.value.length === 0) return domain.allMembers

    return domain.allMembers.filter((member) => {
      return filterTags.value.every((tag) => {
        switch (tag.category) {
          case 'name':
            return member.name.toLowerCase().includes(tag.value.toLowerCase())
          case 'group':
            return member.groups.some((g) =>
              g.groupName.toLowerCase() === tag.value.toLowerCase()
            )
          // 'status' and 'type' require activity data (Phase 14) — return true for now
          case 'status':
          case 'type':
            return true
          default:
            return true
        }
      })
    })
  })

  function addFilter(category: FilterTag['category'], value: string): void {
    if (!value.trim()) return
    // Prevent exact duplicate tags
    const exists = filterTags.value.some(
      (t) => t.category === category && t.value === value
    )
    if (!exists) filterTags.value.push({ category, value })
    searchQuery.value = ''
  }

  function removeFilter(index: number): void {
    filterTags.value.splice(index, 1)
  }

  function clearFilters(): void {
    filterTags.value = []
    searchQuery.value = ''
  }

  function setSearchQuery(query: string): void {
    searchQuery.value = query
  }

  const hasActiveFilters = computed(() => filterTags.value.length > 0)

  return {
    filterTags,
    searchQuery,
    filteredMembers,
    hasActiveFilters,
    dismissedFailedGroups,
    addFilter,
    removeFilter,
    clearFilters,
    setSearchQuery,
  }
})
```

### Pattern 4: reka-ui TagsInput as display-only chip list

**What:** `TagsInputRoot` holds the visible filter chips. Because filter state is owned by Pinia (not v-model on TagsInputRoot), the component is used in a controlled display-only mode: chips are rendered from `filterTags`, and deletions call `removeFilter(index)` rather than mutating a v-model array. Combobox sits alongside (not inside) TagsInput to add new tags.

**When to use:** When tag state is managed by an external store rather than component-local state.

**Example:**
```vue
<!-- Source: reka-ui TagsInput docs + Combobox TagsInput example -->
<!-- https://reka-ui.com/docs/components/tags-input -->
<!-- https://reka-ui.com/examples/combobox-tags-input -->

<template>
  <div class="MemberFilterBar">
    <!-- Search input + Add button for name filters -->
    <div class="MemberFilterBar__search-row">
      <input
        v-model="store.searchQuery"
        class="MemberFilterBar__search-input"
        placeholder="Search members..."
        @keydown.enter.prevent="handleAddName"
      />
      <button class="MemberFilterBar__add-btn" @click="handleAddName">Add</button>
    </div>

    <!-- Category filter dropdowns (Combobox per category) -->
    <div class="MemberFilterBar__dropdowns">
      <ComboboxRoot :ignore-filter="false" @update:model-value="(v) => store.addFilter('group', v)">
        <ComboboxInput placeholder="Group..." class="MemberFilterBar__combobox-input" />
        <ComboboxContent class="MemberFilterBar__combobox-content">
          <ComboboxItem
            v-for="group in availableGroups"
            :key="group"
            :value="group"
            class="MemberFilterBar__combobox-item"
          >
            {{ group }}
          </ComboboxItem>
        </ComboboxContent>
      </ComboboxRoot>
      <!-- similar Combobox for status and type -->
    </div>

    <!-- Active filter chips -->
    <div v-if="store.hasActiveFilters" class="MemberFilterBar__chips">
      <div
        v-for="(tag, index) in store.filterTags"
        :key="index"
        :class="['MemberFilterBar__chip', `MemberFilterBar__chip--${tag.category}`]"
      >
        <span class="MemberFilterBar__chip-label">
          {{ tagLabel(tag) }}
        </span>
        <button class="MemberFilterBar__chip-remove" @click="store.removeFilter(index)">
          <X :size="12" />
        </button>
      </div>
      <button class="MemberFilterBar__clear-all" @click="store.clearFilters()">
        Clear all
      </button>
    </div>
  </div>
</template>
```

### Pattern 5: Skeleton rows (shimmer animation)

**What:** During `isLoading`, render 8 dummy `<tr>` rows with animated shimmer placeholders instead of the real table. This is a new pattern not yet in the codebase — must define the `@keyframes` animation.

**Example (SCSS):**
```scss
// New keyframe — add to admin-virtual-table.scss
@keyframes member-shimmer {
  0% { background-position: -400px 0; }
  100% { background-position: 400px 0; }
}

.AdminVirtualTable {
  &__skeleton-row {
    height: 56px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }

  &__skeleton-cell {
    background: linear-gradient(
      90deg,
      rgba(255, 255, 255, 0.04) 25%,
      rgba(255, 255, 255, 0.08) 50%,
      rgba(255, 255, 255, 0.04) 75%
    );
    background-size: 800px 100%;
    animation: member-shimmer 1.4s ease-in-out infinite;
    border-radius: 4px;
  }
}
```

### Anti-Patterns to Avoid

- **Using `position: absolute` + `transform: translateY()` on `<tr>` elements:** This causes `<tr>` border rendering bugs in Chrome and Firefox when rows are positioned outside the table bounds. Use the spacer-row pattern instead.
- **Calling `getVirtualItems()` directly without a `computed` wrapper:** `useVirtualizer` returns a `Ref<Virtualizer>`. Calling methods on it outside computed/template breaks Vue reactivity. Always wrap in `computed(() => rowVirtualizer.value.getVirtualItems())`.
- **Putting filter state in TanStack's column filter model:** CONTEXT.md locks this — all filter state in Pinia `members-list.ui`. `manualFiltering: true` must be set on the table.
- **Passing a plain array to `useVueTable` data option:** Must use `get data() { return filteredMembers.value }` getter syntax. Plain array assignment loses reactivity after store mutations (documented in STATE.md v2.1 decisions).
- **Accessing the store inside `AdminVirtualTable` or `MemberFilterBar` components:** These are presentational components — they receive data via props and emit events. Only `members-section.vue` accesses Pinia stores.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Row virtualization offset math | Custom scroll math + visible row index calculation | `useVirtualizer` from `@tanstack/vue-virtual` | Off-by-one errors with variable heights, scroll jank, ResizeObserver edge cases |
| Table column definition system | Custom typed column config | `createColumnHelper` + `ColumnDef` from `@tanstack/vue-table` | Type safety, FlexRender handles cell/header rendering |
| Filter chip keyboard navigation | Custom keyboard handler | reka-ui `TagsInput` primitives | Delete, Backspace, ArrowLeft/Right, Home/End fully handled |
| Combobox typeahead filtering | Custom input + dropdown with filter | reka-ui `Combobox` | Focus management, ARIA attributes, keyboard navigation |
| Virtual scroll spacer math | Manual `paddingTop` calculation | `virtualRows.value[0].start` and `totalSize - lastRow.end` | Formula is non-obvious and must account for overscan |

**Key insight:** Both TanStack Table and TanStack Virtual are headless — they provide zero markup. The implementation cost is in wiring them together correctly, not in overriding styles.

---

## Common Pitfalls

### Pitfall 1: `<tr>` borders disappear with absolute positioning
**What goes wrong:** Using `transform: translateY(virtualRow.start + 'px')` + `position: relative` on `<tbody>` causes `<tr>` elements to render outside the table element bounds in Chrome and Firefox. When a `<tr>` is outside table bounds, its `border` stops displaying.
**Why it happens:** CSS table layout is special — `<tr>` borders are clipped to the `<table>` bounding box.
**How to avoid:** Use the spacer-row pattern: two dummy `<tr>` rows with `height: paddingTop` and `height: paddingBottom` containing a single `<td colspan>`.
**Warning signs:** Row borders disappear or are inconsistent when scrolling; first and last visible rows look different.

### Pitfall 2: `useVirtualizer` not reactive after scroll
**What goes wrong:** `rowVirtualizer.value.getVirtualItems()` is called directly in template or non-computed context. The virtual items don't update when the user scrolls.
**Why it happens:** `useVirtualizer` returns a `Ref<Virtualizer>`. The `.value` access must happen inside a reactive context (computed, template expression) for Vue to track the dependency.
**How to avoid:** Always define `const virtualRows = computed(() => rowVirtualizer.value.getVirtualItems())` and use `virtualRows.value` in template.
**Warning signs:** Table appears frozen on scroll — same 5-10 rows visible regardless of scroll position.

### Pitfall 3: Stale data when `allMembers` updates progressively
**What goes wrong:** If `data` is bound as a non-reactive snapshot (`data: filteredMembers.value` evaluated at setup time), the table won't re-render when new groups load and `allMembers` grows.
**Why it happens:** TanStack Table's Vue adapter re-evaluates `data` only if it's a getter or reactive ref. Plain `data: someArray` is evaluated once.
**How to avoid:** Always use `get data() { return filteredMembers.value }` as the data option. This is confirmed in STATE.md as an established project decision.
**Warning signs:** Member count shown in header updates but table row count stays stale.

### Pitfall 4: TagsInput v-model fights Pinia store
**What goes wrong:** If `TagsInputRoot` is wired with `v-model="store.filterTags"`, reka-ui will push raw string values to that array. But the store expects `FilterTag` objects with `{ category, value }`.
**Why it happens:** `TagsInputRoot.modelValue` is typed as string arrays in reka-ui's default configuration.
**How to avoid:** Do NOT use `v-model` on `TagsInputRoot`. Render chips manually from `store.filterTags` using `v-for`, and wire delete buttons to call `store.removeFilter(index)`.
**Warning signs:** Type errors on `filterTags` items; filter logic breaks because items are strings instead of `FilterTag` objects.

### Pitfall 5: `getScrollElement` returns null during setup
**What goes wrong:** `useVirtualizer` is initialized before the scroll container DOM element is mounted. `getScrollElement` returns null and virtualization never activates.
**Why it happens:** `computed` options for `useVirtualizer` are evaluated before `onMounted`. The ref is null at that point.
**How to avoid:** Use `() => tableContainerRef.value` (a function, not the value itself) as `getScrollElement`. The function is called lazily on scroll events, not during setup.
**Warning signs:** `getVirtualItems()` always returns 0 or all items; scroll container has no height.

### Pitfall 6: Combobox `ignoreFilter` needed for custom filter logic
**What goes wrong:** By default, `ComboboxRoot` applies internal text filtering on the items. If group names are already filtered in a computed, the Combobox double-filters and items disappear.
**Why it happens:** reka-ui Combobox has built-in filtering that matches `ComboboxItem.textValue` against the input.
**How to avoid:** Use `ignore-filter` prop on `ComboboxRoot` when providing pre-filtered items from a computed, OR let reka-ui do the filtering (pass all options and let Combobox filter by input value — this is simpler for group names).
**Warning signs:** Typing in Combobox input causes all suggestions to disappear after 1-2 characters.

---

## Code Examples

Verified patterns from official sources and codebase conventions:

### Column Definition with createColumnHelper
```typescript
// Source: TanStack Table v8 docs — createColumnHelper
// https://tanstack.com/table/v8/docs/framework/vue/vue-table
import { createColumnHelper, type ColumnDef } from '@tanstack/vue-table'
import type { UnifiedMember } from '../stores/domain/all-members.domain'
import { h } from 'vue'

const columnHelper = createColumnHelper<UnifiedMember>()

export const memberColumns: ColumnDef<UnifiedMember>[] = [
  columnHelper.display({
    id: 'avatar',
    header: '',
    cell: (ctx) => h('img', {
      src: ctx.row.original.avatarUrl,
      class: 'AdminVirtualTable__avatar',
      alt: '',
    }),
  }),
  columnHelper.accessor('name', {
    header: 'Name',
    cell: (ctx) => ctx.getValue(),
  }),
  columnHelper.display({
    id: 'groups',
    header: 'Groups',
    cell: (ctx) => h('div', { class: 'AdminVirtualTable__group-chips' },
      ctx.row.original.groups.map((g) =>
        h('span', { class: 'AdminVirtualTable__group-chip', key: g.groupId }, g.groupName)
      )
    ),
  }),
  columnHelper.accessor('lastActive', {
    id: 'lastActive',
    header: 'Last Active',
    cell: (ctx) => formatRelativeTime(ctx.getValue()),
  }),
]
```

### Scroll Container Setup (required CSS)
```scss
// The scroll container MUST have a fixed height for useVirtualizer to work
// Source: TanStack Virtual Vue examples
.AdminVirtualTable {
  &__scroll-container {
    height: 600px;         // or use calc(100vh - offset)
    overflow-y: auto;
  }

  &__table {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;   // recommended for column width stability
  }
}
```

### Filter chip label formatter
```typescript
// Formats { category: 'group', value: 'Bible Study' } → "Group: Bible Study"
function tagLabel(tag: FilterTag): string {
  const labels: Record<FilterTag['category'], string> = {
    name: 'Name',
    group: 'Group',
    status: 'Status',
    type: 'Type',
  }
  return `${labels[tag.category]}: ${tag.value}`
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Absolute positioning + translateY on `<tr>` | Spacer-row tbody pattern | Identified as bug in TanStack Virtual discussions | Fixes border rendering bugs in Chrome/Firefox |
| `data: ref(array)` passed to useVueTable | `get data() { return computed.value }` getter | TanStack Table v8 Vue adapter | Required for progressive data loading reactivity |
| Separate filter state in TanStack column model | All filter state in Pinia, `manualFiltering: true` | v2.1 architectural decision (STATE.md) | Prevents split state management bugs |

**Deprecated/outdated:**
- Using `v-model` on `TagsInputRoot` when tags have structured shape — TagsInput v-model expects string arrays, not typed objects.

---

## Open Questions

1. **Status and type filter values (MLIST-04, MLIST-05)**
   - What we know: The context specifies "Status: Completed", "Type: SOAP" as example chips. The `filteredMembers` computed in `members-list.ui` can hardcode filter logic stubs.
   - What's unclear: The actual enumerated values for lesson completion status and activity types are defined in the server API — not yet visible in the client data structures available in Phase 12 (activity data is Phase 14).
   - Recommendation: Hardcode reasonable enum values for status (`Completed`, `In Progress`, `Upcoming`) and type (`SOAP`, `VIDEO`, `ANNOUNCEMENT`, `POLL`, `EVENT`) for the Combobox suggestions. The `filteredMembers` filter for these categories returns `true` (pass-through) until Phase 14 populates activity data on `UnifiedMember`. Document this as a stub clearly in code comments.

2. **`members-section.vue` scroll container height**
   - What we know: `AdminLayout__content` has `overflow-y: auto` and `padding: 32px 24px`. The content max-width is 960px.
   - What's unclear: Whether the scroll container for the virtual table should use the outer `AdminLayout__content` as its scroll element (pass `() => document.querySelector('.AdminLayout__content')`) or create a nested scrollable div inside `members-section.vue`.
   - Recommendation: Create a dedicated scroll container div inside `members-section.vue` with a calculated fixed height (`calc(100vh - 220px)` approximately). Using the outer layout scroll element is fragile and couples component to layout implementation.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel Feature Tests) |
| Config file | `/phpunit.xml` |
| Quick run command | `php artisan test --filter=MembersAdminTest` |
| Full suite command | `php artisan test --testsuite=Feature` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MLIST-02 | Search input creates name filter tag | manual (Vue component behavior) | n/a — no JS test framework | n/a |
| MLIST-03 | Group filter tag chips | manual (Vue component behavior) | n/a — no JS test framework | n/a |
| MLIST-04 | Status filter tag chips | manual (Vue component behavior) | n/a — no JS test framework | n/a |
| MLIST-05 | Activity type filter tag chips | manual (Vue component behavior) | n/a — no JS test framework | n/a |
| MLIST-06 | Remove individual/all filter tags | manual (Vue component behavior) | n/a — no JS test framework | n/a |
| MLIST-07 | Table row renders name, avatar, groups, last active | smoke — page renders member table markup | `php artisan test --filter=MembersAdminTest` | ❌ Wave 0 |
| MLIST-09 | 500+ members virtualized without degradation | manual browser perf test (scroll 500 rows) | n/a — no automated perf test | n/a |

### Sampling Rate
- **Per task commit:** `php artisan test --filter=MembersAdminTest`
- **Per wave merge:** `php artisan test --testsuite=Feature`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/Feature/MembersAdminTest.php` — covers MLIST-07 smoke: GET /admin/members renders AdminIsland with members section mounted; verifies route returns 200 with correct blade layout

*(All MLIST-02 through MLIST-06 and MLIST-09 are Vue component interaction tests — no JS test framework exists in this project. Behavior is verified by manual testing during `/gsd:verify-work`.)*

---

## Sources

### Primary (HIGH confidence)
- TanStack Table v8 Vue docs — `useVueTable`, `createColumnHelper`, `FlexRender`, `getCoreRowModel`, `manualFiltering`: https://tanstack.com/table/v8/docs/framework/vue/vue-table
- TanStack Table v8 Vue basic example (GitHub raw): https://github.com/TanStack/table/blob/main/examples/vue/basic/src/App.vue
- TanStack Table v8 Vue virtualized rows example: https://github.com/TanStack/table/blob/main/examples/vue/virtualized-rows/src/App.vue
- reka-ui TagsInput API: https://reka-ui.com/docs/components/tags-input
- reka-ui Combobox API: https://reka-ui.com/docs/components/combobox
- reka-ui Combobox + TagsInput example: https://reka-ui.com/examples/combobox-tags-input
- TanStack Virtual Vue table discussion (spacer-row pattern): https://github.com/TanStack/virtual/discussions/284
- TanStack Virtual absolute position pitfall: https://github.com/TanStack/virtual/discussions/476
- Codebase: `all-members.domain.ts`, `groups-list.ui.ts`, `admin-table.vue`, `admin-members-tab.scss`, `admin-layout.scss`

### Secondary (MEDIUM confidence)
- DeepWiki TanStack Virtual table virtualization (spacer pattern, translateY formula): https://deepwiki.com/TanStack/virtual/4.5-table-virtualization
- TanStack Virtual Vue useVirtualizer usage discussion #515: https://github.com/TanStack/virtual/discussions/515

### Tertiary (LOW confidence)
- None — all critical claims verified with official sources or codebase inspection.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already installed; versions confirmed from `package.json`
- Architecture: HIGH — TanStack Table + Virtual API verified from GitHub source examples; reka-ui API verified from official docs; Pinia store patterns verified from existing codebase (`groups-list.ui.ts`)
- Pitfalls: HIGH — `<tr>` absolute positioning bug confirmed in two separate TanStack Virtual GitHub discussions (#284, #476); reactivity patterns confirmed in Vue discussion #515
- SCSS patterns: HIGH — existing codebase SCSS inspected (`admin-layout.scss`, `admin-members-tab.scss`, `loading.scss`)

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable libraries; reka-ui v2.x API may evolve faster — verify Combobox `ignoreFilter` prop name if upgrading past 2.9.2)
