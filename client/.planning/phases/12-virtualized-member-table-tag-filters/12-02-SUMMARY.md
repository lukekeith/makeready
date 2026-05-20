---
phase: 12-virtualized-member-table-tag-filters
plan: "02"
subsystem: admin-members
tags: [filter-bar, reka-ui, combobox, filter-chips, members-section, smoke-test]
dependency_graph:
  requires: [12-01-SUMMARY.md]
  provides: [MemberFilterBar, members-section-wired]
  affects: [members-section.vue, admin-virtual-table.scss]
tech_stack:
  added: []
  patterns:
    - Presentational filter bar component: all data via props, all mutations via emits
    - reka-ui ComboboxRoot with controlled model-value for post-selection reset
    - members-section.vue as orchestration layer: stores → props → components → emits → actions
    - Warning banner with dismissible amber styling inside AdminVirtualTable BEM block
key_files:
  created:
    - resources/js/components/admin/member-filter-bar/member-filter-bar.vue
    - resources/css/components/admin/member-filter-bar.scss
    - tests/Feature/MembersAdminTest.php
  modified:
    - resources/js/islands/admin-island/sections/members-section.vue
    - resources/css/components/admin/admin-virtual-table.scss
    - resources/css/app.scss
decisions:
  - "reka-ui ComboboxRoot uses controlled :model-value + @update:model-value with local ref reset rather than uncontrolled v-model — ensures combobox input clears after selection"
  - "Warning banner styles (__warning, __warning-dismiss) added to admin-virtual-table.scss not a new file — banner is rendered by members-section.vue which already depends on that block namespace"
metrics:
  duration: "2 minutes"
  completed_date: "2026-03-21"
  tasks_completed: 2
  files_created: 3
  files_modified: 3
---

# Phase 12 Plan 02: MemberFilterBar + members-section Wiring Summary

**One-liner:** Presentational MemberFilterBar with reka-ui Combobox dropdowns and filter chips wired into members-section.vue via useMembersListUI store, with failed-groups warning banner and complete empty states.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create MemberFilterBar component with SCSS | 9aa2700 | member-filter-bar.vue, member-filter-bar.scss, app.scss |
| 2 | Wire members-section.vue end-to-end + smoke test | ae6fdcb | members-section.vue, admin-virtual-table.scss, MembersAdminTest.php |

## What Was Built

### member-filter-bar.vue
- Fully presentational — no store access; all data via props, all mutations via emits
- Props: `filterTags: FilterTag[]`, `searchQuery: string`, `availableGroups: string[]`, `hasActiveFilters: boolean`
- Emits: `add-filter(category, value)`, `remove-filter(index)`, `clear-filters()`, `update:search-query(value)`
- Search input: local ref synced to prop via watch; Enter key and Add button both call `handleSearchAdd()` which emits `add-filter('name', ...)` and resets local ref
- Three reka-ui ComboboxRoot dropdowns: group (from availableGroups prop), status ('Completed', 'In Progress', 'Upcoming'), activity type ('SOAP', 'VIDEO', 'READ', 'OIA', 'DBS', 'HEAR', 'USER_INPUT')
- Controlled combobox pattern: `:model-value="localRef" @update:model-value="handler"` where handler emits then resets local ref to undefined — clears ComboboxInput after selection
- Filter chips rendered with per-category color modifier classes (--name blue, --group purple, --status green, --type amber)
- `formatLabel(tag)` helper returns "Category: value" string for chip display
- Clear all button visible when `hasActiveFilters` is true

### member-filter-bar.scss
- BEM: `.MemberFilterBar` block with dark theme matching existing admin components
- Search input: dark background (#2a2a2a), 36px left padding for icon, purple focus border (#6c47ff)
- Search icon: absolute positioned with `pointer-events: none`
- Add button: solid purple (#6c47ff), lightened on hover
- Combobox inputs: 150px width, same dark styling as search input
- Combobox content: #2a2a2a background, z-index 50, max-height 200px scrollable
- `[data-highlighted]` selector for keyboard-navigated item highlight

### members-section.vue (rewritten)
- Imports and initializes `useAllMembersDomain`, `useMembersListUI`, `useGroupsDomain`
- `availableGroups` computed from `groupsDomain.groups.map(g => g.name)`
- `onMounted` calls `allMembersDomain.loadAll()` (preserved from prior stub)
- `handleRowClick(_userId)` no-op placeholder with `TODO(Phase 13)` comment
- Header shows total count when not loading
- Warning banner: shown when `failedGroups.length > 0 && !dismissedFailedGroups`; amber styling; dismiss button calls `membersListUI.dismissFailedGroups()`
- MemberFilterBar wired: all props from store, all emits mapped to store actions
- AdminVirtualTable shown when `filteredMembers.length > 0 || isLoading`; receives `filteredMembers` as data
- Empty state (filtered): shown when `hasActiveFilters && filteredMembers.length === 0`; Clear filters action
- Empty state (no members): shown when `!isLoading && allMembers.length === 0`

### admin-virtual-table.scss (modified)
- Added `&__warning` block: amber background/border, flex row, space-between
- Added `&__warning-dismiss` button: amber color, flex centered icon, hover to white

### MembersAdminTest.php
- `adminSession()` helper matches exact pattern from AdminTest.php: `admin_user_session` string key + `admin_user` array
- Smoke test: `GET /admin/members` returns 200 and asserts `admin-island` string present
- Test passes: 1 passed, 2 assertions

## Verification Results

- `npm run build`: PASS (2480 modules, 3.12s)
- `php artisan test --filter=MembersAdminTest`: PASS (1 test, 2 assertions)
- MemberFilterBar is presentational — no direct store access confirmed
- AdminVirtualTable receives `filteredMembers` as data prop — no direct store access confirmed
- Warning banner styles scoped inside `.AdminVirtualTable` BEM block

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

Files exist:
- resources/js/components/admin/member-filter-bar/member-filter-bar.vue: FOUND
- resources/css/components/admin/member-filter-bar.scss: FOUND
- resources/js/islands/admin-island/sections/members-section.vue: FOUND (rewritten)
- tests/Feature/MembersAdminTest.php: FOUND

Commits exist:
- 9aa2700: FOUND
- ae6fdcb: FOUND
