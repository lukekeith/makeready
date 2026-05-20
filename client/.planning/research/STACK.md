# Stack Research

**Domain:** Admin CRUD panel additions to existing Laravel Blade + Vue islands app
**Researched:** 2026-03-21
**Confidence:** HIGH (all versions verified via npm registry; integration patterns verified against existing codebase and official TanStack docs)

> **Scope:** This document covers ONLY new capabilities needed for v2.1 (unified member management, virtualized tables, tag-based filtering, multi-group assignment, activity history replay). The v2.0 stack additions (Tiptap, vue-draggable-plus, ApexCharts, reka-ui DatePicker/Tabs) are documented in the previous STACK.md version and are not re-researched here.

---

## Existing Stack Summary (Do Not Change)

| Technology | Installed Version | Role |
|------------|------------------|------|
| Laravel | 12.x | Routing, API proxy, SSR |
| Vue | 3.5.30 | Interactive islands |
| Pinia | 3.0.4 | State management |
| reka-ui | 2.9.2 | Headless primitives (Dialog, Tabs, TagsInput, Combobox, etc.) |
| lucide-vue-next | 0.577.0 | Icons |
| hls.js | 1.6.15 | HLS video playback (activity history video replay) |
| vue-router | 4.6.4 | Admin SPA routing |
| vue-draggable-plus | 0.6.1 | Drag-and-drop reordering |
| apexcharts + vue3-apexcharts | 5.10.4 / 1.11.1 | Analytics charts |
| axios | 1.11.0 | HTTP client in Vue islands |
| sass | 1.98.0 | SCSS compilation |
| histoire | 0.17.17 | Component stories |

---

## Recommended Stack Additions

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| @tanstack/vue-table | 8.21.3 | Headless table logic — sorting, filtering, column defs, row model | Headless-only: zero CSS output, no style conflicts with existing BEM SCSS. The Vue 3 adapter provides `useVueTable` composable with reactive data (`Ref<T[]>` accepted directly). `manualFiltering: true` mode lets Pinia own filter state and trigger re-fetches on commit rather than on every keystroke — exactly the "not live filtering" requirement. Official TanStack package, actively maintained (8.21.3 published 2025). |
| @tanstack/vue-virtual | 3.13.23 | Row virtualization — renders only visible rows in a large member list | The pairing with `@tanstack/vue-table` is official and documented. `useVirtualizer` returns a `Ref<Virtualizer>`, integrates with `table.getRowModel().rows` directly. Version 3.13.23 published Feb 2026 — actively maintained. Headless: renders nothing, just gives you virtual item positions to apply to your own BEM markup. **Critical:** do NOT use pagination (`getPaginatedRowModel()`) when virtualizing — the two are mutually exclusive by design. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| reka-ui TagsInput + Combobox | 2.9.2 (already installed) | Tag chip input for the filter bar — user types and commits filter tags | Already installed. `TagsInputRoot` + `TagsInputItem` give you the chip/tag UX with full keyboard nav and ARIA. Combine with `ComboboxRoot` for a dropdown-suggest-then-tag pattern (type group name → see suggestions → press Enter to add as filter tag). No new dependency. |
| hls.js | 1.6.15 (already installed) | Video replay in activity history | Already installed. Activity history replay shows video progress events alongside the video itself. The same `hls.js` instance used in the member lesson experience works unchanged — seek to timestamp via `hls.currentTime`. No new dependency. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| No additions needed | — | TanStack Table and Virtual ship their own types. No additional type packages required beyond `@tanstack/vue-table` and `@tanstack/vue-virtual`. |

---

## Installation

```bash
# From /client directory — only two new packages for v2.1
npm install @tanstack/vue-table @tanstack/vue-virtual
```

