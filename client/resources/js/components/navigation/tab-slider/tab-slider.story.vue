<script setup lang="ts">
import { ref } from 'vue'
import TabSlider from './tab-slider.vue'

// Two-segment (plain string tabs)
const view = ref('list')

// Three-segment ({ key, label } tabs)
const range = ref('week')
const rangeTabs = [
  { key: 'day', label: 'Day' },
  { key: 'week', label: 'Week' },
  { key: 'month', label: 'Month' },
]
</script>

<template>
  <Story title="Navigation/TabSlider" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Two segments">
      <div class="wrap">
        <TabSlider v-model="view" :tabs="['List', 'Grid']" />
        <p class="caption">Active: {{ view }}</p>
      </div>
    </Variant>

    <Variant title="Three segments">
      <div class="wrap">
        <TabSlider v-model="range" :tabs="rangeTabs" />
        <p class="caption">Active: {{ range }}</p>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.wrap { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); }
.caption { margin: 0; color: var(--fg-secondary); font-size: var(--text-sm); }
</style>
