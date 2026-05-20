---
phase: 08-activity-editor
plan: "02"
subsystem: admin-activity-list
tags: [admin, activity-editor, vue, pinia, drag-and-drop, accordion]
dependency_graph:
  requires: [08-01]
  provides: [admin-activity-list-component, lesson-accordion-expand]
  affects: [programs-section.vue, program-detail.ui.ts, activity-detail.ui.ts]
tech_stack:
  added: []
  patterns: [vue-draggable-plus v-model with local ref, accordion expand/collapse, BEM SCSS type badges]
key_files:
  created:
    - resources/js/components/admin/admin-activity-list/admin-activity-list.vue
    - resources/css/components/admin/admin-activity-list.scss
  modified:
    - resources/css/app.scss
    - resources/js/islands/admin-island/sections/programs-section.vue
decisions:
  - "ACTIVITY_TYPE_LABELS imported directly from programs.domain (not store return) to avoid reactive overhead in template"
  - "handleDeleteActivity in programs-section uses detailUI.expandedLessonId (not activity.lessonId) since admin-activity-list.vue handles its own delete via detailUI — programs-section handles the dialog confirm only"
  - "Outer wrapper div on each lesson row required so VueDraggable gets one direct child per slot item while activity panel renders outside the drag item"
metrics:
  duration: ~2 min
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 4
---

# Phase 08 Plan 02: Admin Activity List Component Summary

**One-liner:** Activity list accordion with drag-and-drop reorder, type badges, add/delete, and lesson expand/collapse integrated into the programs-section Lessons tab.

## What Was Built

### admin-activity-list.vue
- Receives `programId` and `lessonId` as props
- Renders activity rows with: drag handle (GripVertical), type badge (color-coded per type), title, status label, edit/delete action buttons
- Drag-and-drop reorder via `VueDraggable` with local `ref<Activity[]>` synced via watcher on `detailUI.activitiesForExpandedLesson` (same pattern as lesson reorder in Plan 07)
- "Add Activity" inline form: type `<select>` + title `<input>`, Enter to confirm, Escape to cancel, calls `domain.addActivity`
- Clicking activity row opens activity editor via `activityUI.openEditor` (editing highlight via `--editing` modifier class)
- Delete button calls `detailUI.requestDeleteActivity` (confirmation handled in programs-section.vue)

### admin-activity-list.scss
- Full BEM styles: `AdminActivityList`, `__item`, `__drag-handle`, `__type-badge`, `__title`, `__status`, `__actions`, `__action-btn`, `__add-row`, `__add-btn`, `__type-select`, `__add-title-input`, `__empty`
- Type badge color variants: `--READ` (blue), `--VIDEO` (red), `--SOAP/OIA/DBS/HEAR` (green), `--USER_INPUT` (yellow)
- Actions fade in on item hover via `opacity: 0` / `opacity: 1` transition

### programs-section.vue changes
- Added `ChevronDown`, `ChevronRight` to lucide import
- Added `AdminActivityList` import
- Lesson rows now wrapped in outer `<div>` (required so VueDraggable has one direct child per slot item)
- Expand/collapse chevron button calls `detailUI.toggleExpandLesson` — only one lesson open at a time
- `AdminActivityList` renders conditionally below lesson row when `detailUI.expandedLessonId === lesson.id`
- Added activity delete `AdminConfirmDialog` and `handleDeleteActivity` function

## Verification

- `npm run build` — passes (2 file chunks, SCSS compiles clean)
- `php artisan test --filter ActivitiesAdminTest` — 12/12 pass, 28 assertions

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `resources/js/components/admin/admin-activity-list/admin-activity-list.vue` — created
- [x] `resources/css/components/admin/admin-activity-list.scss` — created (191 lines)
- [x] `resources/css/app.scss` — import added
- [x] `resources/js/islands/admin-island/sections/programs-section.vue` — updated
- [x] Commit bb97275 — Task 1 (SCSS + app.scss)
- [x] Commit d2692bc — Task 2 (Vue component + programs-section integration)

## Self-Check: PASSED
