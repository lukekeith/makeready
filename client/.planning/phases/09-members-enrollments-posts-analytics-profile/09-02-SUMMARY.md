---
phase: 09-members-enrollments-posts-analytics-profile
plan: "02"
subsystem: admin-enrollments
tags: [enrollments, pinia, vue, proxy-tests, admin, caching]
dependency_graph:
  requires: [09-01-members-tab, 07-programs-lessons]
  provides: [enrollments-domain-store, enrollments-tab-ui-store, enrollments-tab-panel]
  affects: [groups-section.vue]
tech_stack:
  added: []
  patterns: [pinia-composition-store, groupId-caching, bem-scss, unenroll-info-dialog]
key_files:
  created:
    - resources/js/islands/admin-island/stores/domain/enrollments.domain.ts
    - resources/js/islands/admin-island/stores/ui/enrollments-tab.ui.ts
    - resources/css/components/admin/admin-enrollments-tab.scss
  modified:
    - resources/js/islands/admin-island/sections/groups-section.vue
    - resources/css/app.scss
decisions:
  - "Form state (createForm, selectedDays, isSaving, formError) lives in UI store — component only holds parseDays helper and unenrollMessage computed"
  - "startDate converted via new Date(date + 'T00:00:00.000Z').toISOString() to produce midnight UTC ISO string matching Swift EnrollmentActions shape"
  - "enabledDays stored as JSON string on server — parseDays() wraps JSON.parse with catch fallback for display"
  - "requestDelete fetches unenroll info before opening dialog so impact is shown immediately"
  - "loadEnrollments uses loadedGroupIds Set for caching — createEnrollment invalidates cache via delete so next load re-fetches"
metrics:
  duration: "~6 min"
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 5
---

# Phase 09 Plan 02: Enrollments Tab Summary

Enrollments domain/UI Pinia stores with full CRUD + cancel-future, plus complete Enrollments tab panel wired into the group detail view replacing the stub.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Enrollments domain store, UI store, and SCSS | dfcd9c6 | enrollments.domain.ts, enrollments-tab.ui.ts, admin-enrollments-tab.scss, app.scss |
| 2 | Wire Enrollments tab panel into groups-section.vue | 5c1b138 | groups-section.vue |

## What Was Built

**enrollments.domain.ts** — Pinia composition store (ID: `enrollments-domain`) with Enrollment/EnrollmentWithProgram/EnrollmentDetails/LessonSchedule/UnenrollInfo/CreateEnrollmentPayload interfaces. Caches by groupId via `enrollmentsByGroup` Record with `loadedGroupIds` Set. `createEnrollment` pushes to local state and invalidates cache. `deleteEnrollment` filters local state and clears enrollment detail. `cancelFuture` POSTs and reloads detail. `getUnenrollInfo` returns impact data before delete confirmation.

**enrollments-tab.ui.ts** — Pinia composition store (ID: `enrollments-tab-ui`) with all form state (createForm, selectedDays, isSaving, formError) living in the store. Computed `programOptions` filters only published programs from programs domain. `submitCreate()` builds ISO startDate, assembles payload, calls domain.createEnrollment(), handles errors. `requestDelete()` fetches unenroll info before opening confirm dialog.

**admin-enrollments-tab.scss** — Full BEM SCSS for EnrollmentsTab: card list with hover, card header with program name/date-range/days-display, action buttons with danger variant, create form with day checkboxes (accent-color purple), form inputs/selects with focus border.

**groups-section.vue** — Enrollments tab stub replaced with full panel. Create button opens inline form with program selector (from programs domain), date input, day checkboxes (SUN-SAT with Mon-Fri defaults), SMS time, and timezone select. Enrollment cards show program name, date range, and parsed enabled days. Cancel-future (Ban icon) and delete (Trash2 icon) buttons per card. Delete opens AdminConfirmDialog with unenroll impact message.

## Deviations from Plan

None — plan executed exactly as written.

## Success Criteria Verification

- [x] Enrollments tab replaces stub with real enrollment list in group detail
- [x] Each enrollment card shows program name, date range, enabled days (parsed from JSON string)
- [x] Create form has program selector (from programs domain), start date, day checkboxes, SMS time, timezone
- [x] Create submission handled entirely in UI store via submitCreate() (no direct isSaving mutation from component)
- [x] Delete triggers unenroll-info fetch and shows impact in confirm dialog
- [x] Cancel-future button available per enrollment
- [x] Enrollment domain store caches by groupId

## Self-Check: PASSED

Files verified:
- resources/js/islands/admin-island/stores/domain/enrollments.domain.ts: FOUND
- resources/js/islands/admin-island/stores/ui/enrollments-tab.ui.ts: FOUND
- resources/css/components/admin/admin-enrollments-tab.scss: FOUND
- resources/js/islands/admin-island/sections/groups-section.vue: FOUND (modified)
- resources/css/app.scss: FOUND (modified)

Commits verified:
- dfcd9c6: feat(09-02): enrollments domain store, UI store, and SCSS — FOUND
- 5c1b138: feat(09-02): wire Enrollments tab panel into groups-section.vue — FOUND
