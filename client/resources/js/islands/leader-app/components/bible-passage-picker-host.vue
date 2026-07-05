<script setup lang="ts">
// BiblePassagePickerHost — production controller for the Bible passage picker
// (iOS BibleReaderOverlayView, the UIKit sheet EditReadActivityPage presents
// for "Bible verse" add-block). Owns the screen state machine, data fetching
// (leader-bible store), the scrim + sheet chrome, and the present/dismiss
// motion (spring up ≈ iOS 0.4s damping .92; ease-in 300ms down; swipe-down
// from the top of the sheet dismisses).
//
// The visual content is the shared BiblePassagePicker twin — this host only
// feeds it props and reacts to its emits.
import { computed, onMounted, ref, watch } from 'vue'
import BiblePassagePicker, {
  type BiblePickerMatchedBook,
  type BiblePickerScreen,
  type BiblePickerSearchResult,
} from '../../../components/card/bible-passage-picker/bible-passage-picker.vue'
import { bibleBookByNumber } from '../../../utils/bible-data'
import { useLeaderBible, type VerseCompact } from '../stores/leader-bible.store'
import type { LeaderPassage } from '../stores/leader-program.store'

export interface ConfirmedPassage {
  bookNumber: number
  bookName: string
  chapterStart: number
  verseStart: number
  verseEnd: number
  selectedText: string
}

const props = defineProps<{
  open: boolean
  usedPassages: LeaderPassage[]
}>()

const emit = defineEmits<{
  close: []
  confirmed: [passage: ConfirmedPassage]
}>()

const bible = useLeaderBible()

// ── Screen state machine (iOS BibleScreen) ──
const screen = ref<BiblePickerScreen>('books')
const bookNumber = ref<number | null>(null)
const chapter = ref<number | null>(null)
const verseCount = ref(0)
const verses = ref<VerseCompact[]>([])
const scrollToVerse = ref<number | null>(null)
const selStart = ref<number | null>(null)
const selEnd = ref<number | null>(null)

// Search state (iOS: 300ms debounce, recents when the query is empty).
const searchQuery = ref('')
const searchLoading = ref(false)
const searchResults = ref<BiblePickerSearchResult[]>([])
const matchedBooks = ref<BiblePickerMatchedBook[]>([])
const recents = ref<string[]>([])
let screenBeforeSearch: BiblePickerScreen = 'books'
let enteredReaderFromSearch = false
let searchTimer: ReturnType<typeof setTimeout> | null = null
let searchSeq = 0

// Version menu.
const versionMenuOpen = ref(false)
const selectedVersionId = computed(
  () => bible.translations.find((t) => t.code === bible.selectedCode)?.id ?? '',
)

onMounted(() => void bible.loadTranslations())

// Reset to the books screen every time the sheet re-opens (iOS constructs a
// fresh overlay per presentation).
watch(
  () => props.open,
  (open) => {
    if (!open) return
    screen.value = 'books'
    bookNumber.value = null
    chapter.value = null
    verseCount.value = 0
    verses.value = []
    selStart.value = null
    selEnd.value = null
    searchQuery.value = ''
    searchResults.value = []
    matchedBooks.value = []
    versionMenuOpen.value = false
    enteredReaderFromSearch = false
    screenBeforeSearch = 'books'
    dragY.value = 0
  },
)

// ── Used-passage tinting (iOS usedBookNumbers / usedChapters / usedVerses) ──
const usedBooks = computed(() => [...new Set(props.usedPassages.map((p) => p.bookNumber))])
const usedChapters = computed(() =>
  props.usedPassages.filter((p) => p.bookNumber === bookNumber.value).map((p) => p.chapterStart),
)
const usedVerses = computed(() => {
  const out: number[] = []
  for (const p of props.usedPassages) {
    if (p.bookNumber !== bookNumber.value || p.chapterStart !== chapter.value) continue
    for (let v = p.verseStart; v <= p.verseEnd; v += 1) out.push(v)
  }
  return out
})

// ── Navigation ──
function goChapters(book: number): void {
  bookNumber.value = book
  screen.value = 'chapters'
}

async function goVerses(ch: number): Promise<void> {
  chapter.value = ch
  verseCount.value = 0
  screen.value = 'verses'
  const loaded = await bible.getChapterVerses(bookNumber.value as number, ch)
  if (loaded) verseCount.value = loaded.length
}

async function goReader(book: number, ch: number, verse: number, fromSearch: boolean): Promise<void> {
  bookNumber.value = book
  chapter.value = ch
  scrollToVerse.value = verse
  selStart.value = null
  selEnd.value = null
  enteredReaderFromSearch = fromSearch
  screen.value = 'reader'
  verses.value = (await bible.getChapterVerses(book, ch)) ?? []
}

