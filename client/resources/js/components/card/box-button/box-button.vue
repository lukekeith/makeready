<script lang="ts">
import { cva } from '../../../util/cva'

// BoxButton — flexible 8px-radius button (iOS BoxButton). Data-driven; the
// `variant` picks colors, `style` picks solid-fill vs 2px-border, `size` picks
// the height/padding/type/icon ramp, and the presence of a `label` decides
// whether it's a text button or a square icon-only button.
//
// Geometry + colors mirror iOS BoxButton.swift exactly. The per-size ramp lives
// in CSS custom properties on the size modifiers (see box-button.scss).
//
// Props:
//   label         string   — button text (omit for a square icon-only button)
//   icon          string   — inline SVG markup (mapped from an SF Symbol by the
//                            compare adapter); rendered with currentColor
//   iconPosition  enum      — left | right | none
//   variant       enum      — primary | secondary | destructive | disabled
//   buttonStyle   enum      — solid | border  (NOT named `style`: Vue reserves
//                            `style` as an attribute binding, which would swallow
//                            the value before it reached the component)
//   size          enum      — lg | md | sm
//   fullWidth     boolean   — stretch to fill the container width
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/box-button.scss exactly.
export const BoxButtonCva = cva('BoxButton', {
  variants: {
    variant: {
      primary: 'BoxButton--primary',
      secondary: 'BoxButton--secondary',
      destructive: 'BoxButton--destructive',
      disabled: 'BoxButton--disabled',
    },
    buttonStyle: {
      solid: 'BoxButton--solid',
      border: 'BoxButton--border',
    },
    size: {
      lg: 'BoxButton--lg',
      md: 'BoxButton--md',
      sm: 'BoxButton--sm',
    },
  },
  defaultVariants: {
    variant: 'primary',
    buttonStyle: 'solid',
    size: 'md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  label?: string
  icon?: string
  iconPosition?: 'left' | 'right' | 'none'
  variant?: keyof typeof BoxButtonCva.variant
  buttonStyle?: keyof typeof BoxButtonCva.buttonStyle
  size?: keyof typeof BoxButtonCva.size
  fullWidth?: boolean
  /** iOS BoxButton iconOpacity (e.g. Preview buttons pass 0.5). */
  iconOpacity?: number
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  label: '',
  icon: '',
  iconPosition: 'none',
  variant: () => BoxButtonCva.defaults?.variant as keyof typeof BoxButtonCva.variant,
  buttonStyle: () => BoxButtonCva.defaults?.buttonStyle as keyof typeof BoxButtonCva.buttonStyle,
  size: () => BoxButtonCva.defaults?.size as keyof typeof BoxButtonCva.size,
  fullWidth: false,
  iconOpacity: 1,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// iOS: isIconOnly = label == nil && icon != nil → square button, icon centered.
const isIconOnly = computed(() => !!props.icon && !props.label)

// iOS resolves "none" to .left when an icon is present (ViewRegistry default).
const resolvedIconPosition = computed(() =>
  props.iconPosition === 'none' && props.icon ? 'left' : props.iconPosition
)

const showLeftIcon = computed(
  () => !isIconOnly.value && !!props.icon && resolvedIconPosition.value === 'left'
)
const showRightIcon = computed(
  () => !isIconOnly.value && !!props.icon && resolvedIconPosition.value === 'right'
)
// iOS adds a Spacer() when fullWidth + label + right icon → label left, icon far right.
const pushRight = computed(
  () => props.fullWidth && !!props.label && showRightIcon.value
)

const classes = computed(() =>
  classnames(
    BoxButtonCva.variants({ variant: props.variant, buttonStyle: props.buttonStyle, size: props.size }),
    isIconOnly.value && 'BoxButton--icon-only',
    props.fullWidth && 'BoxButton--full-width',
    pushRight.value && 'BoxButton--push-right',
    props.class
  )
)

const onClick = (e: MouseEvent) => emit('click', e)
</script>

<template>
  <button
    type="button"
    :class="classes"
    :disabled="variant === 'disabled'"
    @click="onClick"
  >
    <span v-if="isIconOnly && icon" class="BoxButton__icon" :style="{ opacity: iconOpacity }" aria-hidden="true" v-html="icon" />
    <template v-else>
      <span v-if="showLeftIcon" class="BoxButton__icon" :style="{ opacity: iconOpacity }" aria-hidden="true" v-html="icon" />
      <span v-if="label" class="BoxButton__label">{{ label }}</span>
      <span v-if="showRightIcon" class="BoxButton__icon" :style="{ opacity: iconOpacity }" aria-hidden="true" v-html="icon" />
    </template>
  </button>
</template>
