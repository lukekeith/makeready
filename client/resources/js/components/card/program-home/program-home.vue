<script setup lang="ts">
// ProgramHome — web twin of the iPhone ProgramHomePage main content
// (Pages/Manage/Program/ProgramHomePage.swift), presented as the .programHome
// modal. Data-driven and shared by BOTH the capture compare harness (inert —
// no listeners bound) and the production leader app (live data + emits).
//
// Layout (mirrors mainContent, top → bottom):
//   • PageTitle — xmark left; export / eye / gear right (44×44 targets)
//   • CoverImagePicker (display mode) with the PublishBadge overlaid top-left
//     (capsule s12Semibold: Published = appBackground on #57DB5D, Draft =
//     white on #242A3E)
//   • TabSlider ["Lessons", "Enrollments", "Analytics"]
//   • Lessons tab: VStack(spacing 4) of CardLesson(mode "lesson") rows +
//     add-day BoxButton (creator only); skeletons while loading; book.closed
//     empty state
//   • Enrollments: empty state ("No enrollments yet", person.3)
//   • Analytics: KPI 2×2 grid → Top Groups → Recent Activity (Week/Month/Year
//     VerticalBarChart) → Activity Heatmap → "As of …" footer, with the iOS
//     per-section hide rules (ProgramHomePage.analyticsContent)
// Sections stack with VStack(spacing 20); trailing 40px spacer.
import { computed, ref } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import Kpi from '../kpi/kpi.vue'
import VerticalBarChart from '../vertical-bar-chart/vertical-bar-chart.vue'
import HeatMapChart from '../heat-map-chart/heat-map-chart.vue'
import CoverImagePicker from '../cover-image-picker/cover-image-picker.vue'
import TabSlider from '../tab-slider/tab-slider.vue'
import CardLesson, { type CardLessonActivity } from '../card-lesson/card-lesson.vue'
import SkeletonCardLesson from '../skeleton-card-lesson/skeleton-card-lesson.vue'
import CardGroup from '../card-group/card-group.vue'
import SkeletonCardGroup from '../skeleton-card-group/skeleton-card-group.vue'
import BoxButton from '../box-button/box-button.vue'
import SwipeableCard from '../swipeable-card/swipeable-card.vue'
import DragulaList from '../dragula-list/dragula-list.vue'

export interface ProgramHomeLesson {
  id: string
  day: number
  title?: string
  estimatedMinutes?: number
  activities: CardLessonActivity[]
}

// GET /api/programs/:id/analytics contract (iOS AnalyticsModels.swift
// ProgramAnalytics) — the slice the Analytics tab consumes.
export interface ProgramAnalyticsDayCount {
  date: string // "yyyy-MM-dd"
  count: number
}

export interface ProgramAnalytics {
  freshAsOf?: string | null
  kpis: {
    membersReached: number
    activeEnrollments: number
    totalEnrollments: number
    lessonCompletions: number
    completionRate: number // 0–1
    videoCompletions: number
    watchSeconds: number
    avgWatchPercent: number // 0–1
  }
  recent: {
    week: ProgramAnalyticsDayCount[]
    month: ProgramAnalyticsDayCount[]
    year: ProgramAnalyticsDayCount[]
  }
  heatmap: Array<{ day: number; hour: number; count: number }>
  topGroups: Array<{
    groupId: string
    groupName: string
    memberCount: number
    lessonCompletions: number
    completionPct: number // 0–1
  }>
}

