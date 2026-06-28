<script setup lang="ts">
// SkeletonCardStudy — loading placeholder twin for the iOS SkeletonCardStudy.
//
// Mirrors CardStudy's Row layout: a 140px-tall card on the cardBackground
// surface (radius 4) with a vertically-centered stack of title / description /
// metadata placeholder bars on the LEFT and a 72×108 portrait image
// placeholder on the RIGHT (iOS HStack + Spacer). Purely presentational — the
// iPhone view takes no parameters, so no props drive the layout; a `class`
// passthrough is kept for parity with the other skeleton twins.
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

const classes = computed(() => classnames('SkeletonCardStudy', props.class))
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <div class="SkeletonCardStudy__body">
      <span class="SkeletonCardStudy__title" />
      <span class="SkeletonCardStudy__desc" />
      <div class="SkeletonCardStudy__meta">
        <span class="SkeletonCardStudy__metaItem" />
      </div>
    </div>

    <span class="SkeletonCardStudy__image" />
  </div>
</template>
