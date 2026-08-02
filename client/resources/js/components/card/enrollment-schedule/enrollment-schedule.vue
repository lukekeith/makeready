<script setup lang="ts">
// EnrollmentSchedule — web twin of iPhone EnrollmentSchedulePage
// (Pages/Manage/Group/Enrollment/EnrollmentSchedulePage.swift) — the
// `.enrollmentSchedule` modal's primary pane (dismissOnTapOutside FALSE).
//
// Layout (scheduleContent): PageTitle.iconTitleIcon (title = titleOverride ??
// program name ?? "Schedule"; left xmark when modal / chevron when pushed;
// right arrow.triangle.2.circlepath → sync settings) over a flat
// VStack(spacing 4) of SwipeableCard+CardLesson(.lesson) rows (padH16 padT16
// padB40) and the add-lesson BoxButton. No month sections, no progress
// header. Loading = 10× SkeletonCardLesson (spacing 8); error / empty states
// per iOS. Rows: purple `released` background when scheduledDate ≤ today,
// per-activity percent-complete fills from completion-stats.
//
// Fully controlled; the production host owns data + dialogs. Captures bind
// nothing (swipe buttons render closed; the ghost row via `addingLesson`).
import PageTitle from '../page-title/page-title.vue'
import CardLesson, { type CardLessonActivity } from '../card-lesson/card-lesson.vue'
import SkeletonCardLesson from '../skeleton-card-lesson/skeleton-card-lesson.vue'
import SwipeableCard from '../swipeable-card/swipeable-card.vue'
import BoxButton from '../box-button/box-button.vue'

export interface EnrollmentScheduleRow {
  id: string
  day: number
  title?: string
  /** Pre-formatted "Thursday, Jan 30, 2026" (weekday wide, month abbrev). */
  date: string
  estimatedMinutes?: number
  released?: boolean
  activities: CardLessonActivity[]
}

interface Props {
  title?: string
  /** 'xmark' (modal presentations) or 'chevron' (pushed). */
  leftIcon?: 'xmark' | 'chevron'
  rows?: EnrollmentScheduleRow[]
  loading?: boolean
  errorMessage?: string
  /** Ghost skeleton row + dimmed add button while a lesson is being added. */
  addingLesson?: boolean
  /** Production: rows swipe (share / calendar / delete) and tap. */
  interactive?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: 'Schedule',
  leftIcon: 'xmark',
  rows: () => [],
  loading: false,
  errorMessage: '',
  addingLesson: false,
  interactive: false,
})

const emit = defineEmits<{
  dismiss: []
  sync: []
  retry: []
  rowTap: [id: string]
  share: [id: string]
  reschedule: [id: string]
  deleteRow: [id: string]
  addLesson: []
}>()

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'
const CHEVRON_LEFT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5l-7 7 7 7"/></svg>'
// SF arrow.triangle.2.circlepath — the sync-settings glyph.
const SYNC_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20.5 9.5A8.6 8.6 0 0 0 5.6 6.4L4 8"/><path d="M4 3.8V8h4.2"/><path d="M3.5 14.5a8.6 8.6 0 0 0 14.9 3.1l1.6-1.6"/><path d="M20 20.2V16h-4.2"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
// SF calendar.badge.exclamationmark — empty-state glyph.
const CALENDAR_BADGE =
  '<svg viewBox="0 0 26 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4.5" width="17" height="16.5" rx="2.5"/><path d="M6.5 2.5v4M14.5 2.5v4M2 9.5h17"/><circle cx="22" cy="6" r="3.4" fill="none"/><path d="M22 4.2v2.2"/><circle cx="22" cy="7.9" r="0.4" fill="currentColor"/></svg>'
const WARNING_TRIANGLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3L1.8 20.5h20.4L12 3z"/><path d="M12 10v4.5"/><circle cx="12" cy="17.5" r="0.6" fill="currentColor"/></svg>'

