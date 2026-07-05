<script setup lang="ts">
// BlockStyleColorPicker — content of the dynamic
// "blockStyleColorPicker_<blockId>" menu (iOS BlockStyleColorPickerContent,
// BlockStyleEditor.swift:305-482): 24 swatches (4×6, spacing 2, r2, h32,
// selected = white stroke 2), an opacity slider (track h4, thumb 20, %
// readout s13Semibold monospaced, default 0.8, debounced 200ms), and a
// Clear row (xmark.circle + s13Semibold).
import { computed, ref } from 'vue'
import { inject } from 'vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'

const props = defineProps<{
  color: string | null
  opacity: number | null
  onPick?: (hex: string) => void
  onOpacity?: (value: number) => void
  onClear?: () => void
}>()

const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)

// iOS BlockStyleEditor.colorPalette (BlockStyleEditor.swift:319-328).
const PALETTE = [
  '#6c47ff', '#3e1bcc', '#1f0098', '#002198', '#9e173f', '#62001d',
  '#0981d1', '#44a6e7', '#4467e7', '#2245c1', '#ce3965', '#6b0002',
  '#005a55', '#1972c6', '#125798', '#003d77', '#119732', '#2f3341',
  '#0d7a74', '#229e98', '#36bcb5', '#1fb444', '#00671a', '#000000',
]

const selected = ref<string | null>(props.color)
const localOpacity = ref(props.opacity ?? 0.8)
const pct = computed(() => `${Math.round(localOpacity.value * 100)}%`)

function pick(hex: string): void {
  selected.value = hex
  props.onPick?.(hex)
}

// iOS debounces the slider writes 200ms.
let opacityTimer: number | undefined
function onSlide(e: Event): void {
  localOpacity.value = Number((e.target as HTMLInputElement).value)
  window.clearTimeout(opacityTimer)
  opacityTimer = window.setTimeout(() => props.onOpacity?.(localOpacity.value), 200)
}

function clear(): void {
  selected.value = null
  props.onClear?.()
  overlay?.dismiss()
}

const XMARK_CIRCLE =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="10" cy="10" r="8.2"/><path d="M7 7l6 6M13 7l-6 6" stroke-linecap="round"/></svg>'
</script>

<template>
  <div class="BlockStyleColorPicker">
    <div class="BlockStyleColorPicker__grid">
      <button
        v-for="hex in PALETTE"
        :key="hex"
        type="button"
        class="BlockStyleColorPicker__swatch"
        :class="{ 'BlockStyleColorPicker__swatch--selected': selected === hex }"
        :style="{ backgroundColor: hex }"
        :aria-label="hex"
        @click="pick(hex)"
      ></button>
    </div>

    <div class="BlockStyleColorPicker__opacityRow">
      <input
        class="BlockStyleColorPicker__slider"
        type="range"
        min="0"
        max="1"
        step="0.01"
        :value="localOpacity"
        aria-label="Overlay opacity"
        @input="onSlide"
      />
      <span class="BlockStyleColorPicker__pct">{{ pct }}</span>
    </div>

    <button type="button" class="BlockStyleColorPicker__clear" @click="clear">
      <span class="BlockStyleColorPicker__clearIcon" aria-hidden="true" v-html="XMARK_CIRCLE" />
      Clear
    </button>
  </div>
</template>

<style scoped>
.BlockStyleColorPicker {
  display: flex;
  flex-direction: column;
  gap: 16px; /* iOS VStack(spacing: 16) */
  padding: 8px 16px 32px;
}

.BlockStyleColorPicker__grid {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 2px; /* iOS spacing 2 */
}

.BlockStyleColorPicker__swatch {
  height: 32px;
  border: 2px solid transparent;
  border-radius: 2px;
  padding: 0;
  cursor: pointer;
}

.BlockStyleColorPicker__swatch--selected {
  border-color: #fff;
}

.BlockStyleColorPicker__opacityRow {
  display: flex;
  align-items: center;
  gap: 12px;
}

.BlockStyleColorPicker__slider {
  flex: 1;
  appearance: none;
  height: 4px; /* iOS track height */
  border-radius: 2px;
  background: rgba(255, 255, 255, 0.15);
}

.BlockStyleColorPicker__slider::-webkit-slider-thumb {
  appearance: none;
  width: 20px; /* iOS thumb 20 */
  height: 20px;
  border-radius: 50%;
  background: #fff;
  cursor: pointer;
}

.BlockStyleColorPicker__pct {
  min-width: 44px;
  text-align: right;
  font-family: ui-monospace, -apple-system, monospace;
  font-size: 13px;
  font-weight: 600; /* iOS s13Semibold.monospacedDigit() */
  color: #fff;
}

.BlockStyleColorPicker__clear {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 12px;
  border: none;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  font-size: 13px;
  font-weight: 600; /* iOS s13Semibold */
  color: #fff;
  cursor: pointer;
}

.BlockStyleColorPicker__clearIcon {
  display: flex;
  width: 16px;
  height: 16px;
}

.BlockStyleColorPicker__clearIcon :deep(svg) {
  width: 16px;
  height: 16px;
}
</style>
