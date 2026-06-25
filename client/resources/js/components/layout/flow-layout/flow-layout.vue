<script lang="ts">
import { cva } from '../../../util/cva'

// FlowLayout — layout primitive. Wrapping inline row for chips / tags. CVA
// variant names mirror the SCSS modifiers in
// resources/css/components/layout/flow-layout.scss exactly. Styles are global
// via app.scss, so this component only emits classes.
export const FlowLayoutCva = cva('FlowLayout', {
  variants: {
    gap: {
      Xs: 'FlowLayout--gap-xs',
      Sm: 'FlowLayout--gap-sm',
      Md: 'FlowLayout--gap-md',
    },
  },
  defaultVariants: {
    gap: 'Sm',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  gap?: keyof typeof FlowLayoutCva.gap
  as?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  gap: () => FlowLayoutCva.defaults?.gap as keyof typeof FlowLayoutCva.gap,
  as: 'div',
})

const classes = computed(() =>
  classnames(FlowLayoutCva.variants({ gap: props.gap }), props.class)
)
</script>

<template>
  <component :is="as" :class="classes">
    <slot />
  </component>
</template>
