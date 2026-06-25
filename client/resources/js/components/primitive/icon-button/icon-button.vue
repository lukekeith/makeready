<script lang="ts">
import { cva } from '../../../util/cva'

// IconButton — primitive. Circular icon-only button. CVA variant names mirror the
// SCSS modifiers in resources/css/components/primitive/icon-button.scss exactly.
// Styles are global via app.scss, so this component only emits classes.
export const IconButtonCva = cva('IconButton', {
  variants: {
    variant: {
      Default: 'IconButton--default',
      Brand: 'IconButton--brand',
      White: 'IconButton--white',
      Blur: 'IconButton--blur',
    },
    size: {
      Sm: 'IconButton--size-sm',
      Md: 'IconButton--size-md',
      Lg: 'IconButton--size-lg',
      Xl48: 'IconButton--size-xl48',
      Xl64: 'IconButton--size-xl64',
    },
  },
  defaultVariants: {
    variant: 'Default',
    size: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof IconButtonCva.variant
  size?: keyof typeof IconButtonCva.size
  type?: 'button' | 'submit' | 'reset'
  disabled?: boolean
  loading?: boolean
  ariaLabel: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => IconButtonCva.defaults?.variant as keyof typeof IconButtonCva.variant,
  size: () => IconButtonCva.defaults?.size as keyof typeof IconButtonCva.size,
  type: 'button',
  disabled: false,
  loading: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(
    IconButtonCva.variants({ variant: props.variant, size: props.size }),
    props.loading && 'IconButton--loading',
    props.class
  )
)

const onClick = (e: MouseEvent) => {
  if (props.disabled || props.loading) return
  emit('click', e)
}
</script>

<template>
  <button
    :type="type"
    :class="classes"
    :disabled="disabled || loading"
    :aria-label="ariaLabel"
    :aria-busy="loading || undefined"
    @click="onClick"
  >
    <span v-if="loading" class="IconButton__spinner" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-dasharray="44" stroke-dashoffset="14" opacity="0.9" />
      </svg>
    </span>
    <span class="IconButton__icon"><slot /></span>
  </button>
</template>