interface Props {
  programName?: string
  programDescription?: string
  coverUrl?: string
  hasCoverImage?: boolean
  published?: boolean
  selectedTab?: number
  lessons?: ProgramHomeLesson[]
  loading?: boolean
  // Additive: Enrollments-tab rows (iOS enrollmentsContent — CardGroup rows).
  // Captures never pass these, so tab 1 keeps its captured empty state.
  enrollments?: Array<{
    id: string
    name: string
    subtitle?: string
    imageUrl?: string
    dateRange: string
  }>
  enrollmentsLoading?: boolean
  canEdit?: boolean
  // Additive (production only, capture never passes it): creator editing —
  // lessons render inside DragulaList (long-press reorder) + SwipeableCard
  // (swipe-left → trash), mirroring iOS ProgramHomePage.lessonCard. Off, the
  // original inert list renders unchanged.
  editable?: boolean
  // Additive: Analytics-tab payload (iOS analyticsContent, cache-first).
  // Absent + no error → the iOS loading skeleton renders.
  analytics?: ProgramAnalytics | null
  // Production: the load failed with no cached payload (iOS analyticsLoadFailed).
  analyticsError?: boolean
  // Capture-only deterministic "now" (ISO) for the relative "As of …" footer —
  // production omits it and the wall clock is used (iOS relativeTo: Date()).
  analyticsNow?: string
  // Capture-only: render the iOS device status bar (the iPhone reference
  // includes the simulator's). Production (the modal) never passes this.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  programName: '',
  programDescription: '',
  coverUrl: '',
  hasCoverImage: false,
  published: false,
  selectedTab: 0,
  lessons: () => [],
  loading: false,
  enrollments: () => [],
  enrollmentsLoading: false,
  canEdit: true,
  editable: false,
  analytics: null,
  analyticsError: false,
  statusBar: false,
})

const emit = defineEmits<{
  addEnrollment: []
  selectEnrollment: [id: string]
  close: []
  export: []
  preview: []
  settings: []
  selectTab: [index: number]
  selectLesson: [id: string]
  addDay: []
  togglePublish: []
  deleteLesson: [id: string]
  reorderLessons: [ids: string[]]
}>()

// iOS lessonCard slide button: single trash / .delete (SF "trash").
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
  + '<path d="M4 7h16"/>'
  + '<path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/>'
  + '<path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/>'
  + '<path d="M10 11v6.5M14 11v6.5"/>'
  + '</svg>'
const LESSON_BUTTONS = [{ icon: TRASH, variant: 'delete' as const }]

// DragulaList's #item slot is typed { id }; recover the full lesson shape.
function asLesson(item: { id: string }): ProgramHomeLesson {
  return item as ProgramHomeLesson
}

// PageTitle glyphs — iOS SF Symbols: xmark / square.and.arrow.up / eye /
// gearshape (all s17-ish in 44×44 targets).
const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'
const SHARE_UP =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 14.5V3.5"/><path d="M8.2 7l3.8-3.8L15.8 7"/><path d="M5.5 11.5v7a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2v-7"/></svg>'
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
const GEAR =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3.2"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h.01a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51h.01a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v.01a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
// SF "book.closed" — empty-state glyph (s32, white@30).
const BOOK_CLOSED =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15z"/><path d="M4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5"/></svg>'
// SF "person.3" — enrollments empty-state glyph.
// SF "clock" — enrollment dateRange metadata glyph (DataComponent s14).
const CLOCK_SM =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'
const PERSON_3 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="7.8" r="3"/><path d="M6.7 19c0-2.9 2.4-5 5.3-5s5.3 2.1 5.3 5"/><circle cx="4.6" cy="9.4" r="2.3"/><path d="M2 17.5c0-2 1.3-3.6 3.2-4"/><circle cx="19.4" cy="9.4" r="2.3"/><path d="M22 17.5c0-2-1.3-3.6-3.2-4"/></svg>'

const RIGHT_ICONS = [{ icon: SHARE_UP }, { icon: EYE }, { icon: GEAR }]

// PageTitle rightIcons order: export, preview, settings.
const RIGHT_ACTIONS = ['export', 'preview', 'settings'] as const
function onRightIcon(index: number): void {
  const action = RIGHT_ACTIONS[index]
  if (action === 'export') emit('export')
  else if (action === 'preview') emit('preview')
  else if (action === 'settings') emit('settings')
}

// ── Analytics tab (iOS ProgramHomePage.analyticsContent) ────────────────────

