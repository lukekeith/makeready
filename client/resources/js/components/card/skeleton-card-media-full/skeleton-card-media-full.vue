<script setup lang="ts">
// SkeletonCardMediaFull — loading placeholder twin for the iOS SkeletonCardMediaFull.
//
// Mirrors CardMediaFull's grid tile: a square (1:1) placeholder filled with
// white @ 8% — the same faint fill CardMediaFull draws while its image loads.
// The iOS view is rendered at `.frame(width: 120)` in the 3-column media grid,
// so the twin pins a 120px square (the intrinsic grid-cell dimension, a raw
// structural value matching card-media-full). No corner radius — the iOS
// Rectangle draws square. Purely presentational; the iPhone view takes no
// parameters, so no props drive the layout. A `class` passthrough is kept for
// parity with the other skeleton twins.
//
// The iPhone applies an animated .shimmer() sweep, but the isolated /compare
// snapshot captures it mid-cycle with no visible highlight, so the web twin
// renders the static placeholder square to match the reference exactly.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  class?: string
}

const props = defineProps<Props>()

const classes = computed(() => classnames('SkeletonCardMediaFull', props.class))
</script>

<template>
  <div :class="classes" aria-hidden="true" />
</template>
