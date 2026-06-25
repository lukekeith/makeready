<script lang="ts">
import { cva } from '../../../util/cva'

// Divider — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/divider.scss exactly (PRD §6). Styles are
// global via app.scss, so this component only emits classes.
export const DividerCva = cva('Divider', {
  variants: {
    orientation: {
      Horizontal: 'Divider--horizontal',
      Vertical: 'Divider--vertical',
    },
  },
  defaultVariants: {
    orientation: 'Horizontal',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  orientation?: keyof typeof DividerCva.orientation
  inset?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  orientation: () => DividerCva.defaults?.orientation as keyof typeof DividerCva.orientation,
  inset: false,
})

const classes = computed(() =>
  classnames(
    DividerCva.variants({ orientation: props.orientation }),
    props.inset && 'Divider--inset',
    props.class
  )
)

const ariaOrientation = computed(() =>
  props.orientation === 'Vertical' ? 'vertical' : 'horizontal'
)
</script>

<template>
  <div :class="classes" role="separator" :aria-orientation="ariaOrientation" />
</template>
