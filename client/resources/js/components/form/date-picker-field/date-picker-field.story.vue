<script setup lang="ts">
import { ref } from 'vue'
import DatePickerField, { type DateRangeValue } from './date-picker-field.vue'

const empty = ref('')
const selected = ref('2026-06-24')
const errored = ref('')
const range = ref<DateRangeValue>({ start: '2026-06-01', end: '2026-06-30' })
</script>

<template>
  <Story title="Forms/DatePickerField" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default (empty)">
      <DatePickerField v-model="empty" />
    </Variant>
    <Variant title="Selected">
      <DatePickerField v-model="selected" />
    </Variant>
    <Variant title="Error">
      <DatePickerField v-model="errored" state="Error" />
    </Variant>
    <Variant title="Range">
      <DatePickerField v-model="range" range />
    </Variant>
    <Variant title="Min / Max">
      <DatePickerField v-model="selected" min="2026-06-01" max="2026-06-30" />
    </Variant>
    <Variant title="Disabled">
      <DatePickerField :model-value="'2026-06-24'" disabled />
    </Variant>
  </Story>
</template>
