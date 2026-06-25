<script lang="ts">
// FilterChipDropdown — navigation. A pill chip showing "label: value ▾" that
// opens a small dropdown menu of options (iOS FilterChipDropdown parity). No CVA
// variants; the open/active state is a single `--open` modifier toggled in
// template. CSS lives in
// resources/css/components/navigation/filter-chip-dropdown.scss (global via
// app.scss).

export interface FilterChipOption {
  value: string
  label: string
}
</script>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'

interface Props {
  label: string
  modelValue: string
  options: FilterChipOption[]
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const root = ref<HTMLElement | null>(null)
const open = ref(false)

const selectedLabel = computed(
  () => props.options.find((o) => o.value === props.modelValue)?.label ?? '—'
)

const onDocumentClick = (e: MouseEvent) => {
  if (root.value && !root.value.contains(e.target as Node)) close()
}

const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Escape') close()
}

const addListeners = () => {
  document.addEventListener('click', onDocumentClick)
  document.addEventListener('keydown', onKeydown)
}
const removeListeners = () => {
  document.removeEventListener('click', onDocumentClick)
  document.removeEventListener('keydown', onKeydown)
}

const close = () => {
  open.value = false
}
const toggle = () => {
  open.value = !open.value
}

const choose = (value: string) => {
  if (value !== props.modelValue) emit('update:modelValue', value)
  close()
}

// Bind/unbind the document listeners only while open.
watch(open, (isOpen) => {
  if (isOpen) addListeners()
  else removeListeners()
})

onBeforeUnmount(removeListeners)
</script>

<template>
  <div ref="root" :class="['FilterChipDropdown', props.class]">
    <button
      type="button"
      class="FilterChipDropdown__chip"
      :class="{ 'FilterChipDropdown__chip--open': open }"
      :aria-expanded="open"
      aria-haspopup="listbox"
      @click="toggle"
    >
      <span class="FilterChipDropdown__label">{{ label }}:</span>
      <span class="FilterChipDropdown__value">{{ selectedLabel }}</span>
      <span class="FilterChipDropdown__caret" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M6 9l6 6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
    </button>

    <ul v-if="open" class="FilterChipDropdown__menu" role="listbox">
      <li
        v-for="option in options"
        :key="option.value"
        class="FilterChipDropdown__option"
        :class="{ 'FilterChipDropdown__option--selected': option.value === modelValue }"
        role="option"
        :aria-selected="option.value === modelValue"
        @click="choose(option.value)"
      >
        {{ option.label }}
      </li>
    </ul>
  </div>
</template>
