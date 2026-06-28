<script lang="ts">
import { cva } from '../../../util/cva'

// ActionButton — pill / icon button (iOS ActionButton). Data-driven; the
// `variant` picks the fill + foreground colors, and the presence of a `label`
// decides the shape:
//   • label (± icon)            → 32px-tall auto-width PILL (16px h-padding)
//   • icon only                 → 32×32 circle (cornerRadius 16 on iOS)
//   • circleBlur                → 64×64 frosted circle, 24px icon
//
// Geometry mirrors iOS ActionButton.swift exactly (the swipeLarge animated
// variant is iOS-internal and intentionally omitted here).
//
// Props:
//   label    string  — button text (omit for an icon-only button)
//   icon     string  — inline SVG markup (mapped from an SF Symbol by the
//                      compare adapter); rendered with currentColor
//   variant  enum    — purple | purpleIcon | white | whiteIcon | whitePurple | circleBlur
//
// Color modifiers mirror the SCSS in
// resources/css/components/card/action-button.scss.
export const ActionButtonCva = cva('ActionButton', {
  variants: {
    variant: {
      purple: 'ActionButton--purple',
      purpleIcon: 'ActionButton--purple',
      white: 'ActionButton--white',
      whiteIcon: 'ActionButton--white',
      whitePurple: 'ActionButton--white-purple',
      circleBlur: 'ActionButton--circle-blur',
    },
  },
  defaultVariants: {
    variant: 'white',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  label?: string
  icon?: string
  variant?: keyof typeof ActionButtonCva.variant
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  label: '',
  icon: '',
  variant: () => ActionButtonCva.defaults?.variant as keyof typeof ActionButtonCva.variant,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// iOS: isIconOnly = icon != nil && label == nil. circleBlur owns its own (64px)
// sizing, so it never takes the 32px icon-only modifier.
const isIconOnly = computed(
  () => !!props.icon && !props.label && props.variant !== 'circleBlur'
)

const classes = computed(() =>
  classnames(
    ActionButtonCva.variants({ variant: props.variant }),
    isIconOnly.value && 'ActionButton--icon-only',
    props.class
  )
)

const onClick = (e: MouseEvent) => emit('click', e)
</script>

<template>
  <button type="button" :class="classes" @click="onClick">
    <span v-if="icon" class="ActionButton__icon" aria-hidden="true" v-html="icon" />
    <span v-if="label" class="ActionButton__label">{{ label }}</span>
  </button>
</template>
