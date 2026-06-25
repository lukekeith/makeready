<script lang="ts">
import { cva } from '../../../util/cva'

// Badge — primitive. CVA tone/size names mirror the SCSS modifiers in
// resources/css/components/primitive/badge.scss exactly. Styles are global via
// app.scss, so this component only emits classes.
export const BadgeCva = cva('Badge', {
  variants: {
    tone: {
      Default: 'Badge--default',
      Primary: 'Badge--primary',
      Secondary: 'Badge--secondary',
      Indigo: 'Badge--indigo',
      Destructive: 'Badge--destructive',
      Success: 'Badge--success',
      Warning: 'Badge--warning',
      Outline: 'Badge--outline',
    },
    size: {
      Sm: 'Badge--size-sm',
      Md: 'Badge--size-md',
      Lg: 'Badge--size-lg',
    },
  },
  defaultVariants: {
    tone: 'Default',
    size: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  tone?: keyof typeof BadgeCva.tone
  size?: keyof typeof BadgeCva.size
  dot?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  tone: () => BadgeCva.defaults?.tone as keyof typeof BadgeCva.tone,
  size: () => BadgeCva.defaults?.size as keyof typeof BadgeCva.size,
  dot: false,
})

const classes = computed(() =>
  classnames(
    BadgeCva.variants({ tone: props.tone, size: props.size }),
    props.class
  )
)
</script>

<template>
  <span :class="classes">
    <span v-if="dot" class="Badge__dot" aria-hidden="true"></span>
    <slot />
  </span>
</template>
