# Phase 13: Member Profile Drawer - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a slide-over drawer that opens when a member row is clicked, showing the member's profile info, group memberships with add/remove capabilities, and enrollment progress summary. All member info is read-only. The drawer is the gateway to Phase 14's activity history (a tab or link will be added then).

</domain>

<decisions>
## Implementation Decisions

### Drawer Presentation
- Slide-over from the right edge, full viewport height
- Width: 480px on desktop, full-width on mobile (<640px)
- Dark semi-transparent backdrop overlay (rgba(0,0,0,0.5)) — click outside closes
- Close via: X button (top-right), Escape key, click backdrop
- Drawer slides in/out with a 200ms ease transition
- Table remains visible but dimmed behind the backdrop
- BEM class: `MemberProfileDrawer`, `MemberProfileDrawer__header`, `MemberProfileDrawer__section`, etc.

### Drawer Layout (top to bottom)
1. **Header:** Large avatar (64px), full name, joined date. Close X button top-right.
2. **Contact info section:** Phone, email — displayed as read-only text with copy-to-clipboard on click. No edit controls.
3. **Groups section:** List of group chips showing group name and role badge. Each chip has an X to remove from group. "Add to group" button at the bottom opens a dropdown.
4. **Enrollment progress section:** List of enrollments showing program name, progress bar (% complete), and "X of Y lessons" text. Clicking an enrollment is a stub for Phase 14.

### Group Management UX
- **Add to group:** Button opens a reka-ui Combobox dropdown showing groups the member is NOT already in. Selecting a group immediately calls `POST /api/groups/:id/members` and updates the drawer's group list without closing.
- **Remove from group:** Clicking X on a group chip opens the existing `AdminConfirmDialog` with "Remove [name] from [group]?" confirmation. On confirm, calls `DELETE /api/groups/:id/members/:id` and removes the chip. Drawer stays open.
- **Cache invalidation:** After add/remove, force-reload the affected group's member list in `members.domain` (existing `loadMembers(groupId, true)`) so the per-group members tab and the unified all-members list both update.

### Enrollment Progress Display
- Each enrollment shows: program name (bold), progress bar (horizontal, colored fill), "X of Y lessons completed" text
- Progress bar: purple fill (#6c47ff) on dark track — matches the admin accent color
- Enrollments listed vertically, most recent first (by start date)
- If no enrollments: "No enrollments" muted text
- Enrollment rows are not clickable yet — Phase 14 will add drill-down

### Read-Only Enforcement (MPROF-05)
- No text inputs, no edit buttons, no form elements for name/phone/email
- Contact info displayed as plain text with subtle copy icon
- The only interactive elements are: group add/remove, close button, and future Phase 14 links

### Claude's Discretion
- Exact avatar fallback (initials or silhouette)
- Copy-to-clipboard implementation (native API or library)
- Transition animation easing curve
- Whether enrollment progress fetches on drawer open or lazily
- member-detail.ui store structure

</decisions>

<specifics>
## Specific Ideas

- The drawer should feel like a detail panel, not a full page — the table stays visible behind the overlay so the leader can quickly close and open another member
- Group chips in the drawer should use the same color scheme as group chips in the table rows (visual consistency)
- The "Add to group" dropdown should only show groups the member is NOT already in — prevents duplicate assignment

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `members.domain.ts`: `loadMemberProfile(memberId)` returns `MemberProfile` with `groups[]`, `phoneNumber`, `email`, `firstName`, `lastName`, `profilePicture`
- `members.domain.ts`: `removeMember(groupId, memberId)` — existing remove API call
- `groups.domain.ts`: `groups` ref — full list of leader's groups for the "add to" dropdown
- `AdminConfirmDialog` component — reusable confirmation dialog (used in Groups CRUD)
- reka-ui `ComboboxRoot` — already used in MemberFilterBar, same pattern for group selection
- `all-members.domain.ts`: `loadAll()` — can force-refresh after group changes

### Established Patterns
- Pinia UI stores compute component props from domain data
- `AdminConfirmDialog` is mounted once and controlled via props/emits from section
- Modal/overlay pattern: Vue `Teleport` to body for z-index stacking
- Enrollment data: `/api/member/enrollments` returns `progressPercentage`, `completedLessons`, `totalLessons`

### Integration Points
- `members-section.vue`: `handleRowClick(userId)` stub → open drawer with userId
- `member-detail.ui.ts`: New UI store for drawer state (selectedMemberId, profile data, enrollment data)
- `MemberProfileDrawer.vue`: New component consumed by members-section
- After group add/remove: `membersDomain.loadMembers(groupId, true)` invalidates cache

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-member-profile-drawer*
*Context gathered: 2026-03-21*
