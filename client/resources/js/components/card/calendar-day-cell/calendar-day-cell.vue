<script lang="ts">
import { cva } from '../../../util/cva'

// CalendarDayCell — a single day in the split-month calendar grid (iOS
// CalendarDayCell.swift, a UICollectionViewCell). Fully data-driven:
//
//   dayNumber       number        — the day-of-month label (centered)
//   isCurrentMonth  boolean       — false dims the number to 50% white
//   isToday         boolean       — fills a brand-purple circle behind the number
//   isSelected      boolean       — draws a 2px brand-purple selection ring
//   eventColors     string[]      — up to 3 event dots below the number; the
//                                   colors are used as-is UNLESS today/selected,
//                                   where dots flip to white to read on purple
//
// The cell is a fixed 48×56 box (matching the iOS capture frame); the circle /
// ring is a 48×48 disc centered vertically, the number sits 4px above center,
// and the dots pin just beneath it — mirroring the UIKit constraints exactly.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/calendar-day-cell.scss exactly.
export const CalendarDayCellCva = cva('CalendarDayCell', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  dayNumber: number
  isCurrentMonth?: boolean
  isToday?: boolean
  isSelected?: boolean
  eventColors?: string[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  isCurrentMonth: true,
  isToday: false,
  isSelected: false,
  eventColors: () => [],
})

const MAX_DOTS = 3

// iOS configureEventDots: white dots when today/selected (visible on the purple
// disc), otherwise the per-event color. Capped at 3.
const dots = computed(() =>
  props.eventColors
    .slice(0, MAX_DOTS)
    .map((color) => (props.isToday || props.isSelected ? '#ffffff' : color))
)

const classes = computed(() =>
  classnames(
    CalendarDayCellCva.variants({}),
    props.isToday && 'CalendarDayCell--is-today',
    props.isSelected && 'CalendarDayCell--is-selected',
    !props.isCurrentMonth && 'CalendarDayCell--is-outside',
    props.class
  )
)
</script>

<template>
  <div :class="classes">
    <div v-if="isToday" class="CalendarDayCell__today" aria-hidden="true"></div>
    <div v-if="isSelected" class="CalendarDayCell__ring" aria-hidden="true"></div>

    <span class="CalendarDayCell__day">{{ dayNumber }}</span>

    <div v-if="dots.length" class="CalendarDayCell__dots">
      <span
        v-for="(color, i) in dots"
        :key="i"
        class="CalendarDayCell__dot"
        :style="{ backgroundColor: color }"
      ></span>
    </div>
  </div>
</template>