function onBack(): void {
  switch (screen.value) {
    case 'books':
      emit('close')
      break
    case 'chapters':
      screen.value = 'books'
      break
    case 'verses':
      screen.value = 'chapters'
      break
    case 'reader':
      if (enteredReaderFromSearch) {
        enteredReaderFromSearch = false
        screen.value = 'search'
      } else {
        screen.value = 'verses'
        void goVerses(chapter.value as number)
      }
      break
    case 'search':
      clearSearch()
      screen.value = screenBeforeSearch
      break
  }
}

// ── Reader selection (iOS verse-tap: select / extend contiguous / clear) ──
function onTapVerse(v: number): void {
  if (selStart.value != null && selEnd.value != null) {
    if (v >= selStart.value && v <= selEnd.value) {
      selStart.value = null
      selEnd.value = null
      return
    }
    selStart.value = Math.min(selStart.value, v)
    selEnd.value = Math.max(selEnd.value, v)
    return
  }
  selStart.value = v
  selEnd.value = v
}

function cleanVerse(t: string): string {
  return t
    .replace(/\\n|\\r|[\n\r]/g, ' ')
    .replace(/¶/g, '')
    .replace(/ {2,}/g, ' ')
    .trim()
}

// iOS selectTapped: "{v}. {text}" per selected verse, joined by \n.
function onSelect(): void {
  const book = bookNumber.value != null ? bibleBookByNumber(bookNumber.value) : undefined
  if (!book || chapter.value == null || selStart.value == null || selEnd.value == null) return
  const selectedText = verses.value
    .filter((v) => v.v >= (selStart.value as number) && v.v <= (selEnd.value as number))
    .sort((a, b) => a.v - b.v)
    .map((v) => `${v.v}. ${cleanVerse(v.t)}`)
    .join('\n')
  const payload: ConfirmedPassage = {
    bookNumber: book.id,
    bookName: book.name,
    chapterStart: chapter.value,
    verseStart: selStart.value,
    verseEnd: selEnd.value,
    selectedText,
  }
  emit('close')
  emit('confirmed', payload)
}

// ── Search (iOS performSearch / loadRecentSearches / searchTapped) ──
function enterSearch(): void {
  if (screen.value !== 'search') {
    if (!(screen.value === 'reader' && enteredReaderFromSearch)) {
      screenBeforeSearch = screen.value
    }
    screen.value = 'search'
  }
  void loadRecents()
}

async function loadRecents(): Promise<void> {
  recents.value = await bible.recentSearches()
}

function clearSearch(): void {
  if (searchTimer) clearTimeout(searchTimer)
  searchSeq += 1
  searchLoading.value = false
  searchQuery.value = ''
  searchResults.value = []
  matchedBooks.value = []
}

function onSearchQuery(value: string): void {
  searchQuery.value = value
  const trimmed = value.trim()
  if (trimmed) {
    runSearch(trimmed)
  } else if (screen.value === 'search') {
    if (searchTimer) clearTimeout(searchTimer)
    searchSeq += 1
    searchLoading.value = false
    searchResults.value = []
    matchedBooks.value = []
    void loadRecents()
  }
}

function runSearch(query: string): void {
  if (screen.value !== 'search') enterSearch()
  searchLoading.value = true
  if (searchTimer) clearTimeout(searchTimer)
  const seq = ++searchSeq
  searchTimer = setTimeout(async () => {
    try {
      const { results, books } = await bible.smartSearch(query)
      if (seq !== searchSeq) return
      searchResults.value = results
      matchedBooks.value = books
    } catch {
      if (seq !== searchSeq) return
      searchResults.value = []
      matchedBooks.value = []
    } finally {
      if (seq === searchSeq) searchLoading.value = false
    }
  }, 300)
}

function onSearchIconTap(): void {
  if (searchQuery.value) {
    // X: clear but stay in search with the recents state (iOS searchTapped).
    clearSearch()
    if (screen.value !== 'search') enterSearch()
    else void loadRecents()
  } else {
    enterSearch()
  }
}

function onRecentTap(q: string): void {
  searchQuery.value = q
  runSearch(q)
}

function onMatchedBookTap(book: number): void {
  clearSearch()
  goChapters(book)
}

function onResultTap(r: BiblePickerSearchResult): void {
  void goReader(r.bookNumber, r.chapter, r.verse, true)
}

// ── Version menu ──
function onVersionTap(): void {
  versionMenuOpen.value = !versionMenuOpen.value
}

