<script lang="ts">
import { cva } from '../../../util/cva'

// Fab — navigation. Floating action button fixed above the tab bar. Circular
// (icon-only) or extended (with label). CVA variant names mirror the SCSS
// modifiers in resources/css/components/navigation/fab.scss exactly; the .vue
// emits classes only (styles global via app.scss).
export const FabCva = cva('Fab', {
  variants: {
    position: {
      BottomRight: 'Fab--bottom-right',
      BottomCenter: 'Fab--bottom-center',
    },
    mode: {
      Icon: 'Fab--mode-icon',
      Extended: 'Fab--mode-extended',
    },
  },
  defaultVariants: {
    position: 'BottomRight',
    mode: 'Icon',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  label?: string
  position?: keyof typeof FabCva.position
  ariaLabel?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  label: undefined,
  position: () => FabCva.defaults?.position as keyof typeof FabCva.position,
  ariaLabel: undefined,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const mode = computed<keyof typeof FabCva.mode>(() => (props.label ? 'Extended' : 'Icon'))

const classes = computed(() =>
  classnames(
    FabCva.variants({ position: props.position, mode: mode.value }),
    props.class
  )
)

// An icon-only FAB needs an accessible name; fall back to the label otherwise.
const computedAriaLabel = computed(() => props.ariaLabel ?? props.label)
</script>

<template>
  <button type="button" :class="classes" :aria-label="computedAriaLabel" @click="emit('click', $event)">
    <span class="Fab__icon"><slot /></span>
    <span v-if="label" class="Fab__label">{{ label }}</span>
  </button>
</template>
