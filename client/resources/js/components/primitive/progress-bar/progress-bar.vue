<script lang="ts">
import { cva } from '../../../util/cva'

// ProgressBar — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/progress-bar.scss exactly. Styles are
// global via app.scss, so this component only emits classes (+ inline width).
export const ProgressBarCva = cva('ProgressBar', {
  variants: {
    tone: {
      Brand: 'ProgressBar--brand',
      White: 'ProgressBar--white',
    },
    mode: {
      Determinate: '',
      Indeterminate: 'ProgressBar--indeterminate',
    },
  },
  defaultVariants: {
    tone: 'Brand',
    mode: 'Determinate',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  // 0–100. Omit ⇒ indeterminate.
  value?: number
  tone?: keyof typeof ProgressBarCva.tone
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  tone: () => ProgressBarCva.defaults?.tone as keyof typeof ProgressBarCva.tone,
})

const indeterminate = computed(() => props.value === undefined || props.value === null)

const clamped = computed(() =>
  Math.min(100, Math.max(0, props.value ?? 0))
)

const classes = computed(() =>
  classnames(
    ProgressBarCva.variants({
      tone: props.tone,
      mode: indeterminate.value ? 'Indeterminate' : 'Determinate',
    }),
    props.class
  )
)

const fillStyle = computed(() =>
  indeterminate.value ? {} : { width: `${clamped.value}%` }
)
</script>

<template>
  <div
    :class="classes"
    role="progressbar"
    :aria-valuenow="indeterminate ? undefined : clamped"
    :aria-valuemin="indeterminate ? undefined : 0"
    :aria-valuemax="indeterminate ? undefined : 100"
  >
    <div class="ProgressBar__fill" :style="fillStyle"></div>
  </div>
</template>
