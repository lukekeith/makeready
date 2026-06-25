<script lang="ts">
import { cva } from '../../../util/cva'

// Mobile device-frame wrapper for Histoire. Renders story content at a real
// phone width on the dark canvas, with safe-area padding and an optional
// status-bar notch, so components and page templates are tested at size.
export const DeviceFrameCva = cva('DeviceFrame', {
  variants: {
    size: {
      // Widths track common iPhone logical points.
      Se: 'DeviceFrame--size-se', // 320 — smallest (triggers the 360px token shrink)
      Md: 'DeviceFrame--size-md', // 390 — iPhone 14/15/16
      Lg: 'DeviceFrame--size-lg', // 430 — Pro Max
    },
  },
  defaultVariants: {
    size: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import './device-frame.scss'

interface Props {
  size?: keyof typeof DeviceFrameCva.size
  /** Show the rounded bezel + status-bar notch. */
  chrome?: boolean
  /** Show simulated safe-area inset guides (top/bottom). */
  safeAreas?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => DeviceFrameCva.defaults?.size as keyof typeof DeviceFrameCva.size,
  chrome: true,
  safeAreas: false,
})

const classes = computed(() =>
  classnames(
    DeviceFrameCva.variants({ size: props.size }),
    props.chrome && 'DeviceFrame--has-chrome',
    props.safeAreas && 'DeviceFrame--show-safe-areas',
    props.class
  )
)
</script>

<template>
  <div :class="classes">
    <div v-if="chrome" class="DeviceFrame__notch" />
    <div class="DeviceFrame__screen">
      <slot />
    </div>
  </div>
</template>
