<script lang="ts">
import { cva } from '../../../util/cva'

// WeekdayIndicator — data. A 7-cell day-of-week selector/display (iOS
// WeekdayIndicator). CVA variant keys mirror the SCSS modifiers in
// resources/css/components/data/weekday-indicator.scss exactly. Styles are
// global via app.scss, so this component only emits classes.
export const WeekdayIndicatorCva = cva('WeekdayIndicator', {
  variants: {
    state: {
      Readonly: 'WeekdayIndicator--readonly',
      Disabled: 'WeekdayIndicator--disabled',
    },
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue: number[]
  labels?: string[]
  readonly?: boolean
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  // Inlined (not a module-scope const) — the SFC compiler hoists default
  // factories and cannot reference a <script setup> binding.
  labels: () => ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
  readonly: false,
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [number[]] }>()

const classes = computed(() =>
  classnames(
    WeekdayIndicatorCva.variants({
      state: props.disabled ? 'Disabled' : props.readonly ? 'Readonly' : null,
    }),
    props.class
  )
)

const isSelected = (day: number) => props.modelValue.includes(day)

const cellClasses = (day: number) =>
  classnames(
    'WeekdayIndicator__cell',
    isSelected(day) && 'WeekdayIndicator__cell--selected'
  )

const toggle = (day: number) => {
  if (props.readonly || props.disabled) return
  const next = isSelected(day)
    ? props.modelValue.filter((d) => d !== day)
    : [...props.modelValue, day].sort((a, b) => a - b)
  emit('update:modelValue', next)
}
</script>

<template>
  <div :class="classes" role="group">
    <button
      v-for="(label, day) in labels"
      :key="day"
      type="button"
      :class="cellClasses(day)"
      :disabled="disabled"
      :aria-pressed="isSelected(day)"
      @click="toggle(day)"
    >
      {{ label }}
    </button>
  </div>
</template>
