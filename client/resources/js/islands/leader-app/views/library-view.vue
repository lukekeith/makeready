<script setup lang="ts">
// LibraryView — the "Library" tab of the mobile leader app, a production rebuild
// of the iPhone MainLibrary (Pages/Main/MainLibrary.swift). Two sub-tabs driven
// by the shared PageHeader twin:
//   • Programs — currently-enrolled rail (CardStudyMini) + "Browse all" list
//     (CardProgramFull), client-side search over name/description/tags
//   • Media    — full-bleed 3-column square grid, server-side search (?q=,
//     debounced 300ms like the iPhone)
// Header trailing actions mirror iOS: an import button (square.and.arrow.down,
// the .makeready program import — flow not wired yet) and a plus button that
// opens the "Create New" ActionCardMenu (Study Program / Media).
// All data comes from the /admin/api proxy via the leader-library store.
import { computed, inject, onBeforeUnmount, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../../../components/card/page-header/page-header.vue'
import SearchField from '../../../components/card/search-field/search-field.vue'
import CardProgramFull from '../../../components/card/card-program-full/card-program-full.vue'
import SwipeableCard from '../../../components/card/swipeable-card/swipeable-card.vue'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import CardStudyMini from '../../../components/card/card-study-mini/card-study-mini.vue'
import SkeletonCardProgramFull from '../../../components/card/skeleton-card-program-full/skeleton-card-program-full.vue'
import FilterChipDropdown from '../../../components/card/filter-chip-dropdown/filter-chip-dropdown.vue'
import LibraryAddMenu from '../components/library-add-menu.vue'
import LibrarySortMenu from '../components/library-sort-menu.vue'
import ProgramHomeModal from '../components/program-home-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'
import {
  MEDIA_SORTS,
  MEDIA_TIMES,
  MEDIA_TYPES,
  PROGRAM_SORTS,
  mediaTimeCutoff,
  useLeaderLibrary,
} from '../stores/leader-library.store'

const store = useLeaderLibrary()
const route = useRoute()
const router = useRouter()
const overlayManager = useOverlayManager()

// iOS MainLibrary presentProgramHome(): tapping a program card presents the
// .programHome modal (vertical slide-up sheet).
function openProgram(id: string): void {
  overlayManager.present(ROUTES.programHome, ProgramHomeModal, { programId: id })
}

// Each tab is its own route (/admin/library/{programs,media}) so it's
// deep-linkable and survives a refresh (same pattern as the Groups page).
const TAB_SLUGS = ['programs', 'media'] as const
const activeTab = computed(() => {
  const i = TAB_SLUGS.indexOf((route.meta.libraryTab as typeof TAB_SLUGS[number]) ?? 'programs')
  return i < 0 ? 0 : i
})
function selectTab(index: number): void {
  const path = `/admin/library/${TAB_SLUGS[index]}`
  if (route.path !== path) router.push(path)
}

// Saved filters must apply BEFORE the first fetch (iOS loadFiltersFromServer
// runs in .task before content loads) — otherwise the list flashes unfiltered.
let filtersReady = false
async function initFilters(): Promise<void> {
  await store.loadFilters(memberId)
  filtersReady = true
  store.loadFilterOptions() // fire-and-forget; panels show once loaded
  if (activeTab.value === 0) store.loadPrograms()
  else store.loadMedia()
}

watch(activeTab, (tab) => {
  if (!filtersReady) return
  if (tab === 0) store.loadPrograms()
  else store.loadMedia()
})

// ── Search (per iOS: programs filter client-side; media re-query the server
//    with ?q=, debounced 300ms; cleared on tab switch) ──
const search = ref('')
let mediaDebounce: ReturnType<typeof setTimeout> | null = null

watch(activeTab, () => {
  search.value = ''
  expandedDropdown.value = null
  store.searchMedia('')
})

watch(search, (q) => {
  if (activeTab.value !== 1) return
  if (mediaDebounce) clearTimeout(mediaDebounce)
  mediaDebounce = setTimeout(() => store.searchMedia(q), 300)
})

onBeforeUnmount(() => {
  if (mediaDebounce) clearTimeout(mediaDebounce)
})

const searchPlaceholder = computed(() =>
  activeTab.value === 1 ? 'Search media library' : 'Search studies, tags, authors...',
)

// ── Filter chips + dropdown panels (iOS FilterChipDropdown) ──
//
// One panel open at a time (iOS expandedDropdown @State); toggling is INSTANT
// (no animation on iOS). Tags/leaders/type changes refetch server-side; the
// media time filter is client-side. Every change persists via the store's
// debounced FilterState save.
type DropdownId = 'tags' | 'leaders' | 'type' | 'time'
const expandedDropdown = ref<DropdownId | null>(null)

function toggleDropdown(id: DropdownId): void {
  expandedDropdown.value = expandedDropdown.value === id ? null : id
}

function leaderChipLabel(selected: string[]): string {
  if (!selected.length) return 'All leaders'
  if (selected.length === 1) {
    if (selected[0] === memberId) return 'My content'
    const leader = store.filterLeaders.find((l) => l.id === selected[0])
    return leader?.name || '1 group leader'
  }
  return `${selected.length} group leaders`
}

function tagChipLabel(selected: string[], allLabel: string): string {
  if (!selected.length) return allLabel
  return selected.length === 1 ? selected[0] : `${selected.length} tags`
}

interface ChipDef {
  id: DropdownId
  label: string
  active: boolean
}

const filterChips = computed<ChipDef[]>(() =>
  activeTab.value === 1
    ? [
        { id: 'tags', label: tagChipLabel(store.mediaTags, 'All tags'), active: store.mediaTags.length > 0 },
        { id: 'leaders', label: leaderChipLabel(store.mediaLeaders), active: store.mediaLeaders.length > 0 },
        { id: 'type', label: store.mediaType, active: store.mediaType !== 'All' },
        { id: 'time', label: store.mediaTime, active: store.mediaTime !== 'All time' },
      ]
    : [
        { id: 'tags', label: tagChipLabel(store.programTags, 'All tags'), active: store.programTags.length > 0 },
        { id: 'leaders', label: leaderChipLabel(store.programLeaders), active: store.programLeaders.length > 0 },
      ],
)

// Panel props for the open dropdown (iOS programsDropdownOverlay/media…).
const panel = computed(() => {
  const id = expandedDropdown.value
  if (!id) return null
  const isMedia = activeTab.value === 1
  if (id === 'tags') {
    const all = isMedia ? store.allMediaTags : store.allProgramTags
    return {
      items: all.map((t) => ({ id: t, label: t })),
      selectedIds: isMedia ? store.mediaTags : store.programTags,
      showClearAll: true,
      emptyMessage: isMedia
        ? 'No tags have been added to your media yet.'
        : 'No tags have been added to your programs yet.',
    }
  }
  if (id === 'leaders') {
    return {
      items: store.filterLeaders.map((l) => ({
        id: l.id,
        label: `${l.name} (${isMedia ? l.mediaCount : l.programCount})`,
      })),
      selectedIds: isMedia ? store.mediaLeaders : store.programLeaders,
      showClearAll: true,
      emptyMessage: 'You are the only group leader in this org.',
    }
  }
  if (id === 'type') {
    return {
      items: MEDIA_TYPES.map((t) => ({ id: t, label: t })),
      selectedIds: [store.mediaType],
      showClearAll: false,
      emptyMessage: '',
    }
  }
  return {
    items: MEDIA_TIMES.map((t) => ({ id: t, label: t })),
    selectedIds: [store.mediaTime],
    showClearAll: false,
    emptyMessage: '',
  }
})

// Refetch the active tab's list with the current filters (iOS onChange →
// loadX(forceRefresh: true); media keeps live search text via searchMedia).
function refetchActive(): void {
  if (activeTab.value === 0) store.loadPrograms(true)
  else if (search.value.trim()) store.searchMedia(search.value)
  else store.loadMedia(true)
}

function toggleIn(list: string[], value: string): string[] {
  return list.includes(value) ? list.filter((v) => v !== value) : [...list, value]
}

function onPanelToggle(value: string): void {
  const id = expandedDropdown.value
  const isMedia = activeTab.value === 1
  if (id === 'tags') {
    if (isMedia) store.mediaTags = toggleIn(store.mediaTags, value)
    else store.programTags = toggleIn(store.programTags, value)
  } else if (id === 'leaders') {
    if (isMedia) store.mediaLeaders = toggleIn(store.mediaLeaders, value)
    else store.programLeaders = toggleIn(store.programLeaders, value)
  } else if (id === 'type') {
    store.mediaType = value
    expandedDropdown.value = null // iOS single-select closes on pick
  } else if (id === 'time') {
    store.mediaTime = value
    expandedDropdown.value = null
    // Time is client-side only — persist without refetching.
    store.scheduleSave('library.media')
    return
  }
  refetchActive()
  store.scheduleSave(isMedia ? 'library.media' : 'library.programs')
}

function onPanelClearAll(): void {
  const id = expandedDropdown.value
  const isMedia = activeTab.value === 1
  if (id === 'tags') {
    if (isMedia) store.mediaTags = []
    else store.programTags = []
  } else if (id === 'leaders') {
    if (isMedia) store.mediaLeaders = []
    else store.programLeaders = []
  }
  refetchActive()
  store.scheduleSave(isMedia ? 'library.media' : 'library.programs')
}

// ── Sort menus (iOS native Menu → managed-menu bottom card on web) ──
const sortLabel = computed(() =>
  activeTab.value === 1 ? store.mediaSort : store.programSort,
)

function onSortTap(): void {
  const isMedia = activeTab.value === 1
  overlayManager.present(ROUTES.librarySortMenu, LibrarySortMenu, {
    options: isMedia ? [...MEDIA_SORTS] : [...PROGRAM_SORTS],
    selected: isMedia ? store.mediaSort : store.programSort,
    onPick: (option: string) => {
      if (isMedia) store.mediaSort = option
      else store.programSort = option
      store.scheduleSave(isMedia ? 'library.media' : 'library.programs')
    },
  })
}

// ── Programs tab ──
// iOS browsePrograms: client-side search predicate (name/description/tags)
// then the selected sort. Tag/leader filtering is already server-side.
const filteredPrograms = computed(() => {
  const q = search.value.trim().toLowerCase()
  let rows = store.programs
  if (q) {
    rows = rows.filter(
      (p) =>
        p.title.toLowerCase().includes(q) ||
        p.description.toLowerCase().includes(q) ||
        p.tags.some((t) => t.toLowerCase().includes(q)),
    )
  }
  const sorted = [...rows]
  if (store.programSort === 'Most popular') {
    sorted.sort((a, b) => b.enrollmentCount - a.enrollmentCount)
  } else if (store.programSort === 'A - Z') {
    sorted.sort((a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: 'base' }))
  } else {
    sorted.sort((a, b) => b.createdAt - a.createdAt) // Newest first
  }
  return sorted
})

