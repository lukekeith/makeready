---
phase: 07-programs-lessons
plan: "02"
subsystem: admin-island
tags: [vue, pinia, programs, crud, admin]
dependency_graph:
  requires: ["07-01"]
  provides: ["programs list view with CRUD", "create form with template selector"]
  affects: ["programs-section.vue", "programs-list.ui.ts", "programs.domain.ts"]
tech_stack:
  added: []
  patterns: ["list/detail branching via route.params.id", "computed createFields for async-dependent options"]
key_files:
  created: []
  modified:
    - resources/js/islands/admin-island/sections/programs-section.vue
decisions:
  - "createFields is a computed (not const) because templateOptions depends on async loadTemplates — matches plan spec"
  - "Both programs and templates loaded in parallel on mount to ensure template select is populated on first open"
  - "Detail view placeholder kept minimal — will be fully implemented in Plan 03"
metrics:
  duration: 6 min
  completed: 2026-03-20
  tasks_completed: 1
  files_modified: 1
---

# Phase 7 Plan 02: Programs Section List View CRUD Summary

**One-liner:** Programs list CRUD with AdminTable, create form (template select + days field), edit form, and delete confirmation mirroring groups-section.vue pattern.

## What Was Built

The `programs-section.vue` stub was rewritten into a full programs list view with complete CRUD functionality.

### programs-section.vue

The component implements the list/detail branching pattern from `groups-section.vue`:

- **List view** (`v-else`): AdminTable showing Name, Lessons, and Status columns with Create/Edit/Delete actions
- **Detail view** (`v-if="route.params.id"`): Placeholder with back button and page title — will be fully built in Plan 03
- **onMounted**: Loads programs AND templates in parallel when on the list route, or fetches single program on detail route
- **watch(route.params.id)**: Handles navigation between list and detail without remounting

**Key difference from groups-section.vue:** `createFields` is a `computed` ref (not a `const`) because `listUI.templateOptions` is derived from `domain.templates` which populates asynchronously from `loadTemplates()`. Using `const` would capture an empty array at definition time.

**Create form fields:** name (text), description (textarea), templateId (select populated from templates API), days (number)

**Edit form fields:** name (text), description (textarea) only — template and days are set at creation time

**Delete confirmation message:** "This will remove all lessons and enrollments. This cannot be undone." — reflects the cascading impact unique to programs.

## Verification

- `npm run build`: passed (2.20s)
- `php artisan test tests/Feature/ProgramsAdminTest.php`: 12/12 passed (32 assertions)
- `php artisan test`: 194 passed, 1 pre-existing incomplete, 0 failures

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- [x] `resources/js/islands/admin-island/sections/programs-section.vue` exists and has 172 lines added
- [x] Commit `9a3713b` exists: `feat(07-02): rewrite programs-section.vue with full list view CRUD`
- [x] Build passes
- [x] All 12 ProgramsAdminTest tests pass
