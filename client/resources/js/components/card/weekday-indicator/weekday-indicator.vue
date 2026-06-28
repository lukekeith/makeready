<script lang="ts">
// WeekdayIndicator — web twin of iOS Components/Display/WeekdayIndicator.swift.
//
// Displays the seven weekdays (S M T W T F S, Sunday-first) as a row of fixed
// 24pt letter cells, each with a small dot beneath it. Enabled days render the
// letter in solid white with a brand-purple dot; disabled days dim the letter
// to white@30% and drop the dot (iOS fills it Color.clear).
//
// Data-driven via `enabledDays` (weekday indices, 0 = Sunday … 6 = Saturday) —
// the same Set<Int> the SwiftUI view takes. Class names mirror the BEM modifiers
// in resources/css/components/card/weekday-indicator.scss. The block is named
// `.WeekdayIndicatorDisplay` to avoid colliding with the existing interactive
// `.WeekdayIndicator` pill selector (components/data/weekday-indicator).
export const WEEKDAY_LABELS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'] as const
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  // Enabled weekday indices: 0 = Sunday, 1 = Monday, … 6 = Saturday.
  enabledDays: number[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  enabledDays: () => [],
})

const enabledSet = computed(() => new Set(props.enabledDays))

// Sunday-first columns, mirroring the iOS `days` array.
const days = computed(() =>
  // Inlined labels (the SFC compiler can't reference a module binding in a
  // default factory, but this is a plain computed so the const is fine).
  ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((label, index) => ({
    index,
    label,
    enabled: enabledSet.value.has(index),
  }))
)

const classes = computed(() => classnames('WeekdayIndicatorDisplay', props.class))
</script>

<template>
  <div :class="classes" role="group" aria-label="Weekday indicator">
    <div
      v-for="day in days"
      :key="day.index"
      class="WeekdayIndicatorDisplay__day"
      :class="{ 'WeekdayIndicatorDisplay__day--enabled': day.enabled }"
    >
      <span class="WeekdayIndicatorDisplay__label">{{ day.label }}</span>
      <span class="WeekdayIndicatorDisplay__dot" aria-hidden="true"></span>
    </div>
  </div>
</template>
