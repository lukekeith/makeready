<script lang="ts">
import { cva } from '../../../util/cva'

// Alert — inline warning/critical banner (iOS Components/Display/Alert.swift).
// Data-driven: a leading filled warning triangle + a message, on a tinted
// rounded surface. The `variant` drives both the surface tint and the icon
// color (warning = yellow, critical = red).
//
// Fields (props):
//   message  string                      — the alert body text (wraps freely)
//   variant  'warning' | 'critical'      — tone (icon color + background tint)
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/alert.scss exactly.
// NB: BEM block is `AlertBanner`, not `Alert` — the client already ships an
// overlay `.Alert` dialog component, and sharing the class would collide
// (its `.Alert__message` would override this twin's size/color).
export const AlertCva = cva('AlertBanner', {
  variants: {
    variant: {
      warning: 'AlertBanner--warning',
      critical: 'AlertBanner--critical',
    },
  },
  defaultVariants: {
    variant: 'warning',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  message: string
  variant?: keyof typeof AlertCva.variant
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  message: '',
  variant: () => AlertCva.defaults?.variant as keyof typeof AlertCva.variant,
})

const classes = computed(() =>
  classnames(AlertCva.variants({ variant: props.variant }), props.class)
)
</script>

<template>
  <div :class="classes" role="alert">
    <!-- SF Symbol exclamationmark.triangle.fill — filled triangle with the
         exclamation mark punched out (evenodd) so the surface tint shows
         through, matching the iOS .fill rendering. -->
    <span class="AlertBanner__icon" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M10.27 3.94 1.5 19.06a2 2 0 0 0 1.73 3h17.54a2 2 0 0 0 1.73-3L13.73 3.94a2 2 0 0 0-3.46 0Zm1.73 4.56a1 1 0 0 0-1 1v4a1 1 0 0 0 2 0v-4a1 1 0 0 0-1-1Zm0 7.5a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2Z"
        />
      </svg>
    </span>

    <p class="AlertBanner__message">{{ message }}</p>
  </div>
</template>