// iOS "Currently enrolled" rail — hidden while searching OR filtering.
const enrolledPrograms = computed(() =>
  search.value || store.programTags.length || store.programLeaders.length
    ? []
    : store.programs.filter((p) => p.enrollmentCount > 0),
)

// ── Media tab: sort + client-side time cutoff (iOS filteredMedia) ──
const visibleMedia = computed(() => {
  let rows = [...store.media]
  if (store.mediaSort === 'Most used') rows.sort((a, b) => b.usageCount - a.usageCount)
  else if (store.mediaSort === 'A - Z')
    rows.sort((a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: 'base' }))
  const cutoff = mediaTimeCutoff(store.mediaTime)
  if (cutoff != null) rows = rows.filter((m) => m.createdAt >= cutoff)
  return rows
})

const mediaFiltersActive = computed(
  () =>
    store.mediaTags.length > 0 ||
    store.mediaLeaders.length > 0 ||
    store.mediaType !== 'All' ||
    store.mediaTime !== 'All time',
)

// iOS CardProgramFull metadata: calendar (days), clock (weeks), person.2
// (enrollments, only when > 0).
const CALENDAR =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>'
const CLOCK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'
const PERSON_2 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7.5" r="3.3"/><path d="M3 19.5c0-3.3 2.7-5.6 6-5.6s6 2.3 6 5.6"/><path d="M15.2 4.6a3.3 3.3 0 0 1 0 6"/><path d="M16.6 14.2c2.5.5 4.4 2.6 4.4 5.3"/></svg>'

