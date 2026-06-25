<script lang="ts">
import { cva } from '../../../util/cva'

// TextInput — form. Wraps the existing primitive `.Input` (styled in
// resources/css/components/primitive/input.scss). CVA variant names mirror the
// `.Input--*` SCSS modifiers exactly. The optional icon-affordance wrapper
// (`.TextInput`) is styled in resources/css/components/form/text-input.scss.
export const TextInputCva = cva('Input', {
  variants: {
    state: {
      Default: '',
      Error: 'Input--error',
      Success: 'Input--success',
    },
    size: {
      Sm: 'Input--size-sm',
      Md: 'Input--size-md',
      Lg: 'Input--size-lg',
    },
  },
  defaultVariants: {
    state: 'Default',
    size: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed, useSlots } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue?: string
  state?: keyof typeof TextInputCva.state
  size?: keyof typeof TextInputCva.size
  type?: 'text' | 'email' | 'tel' | 'number' | 'password'
  inputmode?: 'text' | 'email' | 'tel' | 'numeric' | 'decimal' | 'search' | 'url' | 'none'
  placeholder?: string
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  state: () => TextInputCva.defaults?.state as keyof typeof TextInputCva.state,
  size: () => TextInputCva.defaults?.size as keyof typeof TextInputCva.size,
  type: 'text',
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const slots = useSlots()
const hasLeading = computed(() => !!slots.leading)
const hasTrailing = computed(() => !!slots.trailing)
const hasIcon = computed(() => hasLeading.value || hasTrailing.value)

const inputClasses = computed(() =>
  classnames(
    TextInputCva.variants({ state: props.state, size: props.size }),
    hasLeading.value && 'TextInput__input--leading',
    hasTrailing.value && 'TextInput__input--trailing',
    props.class
  )
)

const onInput = (e: Event) => {
  emit('update:modelValue', (e.target as HTMLInputElement).value)
}
</script>

<template>
  <div v-if="hasIcon" class="TextInput">
    <span v-if="hasLeading" class="TextInput__icon TextInput__icon--leading" aria-hidden="true">
      <slot name="leading" />
    </span>
    <input
      :class="inputClasses"
      :type="type"
      :inputmode="inputmode"
      :value="modelValue"
      :placeholder="placeholder"
      :disabled="disabled"
      @input="onInput"
    />
    <span v-if="hasTrailing" class="TextInput__icon TextInput__icon--trailing" aria-hidden="true">
      <slot name="trailing" />
    </span>
  </div>
  <input
    v-else
    :class="inputClasses"
    :type="type"
    :inputmode="inputmode"
    :value="modelValue"
    :placeholder="placeholder"
    :disabled="disabled"
    @input="onInput"
  />
</template>