**Register no global components.** TanStack Table and Virtual are composable-only libraries — `useVueTable` and `useVirtualizer` are imported directly in Vue islands. No `app.component()` registration needed.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| @tanstack/vue-table | ag-Grid Community (Vue) | If you need a fully pre-built data grid with built-in UI (column resize handles, row grouping UI, Excel export). ag-Grid Community is free but ships opinionated CSS that would conflict with BEM SCSS. For a list of members with custom row actions, TanStack's headless approach is correct. |
| @tanstack/vue-table | Custom `<table>` component | If the member list has fewer than ~200 rows and no sorting/filtering requirements. For cross-group member management with potentially thousands of members, TanStack Table's row model (sorting, filtering, column defs) is worth the 14KB over a hand-rolled table. |
| @tanstack/vue-virtual | Custom windowing with `IntersectionObserver` | If only infinite scroll (not fixed-height virtualization) is needed. TanStack Virtual handles both fixed and variable row heights with `measureElement`; a custom `IntersectionObserver` approach only works for append-only infinite scroll. |
| reka-ui TagsInput (existing) | vue3-tags-input | reka-ui is already installed. `vue3-tags-input` is an additional dependency that brings nothing reka-ui doesn't already provide. |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| ag-Grid / AG Grid Community | Opinionated CSS grid system — conflicts with BEM SCSS, pulls in 200KB+ of framework CSS even in community edition | @tanstack/vue-table (headless) |
| vue3-easy-data-table | Opinionated table styling; was explicitly deferred in v2.0 research for this reason | @tanstack/vue-table |
| PrimeVue DataTable | Ships the entire PrimeVue component library; opinionated CSS | @tanstack/vue-table |
| DataTables.net | jQuery dependency; pre-Vue era design; not reactive | @tanstack/vue-table |
| vue3-tags-input | Redundant with reka-ui TagsInput already installed | reka-ui TagsInput (2.9.2 already installed) |
| @vueuse/core | Large utility library — VueUse is useful in general but is not needed for this milestone. Do not add it just to get `useVirtualList`; @tanstack/vue-virtual is purpose-built and official. | @tanstack/vue-virtual |
| vue-infinite-loading | Infinite scroll library — incompatible with fixed-height virtualization pattern; adds complexity | @tanstack/vue-virtual (handles both fixed rows and dynamic measurement) |
| Tailwind CSS | Explicitly excluded from this project; user preference, conflicts with custom SCSS design tokens | SCSS/BEM (existing approach) |

---

## Stack Patterns by Variant

**For the /admin/members virtualized list (thousands of rows):**
- Use `@tanstack/vue-table` with `manualFiltering: true` + `@tanstack/vue-virtual`
- Pinia store owns `columnFilters` state; only re-fetches from API when user commits filters (clicks Apply or presses Enter on the tag input)
- Do NOT use `getPaginatedRowModel()` — incompatible with virtualizer
- Row height must be fixed or measured via `measureElement` for accurate scroll calculation

**For the per-group members tab (existing, ~10-100 rows):**
- Keep existing custom table component — no need to migrate to TanStack Table
- TanStack Table is additive for the new /admin/members view only

**For tag filter chips (name, group, lesson status, activity type):**
- Use `reka-ui TagsInput` (already installed) for the chip display
- Use `reka-ui Combobox` (already installed) for the dropdown suggestions when typing a group name or activity type
- Filter state lives in the Pinia UI store as `string[]` per filter category
- Filters are committed to the Pinia domain store on explicit user action, not on each keystroke

**For activity history replay:**
- Timeline list: use `@tanstack/vue-virtual` (same package, `useVirtualizer`) for the scrollable timeline of events
- Video seek: existing `hls.js` instance, call `videoElement.currentTime = event.timestamp` on timeline item click
- No new library needed — the activity types (video, SOAP, scripture) already have their display components from v2.0

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| @tanstack/vue-table 8.21.3 | Vue 3.5.x, @tanstack/table-core 8.21.3 (same version, bundled) | Vue adapter is a thin wrapper over framework-agnostic core. Vue 3 Composition API only — no Options API usage. |
| @tanstack/vue-virtual 3.13.23 | Vue 3.5.x | `useVirtualizer` returns `Ref<Virtualizer>` — access instance methods via `.value`. Compatible with Vue 3 reactivity system. |
| @tanstack/vue-table 8.21.3 | @tanstack/vue-virtual 3.13.23 | These are from different TanStack packages with independent versioning. The integration is via `table.getRowModel().rows` fed into `useVirtualizer({ count: rows.length })`. No shared peer dependency conflicts. |
| reka-ui 2.9.2 | @tanstack/vue-table 8.21.3 | No conflicts — reka-ui provides UI primitives, TanStack Table provides headless logic. They operate at different layers and share no dependencies. |

