# Phase 12: Virtualized Member Table + Tag Filters - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the virtualized member table (TanStack Table + Virtual) and the tag-based filter bar. Leaders see all members in a performant scrollable list and can narrow by name, group, lesson status, or activity type using filter chips. Row click opens the member profile drawer (Phase 13). This phase delivers the visible table and filter UI — data comes from Phase 11's `all-members.domain`.

</domain>

<decisions>
## Implementation Decisions

### Row Layout
- Fixed-height rows (56px) — required for TanStack Virtual `estimateSize`
- Each row: avatar (32px circle), member name (primary text), group chips (small colored pills with group names), last active date (muted secondary text, right-aligned)
- Row is clickable — click opens member profile drawer (Phase 13 wires this; Phase 12 emits the event)
- Hover state: subtle background highlight matching existing AdminTable row hover
- No action buttons per row (edit/delete don't apply — leader can't edit member profiles, removal is in the profile drawer)

### Filter Interaction
- Filter bar sits above the table, below the page title
- Search input with placeholder "Search members..." — typing and pressing Enter (or clicking Add) creates a name filter tag
- Dropdown suggestions for group, status, and activity type filters — use reka-ui Combobox for typeahead suggestions
- Each filter renders as a chip/tag below the search input (reka-ui TagsInput pattern)
- Chips show category + value: "Group: Bible Study", "Status: Completed", "Type: SOAP"
- Individual chip removal via X button
- "Clear all" button appears when any filters are active
- Filters are AND (intersection) — all active chips must match for a member to appear
- All filtering is client-side on the loaded `allMembers` array
- Filter state lives in `members-list.ui` Pinia store (never in TanStack column filter model)

### Empty/Loading States
- **Loading:** Skeleton rows (8 placeholder rows with shimmer animation) while `allMembers` is loading. Progressive: skeleton rows are replaced by real rows as they arrive.
- **No results (filters active):** "No members match your filters" with a "Clear filters" link
- **No members at all (empty org):** "No members yet" with a brief description — no illustration needed
- **Failed groups:** Yellow warning banner at the top of the table: "Could not load members from: [group names]. Other members are shown below." Dismissible with X.

### Table Component Architecture
- New `AdminVirtualTable` component — NOT extending the existing `AdminTable` (which is a basic `<table>` element)
- `AdminVirtualTable` uses `useVueTable` + `useVirtualizer` composables from TanStack
- `getCoreRowModel()` only — no pagination model (virtualization replaces pagination)
- `manualFiltering: true` — Pinia UI store owns all filter logic, table just renders what it receives
- Column definitions passed as props, data as props
- BEM class: `AdminVirtualTable`, `AdminVirtualTable__row`, `AdminVirtualTable__cell`, etc.

### UI Store (members-list.ui)
- Owns: `filterTags` (array of `{ category, value }`), `searchQuery`, computed `filteredMembers`
- Reads from `all-members.domain.allMembers`
- `filteredMembers` is a computed that applies all active filter tags as AND conditions
- Exposes `addFilter(category, value)`, `removeFilter(index)`, `clearFilters()`, `setSearchQuery(query)`

### Claude's Discretion
- Exact chip color per category (group = one color, status = another, etc.)
- Whether Combobox dropdown appears on focus or after typing 1+ characters
- Skeleton row exact animation (shimmer or pulse)
- Exact column widths and responsive behavior
- Whether "last active" shows relative time ("2d ago") or absolute date

</decisions>

<specifics>
## Specific Ideas

- Filter tags should feel like Material React Table's column filter chips — compact, dismissible, stacked horizontally with wrapping
- The table should feel fast even with 500+ rows — no lag when scrolling, no blank rows flashing
- Group chips in each row should be colored consistently (same group = same color across all rows)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `all-members.domain.ts`: `allMembers` computed (UnifiedMember[]), `isLoading`, `failedGroups`, `loadAll()`
- `reka-ui`: TagsInput, TagsInputItem, TagsInputItemText, TagsInputItemDelete, TagsInputInput, TagsInputClear, Combobox, ComboboxInput, ComboboxContent, ComboboxItem
- `@tanstack/vue-table`: `useVueTable`, `getCoreRowModel`, `createColumnHelper`, `FlexRender`
- `@tanstack/vue-virtual`: `useVirtualizer`
- Existing admin SCSS patterns: `AdminSection`, `AdminSection__header`, `AdminSection__action-btn`
- Avatar Blade component pattern: 32px circle with background-image — replicate in Vue for table rows

### Established Patterns
- Pinia UI stores compute component props from domain stores
- Components receive data via props/emits, no direct store imports
- BEM naming: `ComponentName`, `ComponentName__element`, `ComponentName--modifier`
- Dark theme: dark backgrounds (#1a1a1a area), white text, purple accents (#6c47ff), muted text rgba(255,255,255,0.5)

### Integration Points
- `members-section.vue`: Replace placeholder with `AdminVirtualTable` + `MemberFilterBar`
- `members-list.ui.ts`: New UI store consumed by `members-section.vue`
- `all-members.domain.allMembers`: Data source for table
- Row click → emit member `userId` → Phase 13 wires this to open profile drawer

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-virtualized-member-table-tag-filters*
*Context gathered: 2026-03-21*