function onVersionPick(id: string): void {
  const version = bible.translations.find((t) => t.id === id)
  versionMenuOpen.value = false
  if (!version) return
  bible.setTranslation(version.code)
  // In the reader, reload content with the new translation (iOS updateVersion).
  if (screen.value === 'reader' && bookNumber.value != null && chapter.value != null) {
    void goReader(bookNumber.value, chapter.value, scrollToVerse.value ?? 1, enteredReaderFromSearch)
  }
}

// ── Swipe-down dismiss (iOS: pan from the top 90px of the sheet) ──
const dragY = ref(0)
const dragging = ref(false)
let dragStartY = 0
let dragStartTime = 0

function onDragStart(e: PointerEvent): void {
  const sheet = (e.currentTarget as HTMLElement).getBoundingClientRect()
  if (e.clientY - sheet.top > 90) return
  dragging.value = true
  dragStartY = e.clientY
  dragStartTime = e.timeStamp
  ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
}

function onDragMove(e: PointerEvent): void {
  if (!dragging.value) return
  dragY.value = Math.max(0, e.clientY - dragStartY)
}

function onDragEnd(e: PointerEvent): void {
  if (!dragging.value) return
  dragging.value = false
  const dt = Math.max(1, e.timeStamp - dragStartTime)
  const velocity = dragY.value / dt // px per ms
  if (dragY.value > 120 || velocity > 0.5) {
    emit('close')
  }
  dragY.value = 0
}

const sheetStyle = computed(() => ({
  transform: dragY.value > 0 ? `translateY(${dragY.value}px)` : undefined,
  transition: dragging.value ? 'none' : undefined,
}))
</script>

<template>
  <Transition name="BiblePickerHost">
    <div v-if="open" class="BiblePickerHost__scrim">
      <div
        class="BiblePickerHost__sheet"
        :style="sheetStyle"
        @pointerdown="onDragStart"
        @pointermove="onDragMove"
        @pointerup="onDragEnd"
        @pointercancel="onDragEnd"
      >
        <BiblePassagePicker
          interactive
          :screen="screen"
          :version-code="bible.selectedCode"
          :book-number="bookNumber"
          :chapter="chapter"
          :verse-count="verseCount"
          :verses="verses"
          :scroll-to-verse="scrollToVerse"
          :selection-start="selStart"
          :selection-end="selEnd"
          :used-books="usedBooks"
          :used-chapters="usedChapters"
          :used-verses="usedVerses"
          :search-query="searchQuery"
          :search-loading="searchLoading"
          :search-results="searchResults"
          :matched-books="matchedBooks"
          :recents="recents"
          :versions="bible.translations"
          :version-menu-open="versionMenuOpen"
          :selected-version-id="selectedVersionId"
          @back="onBack"
          @select="onSelect"
          @select-book="goChapters"
          @select-chapter="goVerses"
          @select-verse="(v) => goReader(bookNumber as number, chapter as number, v, false)"
          @tap-verse="onTapVerse"
          @book-list="screen = 'books'"
          @version-tap="onVersionTap"
          @version-pick="onVersionPick"
          @version-menu-close="versionMenuOpen = false"
          @search-focus="enterSearch"
          @search-icon-tap="onSearchIconTap"
          @update:search-query="onSearchQuery"
          @recent-tap="onRecentTap"
          @matched-book-tap="onMatchedBookTap"
          @result-tap="onResultTap"
        />
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.BiblePickerHost__scrim {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 12;
  display: flex;
  flex-direction: column;
}

.BiblePickerHost__sheet {
  flex: 1 1 auto;
  min-height: 0;
  margin-top: 10px; /* iOS safeTop + 10 (the pane already sits under the top inset) */
  display: flex;
  flex-direction: column;
  touch-action: none;
}

.BiblePickerHost__sheet > :deep(.BiblePassagePicker) {
  flex: 1 1 auto;
  min-height: 0;
}

/* Present ≈ iOS spring(response 0.4, damping .92); dismiss 300ms ease-in. */
.BiblePickerHost-enter-active {
  transition: opacity 400ms cubic-bezier(0.32, 0.72, 0, 1);
}
.BiblePickerHost-enter-active .BiblePickerHost__sheet {
  transition: transform 400ms cubic-bezier(0.32, 0.72, 0, 1);
}
.BiblePickerHost-leave-active {
  transition: opacity 300ms cubic-bezier(0.42, 0, 1, 1);
}
.BiblePickerHost-leave-active .BiblePickerHost__sheet {
  transition: transform 300ms cubic-bezier(0.42, 0, 1, 1);
}
.BiblePickerHost-enter-from,
.BiblePickerHost-leave-to {
  opacity: 1;
  background: rgba(0, 0, 0, 0);
}
.BiblePickerHost-enter-from .BiblePickerHost__sheet,
.BiblePickerHost-leave-to .BiblePickerHost__sheet {
  transform: translateY(100%);
}
</style>
