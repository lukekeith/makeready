<script setup lang="ts">
// InlineFontSizePicker — twin of iOS Components/Input/InlineFontSizePicker.swift.
//
// A horizontal row of 5 "Aa" tiles (xs/s/m/lg/xl), spacing 4. Each tile fills the
// available width equally (iOS .frame(maxWidth: .infinity)), is 60pt tall, has a
// white@5% background + 4pt corner radius, and shows "Aa" in semibold white at a
// per-key point size. The selected key's tile gets a 2pt white border.
//
// iOS layout (as rendered by ViewRegistry `component.InlineFontSizePicker`):
//   HStack(spacing: 4) {                    → flex row, gap 4
//     ForEach(keys) { key in
//       Text("Aa")
//         .font(.system(size: pointSize(key), weight: .semibold))
//         .foregroundColor(.white)
//         .frame(maxWidth: .infinity).frame(height: 60)   → flex:1, height 60
//         .background(Color.white.opacity(0.05))          → white@5%
//         .clipShape(RoundedRectangle(cornerRadius: 4))   → radius 4
//         .overlay(stroke isSelected ? .white : .clear, lineWidth: 2)
//     }
//   }.padding(16)                           → supplied by the harness .capture-wrap
//
// pointSize(_:) — tile glyph point size per key (matches the iOS switch).
//
// Fully data-driven via `selectedSize`. BEM modifiers mirror
// resources/css/components/card/inline-font-size-picker.scss.
import { computed } from 'vue'

const SIZE_KEYS = ['xs', 's', 'm', 'lg', 'xl'] as const
type SizeKey = (typeof SIZE_KEYS)[number]
const POINT_SIZE: Record<SizeKey, number> = { xs: 13, s: 16, m: 19, lg: 23, xl: 27 }

interface Props {
  // Selected font-size key (xs/s/m/lg/xl) — drives which tile gets the white border.
  selectedSize?: SizeKey
}

const props = withDefaults(defineProps<Props>(), {
  selectedSize: 'm',
})

const tiles = computed(() =>
  SIZE_KEYS.map((key) => ({
    key,
    fontSize: `${POINT_SIZE[key]}px`,
    selected: props.selectedSize === key,
  })),
)
</script>

<template>
  <div class="InlineFontSizePicker">
    <div
      v-for="tile in tiles"
      :key="tile.key"
      class="InlineFontSizePicker__tile"
      :class="{ 'InlineFontSizePicker__tile--selected': tile.selected }"
    >
      <span class="InlineFontSizePicker__glyph" :style="{ fontSize: tile.fontSize }">Aa</span>
    </div>
  </div>
</template>