function programDataItems(p: { days: number; enrollmentCount: number }) {
  const weeks = Math.ceil((p.days || 0) / 7)
  const items = [
    { icon: CALENDAR, value: String(p.days ?? 0) },
    { icon: CLOCK, value: `${weeks} ${weeks === 1 ? 'week' : 'weeks'}` },
  ]
  if (p.enrollmentCount > 0) items.push({ icon: PERSON_2, value: String(p.enrollmentCount) })
  return items
}

// SF "book.fill" — CardStudyMini icon-well fallback for cover-less programs.
const BOOK_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 6.6C9.4 5.4 7.3 4.7 5 4.7c-.95 0-1.9.12-2.8.36A1.5 1.5 0 0 0 1 6.5v10.8c0 .98.92 1.68 1.86 1.43A9.6 9.6 0 0 1 5 18.4c2 0 3.9.58 5.5 1.66.3.2.5-.02.5-.36V7.2c0-.24-.1-.46-.3-.6Z"/><path d="M13 6.6C14.6 5.4 16.7 4.7 19 4.7c.95 0 1.9.12 2.8.36A1.5 1.5 0 0 1 23 6.5v10.8c0 .98-.92 1.68-1.86 1.43A9.6 9.6 0 0 0 19 18.4c-2 0-3.9.58-5.5 1.66-.3.2-.5-.02-.5-.36V7.2c0-.24.1-.46.3-.6Z"/></svg>'

