<script setup lang="ts">
// LibraryMedia — capture-only web twin of the iPhone MainLibrary "Media" tab
// (Pages/Main/MainLibrary.swift, ViewRegistry `pages.media`). Capture-only.
//
// Composes the PageHeader (Programs/Media tabs) + SearchField twins, plus the
// page chrome the iPhone screen adds: the device status bar, the trailing
// export/plus buttons, the four filter pills, and the media grid. The media
// thumbnails never resolve in the isolated snapshot, so the grid cells render
// the iOS placeholder glyphs (photo icon for images, play triangle for videos).
import PageHeader from '../page-header/page-header.vue'
import SearchField from '../search-field/search-field.vue'

interface MediaItem {
  type: 'VIDEO' | 'IMAGE' | string
}

interface Props {
  media?: MediaItem[]
  // ADDITIVE (compare-visibility policy): chip states — default reproduces
  // the original four static pills.
  chips?: Array<{ label: string; active?: boolean }>
}

const props = withDefaults(defineProps<Props>(), {
  media: () => [],
})

const EXPORT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3"/><path d="M8 7l4-4 4 4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
const CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9l7 7 7-7"/></svg>'

const DEFAULT_FILTERS = [
  { label: 'All tags' },
  { label: 'All leaders' },
  { label: 'All' },
  { label: 'All time' },
]
</script>

<template>
  <div class="LibraryMedia">
    <!-- iOS device status bar (62pt top safe-area inset). -->
    <div class="LibraryMedia__statusbar" aria-hidden="true">
      <span class="LibraryMedia__clock">9:41</span>
      <span class="LibraryMedia__indicators">
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

    <!-- PageHeader (Programs/Media — Media active) + trailing export/plus. -->
    <div class="LibraryMedia__headerRow">
      <PageHeader :tabs="['Programs', 'Media']" :active-tab="1" />
      <div class="LibraryMedia__actions">
        <span class="LibraryMedia__actionBtn" aria-hidden="true" v-html="EXPORT"></span>
        <span class="LibraryMedia__actionBtn" aria-hidden="true" v-html="PLUS"></span>
      </div>
    </div>

    <!-- Search + four filter pills. -->
    <div class="LibraryMedia__search">
      <SearchField placeholder="Search media library" />
    </div>
    <div class="LibraryMedia__filters">
      <span
        v-for="(f, i) in props.chips ?? DEFAULT_FILTERS"
        :key="i"
        class="LibraryMedia__chip"
        :class="{ 'LibraryMedia__chip--active': f.active }"
      >
        {{ f.label }}<span class="LibraryMedia__chipChevron" v-html="CHEVRON"></span>
      </span>
    </div>

    <!-- Media grid (3 columns, 2px gaps, full-bleed). Placeholder glyphs only. -->
    <div class="LibraryMedia__grid">
      <span v-for="(m, i) in props.media" :key="i" class="LibraryMedia__cell" aria-hidden="true">
        <svg v-if="m.type === 'IMAGE'" class="LibraryMedia__glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="4" width="18" height="16" rx="2" /><circle cx="8.5" cy="9.5" r="1.5" /><path d="M21 16l-5-5-9 9" />
        </svg>
        <svg v-else class="LibraryMedia__glyph" viewBox="0 0 24 24" fill="currentColor">
          <path d="M8 5.5v13l11-6.5z" />
        </svg>
      </span>
    </div>
  </div>
</template>
