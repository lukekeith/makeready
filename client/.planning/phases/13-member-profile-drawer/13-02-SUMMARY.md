---
phase: 13-member-profile-drawer
plan: "02"
subsystem: admin-island
tags: [pinia, vue, drawer, member-profile, group-management, combobox, confirm-dialog]
dependency_graph:
  requires:
    - member-detail.ui.ts (Plan 01 foundation)
    - members.domain.ts (removeMember, loadMembers)
    - all-members.domain.ts (loadAll for cache invalidation)
    - groups.domain.ts (groups ref for availableGroups computed)
    - AdminConfirmDialog (existing component)
  provides:
    - addToGroup action with full cache invalidation
    - removeFromGroup action with membership ID lookup and cache invalidation
    - availableGroups computed (excludes groups member already belongs to)
    - MemberProfileDrawer fully wired — row click opens drawer, group add/remove functional
  affects:
    - resources/js/islands/admin-island/sections/members-section.vue (drawer mounted, row click wired)
    - resources/css/components/admin/member-profile-drawer.scss (group management styles)
tech_stack:
  added: []
  patterns:
    - reka-ui ComboboxRoot with controlled model-value for group add
    - AdminConfirmDialog for destructive action confirmation
    - Cache invalidation via membersDomain.loadMembers(groupId, true) + allMembersDomain.loadAll()
key_files:
  created: []
  modified:
    - resources/js/islands/admin-island/stores/ui/member-detail.ui.ts
    - resources/js/components/admin/member-profile-drawer/member-profile-drawer.vue
    - resources/js/islands/admin-island/sections/members-section.vue
    - resources/css/components/admin/member-profile-drawer.scss
decisions:
  - removeFromGroup looks up membership ID from membersDomain.membersByGroup[groupId] cache; if not cached, loads group first then finds ID — avoids passing userId to removeMember which expects a membership ID
  - availableGroups computed uses Set of current member's group IDs to filter groupsDomain.groups — O(1) lookup per group
  - addGroupValue ref reset to undefined after successful add so combobox input clears
metrics:
  duration: "~2 min"
  completed_date: "2026-03-21"
  tasks_completed: 1
  files_modified: 4
status: awaiting-checkpoint
---

# Phase 13 Plan 02: Group Management Wiring — Summary

**One-liner:** Group add/remove actions with cache invalidation wired into member-profile-drawer via reka-ui Combobox and AdminConfirmDialog, row click in members-section opens drawer.

## What Was Built

### Task 1: Group Management Actions + Drawer Wiring

**member-detail.ui.ts updates:**
- Imported `useGroupsDomain` and `useAllMembersDomain`
- Added `isAddingToGroup` and `isRemovingFromGroup` loading flags
- Added `availableGroups` computed — filters `groupsDomain.groups` excluding groups the member already belongs to (by Set lookup on profile.groups[].id)
- Added `addToGroup(groupId)` — POSTs to `/admin/api/groups/:id/members`, then refreshes: `membersDomain.loadMembers(groupId, true)`, `loadProfile()`, `allMembersDomain.loadAll()`
- Added `removeFromGroup(groupId)` — looks up membership ID from `membersDomain.membersByGroup[groupId]`, handles uncached case by loading first, calls `membersDomain.removeMember(groupId, membershipId)`, then refreshes same three sources

**member-profile-drawer.vue updates:**
- Added X remove button to each group chip (disabled during `isRemovingFromGroup`)
- Added reka-ui `ComboboxRoot` + `ComboboxAnchor` + `ComboboxInput` + `ComboboxContent` + `ComboboxItem` + `ComboboxEmpty` for "Add to group" — only shown when `store.availableGroups.length > 0`
- Added local `showRemoveConfirm`, `removeTarget`, `addGroupValue` refs
- Added `confirmRemoveGroup`, `handleConfirmRemove`, `handleCancelRemove`, `handleAddGroup` functions
- Mounted `AdminConfirmDialog` inside the panel for remove confirmation

**members-section.vue updates:**
- Imported `useMemberDetailUI` and `MemberProfileDrawer`
- Replaced `handleRowClick` stub with `memberDetailUI.openDrawer(userId)`
- Mounted `<MemberProfileDrawer />` at end of template (Teleports to body)

**member-profile-drawer.scss additions:**
- `.MemberProfileDrawer__group-remove` — no-bg button with hover red state
- `.MemberProfileDrawer__add-group` — margin-top container
- `.MemberProfileDrawer__add-group-input` — full-width input with focus ring
- `.MemberProfileDrawer__add-group-content` — absolute dropdown with shadow
- `.MemberProfileDrawer__add-group-item` — highlighted state on hover/data-highlighted
- `.MemberProfileDrawer__add-group-empty` — muted empty message

## Verification

- `npm run build` — passes (✓ 2483 modules, built in 3.51s)
- `npx vue-tsc --noEmit` — 2 pre-existing errors in unrelated files (members-list.ui.ts ColumnDef types, programs-list.ui.ts lesson property); 0 new errors introduced

## Deviations from Plan

**1. [Rule 2 - Missing Critical Functionality] Added ComboboxAnchor wrapper**

- **Found during:** Task 1 — reka-ui Combobox requires an Anchor element to position the dropdown content
- **Fix:** Added `ComboboxAnchor` wrapper around `ComboboxInput` so the dropdown portal positions correctly relative to the input
- **Files modified:** member-profile-drawer.vue
- **Commit:** ad504fa

**2. [Out of scope] Pre-existing TypeScript errors in unrelated files**

- `members-list.ui.ts` — ColumnDef generic type mismatch (TanStack Table version issue)
- `programs-list.ui.ts` — `lessons` property missing from type
- Both errors confirmed present before Plan 02 changes (verified via `git stash`)
- Logged to deferred items — not introduced by this plan

## Checkpoint Status

Task 2 is `type="checkpoint:human-verify"` — awaiting human verification of the complete drawer workflow.

## Self-Check

- [x] `resources/js/islands/admin-island/stores/ui/member-detail.ui.ts` — modified
- [x] `resources/js/components/admin/member-profile-drawer/member-profile-drawer.vue` — modified
- [x] `resources/js/islands/admin-island/sections/members-section.vue` — modified
- [x] `resources/css/components/admin/member-profile-drawer.scss` — modified
- [x] Commit ad504fa (Task 1) — verified

## Self-Check: PASSED
