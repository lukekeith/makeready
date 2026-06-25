<script lang="ts">
import { cva } from '../../../util/cva'

// Text — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/text.scss exactly (iOS Typography + PRD
// §6.2). Styles are global via app.scss, so this component only emits classes.
export const TextCva = cva('Text', {
  variants: {
    variant: {
      Display: 'Text--display',
      Title: 'Text--title',
      Heading: 'Text--heading',
      Subheading: 'Text--subheading',
      Lead: 'Text--lead',
      Body: 'Text--body',
      BodyStrong: 'Text--body-strong',
      Caption: 'Text--caption',
      Overline: 'Text--overline',
    },
    tone: {
      Primary: 'Text--tone-primary',
      Secondary: 'Text--tone-secondary',
      Tertiary: 'Text--tone-tertiary',
      Brand: 'Text--tone-brand',
      Accent: 'Text--tone-accent',
      Error: 'Text--tone-error',
      Success: 'Text--tone-success',
    },
  },
  defaultVariants: {
    variant: 'Body',
    tone: 'Primary',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof TextCva.variant
  tone?: keyof typeof TextCva.tone
  as?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => TextCva.defaults?.variant as keyof typeof TextCva.variant,
  tone: () => TextCva.defaults?.tone as keyof typeof TextCva.tone,
  as: 'p',
})

const classes = computed(() =>
  classnames(
    TextCva.variants({ variant: props.variant, tone: props.tone }),
    props.class
  )
)
</script>

<template>
  <component :is="as" :class="classes">
    <slot />
  </component>
</template>
