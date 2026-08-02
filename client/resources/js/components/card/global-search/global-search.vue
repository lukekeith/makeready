<script lang="ts">
import { cva } from '../../../util/cva'

// GlobalSearch — web twin of the iPhone global search tab
// (Pages/Search/GlobalSearchPage.swift + GlobalSearchEngine.swift). Shared by
// BOTH the capture harness (inert, props seed everything) and the production
// LeaderApp search view (interactive + emits).
//
// iOS has NO page header on this screen — the SearchField is the first
// element. The body is exactly ONE of four branches (GlobalSearchPage:81-94):
//   • recents  — query shorter than 2 chars; sections WITHOUT dividers
//   • loading  — a centered white@30 spinner, only when nothing is rendered yet
//   • empty    — magnifyingglass + "No results for '<query>'"
//   • results  — the filter-badge rail, then sections WITH dividers
//
// Every entity renders through the SAME row component (CardSearchResult) with
// the first case-insensitive query match recolored brand, and iOS hard-codes
// `showChevron: false` here.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/global-search.scss exactly.
export const GlobalSearchCva = cva('GlobalSearch', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import SearchField from '../search-field/search-field.vue'
import CardSearchResult from '../card-search-result/card-search-result.vue'

export interface GlobalSearchRow {
  id: string
  title: string
  subtitle?: string
  /** Recents carry a relative timestamp ("2h ago"); search results do not. */
  timeAgo?: string
  imageUrl?: string
  /** Members render an Avatar instead of the glyph circle. */
  isMember?: boolean
  initials?: string
}

export interface GlobalSearchSection {
  /** SearchResultCategory key — drives the label, glyph and sort order. */
  category: string
  rows: GlobalSearchRow[]
  /** iOS badge count (the number of returned rows). */
  count?: number
}

interface Props {
  searchText?: string
  /** iOS SearchField isActive — border + close button. */
  active?: boolean
  sections?: GlobalSearchSection[]
  /** iOS isSearching — the spinner shows ONLY when nothing is rendered yet. */
  loading?: boolean
  /** Selected filter badge; null shows every section. */
  activeCategory?: string | null
  /** Production: the field and rows become live. Capture never passes it. */
  interactive?: boolean
  // Capture-only: render the iOS device status bar. Production never passes it.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  searchText: '',
  active: false,
  sections: () => [],
  loading: false,
  activeCategory: null,
  interactive: false,
  statusBar: false,
})

const emit = defineEmits<{
  'update:searchText': [value: string]
  clear: []
  /** Filter badge tapped (null when the selected one is re-tapped). */
  selectCategory: [category: string | null]
  selectRow: [payload: { category: string; id: string }]
}>()

// SF Symbol transcriptions — one per SearchResultCategory
// (GlobalSearchEngine.swift:27-70: displayName, icon and sortOrder).
// Outline glyphs throughout: these icons sit on three different backgrounds
// (canvas, a brand@15% circle, and a solid brand badge), so a knocked-out
// fill would only read correctly on one of them.
const BOOK_CLOSED =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M5 5a2 2 0 0 1 2-2h11a1 1 0 0 1 1 1v13H7a2 2 0 0 0-2 2z"/><path d="M5 19a2 2 0 0 0 2 2h12"/></svg>'
const PERSON_3 =
  '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="8" r="3.2"/><circle cx="5" cy="9.5" r="2.4"/><circle cx="19" cy="9.5" r="2.4"/><path d="M12 12.6c-3 0-5.2 1.7-5.2 3.6V18h10.4v-1.8c0-1.9-2.2-3.6-5.2-3.6z"/><path d="M5 13.2c-2.2 0-3.8 1.2-3.8 2.6V17h4.2v-.9c0-1.1.5-2.1 1.4-2.8A6.6 6.6 0 0 0 5 13.2z"/><path d="M19 13.2c-.6 0-1.2.04-1.8.14.9.7 1.4 1.7 1.4 2.8v.9h4.2v-1.2c0-1.4-1.6-2.6-3.8-2.6z"/></svg>'
const LIST_RECT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><rect x="2.8" y="5" width="18.4" height="14" rx="2.5"/><path d="M7 9.5h.01M7 12.5h.01M7 15.5h.01" stroke-width="2"/><path d="M10 9.5h8M10 12.5h8M10 15.5h5.5"/></svg>'
const PERSON =
  '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="7.5" r="4"/><path d="M12 13c-4 0-7 2.3-7 5.2V20h14v-1.8c0-2.9-3-5.2-7-5.2z"/></svg>'
