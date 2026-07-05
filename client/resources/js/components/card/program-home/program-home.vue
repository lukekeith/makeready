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
//   • TabSlider ["Studies", "Enrollments", "Analytics"]
//   • Studies tab: VStack(spacing 4) of CardLesson(mode "lesson") rows +
//     add-day BoxButton (creator only); skeletons while loading; book.closed
//     empty state
//   • Enrollments: empty state ("No enrollments yet", person.3)
//   • Analytics: "Coming soon"
// Sections stack with VStack(spacing 20); trailing 40px spacer.
import PageTitle from '../page-title/page-title.vue'
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

      <!-- Studies / Enrollments / Analytics -->
      <div class="ProgramHome__tabs">
        <TabSlider
          :tabs="['Studies', 'Enrollments', 'Analytics']"
          :selected-index="props.selectedTab"
          @select="emit('selectTab', $event)"
        />
      </div>

      <!-- Studies tab: lessons list -->
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

      <!-- Analytics tab -->
      <div v-else class="ProgramHome__analytics">Coming soon</div>

      <div class="ProgramHome__bottomSpacer"></div>
    </div>
  </div>
</template>