---

## Integration Points

**TanStack Table + Pinia pattern for manualFiltering:**

```typescript
// In the MemberManagement Pinia UI store
const columnFilters = ref<ColumnFiltersState>([])
const committedFilters = ref<ColumnFiltersState>([])

const table = useVueTable({
  get data() { return memberDomainStore.members },
  columns,
  getCoreRowModel: getCoreRowModel(),
  manualFiltering: true,              // Pinia drives filters, not keystrokes
  state: { columnFilters: committedFilters.value },
  onColumnFiltersChange: (updater) => {
    committedFilters.value = typeof updater === 'function'
      ? updater(committedFilters.value)
      : updater
    memberDomainStore.fetchMembers(committedFilters.value) // API re-fetch on commit
  },
})
```

**TanStack Virtual integration with TanStack Table:**

```typescript
const { rows } = table.getRowModel()
const parentRef = ref<HTMLElement | null>(null)

const virtualizer = useVirtualizer({
  count: rows.length,
  getScrollElement: () => parentRef.value,
  estimateSize: () => 56,             // Fixed row height (px)
  overscan: 10,
})

const virtualRows = computed(() => virtualizer.value.getVirtualItems())
const totalHeight = computed(() => virtualizer.value.getTotalSize())
```

**Vue island registration pattern (existing `resources/js/app.js`):**

No new registration pattern — admin member management will be a Vue island registered in `componentRegistry` under `data-vue="AdminMembersIsland"`. The TanStack composables are imported directly inside the island component's `<script setup>`. Pinia store is accessed via `useMemberManagementStore()` inside the same island.

**SCSS integration:** TanStack Table and Virtual output zero CSS. The table markup (`<table>`, `<tr>`, `<td>`) is written by you in the Vue template, so BEM classes (`.MemberTable`, `.MemberTable__row`, `.MemberTable__cell`) apply exactly as in other admin components.

---

## Sources

- npm registry (`npm view @tanstack/vue-table version`, `npm view @tanstack/vue-virtual version`) — versions 8.21.3 and 3.13.23 confirmed — HIGH confidence
- [TanStack Table Vue docs](https://tanstack.com/table/v8/docs/framework/vue/vue-table) — `useVueTable` composable, reactive data, Vue adapter overview — HIGH confidence
- [TanStack Table virtualization guide](https://tanstack.com/table/v8/docs/guide/virtualization) — `manualFiltering` pattern, `getRowModel().rows` integration with virtualizer, pagination/virtualization mutual exclusivity — HIGH confidence
- [TanStack Table column filtering guide](https://tanstack.com/table/v8/docs/guide/column-filtering) — `manualFiltering: true` mode confirmed, `columnFilters` state API — HIGH confidence
- [TanStack Virtual Vue docs](https://tanstack.com/virtual/v3/docs/framework/vue/vue-virtual) — `useVirtualizer` returns `Ref<Virtualizer>`, `measureElement` pattern — HIGH confidence
- [@tanstack/vue-virtual npm](https://www.npmjs.com/package/@tanstack/vue-virtual) — v3.13.23 published Feb 2026, active maintenance confirmed — HIGH confidence
- [reka-ui TagsInput docs](https://reka-ui.com/docs/components/tags-input) — `TagsInputRoot`, `TagsInputItem` confirmed in reka-ui 2.9.2 — HIGH confidence
- [reka-ui Combobox TagsInput example](https://reka-ui.com/examples/combobox-tags-input) — combined combobox + tags-input pattern confirmed — HIGH confidence
- Existing `package.json` inspection — installed versions confirmed, no TanStack packages currently installed — HIGH confidence

---
*Stack research for: MakeReady v2.1 member management + activity history*
*Researched: 2026-03-21*
