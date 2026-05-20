---
phase: 09-members-enrollments-posts-analytics-profile
plan: "03"
subsystem: admin-enrollments-schedule
tags: [enrollments, schedule, crud, inline-edit, pinia, vue, admin]
dependency_graph:
  requires: [09-02-enrollments-tab]
  provides: [enrollment-detail-expansion, schedule-crud-ui]
  affects: [groups-section.vue, enrollments.domain.ts, enrollments-tab.ui.ts]
tech_stack:
  added: []
  patterns: [inline-edit, expand-collapse, confirm-dialog, local-state-update]
key_files:
  created: []
  modified:
    - resources/js/islands/admin-island/stores/domain/enrollments.domain.ts
    - resources/js/islands/admin-island/stores/ui/enrollments-tab.ui.ts
    - resources/js/islands/admin-island/sections/groups-section.vue
    - resources/css/components/admin/admin-enrollments-tab.scss
decisions:
  - "updateScheduleTitle updates local state directly since PATCH schedules/:id returns only { success } — same pattern as Phase 7 updateLessonTitle"
  - "addSchedule reloads full enrollment detail after POST to get server-assigned date — local state update insufficient for new schedule"
  - "deleteSchedule filters local lessonSchedules array directly without reload"
  - "Schedule editing state (editingScheduleId, editingTitle, confirmDeleteScheduleId) lives in UI store — component stays thin"
  - "Expand/collapse uses existing expandEnrollment/collapseEnrollment methods — card click toggles between the two"
  - "EnrollmentsTab__card--expanded modifier removes bottom radius when detail panel is open"
metrics:
  duration: "~4 min"
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 4
---

# Phase 09 Plan 03: Enrollment Detail Expansion with Schedule CRUD Summary

Expandable enrollment detail panel with lesson schedule list and full inline CRUD (view, edit title, add, delete) wired into the admin Enrollments tab.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add schedule CRUD methods to enrollments domain and UI store | fae127b | enrollments.domain.ts, enrollments-tab.ui.ts |
| 2 | Wire enrollment detail expansion with schedule list into groups-section.vue | 61dff06 | groups-section.vue, admin-enrollments-tab.scss |

## What Was Built

**enrollments.domain.ts** — Three new async methods added: `updateScheduleTitle` PATCHes `/admin/api/enrollments/:id/schedules/:sid` and updates local state directly (title field on matching schedule); `addSchedule` POSTs to create and reloads the full enrollment detail to get server-assigned date; `deleteSchedule` DELETEs and filters the local `lessonSchedules` array. All three added to the store's return object.

**enrollments-tab.ui.ts** — Three new refs: `editingScheduleId`, `editingTitle`, `confirmDeleteScheduleId`. Seven new methods: `startEditSchedule` sets editing refs; `cancelEditSchedule` resets them; `saveScheduleTitle` calls domain, resets editing state; `addSchedule` delegates to domain; `requestDeleteSchedule` sets confirm ref; `cancelDeleteSchedule` resets it; `confirmDeleteSchedule` calls domain and resets. All exposed in return.

**groups-section.vue** — Imports extended with `Pencil`, `ChevronDown`, `ChevronUp` from lucide-vue-next. Enrollment list refactored from `div v-for` to `template v-for` so detail panel renders as sibling (not child) of card. Card click toggles expand/collapse. Card receives `--expanded` modifier class when open. Detail panel renders below each card conditionally showing `enrollmentsUI.enrollmentDetail.lessonSchedules`. Each row: date (left), title (click to inline edit with input+save+cancel, or pencil icon), day number, delete button. Add Lesson button in panel header. Second `AdminConfirmDialog` added for schedule deletion.

**admin-enrollments-tab.scss** — Added `__card--expanded` (removes bottom radius), `__detail` (attached panel with no top border), `__detail-header`, `__detail-title`, `__schedule-list`, `__schedule-row` (hover highlight), `__schedule-date`, `__schedule-title`, `__schedule-edit`, `__schedule-day` BEM classes.

## Deviations from Plan

None — plan executed exactly as written.

## Success Criteria Verification

- [x] Clicking an enrollment card expands to show the lesson schedule
- [x] Each schedule row shows date, title, and day number
- [x] Clicking a title enables inline editing with save/cancel
- [x] Add Lesson button creates a new scheduled lesson via POST
- [x] Delete button with confirmation removes a scheduled lesson
- [x] Collapsing and re-expanding preserves loaded detail data (domain caches by enrollmentId)

## Self-Check: PASSED

Files verified:
- resources/js/islands/admin-island/stores/domain/enrollments.domain.ts: FOUND
- resources/js/islands/admin-island/stores/ui/enrollments-tab.ui.ts: FOUND
- resources/js/islands/admin-island/sections/groups-section.vue: FOUND
- resources/css/components/admin/admin-enrollments-tab.scss: FOUND

Commits verified:
- fae127b: feat(09-03): add schedule CRUD methods to enrollments domain and UI store — FOUND
- 61dff06: feat(09-03): wire enrollment detail expansion with schedule list CRUD — FOUND
