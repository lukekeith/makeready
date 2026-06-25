<script lang="ts">
import { cva } from '../../../util/cva'

// SearchField — form. Pill search box with leading magnifier and a trailing
// clear button (shown only when there's text). CVA mirrors the `.SearchField--*`
// modifiers in resources/css/components/form/search-field.scss.
export const SearchFieldCva = cva('SearchField', {
  variants: {
    state: {
      Default: '',
      Disabled: 'SearchField--disabled',
    },
  },
  defaultVariants: {
    state: 'Default',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue?: string
  placeholder?: string
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  placeholder: 'Search',
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [string]; clear: [] }>()

const classes = computed(() =>
  classnames(
    SearchFieldCva.variants({ state: props.disabled ? 'Disabled' : 'Default' }),
    props.class
  )
)

const hasValue = computed(() => (props.modelValue?.length ?? 0) > 0)

const onInput = (e: Event) => {
  emit('update:modelValue', (e.target as HTMLInputElement).value)
}

const onClear = () => {
  emit('update:modelValue', '')
  emit('clear')
}
</script>

<template>
  <div :class="classes">
    <span class="SearchField__icon" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></svg>
    </span>
    <input
      class="SearchField__input"
      type="search"
      :value="modelValue"
      :placeholder="placeholder"
      :disabled="disabled"
      @input="onInput"
    />
    <button
      v-if="hasValue && !disabled"
      class="SearchField__clear"
      type="button"
      aria-label="Clear search"
      @click="onClear"
    >
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12" /></svg>
    </button>
  </div>
</template>
