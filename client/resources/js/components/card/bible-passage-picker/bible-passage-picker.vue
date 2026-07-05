<script setup lang="ts">
// BiblePassagePicker — web twin of the iPhone Bible reader overlay
// (Pages/Bible/BibleReaderOverlay.swift), the bottom sheet the READ editor's
// "Bible verse" add-block row presents.
//
// This component is the SHEET CONTENT (drag indicator + search bar + subtitle
// row + the five screens); the production host owns the scrim + present /
// dismiss animation, mirroring how iOS adds the UIView to the key window.
// Fully prop-driven so compare variants render each screen statically; all
// interactivity is additive emits (captures bind nothing).
//
// iOS geometry 1:1 (BibleReaderOverlay.layoutSubviews):
//   drag indicator 36×5 white@0.3 at y10 · search bar y27 h40 #0D101A@0.8 r4
//   (version 48×24 brand · book-list 24×24 white@0.2 · field 15pt · icon
//   right) · subtitle row +16 (13pt centered, back 24×24 left, "Select"
//   right) · grid/table +30 (5 columns, 2px gaps, 44px cells, inset 16/16/40)
//   · reader = black@0.5 container, Charter serif, verse numbers hung in the
//   48px left gutter.
import { computed, nextTick, ref, watch } from 'vue'
import CardBibleSearchResult from '../card-bible-search-result/card-bible-search-result.vue'
import {
  BIBLE_CATEGORY_COLORS,
  bibleBookByNumber,
  newTestamentBooks,
  oldTestamentBooks,
} from '../../../utils/bible-data'

export type BiblePickerScreen = 'books' | 'chapters' | 'verses' | 'reader' | 'search'

export interface BiblePickerVerse {
  v: number
  t: string
}

export interface BiblePickerSearchResult {
  reference: string
  text: string
  bookNumber: number
  chapter: number
  verse: number
  title?: string | null
  summary?: string | null
}

export interface BiblePickerMatchedBook {
  bookNumber: number
  bookName: string
  chapters: number
  testament: string
}

export interface BiblePickerVersion {
  id: string
  code: string
  name: string
}

interface Props {
  screen?: BiblePickerScreen
  /** Version badge (uppercased, first 4 chars). */
  versionCode?: string
  /** Current book/chapter context (chapters/verses/reader screens). */
  bookNumber?: number | null
  chapter?: number | null
  /** Verses-grid tile count (iOS fetches the chapter's real verse count). */
  verseCount?: number
  /** Reader content. */
  verses?: BiblePickerVerse[]
  /** Reader: verse the view scrolled to on entry (label shows it). */
  scrollToVerse?: number | null
  /** Live contiguous verse selection (reader). */
  selectionStart?: number | null
  selectionEnd?: number | null
  /** "Already used in this lesson" tinting. */
  usedBooks?: number[]
  usedChapters?: number[]
  usedVerses?: number[]
  /** Search state. */
  searchQuery?: string
  searchLoading?: boolean
  searchResults?: BiblePickerSearchResult[]
  matchedBooks?: BiblePickerMatchedBook[]
  recents?: string[]
  /** Version dropdown. */
  versions?: BiblePickerVersion[]
  versionMenuOpen?: boolean
  selectedVersionId?: string
  /** Production interactivity (captures never pass it). */
  interactive?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  screen: 'books',
  versionCode: 'WEB',
  bookNumber: null,
  chapter: null,
  verseCount: 0,
  verses: () => [],
  scrollToVerse: null,
  selectionStart: null,
  selectionEnd: null,
  usedBooks: () => [],
  usedChapters: () => [],
  usedVerses: () => [],
  searchQuery: '',
  searchLoading: false,
  searchResults: () => [],
  matchedBooks: () => [],
  recents: () => [],
  versions: () => [],
  versionMenuOpen: false,
  selectedVersionId: '',
  interactive: false,
})