// SF "person.2" (filled) — the Members-reached KPI icon, brandPrimary tint.
const PERSON_2 =
  '<svg viewBox="0 0 24 16" fill="currentColor"><circle cx="9" cy="5" r="3.4"/>'
  + '<path d="M9 9.4c-3.6 0-6.5 2.2-6.5 5v1.1h13v-1.1c0-2.8-2.9-5-6.5-5z"/>'
  + '<circle cx="17.4" cy="5.4" r="2.7"/>'
  + '<path d="M17.6 9.6c-.7 0-1.4.1-2 .35 1.5 1.1 2.4 2.7 2.4 4.45v1.1h3.9v-1.1c0-2.6-1.9-4.8-4.3-4.8z"/></svg>'

const HEATMAP_X_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const HEATMAP_Y_LABELS = [
  '12a', '1a', '2a', '3a', '4a', '5a', '6a', '7a', '8a', '9a', '10a', '11a',
  '12p', '1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p', '10p', '11p',
]

// iOS @State analyticsTimeScale — Week(0) / Month(1) / Year(2), pure client
// state (all three series arrive in the one payload).
const analyticsScale = ref(0)

// iOS static analyticsHasAnyActivity / hasRecentActivity — ported verbatim.
function hasRecentActivity(recent: ProgramAnalytics['recent']): boolean {
  return (
    recent.week.some((d) => d.count > 0)
    || recent.month.some((d) => d.count > 0)
    || recent.year.some((d) => d.count > 0)
  )
}

function hasAnyActivity(a: ProgramAnalytics): boolean {
  return (
    a.kpis.membersReached > 0
    || a.kpis.lessonCompletions > 0
    || a.kpis.videoCompletions > 0
    || a.kpis.watchSeconds > 0
    || hasRecentActivity(a.recent)
    || a.heatmap.some((b) => b.count > 0)
    || a.topGroups.some((g) => g.lessonCompletions > 0)
  )
}

// Whole-tab empty rule (iOS analyticsContent:1656).
const analyticsEmpty = computed(() => {
  const a = props.analytics
  if (!a) return false
  return a.kpis.totalEnrollments === 0 || !hasAnyActivity(a)
})

// Per-section hide rules (owner rule: zero-data sections are REMOVED).
const showTopGroups = computed(
  () => !!props.analytics?.topGroups.some((g) => g.lessonCompletions > 0)
)
const showRecent = computed(
  () => !!props.analytics && hasRecentActivity(props.analytics.recent)
)
const showHeatmap = computed(
  () => !!props.analytics?.heatmap.some((b) => b.count > 0)
)

// completionRate KPI: iOS passes completionRate*100 through NumberFormatter
// (max 1 frac) — pre-round so 0.63*100's float dust still reads "63%".
const completionRatePct = computed(() =>
  Math.round((props.analytics?.kpis.completionRate ?? 0) * 100 * 10) / 10
)

function memberCountLabel(n: number): string {
  return `${n} member${n === 1 ? '' : 's'}`
}

function completionPctLabel(pct: number): string {
  return `${Math.round(pct * 100)}%`
}

// "yyyy-MM-dd" parsed as a LOCAL date (iOS DateFormatters.dateKey uses the
// local tz; `new Date(iso)` would parse UTC and shift the day).
function parseDateKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number)
  return new Date(y, (m || 1) - 1, d || 1)
}

// Bar labels: week "EEE" / month "MMM d" / year "MMM" (unique per bar —
// Swift Charts merges same-label categories).
const recentBars = computed(() => {
  const a = props.analytics
  if (!a) return []
  const series =
    analyticsScale.value === 1 ? a.recent.month
    : analyticsScale.value === 2 ? a.recent.year
    : a.recent.week
  return series.map((d) => {
    const date = parseDateKey(d.date)
    const label =
      analyticsScale.value === 1
        ? date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        : analyticsScale.value === 2
          ? date.toLocaleDateString('en-US', { month: 'short' })
          : date.toLocaleDateString('en-US', { weekday: 'short' })
    return { label, value: d.count, color: 'rgba(108,71,255,1)' }
  })
})

const recentHasActivity = computed(() => recentBars.value.some((b) => b.value > 0))

// Month view thins x-axis marks to indices 7/14/21/28 (index 0 skipped — it
// truncates against the y-axis). iOS ProgramHomePage:1793-1795.
const recentAxisValues = computed<string[] | null>(() => {
  if (analyticsScale.value !== 1) return null
  return recentBars.value.filter((_, i) => i > 0 && i % 7 === 0).map((b) => b.label)
})

