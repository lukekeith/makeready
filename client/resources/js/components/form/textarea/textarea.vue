<script lang="ts">
import { cva } from '../../../util/cva'

// Textarea — form. Auto-sizing multiline field. CVA variant names mirror the
// `.Textarea--*` SCSS modifiers in resources/css/components/form/textarea.scss.
export const TextareaCva = cva('Textarea', {
  variants: {
    state: {
      Default: '',
      Error: 'Textarea--error',
      Success: 'Textarea--success',
    },
  },
  defaultVariants: {
    state: 'Default',
  },
})
</script>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue?: string
  state?: keyof typeof TextareaCva.state
  rows?: number
  maxRows?: number
  placeholder?: string
  disabled?: boolean
  maxlength?: number
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  state: () => TextareaCva.defaults?.state as keyof typeof TextareaCva.state,
  rows: 3,
  maxRows: 8,
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const el = ref<HTMLTextAreaElement | null>(null)

const classes = computed(() =>
  classnames(TextareaCva.variants({ state: props.state }), props.class)
)

const remaining = computed(() =>
  props.maxlength != null ? props.maxlength - (props.modelValue?.length ?? 0) : null
)

// Grow with content up to maxRows, then scroll. Measures one line via the
// computed line-height and caps the height at maxRows lines.
const resize = () => {
  const node = el.value
  if (!node) return
  node.style.height = 'auto'
  const style = window.getComputedStyle(node)
  const lineHeight = parseFloat(style.lineHeight) || 0
  const paddingY = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom)
  const borderY = parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth)
  const maxHeight = lineHeight * props.maxRows + paddingY + borderY
  const next = Math.min(node.scrollHeight, maxHeight)
  node.style.height = `${next}px`
  node.style.overflowY = node.scrollHeight > maxHeight ? 'auto' : 'hidden'
}

const onInput = (e: Event) => {
  emit('update:modelValue', (e.target as HTMLTextAreaElement).value)
  resize()
}

onMounted(resize)
watch(() => props.modelValue, () => nextTick(resize))
</script>

<template>
  <div class="Textarea__wrap">
    <textarea
      ref="el"
      :class="classes"
      :rows="rows"
      :value="modelValue"
      :placeholder="placeholder"
      :disabled="disabled"
      :maxlength="maxlength"
      @input="onInput"
    />
    <span v-if="maxlength != null" class="Textarea__count">{{ remaining }}</span>
  </div>
</template>
