<script setup lang="ts">
// SkeletonCardGroup — loading placeholder twin for the iOS SkeletonCardGroup.
//
// Mirrors CardGroup's Row dimensions: a 104px-tall card with a circular 72×72
// image placeholder on the left and stacked title + metadata bars on the right.
// Purely presentational — no props drive the layout (the iPhone view takes no
// parameters); a `class` passthrough is kept for parity with the other twins.
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

const classes = computed(() => classnames('SkeletonCardGroup', props.class))
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <span class="SkeletonCardGroup__avatar" />

    <div class="SkeletonCardGroup__body">
      <span class="SkeletonCardGroup__title" />
      <div class="SkeletonCardGroup__meta">
        <span class="SkeletonCardGroup__metaIcon" />
        <span class="SkeletonCardGroup__metaLabel" />
      </div>
    </div>
  </div>
</template>
