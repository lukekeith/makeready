---
phase: 06-groups-crud
plan: "02"
subsystem: admin-groups-crud-ui
tags: [vue, pinia, admin, groups, crud, reka-ui]
dependency_graph:
  requires: [06-01]
  provides: [useGroupsDomain, useGroupsListUI, AdminTable, AdminForm, AdminConfirmDialog, groups-section]
  affects: [admin-island, resources/css/app.scss, resources/css/layouts/admin-layout.scss]
tech_stack:
  added: []
  patterns: [pinia-composition-store, pure-display-component, store-orchestrator-pattern]
key_files:
  created:
    - resources/js/islands/admin-island/stores/domain/groups.domain.ts
    - resources/js/islands/admin-island/stores/ui/groups-list.ui.ts
    - resources/js/components/admin/admin-table/admin-table.vue
    - resources/js/components/admin/admin-form/admin-form.vue
    - resources/js/components/admin/admin-confirm-dialog/admin-confirm-dialog.vue
    - resources/css/components/admin/admin-table.scss
    - resources/css/components/admin/admin-form.scss
    - resources/css/components/admin/admin-confirm-dialog.scss
  modified:
    - resources/js/islands/admin-island/sections/groups-section.vue
    - resources/css/app.scss
    - resources/css/layouts/admin-layout.scss
decisions:
  - "[Phase 06-02]: Three reusable admin components (AdminTable, AdminForm, AdminConfirmDialog) have zero store imports — pure props/emits pattern establishes the template for Programs, Members, and Enrollments"
  - "[Phase 06-02]: groups-list.ui.ts uses formError as a mutable ref (not readonly computed) so groups-section.vue can assign error messages from catch blocks directly"
  - "[Phase 06-02]: AdminSection__action-btn added to admin-layout.scss (not a component-scoped style) so all future section headers can reuse it"
metrics:
  duration_minutes: 3
  completed_date: "2026-03-20"
  tasks_completed: 3
  files_created: 8
  files_modified: 3
---

# Phase 6 Plan 02: Groups List CRUD Summary

**One-liner:** Pinia domain/UI stores with axios CRUD, three reusable reka-ui Dialog admin components (AdminTable, AdminForm, AdminConfirmDialog), and a fully wired groups-section.vue orchestrating create, edit, and delete.

## What Was Built

### Task 1: Pinia Domain and UI Stores

**`stores/domain/groups.domain.ts`** — Store ID `groups-domain`:

- `Group` interface with all fields (id, name, description, coverImageUrl, isPrivate, allowInvites, memberDirectory, welcomeMessage, ageRange, maxMembers, memberCount)
- `CreateGroupPayload` and `UpdateGroupPayload` exported types
- Methods: `loadGroups`, `getGroup` (with upsert), `createGroup` (push), `updateGroup` (splice-replace), `deleteGroup` (filter), `uploadCoverImage` (upsert coverImageUrl)
- All methods wrap in try/catch; `error.value` set on failure; createGroup/updateGroup/deleteGroup re-throw so callers can catch
- `isLoading` flag gated around `loadGroups` only (non-blocking for individual operations)

**`stores/ui/groups-list.ui.ts`** — Store ID `groups-list-ui`:

- Refs: `isCreateFormOpen`, `editingGroupId`, `confirmDeleteId`, `formError`
- Computeds: `tableColumns` (`['Name', 'Members', 'Privacy']`), `tableRows` (maps domain.groups → `{ id, cells, coverImageUrl, badge }`), `editingGroup`, `confirmDeleteGroup`, `isEditing`
- Methods: `openCreateForm`, `openEditForm`, `closeForm`, `requestDelete`, `cancelDelete`, `navigateToDetail` (router.push)

### Task 2: Reusable Admin Display Components

**`admin-table.vue`** — Pure display, no store imports:
- Props: `columns`, `rows` (with `id`, `cells`, optional `coverImageUrl` and `badge`), `loading`, `emptyMessage`
- Emits: `row-click(id)`, `edit(id)`, `delete(id)` — action buttons call `event.stopPropagation()` to prevent row-click
- First cell renders 40x40 thumbnail when `coverImageUrl` present; last cell renders `AdminTable__badge` when `badge` present
- Uses lucide-vue-next `Pencil` and `Trash2` icons

**`admin-form.vue`** — reka-ui `DialogRoot/DialogPortal/DialogOverlay/DialogContent`:
- Props: `open`, `title`, `fields` (supporting text/textarea/toggle/number/select), `values`, `error`, `saving`
- Deep-copies `values` to internal `formValues` ref on open/values-change to prevent parent mutation
- Toggle renders hidden checkbox + styled `AdminForm__toggle-switch` with `--on` modifier for purple active state
- Emits `save(payload)` with shallow copy of `formValues`, `cancel()` on overlay/escape

**`admin-confirm-dialog.vue`** — reka-ui Dialog with cancel/confirm:
- Props: `open`, `title`, `message`, `confirmLabel` (default "Delete"), `dangerous` (default true)
- `dangerous=true` adds `AdminConfirmDialog__btn--dangerous` class for red confirm button

**SCSS** — All three files use BEM naming; dark theme (#1e1e1e modal background, rgba white borders/backgrounds, #7c3aed purple accent)

**`app.scss`** — Added three `@use` rules under `// Admin components`

### Task 3: groups-section.vue List View with CRUD

Rewrote stub to full orchestrator component:
- Imports both Pinia stores and three admin display components
- `onMounted`: calls `domain.loadGroups()` only when no `route.params.id`
- `createFields` / `editFields` arrays define Name (text, required) + Description (textarea)
- `handleCreate` / `handleUpdate` / `handleDelete` manage `isSaving` ref and store calls
- AdminForm `:key` derived from `editingGroupId ?? 'create'` to reset internal state between create/edit
- Detail route (`route.params.id`) shows placeholder pending Plan 03
- `AdminSection__action-btn` style added to `admin-layout.scss`

## Verification

```
npm run build
  ✓ built in 2.09s — all Vue SFCs and SCSS compiled without errors

php artisan test tests/Feature/GroupsAdminTest.php
  PASS  Tests\Feature\GroupsAdminTest
  7 passed (18 assertions)

php artisan test
  Tests: 1 incomplete, 182 passed (360 assertions) — no regressions
```

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | de2b630 | feat(06-02): create Pinia domain and UI stores for groups |
| 2 | f9adf68 | feat(06-02): create reusable AdminTable, AdminForm, and AdminConfirmDialog components |
| 3 | e20d350 | feat(06-02): rewrite groups-section.vue with full groups list CRUD |

## Self-Check: PASSED
