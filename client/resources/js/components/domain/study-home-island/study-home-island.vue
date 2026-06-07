<script setup lang="ts">
import { ref, computed, nextTick } from 'vue'
import LessonNav from './lesson-nav.vue'
import LessonCard from './lesson-card.vue'
import StudyCalendar from './study-calendar.vue'
import { createStudyHomeState, type StudyLesson } from './use-study-home-state'
import './study-home-island.scss'

interface Props {
  title: string
  coverImageUrl?: string | null
  backHref?: string
  isPreview?: boolean
  lessons: StudyLesson[]
  firstDate?: string | null
  lastDate?: string | null
  activeDays?: number[]
}

const props = withDefaults(defineProps<Props>(), {
  coverImageUrl: null,
  backHref: '',
  isPreview: false,
  firstDate: null,
  lastDate: null,
  activeDays: () => [],
})

// Preview programs carry no enrollment dates, so synthesize a schedule starting
// today (the day the leader is viewing) so the calendar can render. Lessons are
// placed on weekdays only (Mon–Fri), skipping weekends. The LessonCard still
// shows "Day N" in preview (it ignores dates).
function addDays(d: Date, n: number): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n)
}
function isWeekend(d: Date): boolean {
  const dow = d.getDay()
  return dow === 0 || dow === 6
}
function weekdayDates(start: Date, count: number): Date[] {
  const out: Date[] = []
  let d = new Date(start)
  while (out.length < count) {
    if (!isWeekend(d)) out.push(d)
    d = addDays(d, 1)
  }
  return out
}
const previewBase = new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())
const baseLessons = props.lessons ?? []

const previewDates = props.isPreview ? weekdayDates(previewBase, baseLessons.length) : []
const stateLessons = props.isPreview
  ? baseLessons.map((l, i) => ({ ...l, scheduledDate: previewDates[i].toISOString() }))
  : baseLessons
const stateFirstDate = props.isPreview
  ? (previewDates[0] ?? previewBase).toISOString()
  : props.firstDate
const stateLastDate = props.isPreview
  ? (previewDates[previewDates.length - 1] ?? previewBase).toISOString()
  : props.lastDate

const state = createStudyHomeState({
  lessons: stateLessons,
  isPreview: props.isPreview,
  firstDate: stateFirstDate,
  lastDate: stateLastDate,
  activeDays: props.activeDays,
})

// Now that preview also has (synthetic) dates, the calendar renders in both modes.
const showCalendar = computed(() => state.lessons.value.some((l) => !!l.scheduledDate))

// Ids of fully-completed lessons — drives the calendar cells' completed styling.
const completedIds = computed(() =>
  state.lessons.value.filter((l) => state.lessonState(l) === 'complete').map((l) => l.id)
)

// Badge for the selected lesson card: COMPLETE when done, UP NEXT when it's the
// lesson the member should do next, otherwise none.
const selectedBadge = computed(() => {
  if (state.selectedState.value === 'complete') return 'COMPLETE'
  if (state.selectedIndex.value === state.nextIndex.value) return 'UP NEXT'
  return null
})
const selectedBadgeVariant = computed(() =>
  state.selectedState.value === 'complete' ? 'complete' : 'next'
)

// Id of the "up next" lesson (the one the member should do next), unless it's
// already complete — drives the calendar cell's up-next styling.
const upNextId = computed(() => {
  const next = state.lessons.value[state.nextIndex.value]
  if (!next || state.lessonState(next) === 'complete') return null
  return next.id
})

// ─── Parallax background (moves at 25% of scroll speed) ──────────────────────
const scrollEl = ref<HTMLElement | null>(null)
const navSectionEl = ref<HTMLElement | null>(null)
const bgOffset = ref(0)
function onScroll() {
  if (scrollEl.value) bgOffset.value = scrollEl.value.scrollTop * 0.25
}

