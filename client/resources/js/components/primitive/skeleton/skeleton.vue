<script lang="ts">
import { cva } from '../../../util/cva'

// Skeleton — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/skeleton.scss exactly. Styles are global
// via app.scss, so this component only emits classes (+ optional inline sizes).
export const SkeletonCva = cva('Skeleton', {
  variants: {
    variant: {
      Block: 'Skeleton--block',
      Text: 'Skeleton--text',
      Circle: 'Skeleton--circle',
      Card: 'Skeleton--card',
    },
  },
  defaultVariants: {
    variant: 'Block',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof SkeletonCva.variant
  // Optional CSS length strings applied inline (e.g. '80%', '120px').
  width?: string
  height?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => SkeletonCva.defaults?.variant as keyof typeof SkeletonCva.variant,
})

const classes = computed(() =>
  classnames(SkeletonCva.variants({ variant: props.variant }), props.class)
)

const style = computed(() => ({
  width: props.width,
  height: props.height,
}))
</script>

<template>
  <div :class="classes" :style="style" aria-hidden="true"></div>
</template>
