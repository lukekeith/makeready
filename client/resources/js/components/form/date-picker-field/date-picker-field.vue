<script lang="ts">
import { cva } from '../../../util/cva'

// DatePickerField — form. A labeled wrapper around a styled native
// <input type="date"> (full custom calendar is out of scope — Phase 4). CVA
// `state` mirrors the `.DatePickerField--*` SCSS modifiers exactly. Styles live
// in resources/css/components/form/date-picker-field.scss. The .vue never
// imports scss.
export const DatePickerFieldCva = cva('DatePickerField', {
  variants: {
    state: {
      Default: '',
      Error: 'DatePickerField--error',
    },
  },
  defaultVariants: {
    state: 'Default',
  },
})

export interface DateRangeValue {
  start: string
  end: string
}
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue?: string | DateRangeValue
  min?: string
  max?: string
  disabled?: boolean
  placeholder?: string
  range?: boolean
  state?: keyof typeof DatePickerFieldCva.state
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  disabled: false,
  range: false,
  state: () => DatePickerFieldCva.defaults?.state as keyof typeof DatePickerFieldCva.state,
})

const emit = defineEmits<{ 'update:modelValue': [string | DateRangeValue] }>()

const classes = computed(() =>
  classnames(DatePickerFieldCva.variants({ state: props.state }), props.class)
)

const rangeValue = computed<DateRangeValue>(() => {
  const v = props.modelValue
  if (v && typeof v === 'object') return v
  return { start: '', end: '' }
})

const onSingleInput = (e: Event) => {
  emit('update:modelValue', (e.target as HTMLInputElement).value)
}

const onStartInput = (e: Event) => {
  emit('update:modelValue', {
    start: (e.target as HTMLInputElement).value,
    end: rangeValue.value.end,
  })
}

const onEndInput = (e: Event) => {
  emit('update:modelValue', {
    start: rangeValue.value.start,
    end: (e.target as HTMLInputElement).value,
  })
}
</script>

<template>
  <div :class="classes">
    <template v-if="range">
      <div class="DatePickerField__range">
        <input
          class="DatePickerField__input"
          type="date"
          :value="rangeValue.start"
          :min="min"
          :max="rangeValue.end || max"
          :disabled="disabled"
          :placeholder="placeholder"
          @input="onStartInput"
        />
        <span class="DatePickerField__separator" aria-hidden="true">–</span>
        <input
          class="DatePickerField__input"
          type="date"
          :value="rangeValue.end"
          :min="rangeValue.start || min"
          :max="max"
          :disabled="disabled"
          :placeholder="placeholder"
          @input="onEndInput"
        />
      </div>
    </template>
    <input
      v-else
      class="DatePickerField__input"
      type="date"
      :value="modelValue"
      :min="min"
      :max="max"
      :disabled="disabled"
      :placeholder="placeholder"
      @input="onSingleInput"
    />
  </div>
</template>
