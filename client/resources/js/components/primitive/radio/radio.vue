<script lang="ts">
import { cva } from '../../../util/cva'

// Radio — primitive. CVA modifiers mirror the SCSS in
// resources/css/components/primitive/radio.scss exactly.
export const RadioCva = cva('Radio', {
  variants: {
    size: {
      Sm: 'Radio--sm',
      Md: 'Radio--md',
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
  modelValue?: string
  value: string
  name?: string
  size?: keyof typeof RadioCva.size
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  size: () => RadioCva.defaults?.size as keyof typeof RadioCva.size,
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const slots = useSlots()

const checked = computed(() => props.modelValue === props.value)

const classes = computed(() =>
  classnames(
    RadioCva.variants({ size: props.size }),
    props.disabled && 'Radio--disabled',
    props.class
  )
)

const onChange = () => {
  emit('update:modelValue', props.value)
}
</script>

<template>
  <label :class="classes">
    <input
      class="Radio__input"
      type="radio"
      :name="name"
      :value="value"
      :checked="checked"
      :disabled="disabled"
      @change="onChange"
    />
    <span class="Radio__circle">
      <span class="Radio__dot"></span>
    </span>
    <span v-if="slots.default" class="Radio__label"><slot /></span>
  </label>
</template>
