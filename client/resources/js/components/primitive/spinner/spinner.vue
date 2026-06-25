<script lang="ts">
import { cva } from '../../../util/cva'

// Spinner — primitive. Wraps the existing `.Loading` SCSS
// (resources/css/components/primitive/loading.scss) in its spinner variant.
// No new SCSS — CVA modifiers map to the `.Loading--*` classes that already
// exist. This component only emits classes.
export const SpinnerCva = cva('Loading Loading--spinner', {
  variants: {
    size: {
      Sm: 'Loading--sm',
      Md: 'Loading--md',
      Lg: 'Loading--lg',
      Xl: 'Loading--xl',
    },
    tone: {
      White: 'Loading--white',
      Primary: 'Loading--primary',
      Purple: 'Loading--purple',
      Dark: 'Loading--dark',
    },
    speed: {
      Slow: 'Loading--slow',
      Normal: 'Loading--normal',
      Fast: 'Loading--fast',
    },
  },
  defaultVariants: {
    size: 'Md',
    tone: 'White',
    speed: 'Normal',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  size?: keyof typeof SpinnerCva.size
  tone?: keyof typeof SpinnerCva.tone
  speed?: keyof typeof SpinnerCva.speed
  label?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => SpinnerCva.defaults?.size as keyof typeof SpinnerCva.size,
  tone: () => SpinnerCva.defaults?.tone as keyof typeof SpinnerCva.tone,
  speed: () => SpinnerCva.defaults?.speed as keyof typeof SpinnerCva.speed,
  label: 'Loading',
})

const classes = computed(() =>
  classnames(
    SpinnerCva.variants({ size: props.size, tone: props.tone, speed: props.speed }),
    props.class
  )
)
</script>

<template>
  <div :class="classes" role="status" :aria-label="label">
    <div class="Loading__spinner" aria-hidden="true"></div>
  </div>
</template>
