<script setup lang="ts">
import { computed } from 'vue'
import { activityColor, activityIcon } from './activity-meta'

// A 32px rounded square showing an activity-type icon.
// filled = completed (solid color bg, white icon); otherwise outlined (color border + icon).
const props = withDefaults(
  defineProps<{
    type: string
    filled?: boolean
    size?: number
  }>(),
  { filled: false, size: 32 }
)

const color = computed(() => activityColor(props.type))
const icon = computed(() => activityIcon(props.type))
const iconSize = computed(() => Math.round(props.size * 0.4375))

const style = computed(() => {
  const s = `${props.size}px`
  if (props.filled) {
    return { width: s, height: s, background: color.value, borderColor: color.value, color: '#ffffff' }
  }
  return { width: s, height: s, background: 'transparent', borderColor: color.value, color: color.value }
})
</script>

<template>
  <div class="ActivityCube" :class="{ 'ActivityCube--filled': filled }" :style="style">
    <svg
      :width="iconSize"
      :height="iconSize"
      :viewBox="icon.viewBox"
      fill="none"
      v-html="icon.svg"
    />
  </div>
</template>