function miniImageStyle(p: { coverUrl: string | null }) {
  return p.coverUrl
    ? { kind: 'photo' as const, url: p.coverUrl }
    : { kind: 'icon' as const, icon: BOOK_FILL }
}

// ── Media tab ──
// iOS MediaThumbnailCell: duration badge for video/audio ("m:ss" / "h:mm:ss"),
// usage-count badge, type glyph when no thumbnail resolves.
function formatDuration(seconds: number): string {
  const s = Math.max(0, Math.round(seconds))
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = String(s % 60).padStart(2, '0')
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${sec}` : `${m}:${sec}`
}

const PLAY_FILL = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.5v13l11-6.5z"/></svg>'
const PHOTO_GLYPH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="M21 16l-5-5-9 9"/></svg>'
const DOC_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 2h8l5 5v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zm8 1.5V8h4.5z"/></svg>'
const WAVEFORM =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 10v4M7 7v10M11 4v16M15 8v8M19 6v12M23 10v4" transform="scale(0.92)"/></svg>'

function mediaGlyph(type: string): string {
  if (type === 'video') return PLAY_FILL
  if (type === 'document') return DOC_FILL
  if (type === 'audio') return WAVEFORM
  return PHOTO_GLYPH
}

// ── Header actions + "Create New" menu (iOS: import + plus → ActionCardMenu) ──
const IMPORT_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12"/><path d="M8 11l4 4 4-4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
const SORT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M6 12h12M10 18h4"/></svg>'
const CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9l7 7 7-7"/></svg>'

// iOS MainLibrary: plus → present(.libraryAddMenu) — ManagedMenuView chrome
// via the overlay manager; the menu content handles its own dismissThen →
// .createProgram sequencing (library-add-menu.vue).
function onCreateTap(): void {
  overlayManager.present(ROUTES.libraryAddMenu, LibraryAddMenu, {})
}

// ── Swipe-to-delete (iOS MainLibrary programsList SwipeableCard) ──
// Creator-only: iOS gates on program.isEditable(by: currentUser.id).
const memberId = inject<string | null>('memberId', null)

function isOwn(p: { creatorId: string | null }): boolean {
  return Boolean(memberId && p.creatorId && p.creatorId === memberId)
}

// Kick off after memberId is available (loadFilters needs it for the iOS
// "My content" default when no saved preference exists).
initFilters()

// SF "trash" — the single .delete slide button.
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'
const DELETE_BUTTONS = [{ icon: TRASH, variant: 'delete' as const }]

// iOS native .alert "Delete Program?" — exact strings, via the shared
// confirm-dialog service (ConfirmDialogHost renders it full-screen).
const confirmDialog = useConfirmDialog()
const deletingProgram = ref(false)

async function requestDeleteProgram(target: { id: string; title: string }): Promise<void> {
  if (deletingProgram.value) return
  const choice = await confirmDialog.confirm({
    title: 'Delete Program?',
    message: `This will permanently delete "${target.title}" and all its lessons.`,
    buttons: [
      { label: 'Delete', style: 'destructive' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0 || deletingProgram.value) return
  deletingProgram.value = true
  try {
    await store.deleteProgram(target.id)
  } catch (err) {
    void confirmDialog.confirm({
      title: 'Something went wrong',
      message: err instanceof Error ? err.message : 'Failed to delete program',
      buttons: [{ label: 'OK', style: 'secondary' }],
    })
  } finally {
    deletingProgram.value = false
  }
}
</script>

<template>
  <div class="LeaderLibrary">
    <div class="LeaderLibrary__top">
      <div class="LeaderLibrary__headerRow">
        <PageHeader
          class="LeaderLibrary__header"
          :tabs="['Programs', 'Media']"
          :active-tab="activeTab"
          @select="selectTab"
        />
        <div class="LeaderLibrary__actions">
          <button
            class="LeaderLibrary__actionBtn"
            type="button"
            aria-label="Import program"
            v-html="IMPORT_ICON"
          ></button>
          <button
            class="LeaderLibrary__actionBtn"
            type="button"
            aria-label="Create new"
            v-html="PLUS"
            @click="onCreateTap"
          ></button>
        </div>
      </div>
      <div class="LeaderLibrary__searchWrap">
        <SearchField
          interactive
          :is-active="!!search"
          :search-text="search"
          :placeholder="searchPlaceholder"
          @update:search-text="search = $event"
        />
      </div>
      <div class="LeaderLibrary__filters">
        <button
          v-for="chip in filterChips"
          :key="chip.id"
          type="button"
          class="LeaderLibrary__chip"
          :class="{ 'LeaderLibrary__chip--active': chip.active }"
          @click="toggleDropdown(chip.id)"
        >
          {{ chip.label }}<span class="LeaderLibrary__chipChevron" v-html="CHEVRON"></span>
        </button>
      </div>

      <!-- Dropdown panel (iOS FilterChipDropdownPanel overlay — appears
           INSTANTLY, no animation; anchored below the chip row). -->
      <div v-if="panel" class="LeaderLibrary__panelWrap">
        <FilterChipDropdown
          interactive
          :items="panel.items"
          :selected-ids="panel.selectedIds"
          :show-clear-all="panel.showClearAll"
          :empty-message="panel.emptyMessage"
          @toggle="onPanelToggle"
          @clear-all="onPanelClearAll"
        />
      </div>
    </div>

    <!-- Full-bleed dim layer behind the open panel (iOS dropdownDimLayer,
         black@0.5, tap dismisses). -->
    <div
      v-if="expandedDropdown"
      class="LeaderLibrary__panelScrim"
      @click="expandedDropdown = null"
    ></div>

    <!-- ── Programs tab ── -->
    <div v-show="activeTab === 0" class="LeaderLibrary__scroll">
      <div v-if="store.programsLoading && !store.programs.length" class="LeaderLibrary__list">
        <SkeletonCardProgramFull />
        <SkeletonCardProgramFull />
      </div>
      <div v-else-if="store.programsError" class="LeaderLibrary__state">
        {{ store.programsError }}
      </div>
      <div v-else-if="!store.programs.length" class="LeaderLibrary__empty">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15z" /><path d="M4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5" />
        </svg>
        <p class="LeaderLibrary__emptyTitle">No Study Programs</p>
        <p class="LeaderLibrary__emptySub">Create your first study program to get started</p>
      </div>
      <template v-else>
        <!-- Currently enrolled rail (hidden while searching, like iOS). -->
        <template v-if="!search && enrolledPrograms.length">
          <div class="LeaderLibrary__sectionRow">
            <span class="LeaderLibrary__sectionTitle">Currently enrolled</span>
            <span class="LeaderLibrary__sectionAccent">{{ enrolledPrograms.length }} active</span>
          </div>
          <div class="LeaderLibrary__rail">
            <CardStudyMini
              v-for="p in enrolledPrograms"
              :key="p.id"
              :title="p.title"
              :image-style="miniImageStyle(p)"
              :metadata="[{ icon: CLOCK, value: `${p.days} days` }]"
            />
          </div>
        </template>

        <!-- Browse all + sort (iOS native Menu → managed-menu on web). -->
        <div class="LeaderLibrary__sectionRow">
          <span class="LeaderLibrary__sectionTitle">Browse all</span>
          <button type="button" class="LeaderLibrary__sort" @click="onSortTap">
            {{ sortLabel }}<span class="LeaderLibrary__sortIcon" v-html="SORT"></span>
          </button>
        </div>
        <div v-if="!filteredPrograms.length" class="LeaderLibrary__state">No programs found</div>
        <div v-else class="LeaderLibrary__list">
          <!-- iOS MainLibrary: own programs sit in a SwipeableCard with a
               trash button; others render inert (isSwipeEnabled: false). -->
          <SwipeableCard
            v-for="p in filteredPrograms"
            :key="p.id"
            bare
            :slide-buttons="isOwn(p) ? DELETE_BUTTONS : []"
            :is-swipe-enabled="isOwn(p) && !deletingProgram"
            @action="requestDeleteProgram({ id: p.id, title: p.title })"
            @tap="openProgram(p.id)"
          >
            <CardProgramFull
              :title="p.title"
              :description="p.description || undefined"
              :tags="p.tags"
              :data-items="programDataItems(p)"
              :author-name="p.authorName || undefined"
              :relative-date="p.relativeDate || undefined"
              :published="p.published"
              :cover-url="p.coverUrl || undefined"
            />
          </SwipeableCard>
        </div>
      </template>
    </div>

    <!-- ── Media tab ── -->
    <div v-show="activeTab === 1" class="LeaderLibrary__scroll LeaderLibrary__scroll--media">
      <div v-if="store.mediaLoading && !store.media.length" class="LeaderLibrary__grid">
        <span v-for="i in 9" :key="i" class="LeaderLibrary__cellSkeleton"></span>
      </div>
      <div v-else-if="store.mediaError" class="LeaderLibrary__state">{{ store.mediaError }}</div>
      <div
        v-else-if="!visibleMedia.length && !search && !mediaFiltersActive"
        class="LeaderLibrary__empty"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <rect x="7" y="3" width="14" height="11" rx="2" /><circle cx="11" cy="7" r="1.3" /><path d="M8 12.5l3-3.2 2.4 2.4 2.4-2.8L20 13" /><path d="M17 17H5a2 2 0 0 1-2-2V7" />
        </svg>
        <p class="LeaderLibrary__emptyTitle LeaderLibrary__emptyTitle--dim">No Media</p>
      </div>
      <div v-else-if="!visibleMedia.length" class="LeaderLibrary__state">
        {{ search ? `No results for “${search}”` : 'No media found' }}
      </div>
      <template v-else>
        <!-- Browse all + sort (media header mirrors the Programs one). -->
        <div class="LeaderLibrary__sectionRow LeaderLibrary__sectionRow--media">
          <span class="LeaderLibrary__sectionTitle">Browse all</span>
          <button type="button" class="LeaderLibrary__sort" @click="onSortTap">
            {{ sortLabel }}<span class="LeaderLibrary__sortIcon" v-html="SORT"></span>
          </button>
        </div>
        <div class="LeaderLibrary__grid">
        <div v-for="m in visibleMedia" :key="m.id" class="LeaderLibrary__cell">
          <img
            v-if="m.thumbnailUrl"
            class="LeaderLibrary__cellImage"
            :src="m.thumbnailUrl"
            :alt="m.title"
            loading="lazy"
          />
          <span v-else class="LeaderLibrary__cellGlyph" v-html="mediaGlyph(m.type)"></span>
          <span v-if="m.usageCount > 0" class="LeaderLibrary__cellBadge LeaderLibrary__cellBadge--usage">
            {{ m.usageCount }}
          </span>
          <span
            v-if="(m.type === 'video' || m.type === 'audio') && m.duration"
            class="LeaderLibrary__cellBadge LeaderLibrary__cellBadge--duration"
          >
            {{ formatDuration(m.duration) }}
          </span>
        </div>
        </div>
      </template>
    </div>


  </div>
</template>

<style scoped>
.LeaderLibrary {
  display: flex;
  flex-direction: column;
}

/* Fixed top region (tabs + search + filter pills): frosted, content scrolls
   underneath — same treatment as the Groups page top bar. */
.LeaderLibrary__top {
  position: sticky;
  top: 0;
  z-index: 5;
  background: var(--surface-nav);
  backdrop-filter: blur(var(--blur-lg));
  -webkit-backdrop-filter: blur(var(--blur-lg));
}

.LeaderLibrary__headerRow {
  position: relative;
  min-height: var(--header-height);
}

/* Trailing actions — 32px white@10% circles (iOS import + plus). */
.LeaderLibrary__actions {
  position: absolute;
  top: 19px;
  right: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.LeaderLibrary__actionBtn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 50%;
  background: var(--color-white-10);
  color: #fff;
  cursor: pointer;
}

.LeaderLibrary__actionBtn :deep(svg) {
  width: 16px;
  height: 16px;
  display: block;
}

.LeaderLibrary__searchWrap {
  padding: 0 16px;
}

/* Filter pills (iOS FilterChipDropdownTrigger row). */
.LeaderLibrary__filters {
  display: flex;
  gap: 8px;
  padding: 12px 16px 8px;
  overflow-x: auto;
  scrollbar-width: none;
}

.LeaderLibrary__chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border: none;
  border-radius: 999px;
  background: var(--color-white-10);
  font-family: inherit;
  font-size: 13px;
  font-weight: 500;
  color: var(--color-white-70);
  white-space: nowrap;
  cursor: pointer;
}

/* iOS active trigger: solid white capsule, appBackground label + chevron. */
.LeaderLibrary__chip--active {
  background: #fff;
  color: var(--color-canvas);
}

.LeaderLibrary__chipChevron {
  display: inline-flex;
  width: 10px;
  height: 10px;
  color: var(--color-white-50);
}

.LeaderLibrary__chip--active .LeaderLibrary__chipChevron {
  color: var(--color-canvas);
}

.LeaderLibrary__chipChevron :deep(svg) {
  width: 10px;
  height: 10px;
  display: block;
}

/* Dropdown panel anchored under the fixed top region (iOS overlay offset).
   No transition — the iOS panel pops in with no animation. */
.LeaderLibrary__panelWrap {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  padding: 8px 16px 0;
  z-index: 6;
}

/* iOS dropdownDimLayer: black@0.5 over the content, tap dismisses. Sits under
   the sticky top region (z 5) so the search + chips stay visible. */
.LeaderLibrary__panelScrim {
  position: fixed;
  inset: 0;
  z-index: 4;
  background: rgba(0, 0, 0, 0.5);
}

.LeaderLibrary__scroll {
  padding: 8px 16px 16px;
}

/* The media grid is full-bleed (iOS edge-to-edge collection view). */
.LeaderLibrary__scroll--media {
  padding: 8px 0 16px;
}

/* Section header rows (Currently enrolled / Browse all). */
.LeaderLibrary__sectionRow {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0 4px;
}

.LeaderLibrary__sectionTitle {
  font-size: 17px;
  font-weight: 700;
  color: #fff;
}

.LeaderLibrary__sectionAccent {
  font-size: 14px;
  font-weight: 600;
  color: var(--color-brand-500);
}

.LeaderLibrary__sort {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border: none;
  background: none;
  padding: 0;
  font-family: inherit;
  font-size: 14px;
  font-weight: 500;
  color: var(--color-white-70);
  cursor: pointer;
}

/* The media scroll container is full-bleed; its section row supplies its own
   16px gutters (the Programs one inherits them from the scroll padding). */
.LeaderLibrary__sectionRow--media {
  padding-left: 16px;
  padding-right: 16px;
}

.LeaderLibrary__sortIcon {
  display: inline-flex;
  width: 14px;
  height: 14px;
  color: var(--color-white-70);
}

.LeaderLibrary__sortIcon :deep(svg) {
  width: 14px;
  height: 14px;
  display: block;
}

/* Currently-enrolled horizontal rail (iOS horizontal ScrollView, 12px gaps). */
.LeaderLibrary__rail {
  display: flex;
  gap: 12px;
  overflow-x: auto;
  padding: 8px 0 4px;
  scrollbar-width: none;
}

.LeaderLibrary__rail > * {
  flex: 0 0 auto;
}

/* Program cards (iOS VStack(spacing: 12)). */
.LeaderLibrary__list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-top: 8px;
}

/* Media grid — 3 columns, 2px gaps, square cells (iOS UICollectionView). */
.LeaderLibrary__grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
}

.LeaderLibrary__cell {
  position: relative;
  aspect-ratio: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-white-5);
  overflow: hidden;
}

.LeaderLibrary__cellImage {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.LeaderLibrary__cellGlyph {
  display: inline-flex;
  width: 34px;
  height: 34px;
  color: var(--color-white-20);
}

.LeaderLibrary__cellGlyph :deep(svg) {
  width: 100%;
  height: 100%;
}

.LeaderLibrary__cellSkeleton {
  aspect-ratio: 1;
  background: var(--color-white-5);
}

/* Corner badges (iOS 11pt bold on black@60% pills). */
.LeaderLibrary__cellBadge {
  position: absolute;
  padding: 2px 6px;
  border-radius: 8px;
  background: rgba(0, 0, 0, 0.6);
  font-size: 11px;
  font-weight: 700;
  color: #fff;
  line-height: 1.3;
}

.LeaderLibrary__cellBadge--usage {
  top: 6px;
  left: 6px;
}

.LeaderLibrary__cellBadge--duration {
  bottom: 6px;
  right: 6px;
}

.LeaderLibrary__state {
  padding: 40px 16px;
  text-align: center;
  font-size: 15px;
  color: var(--color-white-50);
}

.LeaderLibrary__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 64px 24px;
  text-align: center;
}

.LeaderLibrary__empty svg {
  width: 48px;
  height: 48px;
  color: var(--color-white-20);
}

.LeaderLibrary__emptyTitle {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #fff;
}

/* iOS "No Media" title renders white@20. */
.LeaderLibrary__emptyTitle--dim {
  color: var(--color-white-20);
}

.LeaderLibrary__emptySub {
  margin: 0;
  font-size: 15px;
  color: var(--color-white-50);
  max-width: 260px;
}

</style>
