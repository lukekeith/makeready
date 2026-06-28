<script setup lang="ts">
// DatePickerField — twin of iOS Components/Input/DatePickerField.swift.
//
// A single field-group row: a label on the left, a spacer, then two tappable
// pills — a date pill and a time pill — on the right. The whole row sits inside
// a FieldGroup card (white@5% rounded container) exactly as the iPhone
// ViewRegistry wraps it (`FieldGroup { DatePickerField(...) }.padding(16)`); the
// capture harness's `.capture-wrap` supplies the matching 16px gutter.
//
// The date/time are pre-formatted by the adapter (local-tz, matching the iOS
// DateFormatters: monthPaddedDayYear → "Jan 30, 2026", shortTime → "03:41"),
// so this twin is purely presentational.
//
// BEM modifiers mirror resources/css/components/card/date-picker-field.scss.
interface Props {
  label?: string
  dateText?: string
  timeText?: string
}

withDefaults(defineProps<Props>(), {
  label: 'Date',
  dateText: '',
  timeText: '',
})
</script>

<template>
  <div class="DatePickerField">
    <div class="DatePickerField__row">
      <span class="DatePickerField__label">{{ label }}</span>
      <span class="DatePickerField__spacer" aria-hidden="true"></span>
      <span class="DatePickerField__pill">{{ dateText }}</span>
      <span class="DatePickerField__pill">{{ timeText }}</span>
    </div>
  </div>
</template>