// Heatmap: iOS maps bucket.day → week (x, Sun..Sat) and bucket.hour → day
// (y, 0..23) — the MainHome transposition. Zero cells are dropped by the
// chart itself (colorForValue → clear), so only non-zero buckets are passed.
const heatPoints = computed(
  () =>
    props.analytics?.heatmap.map((b) => ({
      week: b.day,
      day: b.hour,
      value: b.count,
    })) ?? []
)

// "As of …" — mirrors RelativeDateTimeFormatter's numeric style ("11 hours
// ago"). Largest fitting unit, value floored, via Intl.RelativeTimeFormat.
const RELATIVE_UNITS: Array<[Intl.RelativeTimeFormatUnit, number]> = [
  ['year', 31536000],
  ['month', 2592000],
  ['week', 604800],
  ['day', 86400],
  ['hour', 3600],
  ['minute', 60],
]

const freshLabel = computed<string | null>(() => {
  const iso = props.analytics?.freshAsOf
  if (!iso) return null
  const then = Date.parse(iso)
  if (Number.isNaN(then)) return null
  const now = props.analyticsNow ? Date.parse(props.analyticsNow) : Date.now()
  const delta = Math.max(0, (now - then) / 1000)
  const fmt = new Intl.RelativeTimeFormat('en-US', { numeric: 'always' })
  for (const [unit, secs] of RELATIVE_UNITS) {
    if (delta >= secs) return `As of ${fmt.format(-Math.floor(delta / secs), unit)}`
  }
  return `As of ${fmt.format(-Math.floor(delta), 'second')}`
})
</script>

