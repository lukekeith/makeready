---
phase: 12-virtualized-member-table-tag-filters
plan: "01"
subsystem: admin-members
tags: [pinia, tanstack-table, tanstack-virtual, virtualization, filter-state]
dependency_graph:
  requires: [11-01-SUMMARY.md]
  provides: [useMembersListUI, memberColumns, AdminVirtualTable]
  affects: [members-section.vue, 12-02-PLAN.md]
tech_stack:
  added: []
  patterns:
    - useVueTable with manualFiltering:true and getter syntax for data/columns reactivity
    - useVirtualizer spacer-row tbody pattern (no absolute tr positioning)
    - Pinia computed filteredMembers with AND filter logic
    - createColumnHelper for typed column definitions with h() render functions
key_files:
  created:
    - resources/js/islands/admin-island/stores/ui/members-list.ui.ts
    - resources/js/components/admin/admin-virtual-table/admin-virtual-table.vue
    - resources/css/components/admin/admin-virtual-table.scss
  modified:
    - resources/css/app.scss
decisions:
  - "Column definitions (memberColumns) exported from members-list.ui.ts alongside the store — co-locates data shape with store that owns the domain type"
  - "formatRelativeTime helper defined in members-list.ui.ts not in a separate util — scoped to this feature, avoids premature extraction"
  - "status and type filter stubs return true — Phase 14 activity data required before real filter logic is possible"
metrics:
  duration: "8 minutes"
  completed_date: "2026-03-21"
  tasks_completed: 2
  files_created: 3
  files_modified: 1
---

# Phase 12 Plan 01: Members List UI Store + AdminVirtualTable Summary

**One-liner:** Pinia members-list.ui store with AND-logic filteredMembers computed and TanStack Table+Virtual AdminVirtualTable component using spacer-row tbody virtualization at 56px fixed row height.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create members-list.ui store and AdminVirtualTable component | 029c11f | members-list.ui.ts, admin-virtual-table.vue |
| 2 | Create AdminVirtualTable SCSS and wire into app.scss | b0bd0d6 | admin-virtual-table.scss, app.scss |

## What Was Built

### members-list.ui.ts
- `FilterTag` interface: `{ category: 'name' | 'group' | 'status' | 'type', value: string }`
- `useMembersListUI` Pinia store with:
  - `filterTags ref<FilterTag[]>`
  - `searchQuery ref<string>`
  - `dismissedFailedGroups ref<boolean>`
  - `filteredMembers computed<UnifiedMember[]>` — AND logic across all active tags; name/group filter implemented; status/type stubbed with TODO(Phase 14) comment
  - `hasActiveFilters computed<boolean>`
  - `addFilter(category, value)` — trim check + duplicate prevention + searchQuery reset
  - `removeFilter(index)` — splice
  - `clearFilters()` — reset both filterTags and searchQuery
  - `setSearchQuery(query)` — setter
  - `dismissFailedGroups()` — sets dismissedFailedGroups true
- `memberColumns ColumnDef<UnifiedMember>[]` exported alongside store:
  - avatar column: renders `<img>` or initials `<div>` fallback
  - name column: accessor with direct value render
  - groups column: display with group chip spans
  - lastActive column: accessor with `formatRelativeTime()` helper producing relative ("Xm/Xh/Xd ago", "just now") or short date ("Mar 15") output

### admin-virtual-table.vue
- Presentational component — NO store access; all data via props
- Props: `data: UnifiedMember[]`, `columns: ColumnDef<UnifiedMember>[]`, `isLoading: boolean`
- Emits: `row-click(userId: string)`
- `useVueTable` with getter syntax `get data()` and `get columns()` for reactivity; `manualFiltering: true`
- `useVirtualizer` wrapped in `computed(() => ({...}))` with `estimateSize: () => 56`, `overscan: 5`
- `virtualRows`, `totalSize`, `paddingTop`, `paddingBottom` all computed (not direct calls)
- Spacer-row tbody pattern: top/bottom `<tr>` spacers with colspan td; no absolute tr positioning
- Skeleton loading: 8 rows with 4 shimmer td cells per row (avatar, name, groups, date widths)
- Empty state: colspan td with "No members match your filters" message

### admin-virtual-table.scss
- BEM: `.AdminVirtualTable` block with standard element/modifier naming
- `@keyframes member-shimmer` shimmer animation for skeleton cells
- Dark theme matching existing AdminTable: hover `rgba(255,255,255,0.04)`, border `rgba(255,255,255,0.06)`, muted text `rgba(255,255,255,0.5)`
- Column widths: avatar 56px, name 30%, groups auto, last-active 120px right-aligned
- Sticky `thead` with `z-index: 1` and `background: #1a1a1a`
- Scroll container: `height: calc(100vh - 240px)`, `overflow-y: auto`

## Verification Results

- `npx vue-tsc --noEmit`: PASS (no errors)
- `npm run build`: PASS (SCSS compiles, Vue SFCs compile)
- Spacer-row pattern: confirmed (no absolute positioning on tr elements)
- manualFiltering: true: confirmed in useVueTable call
- Getter syntax: confirmed `get data()` and `get columns()` in table options
- memberColumns exported from members-list.ui.ts: confirmed

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

Files exist:
- resources/js/islands/admin-island/stores/ui/members-list.ui.ts: FOUND
- resources/js/components/admin/admin-virtual-table/admin-virtual-table.vue: FOUND
- resources/css/components/admin/admin-virtual-table.scss: FOUND

Commits exist:
- 029c11f: FOUND
- b0bd0d6: FOUND
