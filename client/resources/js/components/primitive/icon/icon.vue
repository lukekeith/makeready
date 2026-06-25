<script lang="ts">
import { cva } from '../../../util/cva'

// Icon — primitive. Renders an inline SVG (Lucide-style) passed via the default
// slot inside the `.Icon` base class. Size/tone are emitted as BEM modifier
// classes (defined in icon.scss with the --icon-*/--fg-* tokens) — CVA keys map
// 1:1 to those SCSS modifiers.
export const IconCva = cva('Icon', {
  variants: {
    size: {
      Xs: 'Icon--size-xs',
      Sm: 'Icon--size-sm',
      Md: 'Icon--size-md',
      Lg: 'Icon--size-lg',
    },
    tone: {
      Current: 'Icon--tone-current',
      Primary: 'Icon--tone-primary',
      Secondary: 'Icon--tone-secondary',
      Tertiary: 'Icon--tone-tertiary',
      Brand: 'Icon--tone-brand',
      Accent: 'Icon--tone-accent',
    },
  },
  defaultVariants: {
    size: 'Md',
    tone: 'Current',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  size?: keyof typeof IconCva.size
  tone?: keyof typeof IconCva.tone
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => IconCva.defaults?.size as keyof typeof IconCva.size,
  tone: () => IconCva.defaults?.tone as keyof typeof IconCva.tone,
})

const classes = computed(() =>
  classnames(IconCva.variants({ size: props.size, tone: props.tone }), props.class)
)
</script>

<template>
  <span :class="classes" aria-hidden="true">
    <slot />
  </span>
</template>