<template>
  <div :class="['ProgramHome', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="ProgramHome__statusbar" aria-hidden="true">
      <span class="ProgramHome__clock">9:41</span>
      <span class="ProgramHome__indicators">
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

    <PageTitle
      :left-icon="XMARK"
      :right-icons="RIGHT_ICONS"
      @left="emit('close')"
      @select-right-icon="onRightIcon"
    />

    <div class="ProgramHome__scroll">
      <!-- Cover + publish badge -->
      <div class="ProgramHome__cover">
        <CoverImagePicker
          mode="display"
          :program-name="props.programName"
          :program-description="props.programDescription"
          :has-image="props.hasCoverImage"
          :cover-url="props.coverUrl || undefined"
        />
        <button
          class="ProgramHome__publishBadge"
          :class="{ 'ProgramHome__publishBadge--published': props.published }"
          type="button"
          @click="emit('togglePublish')"
        >
          {{ props.published ? 'Published' : 'Draft' }}
        </button>
      </div>

      <!-- Lessons / Enrollments / Analytics -->
      <div class="ProgramHome__tabs">
        <TabSlider
          :tabs="['Lessons', 'Enrollments', 'Analytics']"
          :selected-index="props.selectedTab"
          @select="emit('selectTab', $event)"
        />
      </div>

      <!-- Lessons tab: lessons list -->
      <div v-if="props.selectedTab === 0" class="ProgramHome__lessons">
        <template v-if="props.loading && !props.lessons.length">
          <SkeletonCardLesson />
          <SkeletonCardLesson />
        </template>
        <div v-else-if="!props.lessons.length" class="ProgramHome__empty">
          <span class="ProgramHome__emptyIcon" v-html="BOOK_CLOSED"></span>
          <span class="ProgramHome__emptyTitle">No lessons yet</span>
          <span class="ProgramHome__emptySub">Add lessons to build your study program</span>
          <BoxButton
            v-if="props.canEdit"
            class="ProgramHome__addDay"
            variant="secondary"
            size="lg"
            :icon="PLUS"
            icon-position="right"
            full-width
            @click="emit('addDay')"
          />
        </div>
        <!-- Creator editing (production): long-press reorder + swipe-to-delete
             (iOS DragulaView + SwipeableCard around each lessonCard). -->
        <template v-else-if="props.editable">
          <DragulaList
            :items="props.lessons"
            :gap="4"
            @reorder="emit('reorderLessons', $event)"
          >
            <template #item="{ item }">
              <SwipeableCard
                bare
                :slide-buttons="LESSON_BUTTONS"
                @action="emit('deleteLesson', item.id)"
                @tap="emit('selectLesson', item.id)"
              >
                <CardLesson
                  mode="lesson"
                  :day="asLesson(item).day"
                  :title="asLesson(item).title"
                  :estimated-minutes="asLesson(item).estimatedMinutes"
                  :activities="asLesson(item).activities"
                  show-animated-border
                />
              </SwipeableCard>
            </template>
          </DragulaList>
          <BoxButton
            v-if="props.canEdit"
            class="ProgramHome__addDay"
            variant="secondary"
            size="lg"
            :icon="PLUS"
            icon-position="right"
            full-width
            @click="emit('addDay')"
          />
        </template>
        <template v-else>
          <CardLesson
            v-for="lesson in props.lessons"
            :key="lesson.id"
            mode="lesson"
            :day="lesson.day"
            :title="lesson.title"
            :estimated-minutes="lesson.estimatedMinutes"
            :activities="lesson.activities"
            show-animated-border
            @click="emit('selectLesson', lesson.id)"
          />
          <BoxButton
            v-if="props.canEdit"
            class="ProgramHome__addDay"
            variant="secondary"
            size="lg"
            :icon="PLUS"
            icon-position="right"
            full-width
            @click="emit('addDay')"
          />
        </template>
      </div>

      <!-- Enrollments tab (iOS enrollmentsContent: VStack(8) pad-h16) -->
      <div v-else-if="props.selectedTab === 1" class="ProgramHome__enrollments">
        <template v-if="props.enrollmentsLoading && !props.enrollments.length">
          <SkeletonCardGroup v-for="i in 3" :key="i" />
        </template>
        <template v-else-if="props.enrollments.length">
          <CardGroup
            v-for="e in props.enrollments"
            :key="e.id"
            :name="e.name"
            :subtitle="e.subtitle"
            :image-url="e.imageUrl"
            icon-fallback
            :member-count="0"
            :metadata="[{ icon: CLOCK_SM, value: e.dateRange }]"
            @click="emit('selectEnrollment', e.id)"
          />
          <BoxButton
            :icon="PLUS"
            variant="secondary"
            size="lg"
            full-width
            :icon-opacity="0.5"
            @click="emit('addEnrollment')"
          />
        </template>
        <div v-else class="ProgramHome__empty">
          <span class="ProgramHome__emptyIcon" v-html="PERSON_3"></span>
          <span class="ProgramHome__emptyTitle">No enrollments yet</span>
          <span class="ProgramHome__emptySub">Groups enrolled in this program will appear here</span>
          <BoxButton
            class="ProgramHome__emptyAdd"
            :icon="PLUS"
            variant="secondary"
            size="lg"
            full-width
            :icon-opacity="0.5"
            @click="emit('addEnrollment')"
          />
        </div>
      </div>

      <!-- Analytics tab (iOS analyticsContent: cache-first render; sections
           with zero data are hidden, not shown as empty shells) -->
      <div v-else class="ProgramHome__analytics">
        <template v-if="props.analytics">
          <!-- Whole-tab empty state -->
          <div v-if="analyticsEmpty" class="ProgramHome__analyticsState">
            <span class="ProgramHome__analyticsStateTitle">No activity yet</span>
            <span class="ProgramHome__analyticsStateSub"
              >Analytics appear once groups enroll and members engage.</span
            >
          </div>

          <template v-else>
            <!-- 1. KPI grid: 2×2, 116pt rows of Kpi(.standard, expand) -->
            <div class="ProgramHome__kpiGrid">
              <div class="ProgramHome__kpiRow">
                <Kpi
                  expand
                  label="Members reached"
                  :kpi-value="props.analytics.kpis.membersReached"
                  :icon="PERSON_2"
                  icon-color="#6c47ff"
                />
                <Kpi
                  expand
                  label="Active enrollments"
                  :kpi-value="props.analytics.kpis.activeEnrollments"
                  :description="`of ${props.analytics.kpis.totalEnrollments} total`"
                />
              </div>
              <div class="ProgramHome__kpiRow">
                <Kpi
                  expand
                  label="Lessons completed"
                  :kpi-value="props.analytics.kpis.lessonCompletions"
                />
                <Kpi
                  expand
                  label="Completion rate"
                  :kpi-value="completionRatePct"
                  value-type="percent"
                />
              </div>
            </div>

            <!-- 1b. Top Groups: divider-row card w/ completion capsules -->
            <div v-if="showTopGroups" class="ProgramHome__analyticsSection">
              <span class="ProgramHome__analyticsTitle">Top Groups</span>
              <div class="ProgramHome__topGroups">
                <template
                  v-for="(g, i) in props.analytics.topGroups"
                  :key="g.groupId"
                >
                  <div class="ProgramHome__topGroupRow">
                    <div class="ProgramHome__topGroupHead">
                      <div class="ProgramHome__topGroupNames">
                        <span class="ProgramHome__topGroupName">{{ g.groupName }}</span>
                        <span class="ProgramHome__topGroupMembers">{{
                          memberCountLabel(g.memberCount)
                        }}</span>
                      </div>
                      <div class="ProgramHome__topGroupPct">
                        <span class="ProgramHome__topGroupPctValue">{{
                          completionPctLabel(g.completionPct)
                        }}</span>
                        <span class="ProgramHome__topGroupPctLabel">Completion</span>
                      </div>
                    </div>
                    <div class="ProgramHome__topGroupTrack">
                      <div
                        class="ProgramHome__topGroupFill"
                        :style="{
                          width: `${Math.max(0, Math.min(1, g.completionPct)) * 100}%`,
                        }"
                      ></div>
                    </div>
                  </div>
                  <div
                    v-if="i < props.analytics.topGroups.length - 1"
                    class="ProgramHome__topGroupDivider"
                  ></div>
                </template>
              </div>
            </div>

            <!-- 3. Recent Activity: Week/Month/Year toggle + VerticalBarChart -->
            <div v-if="showRecent" class="ProgramHome__analyticsSection">
              <span class="ProgramHome__analyticsTitle">Recent Activity</span>
              <div class="ProgramHome__scaleSlider">
                <TabSlider
                  :tabs="['Week', 'Month', 'Year']"
                  :selected-index="analyticsScale"
                  @select="analyticsScale = $event"
                />
              </div>
              <div class="ProgramHome__recentChart">
                <VerticalBarChart
                  :data-points="recentBars"
                  :show-values="analyticsScale === 0 && recentHasActivity"
                  :chart-height="200"
                  :x-axis-values="recentAxisValues"
                  y-axis-width="auto"
                />
                <span v-if="!recentHasActivity" class="ProgramHome__recentEmpty"
                  >No activity in this period</span
                >
              </div>
            </div>

            <!-- 4. Activity Heatmap: 7 days × 24 hours, last 30 days -->
            <div v-if="showHeatmap" class="ProgramHome__analyticsSection">
              <span class="ProgramHome__analyticsTitle">Activity Heatmap</span>
              <HeatMapChart
                :data-points="heatPoints"
                :show-day-labels="false"
                :x-labels="HEATMAP_X_LABELS"
                :y-labels="HEATMAP_Y_LABELS"
                :chart-height="576"
                show-x-labels
              />
              <span class="ProgramHome__heatmapCaption">Last 30 days</span>
            </div>

            <!-- Freshness footer -->
            <div v-if="freshLabel" class="ProgramHome__analyticsFooter">
              {{ freshLabel }}
            </div>
          </template>
        </template>

        <!-- Error (no cached payload) -->
        <div v-else-if="props.analyticsError" class="ProgramHome__analyticsState">
          <span class="ProgramHome__analyticsStateTitle">Couldn't load analytics</span>
          <span class="ProgramHome__analyticsStateSub">Pull to refresh to try again.</span>
        </div>

        <!-- Loading skeleton -->
        <div v-else class="ProgramHome__analyticsSkeletons">
          <div v-for="i in 3" :key="i" class="ProgramHome__analyticsSkeleton"></div>
        </div>
      </div>

      <div class="ProgramHome__bottomSpacer"></div>
    </div>
  </div>
</template>
