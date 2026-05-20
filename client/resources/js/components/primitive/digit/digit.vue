<script lang="ts">
import { cva } from '../../../util/cva'

export const DigitCva = cva('Digit', {
  variants: {
    style: {
      Digit: 'Digit--style-digit',
      Asterisk: 'Digit--style-asterisk',
      Hashtag: 'Digit--style-hashtag',
      Backspace: 'Digit--style-backspace',
    },
  },
  defaultVariants: {
    style: 'Digit',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import './digit.scss'

interface Props {
  value: string
  style?: keyof typeof DigitCva.style
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  style: () => DigitCva.defaults?.style as keyof typeof DigitCva.style,
  disabled: false,
})

const emit = defineEmits<{ press: [value: string] }>()

const classes = computed(() =>
  classnames(DigitCva.variants({ style: props.style }), props.class)
)

const handleClick = () => {
  if (!props.disabled) {
    emit('press', props.value)
  }
}
</script>

<template>
  <button
    type="button"
    :class="classes"
    :disabled="disabled"
    @click.prevent="handleClick"
  >
    <!-- Asterisk icon -->
    <svg v-if="style === 'Asterisk'" width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M10 0.5V20.5M17.07 3.43L2.93 17.57M20 10.5H0M17.07 17.57L2.93 3.43" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
    </svg>
    <!-- Backspace icon -->
    <svg v-else-if="style === 'Backspace'" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M21 4H8L1 12L8 20H21C21.5304 20 22.0391 19.7893 22.4142 19.4142C22.7893 19.0391 23 18.5304 23 18V6C23 5.46957 22.7893 4.96086 22.4142 4.58579C22.0391 4.21071 21.5304 4 21 4Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M18 9L12 15M12 9L18 15" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
    <!-- Digit/Hashtag label -->
    <span v-else class="Digit__label">{{ value }}</span>
  </button>
</template>
