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
import { classnames } from '../../../util/classnames'

interface Props {
  label?: string
  minAge?: string
  maxAge?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  label: 'Age range',
  minAge: '0',
  maxAge: '99',
})

const emit = defineEmits<{ min: [MouseEvent]; max: [MouseEvent] }>()
</script>

<template>
  <div :class="classnames('AgeRangeField', props.class)">
    <div class="AgeRangeField__row">
      <span class="AgeRangeField__label">{{ label }}</span>
      <div class="AgeRangeField__chips">
        <button type="button" class="AgeRangeField__chip" @click="emit('min', $event)">
          {{ minAge }}
        </button>
        <button type="button" class="AgeRangeField__chip" @click="emit('max', $event)">
          {{ maxAge }}
        </button>
      </div>
    </div>
  </div>
</template>
