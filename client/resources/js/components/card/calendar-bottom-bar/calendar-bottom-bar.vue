<script lang="ts">
import { cva } from '../../../util/cva'

// CalendarBottomBar — floating frosted pill for the calendar (iOS
// CalendarBottomBar.swift). A "Today" button, optionally followed by a divider
// and Day / Week / Month view-mode toggles. Data-driven:
//
//   showViewModes  boolean                       — show the divider + view-mode toggles
//   selectedMode   'day' | 'week' | 'month'      — which toggle reads as active (semibold + white)
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/calendar-bottom-bar.scss exactly.
export const CalendarBottomBarCva = cva('CalendarBottomBar', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

type CalendarViewMode = 'day' | 'week' | 'month'

interface ViewModeOption {
  mode: CalendarViewMode
  title: string
}

interface Props {
  showViewModes?: boolean
  selectedMode?: CalendarViewMode
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  showViewModes: false,
  selectedMode: 'month',
})

// iOS CalendarViewMode.allCases order: day, week, month.
const VIEW_MODES: ViewModeOption[] = [
  { mode: 'day', title: 'Day' },
  { mode: 'week', title: 'Week' },
  { mode: 'month', title: 'Month' },
]

const classes = computed(() =>
  classnames(CalendarBottomBarCva.variants({}), props.class)
)
</script>

<template>
  <div :class="classes">
    <!-- Today button -->
    <button type="button" class="CalendarBottomBar__today">
      <span class="CalendarBottomBar__today-icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="4" width="18" height="18" rx="2" />
          <path d="M16 2v4M8 2v4M3 10h18" />
        </svg>
      </span>
      <span class="CalendarBottomBar__today-label">Today</span>
    </button>

    <template v-if="showViewModes">
      <span class="CalendarBottomBar__divider" aria-hidden="true"></span>

      <div class="CalendarBottomBar__modes">
        <button
          v-for="opt in VIEW_MODES"
          :key="opt.mode"
          type="button"
          class="CalendarBottomBar__mode"
          :class="{ 'CalendarBottomBar__mode--active': opt.mode === selectedMode }"
        >
          {{ opt.title }}
        </button>
      </div>
    </template>
  </div>
</template>
