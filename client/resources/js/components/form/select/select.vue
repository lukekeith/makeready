<script lang="ts">
import { cva } from '../../../util/cva'

// Select (a.k.a. MenuInput) — form. A custom dropdown (not native <select>).
// CVA `state` mirrors the `.Select--*` SCSS modifiers exactly. Styles live in
// resources/css/components/form/select.scss. The .vue never imports scss.
export const SelectCva = cva('Select', {
  variants: {
    state: {
      Default: '',
      Error: 'Select--error',
    },
  },
  defaultVariants: {
    state: 'Default',
  },
})

export interface SelectOption {
  value: string
  label: string
}
</script>

<script setup lang="ts">
import { computed, ref, onBeforeUnmount, nextTick } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue?: string | string[]
  options?: SelectOption[]
  placeholder?: string
  disabled?: boolean
  multiple?: boolean
  state?: keyof typeof SelectCva.state
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  options: () => [],
  placeholder: 'Select…',
  disabled: false,
  multiple: false,
  state: () => SelectCva.defaults?.state as keyof typeof SelectCva.state,
})

const emit = defineEmits<{ 'update:modelValue': [string | string[]] }>()

const open = ref(false)
const highlighted = ref(-1)
const rootEl = ref<HTMLElement | null>(null)

const selectedValues = computed<string[]>(() => {
  if (props.multiple) {
    return Array.isArray(props.modelValue) ? props.modelValue : []
  }
  return props.modelValue ? [props.modelValue as string] : []
})

const isSelected = (value: string) => selectedValues.value.includes(value)

const triggerLabel = computed(() => {
  const selected = props.options.filter((o) => isSelected(o.value))
  if (selected.length === 0) return ''
  if (props.multiple) {
    if (selected.length === 1) return selected[0].label
    return `${selected.length} selected`
  }
  return selected[0].label
})

const hasValue = computed(() => triggerLabel.value !== '')

const classes = computed(() =>
  classnames(SelectCva.variants({ state: props.state }), props.class)
)

const onDocumentMousedown = (e: MouseEvent) => {
  if (rootEl.value && !rootEl.value.contains(e.target as Node)) {
    close()
  }
}

const openMenu = async () => {
  if (props.disabled) return
  open.value = true
  document.addEventListener('mousedown', onDocumentMousedown)
  // Highlight the first selected option (or first option) when opening.
  const firstSelected = props.options.findIndex((o) => isSelected(o.value))
  highlighted.value = firstSelected >= 0 ? firstSelected : props.options.length ? 0 : -1
  await nextTick()
}

const close = () => {
  open.value = false
  document.removeEventListener('mousedown', onDocumentMousedown)
}

const toggle = () => {
  if (props.disabled) return
  if (open.value) close()
  else openMenu()
}

const selectOption = (option: SelectOption) => {
  if (props.multiple) {
    const current = selectedValues.value.slice()
    const idx = current.indexOf(option.value)
    if (idx >= 0) current.splice(idx, 1)
    else current.push(option.value)
    emit('update:modelValue', current)
    // Menu stays open in multiple mode.
  } else {
    emit('update:modelValue', option.value)
    close()
  }
}

const onTriggerKeydown = (e: KeyboardEvent) => {
  if (props.disabled) return

  if (!open.value) {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp' || e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      openMenu()
    }
    return
  }

  switch (e.key) {
    case 'Escape':
      e.preventDefault()
      close()
      break
    case 'ArrowDown':
      e.preventDefault()
      if (props.options.length) {
        highlighted.value = (highlighted.value + 1) % props.options.length
      }
      break
    case 'ArrowUp':
      e.preventDefault()
      if (props.options.length) {
        highlighted.value =
          (highlighted.value - 1 + props.options.length) % props.options.length
      }
      break
    case 'Enter':
    case ' ':
      e.preventDefault()
      if (highlighted.value >= 0 && highlighted.value < props.options.length) {
        selectOption(props.options[highlighted.value])
      }
      break
  }
}

onBeforeUnmount(() => {
  document.removeEventListener('mousedown', onDocumentMousedown)
})
</script>

<template>
  <div ref="rootEl" :class="classes">
    <button
      type="button"
      class="Select__trigger"
      :class="{ 'Select__trigger--placeholder': !hasValue }"
      :disabled="disabled"
      role="combobox"
      aria-haspopup="listbox"
      :aria-expanded="open"
      @click="toggle"
      @keydown="onTriggerKeydown"
    >
      <span class="Select__value">{{ hasValue ? triggerLabel : placeholder }}</span>
      <svg
        class="Select__chevron"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        <path
          d="M6 9l6 6 6-6"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>

    <ul v-if="open" class="Select__menu" role="listbox" :aria-multiselectable="multiple">
      <li
        v-for="(option, index) in options"
        :key="option.value"
        class="Select__option"
        :class="{
          'Select__option--highlighted': index === highlighted,
          'Select__option--selected': isSelected(option.value),
        }"
        role="option"
        :aria-selected="isSelected(option.value)"
        @click="selectOption(option)"
        @mousemove="highlighted = index"
      >
        <span class="Select__option-label">{{ option.label }}</span>
        <svg
          v-if="isSelected(option.value)"
          class="Select__check"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          aria-hidden="true"
        >
          <path
            d="M5 12l5 5L20 7"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </li>
    </ul>
  </div>
</template>
