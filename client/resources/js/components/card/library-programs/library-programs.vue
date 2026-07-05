<script setup lang="ts">
// LibraryPrograms — capture-only web twin of the iPhone MainLibrary "Programs"
// tab (Pages/Main/MainLibrary.swift, ViewRegistry `pages.study-programs`).
// Capture-only, like group-home-leader / home-dashboard / groups-leader.
//
// Composed from existing design-system twins — PageHeader (Programs/Media tabs),
// SearchField (the studies search), CardProgramFull (each program card) — plus
// the page chrome the iPhone screen adds: the device status bar, the PageHeader
// trailing export/plus buttons, the tag/leader filter pills, and the "Browse all"
// + sort row.
import PageHeader from '../page-header/page-header.vue'
import SearchField from '../search-field/search-field.vue'
import CardProgramFull from '../card-program-full/card-program-full.vue'
import FilterChipDropdown, { type FilterChipItem } from '../filter-chip-dropdown/filter-chip-dropdown.vue'

interface ProgramItem {
  title: string
  description?: string
  days: number
  authorName?: string
  relativeDate?: string
  published?: boolean
  coverUrl?: string
}

interface Props {
  programs?: ProgramItem[]
  // ADDITIVE (compare-visibility policy 2026-07-03): filter/sort state
  // renderings. Defaults reproduce the original captured chrome exactly.
  chips?: Array<{ label: string; active?: boolean }>
  sortLabel?: string
  /** Renders the FilterChipDropdown panel + dim layer under the chips
   *  (the wired open-panel state). Absent by default. */
  openPanel?: { items: FilterChipItem[]; selectedIds?: string[]; emptyMessage?: string }
}

const props = withDefaults(defineProps<Props>(), {
  programs: () => [],
  chips: () => [
    { label: 'All tags' },
    { label: 'All leaders' },
  ],
  sortLabel: 'Newest first',
})

// iOS CardProgramFull metadata: calendar (days) + clock (weeks = ceil(days/7)).
const CALENDAR =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>'
const CLOCK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'

function dataItems(p: ProgramItem) {
  const weeks = Math.ceil((p.days || 0) / 7)
  return [
    { icon: CALENDAR, value: String(p.days ?? 0) },
    { icon: CLOCK, value: `${weeks} ${weeks === 1 ? 'week' : 'weeks'}` },
  ]
}

// iOS PageHeader trailing buttons: square.and.arrow.up (export) + plus.
const EXPORT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3"/><path d="M8 7l4-4 4 4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
// iOS "line.3.horizontal.decrease" — sort/filter glyph next to "Newest first".
const SORT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M6 12h12M10 18h4"/></svg>'
// iOS chevron.down on the filter pills.
const CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9l7 7 7-7"/></svg>'
</script>

<template>
  <div class="LibraryPrograms">
    <!-- iOS device status bar (62pt top safe-area inset). -->
    <div class="LibraryPrograms__statusbar" aria-hidden="true">
      <span class="LibraryPrograms__clock">9:41</span>
      <span class="LibraryPrograms__indicators">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <!-- PageHeader (Programs/Media) + trailing export/plus. -->
    <div class="LibraryPrograms__headerRow">
      <PageHeader :tabs="['Programs', 'Media']" :active-tab="0" />
      <div class="LibraryPrograms__actions">
        <span class="LibraryPrograms__actionBtn" aria-hidden="true" v-html="EXPORT"></span>
        <span class="LibraryPrograms__actionBtn" aria-hidden="true" v-html="PLUS"></span>
      </div>
    </div>

    <!-- Search + filter pills (iOS fixed overlay; here in flow). -->
    <div class="LibraryPrograms__search">
      <SearchField placeholder="Search studies, tags, authors..." />
    </div>
    <div class="LibraryPrograms__filters">
      <span
        v-for="(chip, i) in props.chips"
        :key="i"
        class="LibraryPrograms__chip"
        :class="{ 'LibraryPrograms__chip--active': chip.active }"
      >{{ chip.label }}<span class="LibraryPrograms__chipChevron" v-html="CHEVRON"></span></span>
    </div>

    <!-- Open filter panel + dim layer (wired state; compare-visibility). -->
    <div v-if="props.openPanel" class="LibraryPrograms__panelWrap">
      <FilterChipDropdown
        :items="props.openPanel.items"
        :selected-ids="props.openPanel.selectedIds ?? []"
        :empty-message="props.openPanel.emptyMessage ?? 'Nothing to show yet.'"
      />
    </div>
    <div v-if="props.openPanel" class="LibraryPrograms__panelScrim" aria-hidden="true"></div>

    <!-- Browse all + sort -->
    <div class="LibraryPrograms__browse">
      <span class="LibraryPrograms__browseTitle">Browse all</span>
      <span class="LibraryPrograms__sort">
        {{ props.sortLabel }}<span class="LibraryPrograms__sortIcon" v-html="SORT"></span>
      </span>
    </div>

    <!-- Program cards -->
    <div class="LibraryPrograms__list">
      <CardProgramFull
        v-for="(p, i) in props.programs"
        :key="i"
        :title="p.title"
        :description="p.description"
        :data-items="dataItems(p)"
        :author-name="p.authorName"
        :relative-date="p.relativeDate"
        :published="p.published !== false"
        :cover-url="p.coverUrl || undefined"
      />
    </div>
  </div>
</template>
