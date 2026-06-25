<script lang="ts">
import { cva } from '../../../util/cva'

// Spacer — layout primitive. A flexible or fixed spacer. CVA variant names
// mirror the SCSS modifiers in resources/css/components/layout/spacer.scss
// exactly. Styles are global via app.scss, so this component only emits classes.
//
//   size="Flex"  → grows to fill, pushing siblings apart (use inside a Stack)
//   size="Xs..Xl" → a fixed block whose height equals the matching space token
export const SpacerCva = cva('Spacer', {
  variants: {
    size: {
      Xs: 'Spacer--xs',
      Sm: 'Spacer--sm',
      Md: 'Spacer--md',
      Lg: 'Spacer--lg',
      Xl: 'Spacer--xl',
      Flex: 'Spacer--flex',
    },
  },
  defaultVariants: {
    size: 'Flex',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  size?: keyof typeof SpacerCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => SpacerCva.defaults?.size as keyof typeof SpacerCva.size,
})

const classes = computed(() =>
  classnames(SpacerCva.variants({ size: props.size }), props.class)
)
</script>

<template>
  <div :class="classes" aria-hidden="true" />
</template>
