---
phase: 08-activity-editor
plan: "03"
subsystem: admin-activity-list
tags: [admin, activity-editor, vue, read-blocks, source-references, help-panel, drag-and-drop]
dependency_graph:
  requires: [08-02]
  provides: [activity-editor-panel, read-blocks-management, source-reference-add, help-panel, reset-activity]
  affects: [admin-activity-list.vue, admin-activity-list.scss]
tech_stack:
  added: []
  patterns: [type-gated conditional rendering, inline form with watcher sync, nested VueDraggable for read block reorder]
key_files:
  created: []
  modified:
    - resources/js/components/admin/admin-activity-list/admin-activity-list.vue
    - resources/css/components/admin/admin-activity-list.scss
decisions:
  - "addReadBlock called with empty string (not undefined) for optional title/content because domain function signature is string not string|undefined"
  - "activityUI.isSaving and saveError written directly from component (valid for Pinia refs) — domain.updateActivity already handles status: COMPLETE internally"
  - "Source reference delete not implemented per MVP scope — reset clears all content including references"
  - "localReadBlocks ref synced from currentActivity.readBlocks via watcher to support nested VueDraggable reorder without breaking outer VueDraggable"
metrics:
  duration: ~4 min
  completed_date: "2026-03-20"
  tasks_completed: 1
  files_changed: 2
---

# Phase 08 Plan 03: Activity Editor Panel Summary

**One-liner:** Type-gated inline editor panel with READ blocks management, source reference add, collapsible help panel, and reset — fully wired to domain store functions.

## What Was Built

### admin-activity-list.vue (extended)

**Editor panel** renders inline below each activity row when `activityUI.editingActivityId === activity.id`. A `watch` on `activityUI.currentActivity` populates all form state when a different activity is opened.

**Type-gated fields:**
- All types: title input
- READ: `readContent` textarea (plain text, NOT rich text) + read blocks section
- VIDEO: `videoUrl` + `videoId` inputs
- SOAP/OIA/DBS/HEAR: `passageReference` input
- USER_INPUT: title only

**Read blocks section** (READ type only):
- Lists existing blocks with drag handle, title, content preview
- Inline edit: clicking pencil replaces block display with textarea + save/cancel buttons; Escape cancels
- Delete block calls `domain.deleteReadBlock`
- Drag-and-drop reorder via nested `VueDraggable` with `localReadBlocks` ref synced from `activityUI.currentActivity.readBlocks` via watcher; `handleReorderBlocks` calls `domain.reorderReadBlocks` on `@end`
- Add block form: optional title + content textarea, calls `domain.addReadBlock` with `orderNumber = readBlocks.length + 1`

**Source references section** (all types):
- Lists existing references (passageReference + bookName/chapter/verse details)
- Add form: passageReference, bookName, bookNumber, chapterStart, verseStart, verseEnd
- Calls `domain.addSourceReference` — no delete (reset to clear)

**Help panel** (all types, collapsible):
- Toggle button with ChevronDown/ChevronRight icon
- When expanded: enable checkbox, and when enabled: helpTitle input, helpDescription textarea, helpIcon input

**Save / Reset:**
- Save calls `domain.updateActivity` with type-appropriate payload — domain store unconditionally appends `status: 'COMPLETE'`
- Reset button shows browser confirm then calls `domain.resetActivity`
- Inline save error display from `activityUI.saveError`
- isSaving disables the save button with "Saving..." text

### admin-activity-list.scss (extended)

Added BEM blocks: `__editor`, `__field`, `__field-label`, `__field-input`, `__field-textarea`, `__blocks-section`, `__refs-section`, `__blocks-header`, `__block-item`, `__block-drag`, `__block-content`, `__block-title`, `__block-text`, `__block-actions`, `__add-block-form`, `__refs-list`, `__ref-item`, `__ref-detail`, `__help-section`, `__help-toggle`, `__help-fields`, `__editor-actions`, `__save-btn`, `__reset-btn`, `__error`

## Verification

- `npm run build` — passes (2.35s, no TypeScript or SCSS errors)
- `php artisan test --filter ActivitiesAdminTest` — 12/12 pass, 28 assertions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correctness] addReadBlock called with empty string instead of undefined**
- **Found during:** Task 1
- **Issue:** `domain.addReadBlock` signature is `(activityId, programId, lessonId, title: string, content: string, orderNumber, isLocked)` — plan passed `newBlockTitle.value || undefined` which TypeScript would reject
- **Fix:** Changed to `newBlockTitle.value || ''` and `newBlockContent.value || ''`
- **Files modified:** `admin-activity-list.vue`
- **Commit:** af9ed71

## Self-Check

- [x] `resources/js/components/admin/admin-activity-list/admin-activity-list.vue` — modified (295 lines → 340+ lines)
- [x] `resources/css/components/admin/admin-activity-list.scss` — modified (191 lines → 400+ lines)
- [x] Commit af9ed71 — Task 1 (editor panel + SCSS)

## Self-Check: PASSED
