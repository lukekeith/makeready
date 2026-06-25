<script lang="ts">
import { cva } from '../../../util/cva'

// ScrollArea — layout. A momentum scroll container with contained overscroll and
// an optionally hidden scrollbar. CVA axis names mirror the SCSS modifiers in
// resources/css/components/layout/scroll-area.scss exactly. Styles are global
// via app.scss, so this component only emits classes.
export const ScrollAreaCva = cva('ScrollArea', {
  variants: {
    axis: {
      Y: 'ScrollArea--axis-y',
      X: 'ScrollArea--axis-x',
      Both: 'ScrollArea--axis-both',
    },
  },
  defaultVariants: {
    axis: 'Y',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  axis?: keyof typeof ScrollAreaCva.axis
  /** Hide the scrollbar (still scrollable). Default true. */
  hideScrollbar?: boolean
  /** CSS length cap on the container height (applied inline). */
  maxHeight?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  axis: () => ScrollAreaCva.defaults?.axis as keyof typeof ScrollAreaCva.axis,
  hideScrollbar: true,
})

const classes = computed(() =>
  classnames(
    ScrollAreaCva.variants({ axis: props.axis }),
    props.hideScrollbar && 'ScrollArea--hide-scrollbar',
    props.class
  )
)

const style = computed(() =>
  props.maxHeight ? { maxHeight: props.maxHeight } : undefined
)
</script>

<template>
  <div :class="classes" :style="style">
    <slot />
  </div>
</template>