// Swipe buttons (iOS: share / calendar → accentBlue #5680ff; trash → delete).
const SHARE_SVG =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 14.5V3.5"/><path d="M8.2 7l3.8-3.8L15.8 7"/><path d="M5.5 11.5v7a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2v-7"/></svg>'
const CALENDAR_SVG =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M8 2.8v4M16 2.8v4M3 10h18"/></svg>'
const TRASH_SVG =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'

const ROW_BUTTONS = [
  { icon: SHARE_SVG, variant: 'reschedule' as const },
  { icon: CALENDAR_SVG, variant: 'reschedule' as const },
  { icon: TRASH_SVG, variant: 'delete' as const },
]

function onRowAction(id: string, index: number): void {
  if (index === 0) emit('share', id)
  else if (index === 1) emit('reschedule', id)
  else emit('deleteRow', id)
}
</script>

<template>
  <div :class="['EnrollmentSchedule', props.class]">
    <div class="EnrollmentSchedule__dragSpacer"></div>
    <PageTitle
      :title="props.title"
      :left-icon="props.leftIcon === 'chevron' ? CHEVRON_LEFT : XMARK"
      :right-icon="SYNC_ICON"
      @left="emit('dismiss')"
      @right="emit('sync')"
    />

    <!-- Loading: 10 skeleton rows, VStack(spacing 8) -->
    <div v-if="props.loading" class="EnrollmentSchedule__scroll">
      <div class="EnrollmentSchedule__skeletons">
        <SkeletonCardLesson v-for="i in 10" :key="i" />
      </div>
    </div>

    <!-- Error -->
    <div v-else-if="props.errorMessage" class="EnrollmentSchedule__state">
      <span class="EnrollmentSchedule__stateIcon" v-html="WARNING_TRIANGLE"></span>
      <span class="EnrollmentSchedule__stateText">{{ props.errorMessage }}</span>
      <button type="button" class="EnrollmentSchedule__retry" @click="emit('retry')">
        Try Again
      </button>
    </div>

    <!-- Content -->
    <div v-else-if="props.rows.length || props.addingLesson" class="EnrollmentSchedule__scroll">
      <div class="EnrollmentSchedule__list">
        <template v-if="props.interactive">
          <SwipeableCard
            v-for="row in props.rows"
            :key="row.id"
            bare
            :slide-buttons="ROW_BUTTONS"
            @action="onRowAction(row.id, $event)"
            @tap="emit('rowTap', row.id)"
          >
            <CardLesson
              mode="lesson"
              :day="row.day"
              :title="row.title"
              :date="row.date"
              :estimated-minutes="row.estimatedMinutes"
              :activities="row.activities"
              :released="row.released"
            />
          </SwipeableCard>
        </template>
        <template v-else>
          <CardLesson
            v-for="row in props.rows"
            :key="row.id"
            mode="lesson"
            :day="row.day"
            :title="row.title"
            :date="row.date"
            :estimated-minutes="row.estimatedMinutes"
            :activities="row.activities"
            :released="row.released"
          />
        </template>

        <SkeletonCardLesson v-if="props.addingLesson" />

        <BoxButton
          class="EnrollmentSchedule__add"
          :class="{ 'EnrollmentSchedule__add--busy': props.addingLesson }"
          :icon="PLUS"
          variant="secondary"
          size="lg"
          full-width
          :icon-opacity="0.5"
          @click="!props.addingLesson && emit('addLesson')"
        />
      </div>
    </div>

    <!-- Empty -->
    <div v-else class="EnrollmentSchedule__state">
      <span class="EnrollmentSchedule__stateIcon" v-html="CALENDAR_BADGE"></span>
      <span class="EnrollmentSchedule__emptyTitle">No lessons scheduled</span>
      <span class="EnrollmentSchedule__stateText"
        >This enrollment doesn't have any lessons yet</span
      >
    </div>
  </div>
</template>
