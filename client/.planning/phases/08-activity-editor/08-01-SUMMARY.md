---
phase: 08-activity-editor
plan: "01"
subsystem: admin-activity-data-layer
tags: [pinia, typescript, phpunit, activity-crud, domain-store]
dependency_graph:
  requires: [07-programs-lessons]
  provides: [activity-crud-domain, activity-detail-ui, activity-test-scaffold]
  affects: [programs.domain.ts, program-detail.ui.ts]
tech_stack:
  added: []
  patterns: [pinia-defineStore, vue-computed, phpunit-http-fake-per-test]
key_files:
  created:
    - tests/Feature/ActivitiesAdminTest.php
    - resources/js/islands/admin-island/stores/ui/activity-detail.ui.ts
  modified:
    - resources/js/islands/admin-island/stores/domain/programs.domain.ts
    - resources/js/islands/admin-island/stores/ui/program-detail.ui.ts
decisions:
  - "updateActivity always includes status: COMPLETE unconditionally — required by API to mark activity as authored (confirmed from ProgramActions.swift)"
  - "updateReadBlock manually updates local state since PATCH read-blocks/:id returns only { success: true } (no activity in response)"
  - "replaceActivity helper centralizes nested activity replacement logic used by 5+ functions"
  - "ACTIVITY_TYPE_LABELS exported from domain store (not UI store) for shared use across components"
metrics:
  duration: "~3 minutes"
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 4
---

# Phase 8 Plan 01: Activity Data Layer and Test Scaffold Summary

**One-liner:** Activity CRUD data layer with 10 domain store functions, type-gated UI store, and 12 PHPUnit proxy tests covering all 9 ACTV requirements.

## What Was Built

### Task 1: ActivitiesAdminTest.php (12 tests)

Created `tests/Feature/ActivitiesAdminTest.php` following the established `ProgramsAdminTest.php` per-test `Http::fake()` pattern. 12 tests cover all 9 ACTV requirements — ACTV-06 split into 4 separate tests for read block CRUD to avoid Http::fake URL matching conflicts.

All 12 tests pass immediately without any fix cycles.

### Task 2: Domain Store Extension + New UI Stores

**programs.domain.ts extended with:**
- 4 new TypeScript interfaces: `Activity`, `ActivityReadBlock`, `ActivitySourceReference`, `UpdateActivityPayload`
- `Lesson` interface extended with `activities?: Activity[]`
- `ACTIVITY_TYPE_LABELS` constant (exported)
- `replaceActivity()` helper function for nested state mutation
- 10 new async CRUD functions: `addActivity`, `updateActivity`, `deleteActivity`, `reorderActivities`, `resetActivity`, `addReadBlock`, `updateReadBlock`, `deleteReadBlock`, `reorderReadBlocks`, `addSourceReference`

**program-detail.ui.ts extended with:**
- `expandedLessonId` ref — tracks which lesson's activity panel is open (accordion pattern)
- `confirmDeleteActivityId` ref
- `activitiesForExpandedLesson` computed — returns activities for the currently expanded lesson
- `confirmDeleteActivity` computed — resolves activity object from nested lesson structure
- `toggleExpandLesson`, `requestDeleteActivity`, `cancelDeleteActivity` methods

**activity-detail.ui.ts created (new file):**
- Type-gated boolean computeds: `isReadType`, `isVideoType`, `isStudyMethodType`, `isUserInputType`
- Per-activity editing state: `editingActivityId`, `editingProgramId`, `editingLessonId`
- `isSaving`, `saveError` state for async save feedback
- `openEditor(activityId, programId, lessonId)` and `closeEditor()` methods

## Verification Results

- `php artisan test --filter ActivitiesAdminTest` — 12 passed (28 assertions)
- `npm run build` — passes (TypeScript compiles, no import errors)
- `php artisan test` — 206 passed, 1 incomplete (pre-existing), 0 failures

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `tests/Feature/ActivitiesAdminTest.php` — FOUND (378 lines)
- `resources/js/islands/admin-island/stores/domain/programs.domain.ts` — FOUND (extended with 10 new functions)
- `resources/js/islands/admin-island/stores/ui/program-detail.ui.ts` — FOUND (extended with expandedLessonId + activity state)
- `resources/js/islands/admin-island/stores/ui/activity-detail.ui.ts` — FOUND (new file)
- Commit `5d86c15` — test scaffold
- Commit `c69be46` — domain + UI store extensions
