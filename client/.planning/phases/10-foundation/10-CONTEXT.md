# Phase 10: Foundation - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Register the `/admin/members` route in Vue Router, install `@tanstack/vue-table` and `@tanstack/vue-virtual` npm packages, and add a "Members" navigation item to the admin sidebar. No table, no data loading, no filtering — just the route, packages, and nav link so subsequent phases have a reachable page.

</domain>

<decisions>
## Implementation Decisions

### Sidebar Placement
- Members goes between Groups and Programs: Dashboard, Groups, **Members**, Programs, Profile
- Members is a top-level entity like Groups — it makes sense adjacent to Groups since both deal with people

### Sidebar Icon
- Use `ContactRound` from lucide-vue-next (`Users` is taken by Groups, `UserRound` is taken by Profile)
- Key: `members`, path: `/admin/members`

### Placeholder Page
- MembersSection shows a page title "Members" and an empty content area
- No loading skeleton, no empty state illustration — just the section title matching the pattern of other sections when first created
- The placeholder will be replaced in Phase 12 when the table is wired

### Claude's Discretion
- Exact import ordering in router.ts
- Whether MembersSection is a new file or a stub component
- npm install flags (--save vs --save-dev for TanStack packages — they're runtime deps, use --save)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — user said "all your call" for this infrastructure phase.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `admin-sidebar.vue`: navItems array at line 24 — add Members entry between Groups and Programs
- `router.ts`: Route array with catch-all redirect at bottom — add `/admin/members` route before the catch-all
- Existing section pattern: `dashboard-section.vue`, `groups-section.vue` etc. — follow same structure for `members-section.vue`

### Established Patterns
- Nav items: `{ label: string, icon: LucideIcon, path: string, key: string }`
- Route: `{ path: '/admin/members', component: MembersSection }`
- Section components: Vue SFC in `islands/admin-island/sections/`
- `isActive()` uses `startsWith` prefix matching for nested routes

### Integration Points
- `router.ts`: Add route before catch-all `/:pathMatch(.*)*`
- `admin-sidebar.vue`: Add nav item to `navItems` array between Groups and Programs
- `package.json`: Add `@tanstack/vue-table` and `@tanstack/vue-virtual` to dependencies

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-foundation*
*Context gathered: 2026-03-21*
