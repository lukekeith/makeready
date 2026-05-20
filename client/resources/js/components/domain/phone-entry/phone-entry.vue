<script lang="ts">
import { cva } from '../../../util/cva'

export const PhoneEntryCva = cva('PhoneEntry', {
  variants: {
    variant: {
      Default: 'PhoneEntry--default',
    },
  },
  defaultVariants: {
    variant: 'Default',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Digit from '../../primitive/digit/digit.vue'
import './phone-entry.scss'

interface Props {
  variant?: keyof typeof PhoneEntryCva.variant
  formattedNumber?: string
  onDigitPress: (digit: string) => void
  onBackspace: () => void
  onSubmit: () => void
  isValid?: boolean
  isLoading?: boolean
  disabled?: boolean
  error?: string
  title?: string
  buttonLabel?: string
  secondaryButtonLabel?: string
  onSecondaryClick?: () => void
  className?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => PhoneEntryCva.defaults?.variant as keyof typeof PhoneEntryCva.variant,
  isValid: false,
  isLoading: false,
  disabled: false,
  title: 'Enter your phone',
  buttonLabel: 'Send code',
})

const emit = defineEmits<{
  digitPress: [digit: string]
  backspace: []
  submit: []
  secondaryClick: []
}>()

const containerClass = computed(() =>
  classnames(PhoneEntryCva.variants({ variant: props.variant }), props.className),
)

function handleDigitPress(digit: string) {
  props.onDigitPress(digit)
}

function handleBackspace() {
  props.onBackspace()
}

function handleSubmit() {
  props.onSubmit()
}

function handleSecondaryClick() {
  props.onSecondaryClick?.()
}

// Keypad rows: [['1','2','3'],['4','5','6'],['7','8','9'],['*','0','<']]
const keypadRows = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['*', '0', '<'],
]
</script>

<template>
  <div :class="containerClass">
    <div class="PhoneEntry__content">
      <!-- Header: Title + Phone display -->
      <div class="PhoneEntry__header">
        <h1 class="PhoneEntry__title">{{ title }}</h1>
        <div class="PhoneEntry__display">
          <span class="PhoneEntry__number">{{ formattedNumber || '\u00A0' }}</span>
        </div>
      </div>

      <!-- Keypad -->
      <div class="PhoneEntry__keypad">
        <div class="PhoneEntry__keypad-grid">
          <template v-for="row in keypadRows" :key="row.join('')">
            <Digit
              v-for="key in row"
              :key="key"
              :value="key === '<' ? '' : key"
              :style="key === '*' ? 'Asterisk' : key === '<' ? 'Backspace' : 'Digit'"
              :disabled="disabled || isLoading"
              @press="key === '<' ? handleBackspace() : key === '*' ? undefined : handleDigitPress(key)"
            />
          </template>
        </div>
      </div>

      <!-- Error message -->
      <div v-if="error" class="PhoneEntry__error">
        {{ error }}
      </div>

      <!-- Optional extra content (slot) -->
      <slot />

      <!-- Submit Button -->
      <div class="PhoneEntry__button">
        <button
          type="button"
          :class="['Button', 'Button--white', 'Button--mode-block', isLoading ? 'Button--loading' : '']"
          :disabled="!isValid || disabled || isLoading"
          @click="handleSubmit"
        >
          <span v-if="isLoading" class="Button__content">
            <span class="Button__spinner"></span>
            {{ buttonLabel }}
          </span>
          <template v-else>{{ buttonLabel }}</template>
        </button>
        <button
          v-if="secondaryButtonLabel && onSecondaryClick"
          type="button"
          class="Button Button--secondary Button--mode-block"
          @click="handleSecondaryClick"
        >
          {{ secondaryButtonLabel }}
        </button>
      </div>
    </div>
  </div>
</template>
