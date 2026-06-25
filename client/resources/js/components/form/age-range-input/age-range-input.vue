<script setup lang="ts">
// AgeRangeInput — form. A min/max numeric age range (iOS AgeRangeInput): two
// small number inputs styled like the primitive `.Input`, an en-dash separator,
// and a trailing "yrs" unit. Clamps to [minAge, maxAge] and enforces min ≤ max
// on blur. Styled in resources/css/components/form/age-range-input.scss
// (block `.AgeRangeInput`). Tokens only.

interface AgeRange {
  min: number | null
  max: number | null
}

interface Props {
  modelValue?: AgeRange
  disabled?: boolean
  minAge?: number
  maxAge?: number
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: () => ({ min: null, max: null }),
  disabled: false,
  minAge: 0,
  maxAge: 120,
})

const emit = defineEmits<{ 'update:modelValue': [value: AgeRange] }>()

const parse = (raw: string): number | null => {
  if (raw.trim() === '') return null
  const n = Number.parseInt(raw, 10)
  return Number.isNaN(n) ? null : n
}

const clamp = (n: number | null): number | null => {
  if (n === null) return null
  return Math.min(props.maxAge, Math.max(props.minAge, n))
}

const onMinInput = (e: Event) => {
  emit('update:modelValue', {
    min: parse((e.target as HTMLInputElement).value),
    max: props.modelValue.max,
  })
}

const onMaxInput = (e: Event) => {
  emit('update:modelValue', {
    min: props.modelValue.min,
    max: parse((e.target as HTMLInputElement).value),
  })
}

const normalize = () => {
  let min = clamp(props.modelValue.min)
  let max = clamp(props.modelValue.max)
  if (min !== null && max !== null && min > max) {
    // Keep both ends, clamp min down to max so min ≤ max holds.
    min = max
  }
  emit('update:modelValue', { min, max })
}
</script>

<template>
  <div class="AgeRangeInput" :class="{ 'AgeRangeInput--disabled': disabled }">
    <input
      class="Input AgeRangeInput__field"
      type="number"
      inputmode="numeric"
      :min="minAge"
      :max="maxAge"
      :value="modelValue.min ?? ''"
      :disabled="disabled"
      aria-label="Minimum age"
      @input="onMinInput"
      @blur="normalize"
    />
    <span class="AgeRangeInput__separator" aria-hidden="true">–</span>
    <input
      class="Input AgeRangeInput__field"
      type="number"
      inputmode="numeric"
      :min="minAge"
      :max="maxAge"
      :value="modelValue.max ?? ''"
      :disabled="disabled"
      aria-label="Maximum age"
      @input="onMaxInput"
      @blur="normalize"
    />
    <span class="AgeRangeInput__unit">yrs</span>
  </div>
</template>
