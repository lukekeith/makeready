<script lang="ts">
import { cva } from '../../../util/cva'

// Grid — layout primitive. CSS grid container. CVA variant names mirror the
// SCSS modifiers in resources/css/components/layout/grid.scss exactly. Styles
// are global via app.scss, so this component only emits classes.
export const GridCva = cva('Grid', {
  variants: {
    cols: {
      '1': 'Grid--cols-1',
      '2': 'Grid--cols-2',
      '3': 'Grid--cols-3',
      '4': 'Grid--cols-4',
      Auto: 'Grid--cols-auto',
    },
    gap: {
      Sm: 'Grid--gap-sm',
      Md: 'Grid--gap-md',
      Lg: 'Grid--gap-lg',
    },
    align: {
      Start: 'Grid--align-start',
      Center: 'Grid--align-center',
      End: 'Grid--align-end',
      Stretch: 'Grid--align-stretch',
    },
  },
  defaultVariants: {
    cols: 'Auto',
    gap: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  cols?: keyof typeof GridCva.cols
  gap?: keyof typeof GridCva.gap
  align?: keyof typeof GridCva.align
  as?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  cols: () => GridCva.defaults?.cols as keyof typeof GridCva.cols,
  gap: () => GridCva.defaults?.gap as keyof typeof GridCva.gap,
  as: 'div',
})

const classes = computed(() =>
  classnames(
    GridCva.variants({ cols: props.cols, gap: props.gap, align: props.align }),
    props.class
  )
)
</script>

<template>
  <component :is="as" :class="classes">
    <slot />
  </component>
</template>