const emit = defineEmits<{
  back: []
  select: []
  selectBook: [bookNumber: number]
  selectChapter: [chapter: number]
  selectVerse: [verse: number]
  tapVerse: [verse: number]
  bookList: []
  versionTap: []
  versionPick: [id: string]
  versionMenuClose: []
  searchIconTap: []
  searchFocus: []
  searchSubmit: []
  'update:searchQuery': [value: string]
  recentTap: [query: string]
  matchedBookTap: [bookNumber: number]
  resultTap: [result: BiblePickerSearchResult]
}>()

const book = computed(() => (props.bookNumber != null ? bibleBookByNumber(props.bookNumber) : undefined))

// ── Subtitle row (iOS navigateTo header updates) ──
const subtitle = computed<{ text: string; dim: boolean }>(() => {
  const sel = selectionRange.value
  switch (props.screen) {
    case 'books':
      return { text: 'Select a book or enter reference', dim: true }
    case 'chapters':
      return { text: book.value?.name ?? '', dim: false }
    case 'verses':
      return { text: `${book.value?.name ?? ''} ${props.chapter ?? ''}`, dim: false }
    case 'reader':
      if (sel) {
        const range = sel.end > sel.start ? `${sel.start}-${sel.end}` : `${sel.start}`
        return { text: `${book.value?.name ?? ''} ${props.chapter ?? ''}:${range}`, dim: false }
      }
      return { text: 'Highlight passage', dim: true }
    case 'search':
      return { text: 'Search', dim: false }
  }
  return { text: '', dim: false }
})

const selectionRange = computed(() =>
  props.selectionStart != null && props.selectionEnd != null
    ? { start: props.selectionStart, end: props.selectionEnd }
    : null,
)

const isSelected = (v: number) =>
  selectionRange.value != null && v >= selectionRange.value.start && v <= selectionRange.value.end

// ── Search bar mode (reader replaces the field with a tappable label) ──
const readerMode = computed(() => props.screen === 'reader')
const hasQuery = computed(() => props.searchQuery.length > 0)

// Top-verse label — iOS updateTopVerseLabel tracks scroll; statically it shows
// the entry verse.
const topVerse = ref<number | null>(null)
watch(
  () => [props.screen, props.scrollToVerse],
  () => {
    topVerse.value = props.scrollToVerse
  },
  { immediate: true },
)
const readerLabel = computed(
  () => `${book.value?.name ?? ''} ${props.chapter ?? ''}:${topVerse.value ?? props.verses[0]?.v ?? 1}`,
)

// ── Reader rendering (iOS renderChapterText: one line per verse, cleaned) ──
function cleanVerse(t: string): string {
  return t
    .replace(/\\n|\\r|[\n\r]/g, ' ')
    .replace(/¶/g, '')
    .replace(/ {2,}/g, ' ')
    .trim()
}

const readerVerses = computed(() =>
  props.verses.map((v) => ({
    v: v.v,
    text: cleanVerse(v.t),
    used: props.usedVerses.includes(v.v),
    selected: isSelected(v.v),
  })),
)

const readerScroll = ref<HTMLElement | null>(null)
const verseEls = new Map<number, HTMLElement>()
function setVerseEl(v: number, el: unknown): void {
  if (el) verseEls.set(v, el as HTMLElement)
  else verseEls.delete(v)
}

// Interactive: scroll to the entry verse once content lands (iOS scrolls the
// UITextView; verse 1 stays at the top showing the chapter heading).
watch(
  () => [props.interactive, props.screen, props.verses.length, props.scrollToVerse] as const,
  async ([interactive, screen, count, target]) => {
    if (!interactive || screen !== 'reader' || count === 0) return
    await nextTick()
    const container = readerScroll.value
    if (!container) return
    if (!target || target <= 1) {
      container.scrollTop = 0
      return
    }
    const el = verseEls.get(target)
    if (el) container.scrollTop = Math.max(0, el.offsetTop - 20)
  },
  { immediate: true },
)

