# Phase 5: Admin Shell - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a fully operational admin panel shell at /admin — authenticated, client-side-navigable via Vue Router, with a sidebar, avatar menu, and member/admin experience toggle. No entity CRUD in this phase — just the infrastructure that all subsequent phases build on.

</domain>

<decisions>
## Implementation Decisions

### Sidebar Navigation
- Fixed left sidebar, icon-only by default, expandable on hover/click to show labels
- Sections: Dashboard, Groups, Programs, Profile
- Active item indicated by highlight background (subtle background color change)
- Avatar at bottom of sidebar, opens menu on click

### Admin Layout
- Sidebar + content area layout (no header bar)
- Same dark theme as member experience (dark backgrounds, white text, purple accents)
- Content area has max-width and is centered (similar to member experience's constrained containers)
- Each section has a page title header with action buttons on the right (e.g., "Groups" title + "Create Group" button)

### Experience Toggle
- "Member Experience" / "Group Leader Admin" link appears at TOP of avatar menu
- Full page navigation when switching (clicking navigates to /admin or /member/home)
- "Group Leader Admin" link only shows for leaders — determined by having a linked Google account (call `/auth/me/linked-user` to check)
- "Member Experience" link always shows on admin avatar menu (you're already authenticated as a leader)

### Section Routing
- Path-based URLs: /admin, /admin/groups, /admin/groups/:id, /admin/programs, /admin/programs/:id, /admin/profile
- Client-side navigation via Vue Router (history mode) — sidebar clicks don't cause full page reloads
- Deep links work — Laravel catch-all route for /admin/* serves the admin shell Blade template, Vue Router picks up the path
- Single AdminIsland Vue app with shared Pinia state across all sections
- Skeleton loaders while content loads from API (placeholder shapes matching content layout)

### Claude's Discretion
- Exact sidebar width (collapsed and expanded)
- Skeleton loader shapes and animation
- Transition animations for sidebar expand/collapse
- Exact content area max-width value
- CSRF configuration approach (meta tag or cookie)

</decisions>

<specifics>
## Specific Ideas

- Leader detection: Leaders have linked Google accounts. Check via `/auth/me/linked-user` endpoint (same as React SessionStore). If linked user exists, show "Group Leader Admin" in member avatar menu.
- The admin sidebar should feel like a natural extension of the member experience — same dark palette, same font family, same component patterns (BEM/SCSS).
- Avatar menu in admin should show the same member info (name, avatar) as the member experience, just with "Member Experience" link instead of "Group Leader Admin".

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `navigation-island.vue`: Has avatar menu with modal stack, teleported overlays, logout form. The admin sidebar is a different component but the avatar menu pattern can be reused.
- `modal.store.ts`: Pinia composition store for modal management. Can be shared in the single AdminIsland.
- `cva()` PHP helper: For Blade component BEM class generation.
- `Loading` Blade component: Has spinner variant. Skeleton loaders will be new admin-specific components.
- `Avatar` Blade component: Background-image based, size prop. Reusable in admin sidebar.

### Established Patterns
- Vue island mounting: `data-vue="ComponentName"` + `data-props`. Admin will be a single `data-vue="AdminIsland"` that owns all admin state.
- Pinia stores: Composition API with `defineStore` + `ref`/`computed`. New admin domain stores follow this pattern.
- SCSS: `@use` module system, BEM naming, imported in `app.scss`. Admin SCSS follows same pattern.
- CSRF: Meta tag `<meta name="csrf-token">` already in layouts. Axios needs to read this.

### Integration Points
- `routes/web.php`: Add catch-all `/admin/{any?}` route that serves admin Blade template
- `app.js`: Register `AdminIsland` in `componentRegistry`
- `app.scss`: Import new admin SCSS files
- `CheckMemberSession` middleware: Already on admin route, provides `$member` and `$memberGroups`
- `ApiService.php`: Needs `delete()` method added for CRUD operations. May need catch-all proxy route for admin API calls.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-admin-shell*
*Context gathered: 2026-03-19*
