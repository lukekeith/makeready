---
phase: 07-programs-lessons
plan: "03"
subsystem: admin-programs-detail
tags: [vue, pinia, drag-and-drop, tabs, lessons-management, programs]
dependency_graph:
  requires: [07-02]
  provides: [program-detail-view, lessons-crud, drag-reorder, publish-toggle, cover-image-upload]
  affects: [programs-section.vue, admin-lesson-list.scss]
tech_stack:
  added: [vue-draggable-plus]
  patterns: [local-writable-ref-sync, inline-edit, tabbed-detail-view, reka-ui-tabs]
key_files:
  created:
    - resources/css/components/admin/admin-lesson-list.scss
  modified:
    - resources/js/islands/admin-island/sections/programs-section.vue
    - resources/css/app.scss
    - package.json
decisions:
  - vue-draggable-plus v-model requires local writable ref (not store computed) — synced via watcher
  - Lesson title editing is inline in the list row (Enter saves, Escape cancels), not a modal
  - @end fires after drag completes — sends full ordered ID array to reorderLessons API
  - AdminSection__action-btn--secondary added as scoped style in programs-section.vue for unpublish state
metrics:
  duration: "~15 min"
  completed: "2026-03-20"
  tasks_completed: 2
  files_changed: 4
---

# Phase 07 Plan 03: Program Detail View Summary

Program detail view built with tabbed interface, drag-and-drop lesson reorder using vue-draggable-plus, inline lesson title editing, publish toggle, and cover image upload.

## What Was Built

### Task 1: Install vue-draggable-plus and create admin-lesson-list.scss
**Commit:** 001fcaa

- Installed vue-draggable-plus ^0.6.1
- Created `resources/css/components/admin/admin-lesson-list.scss` with full BEM styles: lesson items, drag handle, inline edit input, add button, empty state, dragging state
- Added `@use 'components/admin/admin-lesson-list'` import to `resources/css/app.scss`

### Task 2: Extend programs-section.vue with detail view, tabs, lessons management, and publish toggle
**Commit:** 41a8062

Extended `programs-section.vue` (from Plan 02) to replace the detail placeholder with a complete program detail view:

- **TabsRoot/TabsList/TabsTrigger/TabsContent** from reka-ui — three tabs: Lessons (default), Enrollments (stub), Details
- **VueDraggable** from vue-draggable-plus — bound to `localLessons` (local writable ref synced from `detailUI.lessons` computed via watcher). `@end` fires `handleReorder()` which sends the ordered ID array to `domain.reorderLessons()`
- **Inline lesson title editing** — `inlineEditId` ref tracks which row is in edit mode; Enter saves, Escape cancels; calls `domain.updateLessonTitle()`
- **Lesson delete** — `AdminConfirmDialog` with `detailUI.requestDeleteLesson()` / `cancelDeleteLesson()`; `domain.deleteLesson()` re-fetches program after delete so dayNumbers update
- **Add Lesson** button calls `domain.addLesson()` and watcher syncs localLessons automatically
- **Publish toggle** button changes text (Publish/Unpublish) based on `currentProgram.isPublished`; calls `domain.updateProgram()` with toggled boolean
- **AdminImageUpload** for cover image — `detailUI.isUploadingCover` tracks state; calls `domain.uploadCoverImage()`
- **Metadata tab** with inline `AdminForm` (`:inline="true"` `:hide-cancel-button="true"`) for name/description
- **Back button** with ArrowLeft icon navigates to `/admin/programs`
- **Enrollments tab** stubbed for Phase 9

## Verification

- Build: passes (✓ built in 2.50s, 2453 modules transformed)
- ProgramsAdminTest: 12 passed (32 assertions)
- Full suite: 194 passed, 1 incomplete (pre-existing), 0 failures

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check

### Files Created/Modified
- `resources/css/components/admin/admin-lesson-list.scss` — FOUND
- `resources/js/islands/admin-island/sections/programs-section.vue` — FOUND
- `resources/css/app.scss` — FOUND (admin-lesson-list import added)
- `package.json` — FOUND (vue-draggable-plus added)

### Commits
- `001fcaa` — chore(07-03): install vue-draggable-plus and create admin-lesson-list.scss
- `41a8062` — feat(07-03): program detail view with tabs, lessons management, and publish toggle

## Self-Check: PASSED