function onReaderScroll(): void {
  if (!props.interactive) return
  const container = readerScroll.value
  if (!container) return
  const top = container.scrollTop + 4
  let current: number | null = null
  for (const rv of readerVerses.value) {
    const el = verseEls.get(rv.v)
    if (el && el.offsetTop <= top) current = rv.v
    else if (el) break
  }
  if (current != null) topVerse.value = current
}

// ── Grids ──
const chapterTiles = computed(() => {
  const total = book.value?.chapters ?? 0
  return Array.from({ length: total }, (_, i) => ({
    n: i + 1,
    used: props.usedChapters.includes(i + 1),
  }))
})

const verseTiles = computed(() =>
  Array.from({ length: props.verseCount }, (_, i) => ({
    n: i + 1,
    used: props.usedVerses.includes(i + 1),
  })),
)

const bookSections = computed(() => [
  { key: 'ot', books: oldTestamentBooks },
  { key: 'nt', books: newTestamentBooks },
])

function bookTileStyle(bookInfo: (typeof oldTestamentBooks)[number]): Record<string, string> {
  const used = props.usedBooks.includes(bookInfo.id)
  return { backgroundColor: used ? '#6c47ff' : BIBLE_CATEGORY_COLORS[bookInfo.category] }
}

// ── Search states ──
const showRecents = computed(
  () =>
    props.screen === 'search' &&
    !props.searchLoading &&
    props.searchResults.length === 0 &&
    props.matchedBooks.length === 0 &&
    props.searchQuery.trim() === '',
)
const showEmpty = computed(
  () =>
    props.screen === 'search' &&
    !props.searchLoading &&
    !showRecents.value &&
    props.searchResults.length === 0 &&
    props.matchedBooks.length === 0,
)

function testamentLabel(t: string): string {
  return t === 'OT' ? 'Old Testament' : 'New Testament'
}

function onSearchInput(e: Event): void {
  emit('update:searchQuery', (e.target as HTMLInputElement).value)
}

const selectEnabled = computed(() => selectionRange.value != null)

// SF glyphs.
const XMARK =
  '<svg viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 2l10 10M12 2L2 12"/></svg>'
const CHEV_LEFT =
  '<svg viewBox="0 0 10 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8.5 1L1.5 8l7 7"/></svg>'
const MAGNIFY =
  '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><circle cx="7" cy="7" r="5"/><path d="M11 11l3.5 3.5"/></svg>'
const TEXT_JUSTIFY_LEFT =
  '<svg viewBox="0 0 14 12" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M1 1.5h12M1 4.8h8M1 8.1h12M1 11.4h8"/></svg>'
const BOOK_CLOSED =
  '<svg viewBox="0 0 16 18" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 1.5h10.5v15H3a1.8 1.8 0 0 1-1.8-1.8V3.3A1.8 1.8 0 0 1 3 1.5z"/><path d="M1.2 14.7A1.8 1.8 0 0 1 3 12.9h10.5"/></svg>'
const CLOCK_RECENT =
  '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="8" cy="8" r="6.2"/><path d="M8 4.5V8l2.4 1.6"/><path d="M1.8 8a6.2 6.2 0 0 1 .6-2.7"/></svg>'
const CHECK =
  '<svg viewBox="0 0 12 10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 5l3.4 3.4L11 1.4"/></svg>'
</script>

