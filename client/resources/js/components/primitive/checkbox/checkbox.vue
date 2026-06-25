<script lang="ts">
import { cva } from '../../../util/cva'

// Checkbox — primitive. CVA modifiers mirror the SCSS in
// resources/css/components/primitive/checkbox.scss exactly.
export const CheckboxCva = cva('Checkbox', {
  variants: {
    size: {
      Sm: 'Checkbox--sm',
      Md: 'Checkbox--md',
    },
  },
  defaultVariants: {
    size: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed, useSlots } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue?: boolean
  size?: keyof typeof CheckboxCva.size
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: false,
  size: () => CheckboxCva.defaults?.size as keyof typeof CheckboxCva.size,
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>()

const slots = useSlots()

const classes = computed(() =>
  classnames(
    CheckboxCva.variants({ size: props.size }),
    props.disabled && 'Checkbox--disabled',
    props.class
  )
)

const onChange = (e: Event) => {
  emit('update:modelValue', (e.target as HTMLInputElement).checked)
}
</script>

<template>
  <label :class="classes">
    <input
      class="Checkbox__input"
      type="checkbox"
      :checked="modelValue"
      :disabled="disabled"
      @change="onChange"
    />
    <span class="Checkbox__box">
      <svg
        class="Checkbox__check"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        <path
          d="M5 12.5L10 17.5L19 7.5"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </span>
    <span v-if="slots.default" class="Checkbox__label"><slot /></span>
  </label>
</template>
