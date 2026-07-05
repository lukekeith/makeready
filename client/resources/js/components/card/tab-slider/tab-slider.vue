<script setup lang="ts">
// TabSlider — web twin of iOS Components/Navigation/TabSlider.swift.
//
// A segmented tab control: a content-hugging row of text tabs on a white@20%
// rounded track, with a brandPrimary rounded pill behind the selected tab.
// From the Swift source:
//   HStack(spacing: 0) { ForEach tabs → Button { Text(tab) } }
//   Text: .font(s17).foregroundColor(.white)
//         .padding(.horizontal, 16).padding(.vertical, 4)
//         .background(selected ? RoundedRectangle(cornerRadius: 4).fill(.brandPrimary))
//   .padding(4)
//   .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.2)))
//
// Both selected and unselected labels are white (only the pill background
// changes), so the only variant-varying data is the tab labels + which index is
// selected. The matchedGeometryEffect spring is an interaction detail; the
// resting snapshot just shows the pill under the selected tab.
//
// The ViewRegistry harness wraps TabSlider in `.padding(16)`; the capture
// `.capture-wrap` supplies that 16px, so this component renders only the control
// itself (its own `.padding(4)`). SF Pro (the iOS system font) drives the 17pt
// tab metrics, hence `-apple-system`.

interface Props {
  tabs?: string[]
  selectedIndex?: number
}

const props = withDefaults(defineProps<Props>(), {
  tabs: () => [],
  selectedIndex: 0,
})

// Additive interaction (like PageHeader's `select`): the compare harness binds
// no listeners, so the twin's captured rendering is unchanged.
const emit = defineEmits<{ select: [index: number] }>()
</script>

<template>
  <div class="TabSliderControl">
    <span
      v-for="(tab, index) in props.tabs"
      :key="index"
      class="TabSliderControl__tab"
      :class="{ 'TabSliderControl__tab--active': index === props.selectedIndex }"
      role="button"
      tabindex="0"
      @click="emit('select', index)"
      @keydown.enter.prevent="emit('select', index)"
    >
      {{ tab }}
    </span>
  </div>
</template>