<template>
  <div :class="['BiblePassagePicker', props.class]">
    <!-- Drag indicator (36×5 white@0.3 at y10) -->
    <div class="BiblePassagePicker__grabberStrip">
      <span class="BiblePassagePicker__grabber"></span>
    </div>

    <!-- Search bar -->
    <div class="BiblePassagePicker__searchBar">
      <button
        type="button"
        class="BiblePassagePicker__version"
        @click="interactive && emit('versionTap')"
      >{{ versionCode.toUpperCase().slice(0, 4) }}</button>
      <button
        type="button"
        class="BiblePassagePicker__bookList"
        aria-label="Book list"
        v-html="TEXT_JUSTIFY_LEFT"
        @click="interactive && emit('bookList')"
      ></button>
      <template v-if="!readerMode">
        <input
          class="BiblePassagePicker__field"
          type="text"
          placeholder="Search reference or topic"
          :value="searchQuery"
          :readonly="!interactive"
          @input="onSearchInput"
          @focus="interactive && emit('searchFocus')"
          @keydown.enter="interactive && emit('searchSubmit')"
        />
      </template>
      <template v-else>
        <span class="BiblePassagePicker__readerLabel" @click="interactive && emit('bookList')">{{
          readerLabel
        }}</span>
      </template>
      <button
        v-if="readerMode || screen === 'books' || hasQuery || screen === 'search'"
        type="button"
        class="BiblePassagePicker__searchIcon"
        aria-label="Search"
        v-html="hasQuery ? XMARK : MAGNIFY"
        @click="interactive && emit('searchIconTap')"
      ></button>
    </div>

    <!-- Subtitle row -->
    <div class="BiblePassagePicker__subtitleRow">
      <button
        type="button"
        class="BiblePassagePicker__back"
        aria-label="Back"
        v-html="screen === 'books' ? XMARK : CHEV_LEFT"
        @click="interactive && emit('back')"
      ></button>
      <span
        class="BiblePassagePicker__subtitle"
        :class="{ 'BiblePassagePicker__subtitle--dim': subtitle.dim }"
      >{{ subtitle.text }}</span>
      <button
        v-if="screen === 'reader'"
        type="button"
        class="BiblePassagePicker__select"
        :disabled="!selectEnabled"
        @click="interactive && selectEnabled && emit('select')"
      >Select</button>
    </div>

    <!-- ── Books grid (OT / NT sections, 5 columns) ── -->
    <div v-if="screen === 'books'" class="BiblePassagePicker__gridScroll">
      <template v-for="section in bookSections" :key="section.key">
        <div v-if="section.key === 'nt'" class="BiblePassagePicker__sectionSpacer"></div>
        <div class="BiblePassagePicker__grid">
          <button
            v-for="b in section.books"
            :key="b.id"
            type="button"
            class="BiblePassagePicker__bookCell"
            :style="bookTileStyle(b)"
            @click="interactive && emit('selectBook', b.id)"
          >{{ b.abbreviation }}</button>
        </div>
      </template>
    </div>

    <!-- ── Chapters grid ── -->
    <div v-else-if="screen === 'chapters'" class="BiblePassagePicker__gridScroll">
      <div class="BiblePassagePicker__grid">
        <button
          v-for="tile in chapterTiles"
          :key="tile.n"
          type="button"
          class="BiblePassagePicker__numberCell"
          :class="{ 'BiblePassagePicker__numberCell--used': tile.used }"
          @click="interactive && emit('selectChapter', tile.n)"
        >{{ tile.n }}</button>
      </div>
    </div>

    <!-- ── Verses grid ── -->
    <div v-else-if="screen === 'verses'" class="BiblePassagePicker__gridScroll">
      <div class="BiblePassagePicker__grid">
        <button
          v-for="tile in verseTiles"
          :key="tile.n"
          type="button"
          class="BiblePassagePicker__numberCell"
          :class="{ 'BiblePassagePicker__numberCell--used': tile.used }"
          @click="interactive && emit('selectVerse', tile.n)"
        >{{ tile.n }}</button>
      </div>
    </div>

    <!-- ── Reader ── -->
    <div
      v-else-if="screen === 'reader'"
      ref="readerScroll"
      class="BiblePassagePicker__reader"
      @scroll="onReaderScroll"
    >
      <div class="BiblePassagePicker__chapterHeading">{{ book?.name }} {{ chapter }}</div>
      <div
        v-for="rv in readerVerses"
        :key="rv.v"
        :ref="(el) => setVerseEl(rv.v, el)"
        class="BiblePassagePicker__verse"
        @click="interactive && emit('tapVerse', rv.v)"
      >
        <span
          class="BiblePassagePicker__verseNum"
          :class="{
            'BiblePassagePicker__verseNum--used': rv.used && !rv.selected,
            'BiblePassagePicker__verseNum--selected': rv.selected,
          }"
        >{{ rv.v }}</span>
        <span
          class="BiblePassagePicker__verseText"
          :class="{
            'BiblePassagePicker__verseText--used': rv.used && !rv.selected,
            'BiblePassagePicker__verseText--selected': rv.selected,
          }"
        >{{ rv.text }}</span>
      </div>
    </div>

    <!-- ── Search results ── -->
    <div v-else-if="screen === 'search'" class="BiblePassagePicker__results">
      <!-- Loading spinner -->
      <div v-if="searchLoading" class="BiblePassagePicker__loading">
        <span class="BiblePassagePicker__spinner"></span>
      </div>

      <!-- Recents (empty query) -->
      <template v-else-if="showRecents">
        <div v-if="recents.length === 0" class="BiblePassagePicker__message">Type to search the Bible</div>
        <button
          v-for="q in recents"
          :key="q"
          type="button"
          class="BiblePassagePicker__recent"
          @click="interactive && emit('recentTap', q)"
        >
          <span class="BiblePassagePicker__recentIcon" v-html="CLOCK_RECENT"></span>
          <span class="BiblePassagePicker__recentQuery">{{ q }}</span>
        </button>
      </template>

      <!-- Empty -->
      <div v-else-if="showEmpty" class="BiblePassagePicker__message">No results found</div>

      <!-- Grouped results -->
      <template v-else>
        <template v-if="matchedBooks.length > 0">
          <div class="BiblePassagePicker__sectionHeader">Books</div>
          <button
            v-for="mb in matchedBooks"
            :key="mb.bookNumber"
            type="button"
            class="BiblePassagePicker__matchedBook"
            @click="interactive && emit('matchedBookTap', mb.bookNumber)"
          >
            <span class="BiblePassagePicker__matchedIcon" v-html="BOOK_CLOSED"></span>
            <span class="BiblePassagePicker__matchedText">
              <span class="BiblePassagePicker__matchedName">{{ mb.bookName }}</span>
              <span class="BiblePassagePicker__matchedDetail"
                >{{ mb.chapters }} chapters · {{ testamentLabel(mb.testament) }}</span
              >
            </span>
          </button>
        </template>
        <template v-if="searchResults.length > 0">
          <div class="BiblePassagePicker__sectionHeader">Verses</div>
          <div
            v-for="(r, i) in searchResults"
            :key="`${r.reference}-${i}`"
            class="BiblePassagePicker__result"
            @click="interactive && emit('resultTap', r)"
          >
            <CardBibleSearchResult
              :passage="r.reference"
              :text="r.text"
              :title="r.title ?? ''"
              :description="r.summary ?? ''"
            />
          </div>
        </template>
      </template>
    </div>

    <!-- ── Version dropdown (anchored below the version button) ── -->
    <div
      v-if="versionMenuOpen"
      class="BiblePassagePicker__versionScrim"
      @click.self="interactive && emit('versionMenuClose')"
    >
      <div class="BiblePassagePicker__versionMenu">
        <button
          v-for="v in versions"
          :key="v.id"
          type="button"
          class="BiblePassagePicker__versionRow"
          @click="interactive && emit('versionPick', v.id)"
        >
          <span
            class="BiblePassagePicker__versionRadio"
            :class="{ 'BiblePassagePicker__versionRadio--selected': v.id === selectedVersionId }"
          >
            <span v-if="v.id === selectedVersionId" v-html="CHECK"></span>
          </span>
          <span class="BiblePassagePicker__versionName">{{ v.name }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
