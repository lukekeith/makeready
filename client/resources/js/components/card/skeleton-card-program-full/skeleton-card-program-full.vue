<script setup lang="ts">
// SkeletonCardProgramFull — loading placeholder twin for the iOS
// SkeletonCardProgramFull.
//
// Mirrors CardProgramFull's full-width browse card: a 280px-tall card with a
// full-bleed faint image placeholder (white @ 8%) and a bottom content overlay
// (cardBackground @ 80%) holding stacked title / description / tag / metadata
// placeholder bars. Purely presentational — the iPhone view takes no
// parameters, so no props drive the layout; a `class` passthrough is kept for
// parity with the other skeleton twins.
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

const classes = computed(() => classnames('SkeletonCardProgramFull', props.class))
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <div class="SkeletonCardProgramFull__overlay">
      <span class="SkeletonCardProgramFull__title" />
      <span class="SkeletonCardProgramFull__desc SkeletonCardProgramFull__desc--1" />
      <span class="SkeletonCardProgramFull__desc SkeletonCardProgramFull__desc--2" />

      <div class="SkeletonCardProgramFull__tags">
        <span class="SkeletonCardProgramFull__tag SkeletonCardProgramFull__tag--wide" />
        <span class="SkeletonCardProgramFull__tag SkeletonCardProgramFull__tag--narrow" />
      </div>

      <div class="SkeletonCardProgramFull__meta">
        <span class="SkeletonCardProgramFull__metaItem SkeletonCardProgramFull__metaItem--a" />
        <span class="SkeletonCardProgramFull__metaItem SkeletonCardProgramFull__metaItem--b" />
      </div>
    </div>
  </div>
</template>
