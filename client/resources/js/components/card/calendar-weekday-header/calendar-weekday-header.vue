<script lang="ts">
import { cva } from '../../../util/cva'

// CalendarWeekdayHeader — the fixed "S M T W T F S" header pinned above the
// split-month calendar grid (iOS CalendarHeaderView.swift → CalendarWeekdayHeader,
// a SwiftUI View). Fully data-driven:
//
//   days  string[]  — the seven weekday letters, in order (defaults to the
//                     Sunday-first S M T W T F S the iPhone hard-codes)
//
// Layout mirrors the SwiftUI HStack(spacing: 0): each letter sits in an
// equal-width column (frame maxWidth: .infinity), centered, at 12pt / 50% white,
// with 16px horizontal + 8px vertical padding over the app background.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/calendar-weekday-header.scss exactly.
export const CalendarWeekdayHeaderCva = cva('CalendarWeekdayHeader', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
interface Props {
  days?: string[]
  class?: string
}

withDefaults(defineProps<Props>(), {
  days: () => ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
})
</script>

<template>
  <div :class="['CalendarWeekdayHeader', $props.class]">
    <span v-for="(day, i) in days" :key="i" class="CalendarWeekdayHeader__day">{{
      day
    }}</span>
  </div>
</template>
