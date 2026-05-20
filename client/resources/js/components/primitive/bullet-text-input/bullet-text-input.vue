<script lang="ts">
import { cva } from '../../../util/cva'

export const BulletTextInputCva = cva('BulletTextInput', {
  variants: {
    size: {
      Default: 'BulletTextInput--size-default',
      Large: 'BulletTextInput--size-large',
    },
  },
  defaultVariants: {
    size: 'Default',
  },
})
</script>

<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue'
import { classnames } from '../../../util/classnames'
import './bullet-text-input.scss'

interface Props {
  size?: keyof typeof BulletTextInputCva.size
  modelValue: string
  placeholder?: string
  autoFocus?: boolean
  fill?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => BulletTextInputCva.defaults?.size as keyof typeof BulletTextInputCva.size,
  placeholder: 'Start typing...',
  autoFocus: false,
  fill: false,
})

const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const editorRef = ref<HTMLDivElement | null>(null)
const isEmpty = computed(() => !props.modelValue || props.modelValue.trim() === '')

const classes = computed(() =>
  classnames(
    BulletTextInputCva.variants({ size: props.size }),
    props.fill && 'BulletTextInput--fill',
    props.class
  )
)

// Convert modelValue to HTML content for contenteditable
const valueToHtml = (value: string): string => {
  if (!value) return ''
  const lines = value.split('\n')
  if (lines.length > 1) {
    return `<ul class="BulletTextInput__list">${lines.map(line =>
      `<li class="BulletTextInput__list-item">${line}</li>`
    ).join('')}</ul>`
  }
  return `<p class="BulletTextInput__paragraph">${value}</p>`
}

// Extract plain text from editor DOM
const getTextContent = (el: HTMLDivElement): string => {
  const items = el.querySelectorAll('li')
  if (items.length > 0) {
    return Array.from(items).map(li => li.textContent || '').join('\n')
  }
  return el.textContent || ''
}

onMounted(() => {
  if (editorRef.value) {
    const html = valueToHtml(props.modelValue)
    if (html) editorRef.value.innerHTML = html
    if (props.autoFocus) editorRef.value.focus()
  }
})

// Sync from outside
watch(
  () => props.modelValue,
  (val) => {
    if (editorRef.value) {
      const currentText = getTextContent(editorRef.value)
      if (currentText !== val) {
        editorRef.value.innerHTML = valueToHtml(val)
      }
    }
  }
)

const handleInput = () => {
  if (editorRef.value) {
    emit('update:modelValue', getTextContent(editorRef.value))
  }
}

const handleKeyDown = (e: KeyboardEvent) => {
  if (e.key === 'Enter') {
    e.preventDefault()
    document.execCommand('insertOrderedList', false)
    // Switch to unordered
    document.execCommand('insertUnorderedList', false)
    handleInput()
  }
}

const handleContainerClick = () => {
  editorRef.value?.focus()
}
</script>

<template>
  <div :class="classes" @click="handleContainerClick">
    <div class="BulletTextInput__editor-container">
      <div
        ref="editorRef"
        class="BulletTextInput__editor"
        contenteditable="true"
        @input="handleInput"
        @keydown="handleKeyDown"
      />
      <div
        :class="['BulletTextInput__placeholder', !isEmpty && 'BulletTextInput__placeholder--hidden']"
      >
        {{ placeholder }}
      </div>
    </div>
    <div v-if="fill" class="BulletTextInput__click-area" @click="handleContainerClick" />
  </div>
</template>
