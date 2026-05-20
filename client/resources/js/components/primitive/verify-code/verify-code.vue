<script lang="ts">
import { cva } from '../../../util/cva'

export const VerifyCodeCva = cva('VerifyCode', {
  variants: {
    size: {
      Default: 'VerifyCode--size-default',
      Large: 'VerifyCode--size-large',
    },
    theme: {
      Dark: 'VerifyCode--theme-dark',
      Light: 'VerifyCode--theme-light',
    },
    mode: {
      Numeric: 'VerifyCode--mode-numeric',
      Alphanumeric: 'VerifyCode--mode-alphanumeric',
    },
  },
  defaultVariants: {
    size: 'Default',
    theme: 'Dark',
    mode: 'Numeric',
  },
})
</script>

<script setup lang="ts">
import { computed, ref, watch, onMounted, useTemplateRef } from 'vue'
import { classnames } from '../../../util/classnames'
import './verify-code.scss'

interface Props {
  size?: keyof typeof VerifyCodeCva.size
  theme?: keyof typeof VerifyCodeCva.theme
  mode?: keyof typeof VerifyCodeCva.mode
  modelValue?: string
  length?: number
  disabled?: boolean
  autoFocus?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => VerifyCodeCva.defaults?.size as keyof typeof VerifyCodeCva.size,
  theme: () => VerifyCodeCva.defaults?.theme as keyof typeof VerifyCodeCva.theme,
  mode: () => VerifyCodeCva.defaults?.mode as keyof typeof VerifyCodeCva.mode,
  modelValue: '',
  length: 6,
  disabled: false,
  autoFocus: false,
})

const emit = defineEmits<{
  'update:modelValue': [code: string]
  complete: [code: string]
}>()

const isAlphanumeric = computed(() => props.mode === 'Alphanumeric')

const code = ref<string[]>(
  props.modelValue.split('').slice(0, props.length).concat(Array(props.length).fill('')).slice(0, props.length)
)

const inputRefs = ref<(HTMLInputElement | null)[]>([])

const setInputRef = (el: Element | null, index: number) => {
  inputRefs.value[index] = el as HTMLInputElement | null
}

const classes = computed(() =>
  classnames(
    VerifyCodeCva.variants({ size: props.size, theme: props.theme, mode: props.mode }),
    props.class
  )
)

watch(
  () => props.modelValue,
  (val) => {
    const newCode = val.split('').slice(0, props.length).concat(Array(props.length).fill('')).slice(0, props.length)
    code.value = newCode
  }
)

onMounted(() => {
  if (props.autoFocus) {
    inputRefs.value[0]?.focus()
  }
})

const handleChange = (index: number, inputValue: string) => {
  const pattern = isAlphanumeric.value ? /[^A-Za-z0-9]/g : /[^0-9]/g
  const char = inputValue.replace(pattern, '').toUpperCase()
  if (char.length === 0) return

  const newCode = [...code.value]
  newCode[index] = char[0]
  code.value = newCode

  const codeString = newCode.join('')
  emit('update:modelValue', codeString)

  if (newCode.every((d) => d !== '')) {
    emit('complete', codeString)
  }

  if (index < props.length - 1 && char.length > 0) {
    inputRefs.value[index + 1]?.focus()
  }
}

const handleKeyDown = (index: number, e: KeyboardEvent) => {
  if (e.key === 'Backspace') {
    e.preventDefault()
    const newCode = [...code.value]
    newCode[index] = ''
    code.value = newCode
    emit('update:modelValue', newCode.join(''))
    if (index > 0) {
      inputRefs.value[index - 1]?.focus()
    }
  } else if (e.key === 'ArrowLeft' && index > 0) {
    inputRefs.value[index - 1]?.focus()
  } else if (e.key === 'ArrowRight' && index < props.length - 1) {
    inputRefs.value[index + 1]?.focus()
  } else if (e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
    const pattern = isAlphanumeric.value ? /^[A-Za-z0-9]$/ : /^[0-9]$/
    if (pattern.test(e.key)) {
      e.preventDefault()
      const char = e.key.toUpperCase()
      const newCode = [...code.value]
      newCode[index] = char
      code.value = newCode

      const codeString = newCode.join('')
      emit('update:modelValue', codeString)

      if (newCode.every((d) => d !== '')) {
        emit('complete', codeString)
      }

      if (index < props.length - 1) {
        inputRefs.value[index + 1]?.focus()
      }
    }
  }
}

const handlePaste = (e: ClipboardEvent) => {
  e.preventDefault()
  const pattern = isAlphanumeric.value ? /[^A-Za-z0-9]/g : /[^0-9]/g
  const pastedData = (e.clipboardData?.getData('text') || '').replace(pattern, '').toUpperCase()

  const chars = pastedData.split('').slice(0, props.length)
  const newCode = chars.concat(Array(props.length).fill('')).slice(0, props.length)
  code.value = newCode

  const codeString = newCode.join('')
  emit('update:modelValue', codeString)

  if (newCode.every((d) => d !== '')) {
    emit('complete', codeString)
  } else {
    const nextEmptyIndex = newCode.findIndex((d) => d === '')
    if (nextEmptyIndex >= 0) {
      inputRefs.value[nextEmptyIndex]?.focus()
    }
  }
}

// Expose focus and clear methods
defineExpose({
  focus: () => inputRefs.value[0]?.focus(),
  clear: () => {
    const emptyCode = Array(props.length).fill('')
    code.value = emptyCode
    emit('update:modelValue', '')
    inputRefs.value[0]?.focus()
  },
})
</script>

<template>
  <div
    :class="classes"
    :tabindex="-1"
    v-bind="$attrs"
    @paste="handlePaste"
  >
    <div
      v-for="(_, index) in Array.from({ length })"
      :key="index"
      class="VerifyCode__input-wrapper"
    >
      <input
        :ref="(el) => setInputRef(el as Element | null, index)"
        type="text"
        :inputmode="isAlphanumeric ? 'text' : 'numeric'"
        :pattern="isAlphanumeric ? '[A-Za-z0-9]*' : '[0-9]*'"
        :autocapitalize="isAlphanumeric ? 'characters' : 'off'"
        maxlength="1"
        class="VerifyCode__input"
        :value="code[index] || ''"
        :disabled="disabled"
        :aria-label="`Character ${index + 1}`"
        @input="handleChange(index, ($event.target as HTMLInputElement).value)"
        @keydown="handleKeyDown(index, $event)"
        @paste="handlePaste"
      />
      <span class="VerifyCode__cursor" />
    </div>
  </div>
</template>
