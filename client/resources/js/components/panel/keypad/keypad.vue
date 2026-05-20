<script lang="ts">
import { cva } from '../../../util/cva'

export const KeypadCva = cva('Keypad', {
  variants: {
    variant: {
      Default: 'Keypad--default',
    },
  },
  defaultVariants: {
    variant: 'Default',
  },
})
</script>

<script setup lang="ts">
import { classnames } from '../../../util/classnames'
import Digit from '../../primitive/digit/digit.vue'
import './keypad.scss'

interface Props {
  disabled?: boolean
  variant?: 'Default'
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'Default',
  disabled: false,
})

const emit = defineEmits<{
  digitPress: [digit: string]
  backspace: []
}>()

function handleDigitClick(digit: string) {
  if (digit === 'backspace') {
    emit('backspace')
  } else {
    emit('digitPress', digit)
  }
}

function handleBackspaceClick(_value: string) {
  emit('backspace')
}
</script>

<template>
  <div :class="classnames(KeypadCva.variants({ variant }), props.class)">
    <!-- Row 1 -->
    <Digit value="1" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="2" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="3" :disabled="disabled" @click="handleDigitClick" />

    <!-- Row 2 -->
    <Digit value="4" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="5" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="6" :disabled="disabled" @click="handleDigitClick" />

    <!-- Row 3 -->
    <Digit value="7" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="8" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="9" :disabled="disabled" @click="handleDigitClick" />

    <!-- Row 4 -->
    <Digit value="*" :style="'Asterisk'" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="0" :disabled="disabled" @click="handleDigitClick" />
    <Digit value="backspace" :style="'Backspace'" :disabled="disabled" @click="handleBackspaceClick" />
  </div>
</template>
