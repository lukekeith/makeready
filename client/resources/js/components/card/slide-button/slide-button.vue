<script lang="ts">
import { cva } from '../../../util/cva'

// SlideButton — a single revealed action inside a SwipeableCard. CVA keys mirror
// the .SlideButton--* modifiers.
export const SlideButtonCva = cva('SlideButton', {
  variants: {
    style: {
      Normal: 'SlideButton--normal',
      Neutral: 'SlideButton--neutral',
      Destructive: 'SlideButton--destructive',
    },
  },
  defaultVariants: {
    style: 'Normal',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  label?: string
  style?: keyof typeof SlideButtonCva.style
  class?: string
}
const props = withDefaults(defineProps<Props>(), {
  style: () => SlideButtonCva.defaults?.style as keyof typeof SlideButtonCva.style,
})
const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(SlideButtonCva.variants({ style: props.style }), props.class)
)
</script>

<template>
  <button type="button" :class="classes" :aria-label="label" @click="emit('click', $event)">
    <span v-if="$slots.icon" class="SlideButton__icon"><slot name="icon" /></span>
    <span v-if="label" class="SlideButton__label">{{ label }}</span>
  </button>
</template>
