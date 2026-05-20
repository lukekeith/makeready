---
phase: 13-member-profile-drawer
plan: "01"
subsystem: admin-island
tags: [pinia, vue, drawer, member-profile, enrollment-progress]
dependency_graph:
  requires:
    - members.domain.ts (loadMemberProfile)
    - all-members.domain.ts (UnifiedMember type reference)
  provides:
    - useMemberDetailUI store (openDrawer, closeDrawer, profile, enrollmentProgress)
    - MemberProfileDrawer component (slide-over drawer)
  affects:
    - resources/css/app.scss (new @use import)
tech_stack:
  added: []
  patterns:
    - Pinia composable store with computed display props
    - Vue Teleport + Transition for slide-over drawer
    - BEM SCSS with no Tailwind
key_files:
  created:
    - resources/js/islands/admin-island/stores/ui/member-detail.ui.ts
    - resources/js/components/admin/member-profile-drawer/member-profile-drawer.vue
    - resources/css/components/admin/member-profile-drawer.scss
  modified:
    - resources/css/app.scss
decisions:
  - Enrollment progress endpoint gracefully handles 404/errors — sets enrollmentProgress to [] without surfacing error UI (not all members have enrollments)
  - closeDrawer resets state with 200ms delay to allow slide-out transition before data clears
  - Store imports useMembersDomain directly — follows established Pinia store composition pattern
metrics:
  duration: "~2 min"
  completed_date: "2026-03-21"
  tasks_completed: 2
  files_modified: 4
---

# Phase 13 Plan 01: Member Profile Drawer — Foundation Summary

**One-liner:** Slide-over member profile drawer with Pinia UI store managing profile/enrollment loading, read-only contact display, group chips, and progress bars via Vue Teleport.

## What Was Built

### Task 1: member-detail.ui Pinia Store

Created `useMemberDetailUI` store managing the complete drawer lifecycle:

- **State:** `isOpen`, `selectedMemberId`, `profile` (MemberProfile), `enrollmentProgress`, loading flags, error
- **Actions:** `openDrawer(userId)` triggers parallel profile + enrollment fetches; `closeDrawer()` hides drawer immediately then clears state after 200ms transition delay
- **Computed:** `displayName` (firstName + lastName with Unknown fallback), `avatarUrl` (profilePicture or googlePicture), `initials` (first letter of each name), `joinedDate` (earliest group joinedAt formatted as "Joined Mar 15, 2026"), `groupsWithMeta` (pass-through for Plan 02 add/remove)
- Enrollment endpoint (`GET /admin/api/members/:id/enrollments`) failures silently set `enrollmentProgress = []`

### Task 2: MemberProfileDrawer Vue Component + SCSS

Created `member-profile-drawer.vue` SFC:
- `<Teleport to="body">` with `<Transition name="drawer">` — 200ms ease slide animation
- **Backdrop:** Semi-transparent overlay, click closes drawer
- **Header:** 64px avatar (image or initials placeholder with purple background), name, joined date, X button
- **Contact section:** Phone and email as read-only text with click-to-copy (navigator.clipboard) and hover copy icon
- **Groups section:** BEM chips showing group name + uppercase role badge; Plan 02 wires add/remove
- **Enrollments section:** Loading state, "No enrollments" empty state, or list of program name + progress bar (purple fill) + "X of Y lessons" text
- Escape key closes drawer via `window.addEventListener('keydown')`

Created `member-profile-drawer.scss` — full BEM block, mobile-responsive (full-width < 640px), no Tailwind.

Updated `resources/css/app.scss` — added `@use 'components/admin/member-profile-drawer'` after admin-dashboard.

## Verification

- `npx vue-tsc --noEmit` — passes with no errors
- `npm run build` — passes (✓ built in 3.08s)

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `resources/js/islands/admin-island/stores/ui/member-detail.ui.ts` — created
- [x] `resources/js/components/admin/member-profile-drawer/member-profile-drawer.vue` — created
- [x] `resources/css/components/admin/member-profile-drawer.scss` — created
- [x] `resources/css/app.scss` — updated with @use import
- [x] Commit 265ec6f (Task 1) — verified
- [x] Commit 41ef530 (Task 2) — verified

## Self-Check: PASSED
