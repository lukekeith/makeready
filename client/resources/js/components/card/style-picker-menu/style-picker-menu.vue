<script setup lang="ts">
// StylePickerMenu — twin of iOS Components/Overlays/StylePickerMenu.swift.
//
// The bottom-sheet menu shown after a tap-and-hold selection inside a locked
// read block (or when tapping an existing styled span). Pure, fully data-driven:
//   • a snippet preview — “<snippet>” in s13 white@50%, single-line, middle-
//     truncated, left-aligned, padded .bottom 12;
//   • a rounded white@5% card holding two StylePickerRows (Bold / Highlight). Each
//     row: a 22×22 leading circle (filled brand checkmark when selected, else a
//     white@25% outline) + 12 gap + s17Semibold label (brand when selected, else
//     white) + Spacer + a trailing sample chip (Bold → s17Bold "Bold" no bg;
//     Highlight → s17 "Highlight" on a brand@35% h8/v2 radius-4 chip);
//   • when a style is applied, a white@5% rounded "Remove style" button
//     (s17Semibold, #ff5d5d), padded .top 8;
//   • a "Cancel" button (s17Semibold, white@70%), padded .top 4 / .bottom 8.
//
// OverlayManager's dark scrim / slide-up chrome is out of scope for the isolated
// snapshot. BEM classes mirror resources/css/components/card/style-picker-menu.scss.
//
// NB: the iPhone reference renders the snippet preview as empty quotes (“”). The
// component.StylePickerMenu ViewRegistry case reads `state.component.text`, but the
// fixture's shared block carries the snippet under `snippet`, so the iOS Text gets
// "" (the same data-key artifact as HeatMapChart / SearchableList). This twin stays
// data-driven and renders the real snippet from props — a surfaced parity gap on
// that one preview line; the rows / buttons match the iPhone pixel-tight.

import { computed } from 'vue'

interface Props {
  snippet?: string
  // null | 'bold' | 'highlight'.  NB: NOT named `style` — that's a reserved Vue/HTML
  // attribute, so a `style` prop silently never binds via v-bind (same trap as
  // ConfirmationOverlay's `tone` and MenuInput's `pickerStyle`).
  appliedStyle?: string | null
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  snippet: '',
  appliedStyle: null,
})

// ADDITIVE emits (production .stylePicker route; captures bind nothing).
// iOS StylePickerMenu fires onSelect ONLY when the picked style differs from
// the current one; "Remove style" fires onSelect(nil); Cancel just dismisses.
const emit = defineEmits<{
  select: [style: 'bold' | 'highlight' | null]
  cancel: []
}>()

const isBold = computed(() => props.appliedStyle === 'bold')
const isHighlight = computed(() => props.appliedStyle === 'highlight')
const hasStyle = computed(() => isBold.value || isHighlight.value)

function pick(style: 'bold' | 'highlight'): void {
  if (props.appliedStyle === style) return
  emit('select', style)
}
</script>

<template>
  <div :class="['StylePickerMenu', props.class]">
    <!-- Snippet preview -->
    <div class="StylePickerMenu__snippet">{{ '“' + snippet + '”' }}</div>

    <!-- Style rows card -->
    <div class="StylePickerMenu__card">
      <!-- Bold -->
      <div class="StylePickerMenu__row" role="button" tabindex="0" @click="pick('bold')">
        <span
          class="StylePickerMenu__circle"
          :class="{ 'StylePickerMenu__circle--selected': isBold }"
          aria-hidden="true"
        >
          <svg v-if="isBold" viewBox="0 0 22 22" aria-hidden="true">
            <circle cx="11" cy="11" r="9" fill="currentColor" />
            <path
              d="M7 11l2.6 2.6L15 8.2"
              fill="none"
              stroke="#fff"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <svg v-else viewBox="0 0 22 22" aria-hidden="true">
            <circle cx="11" cy="11" r="9" fill="none" stroke="currentColor" stroke-width="1.5" />
          </svg>
        </span>
        <span
          class="StylePickerMenu__label"
          :class="{ 'StylePickerMenu__label--selected': isBold }"
        >Bold</span>
        <span class="StylePickerMenu__spacer" />
        <span class="StylePickerMenu__sample StylePickerMenu__sample--bold">Bold</span>
      </div>

      <!-- Highlight -->
      <div class="StylePickerMenu__row" role="button" tabindex="0" @click="pick('highlight')">
        <span
          class="StylePickerMenu__circle"
          :class="{ 'StylePickerMenu__circle--selected': isHighlight }"
          aria-hidden="true"
        >
          <svg v-if="isHighlight" viewBox="0 0 22 22" aria-hidden="true">
            <circle cx="11" cy="11" r="9" fill="currentColor" />
            <path
              d="M7 11l2.6 2.6L15 8.2"
              fill="none"
              stroke="#fff"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <svg v-else viewBox="0 0 22 22" aria-hidden="true">
            <circle cx="11" cy="11" r="9" fill="none" stroke="currentColor" stroke-width="1.5" />
          </svg>
        </span>
        <span
          class="StylePickerMenu__label"
          :class="{ 'StylePickerMenu__label--selected': isHighlight }"
        >Highlight</span>
        <span class="StylePickerMenu__spacer" />
        <span class="StylePickerMenu__sample StylePickerMenu__sample--highlight">Highlight</span>
      </div>
    </div>

    <!-- Remove style (only when a style is applied) -->
    <button v-if="hasStyle" type="button" class="StylePickerMenu__remove" @click="emit('select', null)">Remove style</button>

    <!-- Cancel -->
    <button type="button" class="StylePickerMenu__cancel" @click="emit('cancel')">Cancel</button>
  </div>
</template>