const PLAY_RECT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><rect x="2.8" y="5" width="18.4" height="14" rx="2.5"/><path d="M10.2 9.4l4.6 2.6-4.6 2.6z" fill="currentColor" stroke="none"/></svg>'
const CAL_CLOCK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><path d="M3.5 8.5h11"/><path d="M3.5 6.5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v5"/><path d="M6.5 3v3M12.5 3v3"/><path d="M5.5 19.5h-0a2 2 0 0 1-2-2V8.5"/><circle cx="17" cy="16" r="4.5"/><path d="M17 14v2.2l1.4 1"/></svg>'
const CALENDAR =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 9.5h17"/><path d="M8 3v3M16 3v3"/></svg>'
const TEXT_BUBBLE =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 3.5c-5 0-9 3.2-9 7.2 0 2.3 1.3 4.3 3.4 5.6-.2 1-.8 2.3-1.8 3.2 1.8-.2 3.5-1 4.7-1.9 .9.2 1.8.3 2.7.3 5 0 9-3.2 9-7.2S17 3.5 12 3.5z"/></svg>'
const DOC_TEXT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2.8H6.8a1.8 1.8 0 0 0-1.8 1.8v14.8a1.8 1.8 0 0 0 1.8 1.8h10.4a1.8 1.8 0 0 0 1.8-1.8V8.5z"/><path d="M13 2.8V8.5h5.8"/><path d="M8.2 12.5h7.6M8.2 15.5h7.6M8.2 18.2h5"/></svg>'
const BELL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 3a5.5 5.5 0 0 0-5.5 5.5v3.2L5 15.5h14l-1.5-3.8V8.5A5.5 5.5 0 0 0 12 3z"/><path d="M10.2 17a1.8 1.8 0 0 0 3.6 0z"/></svg>'
// Empty-state glyphs are drawn INK-TIGHT to their 36px box: iOS renders these
// as SF Symbols at Typography.s36, whose ink very nearly fills the nominal
// size (the reference clock measures ~35pt tall). A conventional 24-viewBox
// icon would only ink ~29pt and read visibly small.
const CLOCK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10.9"/><path d="M12 5.7V12h5.5"/></svg>'
const MAGNIFIER =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="10" cy="10" r="7.6"/><path d="M15.4 15.4L22.4 22.4"/></svg>'

// iOS SearchResultCategory: displayName + icon + sortOrder, verbatim.
const CATEGORY_META: Record<string, { label: string; icon: string; order: number }> = {
  program: { label: 'Programs', icon: BOOK_CLOSED, order: 0 },
  group: { label: 'Groups', icon: PERSON_3, order: 1 },
  lesson: { label: 'Lessons', icon: LIST_RECT, order: 2 },
  member: { label: 'Members', icon: PERSON, order: 3 },
  video: { label: 'Videos', icon: PLAY_RECT, order: 4 },
  enrollment: { label: 'Enrollments', icon: CAL_CLOCK, order: 5 },
  event: { label: 'Events', icon: CALENDAR, order: 6 },
  post: { label: 'Posts', icon: TEXT_BUBBLE, order: 7 },
  template: { label: 'Templates', icon: DOC_TEXT, order: 8 },
  notification: { label: 'Notifications', icon: BELL, order: 9 },
}

function meta(category: string) {
  return CATEGORY_META[category] ?? { label: category, icon: DOC_TEXT, order: 99 }
}

// iOS sortedCategories — sortOrder, not insertion order.
const sortedSections = computed(() =>
  [...props.sections].sort((a, b) => meta(a.category).order - meta(b.category).order)
)

// iOS visibleCategories: a selected badge collapses the list to that one
// category, while the rail keeps showing every category.
const visibleSections = computed(() =>
  props.activeCategory
    ? sortedSections.value.filter((s) => s.category === props.activeCategory)
    : sortedSections.value
)

// iOS body branch order (GlobalSearchPage.swift:81-94).
const mode = computed<'recents' | 'loading' | 'empty' | 'results'>(() => {
  if (props.searchText.trim().length < 2) return 'recents'
  if (props.loading && sortedSections.value.length === 0) return 'loading'
  if (sortedSections.value.length === 0) return 'empty'
  return 'results'
})

function onRow(category: string, id: string): void {
  if (!props.interactive) return
  emit('selectRow', { category, id })
}

function onBadge(category: string): void {
  if (!props.interactive) return
  // iOS: re-tapping the selected badge clears the filter.
  emit('selectCategory', props.activeCategory === category ? null : category)
}