// After a LessonNav change, smooth-scroll the calendar so the now-selected day
// is never left hidden behind the sticky nav header (or off-screen below it).
async function scrollSelectedIntoView() {
  await nextTick()
  const scroll = scrollEl.value
  if (!scroll) return
  const cell = scroll.querySelector<HTMLElement>('.StudyCalendar__cell--selected')
  if (!cell) return

  const scrollRect = scroll.getBoundingClientRect()
  const cellRect = cell.getBoundingClientRect()
  // The sticky nav header overlaps the top of the scroll viewport, so anything
  // above its bottom edge is visually obscured.
  const headerH = navSectionEl.value?.offsetHeight ?? 0
  const margin = 16
  const visibleTop = headerH + margin
  const visibleBottom = scrollRect.height - margin

  const cellTop = cellRect.top - scrollRect.top
  const cellBottom = cellRect.bottom - scrollRect.top
  if (cellTop >= visibleTop && cellBottom <= visibleBottom) return // already fully visible

  // Position the cell just below the sticky header.
  const target = scroll.scrollTop + cellTop - visibleTop
  scroll.scrollTo({ top: Math.max(0, target), behavior: 'smooth' })
}

function navPrev() {
  state.prev()
  scrollSelectedIntoView()
}
function navNext() {
  state.next()
  scrollSelectedIntoView()
}
function navJump() {
  state.jumpToNext()
  scrollSelectedIntoView()
}

function openLesson(lesson: StudyLesson) {
  if (lesson.href) window.location.href = lesson.href
}
function goBack() {
  if (props.backHref) window.location.href = props.backHref
  else window.history.back()
}
</script>

<template>
  <div class="StudyHomeIsland">
    <!-- Parallax cover background + gradient -->
    <div class="StudyHomeIsland__bg" :style="{ transform: `translateY(${-bgOffset}px)` }">
      <div
        v-if="coverImageUrl"
        class="StudyHomeIsland__bg-image"
        :style="{ backgroundImage: `url('${coverImageUrl}')` }"
      />
      <div class="StudyHomeIsland__bg-gradient" />
    </div>

    <!-- Scrollable content -->
    <div ref="scrollEl" class="StudyHomeIsland__scroll" @scroll="onScroll">
      <div class="StudyHomeIsland__content">
        <!-- Page title -->
        <div class="StudyHomeIsland__page-title">
          <button class="StudyHomeIsland__back" aria-label="Go back" @click="goBack">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M5 12L12 19M5 12L12 5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </button>
          <h1 class="StudyHomeIsland__title">{{ title }}</h1>
        </div>

        <!-- Lesson navigation + selected card -->
        <div ref="navSectionEl" class="StudyHomeIsland__nav-section">
          <LessonNav
            :current="state.selectedIndex.value + 1"
            :total="state.totalLessons.value"
            :can-prev="state.canPrev.value"
            :can-next="state.canNext.value"
            :show-jump="state.nextIndex.value !== state.selectedIndex.value"
            @prev="navPrev"
            @next="navNext"
            @jump="navJump"
          />

          <LessonCard
            v-if="state.selected.value"
            :lesson="state.selected.value"
            :state="state.selectedState.value"
            :is-preview="isPreview"
            :days-until="state.selected.value ? state.daysUntilAvailable(state.selected.value) : 0"
            :badge="selectedBadge"
            :badge-variant="selectedBadgeVariant"
            :up-next="selectedBadge === 'UP NEXT'"
            @open="openLesson"
          />
        </div>

        <!-- Calendar -->
        <StudyCalendar
          v-if="showCalendar"
          :lessons="state.lessons.value"
          :selected-id="state.selected.value?.id"
          :up-next-id="upNextId"
          :completed-ids="completedIds"
          :first-date="stateFirstDate"
          :last-date="stateLastDate"
          @select="state.selectById"
        />

        <div class="StudyHomeIsland__bottom-spacer" />
      </div>
    </div>
  </div>
</template>
