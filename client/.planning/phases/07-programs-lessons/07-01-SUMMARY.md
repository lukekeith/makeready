---
phase: 07-programs-lessons
plan: "01"
subsystem: admin-programs
tags: [pinia, programs, lessons, proxy, tests]
dependency_graph:
  requires: [06-groups-crud]
  provides: [programs.domain.ts, programs-list.ui.ts, program-detail.ui.ts, ProgramsAdminTest]
  affects: [07-02, 07-03]
tech_stack:
  added: []
  patterns: [defineStore composition API, per-test Http::fake, proxy wildcard multi-segment paths]
key_files:
  created:
    - tests/Feature/ProgramsAdminTest.php
    - resources/js/islands/admin-island/stores/domain/programs.domain.ts
    - resources/js/islands/admin-island/stores/ui/programs-list.ui.ts
    - resources/js/islands/admin-island/stores/ui/program-detail.ui.ts
  modified: []
decisions:
  - updateLessonTitle updates local state directly since PATCH /lessons/:id response only returns { success }
  - deleteLesson calls getProgram after delete to re-fetch server-assigned dayNumbers
  - tableRows lesson count: programs.lessons.length > _count.lessons > '--' (priority order)
  - activeTab defaults to 'lessons' in program-detail (unlike group-detail which defaults to 'settings')
  - loadTemplates caches after first load (return early if templates.length > 0)
metrics:
  duration_minutes: 12
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_created: 4
  files_modified: 0
---

# Phase 7 Plan 01: Programs and Lessons - Test Scaffold and Pinia Stores Summary

**One-liner:** PHPUnit proxy tests for all 12 PROG/LSSN endpoints plus Pinia domain + 2 UI stores for programs and lessons management, mirroring groups pattern.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Create ProgramsAdminTest with all proxy test cases | 6253a61 | tests/Feature/ProgramsAdminTest.php |
| 2 | Create programs domain store and both UI stores | d473916 | programs.domain.ts, programs-list.ui.ts, program-detail.ui.ts |

## What Was Built

### Task 1 — ProgramsAdminTest.php

12 PHPUnit tests covering all proxy paths through `AdminApiProxyController`:

- **PROG-01** `test_programs_list_proxy` — GET /admin/api/programs returns programs array
- **PROG-02** `test_create_program_proxy` — POST with name/templateId/days returns program
- **PROG-03** `test_update_program_proxy` — PATCH with name/description, asserts PATCH method
- **PROG-04** `test_program_cover_image_upload_proxy` — Multipart upload via `$this->call()`, asserts coverImageUrl in response
- **PROG-05** `test_publish_program_proxy` — PATCH with isPublished field, asserts field presence in request
- **PROG-06** `test_delete_program_proxy` — DELETE returns `{ success: true }`
- **PROG-07** `test_program_detail_renders` — Catch-all Blade shell returns AdminIsland
- **LSSN-01** `test_program_lessons_list_proxy` — GET /admin/api/programs/:id returns nested lessons
- **LSSN-02** `test_add_lesson_proxy` — POST /admin/api/programs/:id/lessons, validates multi-segment proxy path
- **LSSN-03** `test_update_lesson_title_proxy` — PATCH /admin/api/programs/:id/lessons/:lessonId (3 segments)
- **LSSN-04** `test_delete_lesson_proxy` — DELETE /admin/api/programs/:id/lessons/:lessonId
- **LSSN-05** `test_reorder_lessons_proxy` — POST /admin/api/programs/:id/reorder-lessons with lessonOrder array

All 12 pass. Per-test Http::fake() pattern used throughout to avoid first-match conflicts.

### Task 2 — Pinia Stores

**programs.domain.ts** (`programs-domain` store):
- Interfaces: `Program`, `Lesson`, `Template`, `CreateProgramPayload`, `UpdateProgramPayload`
- 12 methods mirroring groups pattern: `loadPrograms`, `loadTemplates` (cached), `getProgram`, `createProgram`, `updateProgram`, `deleteProgram`, `uploadCoverImage`, `addLesson`, `updateLessonTitle`, `deleteLesson`, `reorderLessons`
- `updateLessonTitle` mutates local state directly (API response has no lesson object)
- `deleteLesson` re-fetches via `getProgram()` after delete to get server-reassigned dayNumbers

**programs-list.ui.ts** (`programs-list-ui` store):
- Computeds: `tableColumns` (`['Name', 'Lessons', 'Status']`), `tableRows` (lesson count with 3-way fallback), `editingProgram`, `confirmDeleteProgram`, `templateOptions`, `isEditing`
- Methods: `openCreateForm`, `openEditForm`, `closeForm`, `requestDelete`, `cancelDelete`, `navigateToDetail`

**program-detail.ui.ts** (`program-detail-ui` store):
- Refs: `activeTab` (default: `'lessons'`), `editingLessonId`, `confirmDeleteLessonId`, `isUploadingCover`, `isSavingMetadata`, `metadataError`
- Computeds: `currentProgram`, `pageTitle`, `lessons`, `editingLesson`, `confirmDeleteLesson`, `metadataFormValues`, `metadataFields`
- Methods: `openEditLesson`, `closeEditLesson`, `requestDeleteLesson`, `cancelDeleteLesson`

## Verification

- `php artisan test tests/Feature/ProgramsAdminTest.php` — 12 passed (32 assertions)
- `npm run build` — TypeScript compiles cleanly, 2448 modules
- `php artisan test` — 1 incomplete, 194 passed (no regressions)

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] tests/Feature/ProgramsAdminTest.php — created, 521 lines
- [x] resources/js/islands/admin-island/stores/domain/programs.domain.ts — created
- [x] resources/js/islands/admin-island/stores/ui/programs-list.ui.ts — created
- [x] resources/js/islands/admin-island/stores/ui/program-detail.ui.ts — created
- [x] Commit 6253a61 exists — Task 1
- [x] Commit d473916 exists — Task 2

## Self-Check: PASSED
