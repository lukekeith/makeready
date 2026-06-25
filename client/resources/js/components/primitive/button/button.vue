<script lang="ts">
import { cva } from '../../../util/cva'

// Button — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/button.scss exactly (PRD §16). Styles are
// global via app.scss, so this component only emits classes.
export const ButtonCva = cva('Button', {
  variants: {
    variant: {
      Primary: 'Button--primary',
      Secondary: 'Button--secondary',
      Ghost: 'Button--ghost',
      Outline: 'Button--outline',
      Destructive: 'Button--destructive',
      White: 'Button--white',
      Link: 'Button--link',
      LinkMuted: 'Button--link-muted',
      Jump: 'Button--jump',
      JumpPrimary: 'Button--jump-primary',
    },
    size: {
      Sm: 'Button--size-sm',
      Default: 'Button--size-default',
      Lg: 'Button--size-lg',
      Icon: 'Button--size-icon',
    },
    mode: {
      Block: 'Button--mode-block',
      Action: 'Button--mode-action',
    },
  },
  defaultVariants: {
    variant: 'Primary',
    size: 'Default',
    mode: 'Block',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof ButtonCva.variant
  size?: keyof typeof ButtonCva.size
  mode?: keyof typeof ButtonCva.mode
  type?: 'button' | 'submit' | 'reset'
  disabled?: boolean
  loading?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => ButtonCva.defaults?.variant as keyof typeof ButtonCva.variant,
  size: () => ButtonCva.defaults?.size as keyof typeof ButtonCva.size,
  mode: () => ButtonCva.defaults?.mode as keyof typeof ButtonCva.mode,
  type: 'button',
  disabled: false,
  loading: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(
    ButtonCva.variants({ variant: props.variant, size: props.size, mode: props.mode }),
    props.loading && 'Button--loading',
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
    :aria-busy="loading || undefined"
    @click="onClick"
  >
    <span v-if="loading" class="Button__spinner" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-dasharray="44" stroke-dashoffset="14" opacity="0.9" />
      </svg>
    </span>
    <span class="Button__content">
      <span v-if="$slots.icon" class="Button__icon"><slot name="icon" /></span>
      <span class="Button__label"><slot /></span>
    </span>
  </button>
</template>
