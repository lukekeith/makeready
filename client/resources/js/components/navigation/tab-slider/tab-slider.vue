<script lang="ts">
// TabSlider — navigation. Animated segmented control (iOS TabSlider parity). A
// pill track with a sliding thumb that translates to the active segment. No CVA
// variants (single visual style), so this component emits the block class only.
// Styles are global via app.scss; CSS lives in
// resources/css/components/navigation/tab-slider.scss.

export interface TabSliderTab {
  key: string
  label: string
}
</script>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  // Either an array of plain string keys, or { key, label } objects.
  tabs: Array<string | TabSliderTab>
  modelValue: string
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const normalized = computed<TabSliderTab[]>(() =>
  props.tabs.map((t) =>
    typeof t === 'string' ? { key: t, label: t } : t
  )
)

const activeIndex = computed(() =>
  Math.max(
    0,
    normalized.value.findIndex((t) => t.key === props.modelValue)
  )
)

const count = computed(() => Math.max(1, normalized.value.length))

// Track width is split into N equal segments; the thumb is 100/N % wide and
// translated by (100% of its own width) * index.
const thumbStyle = computed(() => ({
  width: `${100 / count.value}%`,
  transform: `translateX(${100 * activeIndex.value}%)`,
}))

const select = (key: string) => {
  if (key !== props.modelValue) emit('update:modelValue', key)
}
</script>

<template>
  <div
    :class="['TabSlider', props.class]"
    role="tablist"
  >
    <span class="TabSlider__thumb" :style="thumbStyle" aria-hidden="true" />
    <button
      v-for="tab in normalized"
      :key="tab.key"
      type="button"
      role="tab"
      :aria-selected="tab.key === modelValue"
      class="TabSlider__segment"
      :class="{ 'TabSlider__segment--active': tab.key === modelValue }"
      @click="select(tab.key)"
    >
      {{ tab.label }}
    </button>
  </div>
</template>
