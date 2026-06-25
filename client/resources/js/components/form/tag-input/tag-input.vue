<script setup lang="ts">
// TagInput — form. A token-entry field styled like the primitive `.Input`: a
// flex-wrap container holding existing tags as removable chips followed by an
// inline text input. Enter or comma commits the current text; Backspace on an
// empty input removes the last tag. Styled in
// resources/css/components/form/tag-input.scss (block `.TagInput`). Tokens only.
import { ref } from 'vue'

interface Props {
  modelValue?: string[]
  placeholder?: string
  disabled?: boolean
  max?: number
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: () => [],
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const draft = ref('')
const focused = ref(false)

const atMax = () => props.max !== undefined && props.modelValue.length >= props.max

const commit = () => {
  const value = draft.value.trim()
  draft.value = ''
  if (!value || props.disabled || atMax()) return
  if (props.modelValue.includes(value)) return
  emit('update:modelValue', [...props.modelValue, value])
}

const removeAt = (index: number) => {
  if (props.disabled) return
  const next = props.modelValue.slice()
  next.splice(index, 1)
  emit('update:modelValue', next)
}

const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ',') {
    e.preventDefault()
    commit()
  } else if (e.key === 'Backspace' && draft.value === '' && props.modelValue.length) {
    e.preventDefault()
    removeAt(props.modelValue.length - 1)
  }
}
</script>

<template>
  <div
    class="TagInput"
    :class="{ 'TagInput--focused': focused, 'TagInput--disabled': disabled }"
  >
    <span
      v-for="(tag, index) in modelValue"
      :key="`${tag}-${index}`"
      class="TagInput__tag"
    >
      <span class="TagInput__tag-label">{{ tag }}</span>
      <button
        type="button"
        class="TagInput__remove"
        aria-label="Remove tag"
        :disabled="disabled"
        @click="removeAt(index)"
      >×</button>
    </span>
    <input
      class="TagInput__input"
      :value="draft"
      :placeholder="modelValue.length ? '' : placeholder"
      :disabled="disabled || atMax()"
      @input="draft = ($event.target as HTMLInputElement).value"
      @keydown="onKeydown"
      @focus="focused = true"
      @blur="focused = false; commit()"
    />
  </div>
</template>
