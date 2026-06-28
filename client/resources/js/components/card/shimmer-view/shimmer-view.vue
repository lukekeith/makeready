<script setup lang="ts">
// ShimmerView — skeleton-shape twin of iOS Components/Loading/ShimmerView.swift.
//
// On device `ShimmerView` ships as a `.shimmer()` view modifier (an animated
// white@10% gradient sweeping across whatever skeleton shape it decorates), not
// a standalone view. The capture harness (ViewRegistry `component.ShimmerView`)
// builds the skeleton shape the fixture describes — a gray@0.3 rounded block, or
// a leading-aligned column of gray@0.3 text-row bars — and applies `.shimmer()`.
//
// The shimmer gradient starts off-screen (phase = -200) and only sweeps in via
// an `.onAppear` animation, so the frozen snapshot shows just the static gray
// skeleton shapes — which is exactly what this twin renders. Fully data-driven:
//   - shape "block"    → one rounded rectangle (width × height × cornerRadius)
//   - shape "textRows" → a leading-aligned column (12px gaps) of rounded bars
import { computed } from 'vue'

interface ShimmerRow {
  width: number
  height: number
  cornerRadius: number
}

const props = withDefaults(
  defineProps<{
    shape?: 'block' | 'textRows'
    width?: number
    height?: number
    cornerRadius?: number
    rows?: ShimmerRow[]
  }>(),
  {
    shape: 'block',
    width: 320,
    height: 100,
    cornerRadius: 8,
    rows: () => [],
  },
)

const isTextRows = computed(() => props.shape === 'textRows')
</script>

<template>
  <!-- textRows: iOS VStack(alignment: .leading, spacing: 12) — leading-aligned
       column of skeleton bars sized per row. -->
  <div v-if="isTextRows" class="ShimmerView ShimmerView--textRows" aria-hidden="true">
    <div
      v-for="(row, i) in rows"
      :key="i"
      class="ShimmerView__bar"
      :style="{
        width: `${row.width}px`,
        height: `${row.height}px`,
        borderRadius: `${row.cornerRadius}px`,
      }"
    />
  </div>

  <!-- block: iOS RoundedRectangle(cornerRadius:).frame(width:height:). -->
  <div
    v-else
    class="ShimmerView ShimmerView__bar"
    aria-hidden="true"
    :style="{
      width: `${width}px`,
      height: `${height}px`,
      borderRadius: `${cornerRadius}px`,
    }"
  />
</template>
