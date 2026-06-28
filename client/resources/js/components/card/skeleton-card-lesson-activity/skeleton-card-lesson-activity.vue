<script setup lang="ts">
// SkeletonCardLessonActivity — loading placeholder twin for iOS SkeletonCardLessonActivity.
//
// Mirrors CardLessonActivity's small layout: a 40×40 image placeholder on the
// left, then two stacked text-line placeholders (title + description), with the
// remaining space pushed out by a trailing spacer — all on the cardBackground
// surface (radius 4), padded 12 horizontal / 10 vertical. Purely presentational;
// the iPhone view takes no parameters, so no props drive the layout. A `class`
// passthrough is kept for parity with the other twins.
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

const classes = computed(() => classnames('SkeletonCardLessonActivity', props.class))
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <!-- Left: 40×40 image placeholder -->
    <span class="SkeletonCardLessonActivity__image" />

    <!-- Right: title + description line placeholders -->
    <div class="SkeletonCardLessonActivity__text">
      <span class="SkeletonCardLessonActivity__line SkeletonCardLessonActivity__line--title" />
      <span class="SkeletonCardLessonActivity__line SkeletonCardLessonActivity__line--desc" />
    </div>
  </div>
</template>
