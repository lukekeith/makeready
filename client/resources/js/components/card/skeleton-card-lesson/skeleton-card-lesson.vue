<script setup lang="ts">
// SkeletonCardLesson — loading placeholder twin for the iOS SkeletonCardLesson.
//
// Mirrors CardLesson's Row dimensions: a 76px-tall card with a left day-indicator
// column (two stacked bars), a center pair of activity lines, and a tall chevron
// placeholder pinned to the right — all vertically centered on the cardBackground
// surface (radius 4). Purely presentational; the iPhone view takes no parameters,
// so no props drive the layout. A `class` passthrough is kept for parity with the
// other twins.
//
// The iPhone applies an animated .shimmer() sweep, but the isolated /compare
// snapshot captures it mid-cycle with no visible highlight, so the web twin
// renders the static placeholder bars to match the reference exactly.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  class?: string
}

const props = defineProps<Props>()

const classes = computed(() => classnames('SkeletonCardLesson', props.class))
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <!-- Left: day indicator placeholder -->
    <div class="SkeletonCardLesson__day">
      <span class="SkeletonCardLesson__dayTop" />
      <span class="SkeletonCardLesson__dayBottom" />
    </div>

    <!-- Center: activity line placeholders -->
    <div class="SkeletonCardLesson__activities">
      <span class="SkeletonCardLesson__line SkeletonCardLesson__line--1" />
      <span class="SkeletonCardLesson__line SkeletonCardLesson__line--2" />
    </div>

    <!-- Right: chevron placeholder -->
    <span class="SkeletonCardLesson__chevron" />
  </div>
</template>
