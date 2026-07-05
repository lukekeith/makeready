<script setup lang="ts">
// AgeRangeInput — labelled row with two side-by-side age chips (iOS
// AgeRangeInput, rendered inside a FieldGroup). Data-driven; the iPhone twin is
// captured inside a FieldGroup, so the FieldGroup surface (white@5% card,
// radius 10, 4px vertical padding) is reproduced here as the component root.
//
// BEM block is `.AgeRangeField` (not `.AgeRangeInput`) to avoid colliding with
// the pre-existing, unrelated components/form/age-range-input component.
//
// Layout mirrors iOS exactly:
//   FieldGroup card → row (h-pad 16, v-pad 8): label · spacer · [min][max] chips
//   each chip: 17pt white on white@10%, 8px radius, 10×8 padding, 4px gap.
//
// Props:
//   label   string — left-aligned field label
//   minAge  string — value shown in the first chip
//   maxAge  string — value shown in the second chip
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  label?: string
  minAge?: string
  maxAge?: string
  // Additive: invisible native selects over the chips (the MenuInput idiom) —
  // iOS presents "Age from" (0…max) / "Age to" (min…99) wheel sheets. The
  // compare harness never sets this, so the captured rendering is unchanged.
  interactive?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  label: 'Age range',
  minAge: '0',
  maxAge: '99',
  interactive: false,
})

const emit = defineEmits<{
  min: [MouseEvent]
  max: [MouseEvent]
  'update:minAge': [value: string]
  'update:maxAge': [value: string]
}>()

// iOS wheel option ranges: min = 0…maxAge, max = minAge…99.
const minOptions = computed(() => {
  const hi = Number(props.maxAge) || 99
  return Array.from({ length: hi + 1 }, (_, i) => String(i))
})
const maxOptions = computed(() => {
  const lo = Number(props.minAge) || 0
  return Array.from({ length: 99 - lo + 1 }, (_, i) => String(lo + i))
})
</script>

<template>
  <div :class="classnames('AgeRangeField', props.class)">
    <div class="AgeRangeField__row">
      <span class="AgeRangeField__label">{{ label }}</span>
      <div class="AgeRangeField__chips">
        <button type="button" class="AgeRangeField__chip" @click="emit('min', $event)">
          {{ minAge }}
          <select
            v-if="interactive"
            class="AgeRangeField__select"
            :value="minAge"
            aria-label="Age from"
            @change="emit('update:minAge', ($event.target as HTMLSelectElement).value)"
          >
            <option v-for="opt in minOptions" :key="opt" :value="opt">{{ opt }}</option>
          </select>
        </button>
        <button type="button" class="AgeRangeField__chip" @click="emit('max', $event)">
          {{ maxAge }}
          <select
            v-if="interactive"
            class="AgeRangeField__select"
            :value="maxAge"
            aria-label="Age to"
            @change="emit('update:maxAge', ($event.target as HTMLSelectElement).value)"
          >
            <option v-for="opt in maxOptions" :key="opt" :value="opt">{{ opt }}</option>
          </select>
        </button>
      </div>
    </div>
  </div>
</template>