const classes = computed(() =>
  classnames(GlobalSearchCva.variants({}), props.class)
)
</script>

<template>
  <div :class="classes">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="GlobalSearch__statusbar" aria-hidden="true">
      <span class="GlobalSearch__clock">9:41</span>
      <span class="GlobalSearch__indicators">
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

    <!-- iOS: the SearchField is the FIRST element — there is no page header. -->
    <div class="GlobalSearch__field">
      <SearchField
        placeholder="Search everything"
        :search-text="props.searchText"
        :is-active="props.active"
        :interactive="props.interactive"
        @update:search-text="emit('update:searchText', $event)"
        @clear="emit('clear')"
      />
    </div>

    <!-- ── Recents (query < 2 chars) ── -->
    <div v-if="mode === 'recents'" class="GlobalSearch__body">
      <div v-if="sortedSections.length === 0" class="GlobalSearch__recentsEmpty">
        <span class="GlobalSearch__emptyGlyph" v-html="CLOCK"></span>
        <span class="GlobalSearch__emptyText">No recent items</span>
      </div>

      <div v-else class="GlobalSearch__scroll GlobalSearch__scroll--recents">
        <section
          v-for="section in sortedSections"
          :key="section.category"
          class="GlobalSearch__section"
        >
          <header class="GlobalSearch__sectionHeader">
            <span class="GlobalSearch__sectionIcon" v-html="meta(section.category).icon"></span>
            <span class="GlobalSearch__sectionLabel">{{ meta(section.category).label }}</span>
          </header>
          <CardSearchResult
            v-for="row in section.rows"
            :key="row.id"
            :title="row.title"
            :subtitle="row.subtitle"
            :time-ago="row.timeAgo"
            :image-url="row.imageUrl"
            :is-member="row.isMember"
            :initials="row.initials"
            :icon="meta(section.category).icon"
            :show-chevron="false"
            @click="onRow(section.category, row.id)"
          />
        </section>
      </div>
    </div>

    <!-- ── Loading (only when nothing is rendered yet) ── -->
    <div v-else-if="mode === 'loading'" class="GlobalSearch__body">
      <div class="GlobalSearch__loading">
        <span class="GlobalSearch__spinner" aria-hidden="true"></span>
      </div>
    </div>

    <!-- ── No results ── -->
    <div v-else-if="mode === 'empty'" class="GlobalSearch__body">
      <div class="GlobalSearch__empty">
        <span class="GlobalSearch__emptyGlyph" v-html="MAGNIFIER"></span>
        <span class="GlobalSearch__emptyText">No results for '{{ props.searchText }}'</span>
      </div>
    </div>

    <!-- ── Results: badge rail + sections (with dividers) ── -->
    <div v-else class="GlobalSearch__body">
      <div class="GlobalSearch__rail">
        <component
          :is="props.interactive ? 'button' : 'div'"
          v-for="section in sortedSections"
          :key="section.category"
          :type="props.interactive ? 'button' : undefined"
          class="GlobalSearch__badge"
          :class="{ 'GlobalSearch__badge--selected': props.activeCategory === section.category }"
          @click="onBadge(section.category)"
        >
          <span class="GlobalSearch__badgeIcon" v-html="meta(section.category).icon"></span>
          <span class="GlobalSearch__badgeLabel">
            {{ meta(section.category).label }} {{ section.count ?? section.rows.length }}
          </span>
        </component>
      </div>

      <div class="GlobalSearch__scroll">
        <section
          v-for="(section, i) in visibleSections"
          :key="section.category"
          class="GlobalSearch__section"
        >
          <!-- iOS draws the divider ABOVE every section but the first. -->
          <div v-if="i > 0" class="GlobalSearch__divider" aria-hidden="true"></div>
          <header class="GlobalSearch__sectionHeader">
            <span class="GlobalSearch__sectionIcon" v-html="meta(section.category).icon"></span>
            <span class="GlobalSearch__sectionLabel">{{ meta(section.category).label }}</span>
          </header>
          <CardSearchResult
            v-for="row in section.rows"
            :key="row.id"
            :title="row.title"
            :subtitle="row.subtitle"
            :time-ago="row.timeAgo"
            :image-url="row.imageUrl"
            :is-member="row.isMember"
            :initials="row.initials"
            :icon="meta(section.category).icon"
            :show-chevron="false"
            :highlight-query="props.searchText"
            @click="onRow(section.category, row.id)"
          />
        </section>
      </div>
    </div>
  </div>
</template>
