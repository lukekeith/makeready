<script setup lang="ts">
import { ref } from 'vue'
import WeekdayIndicator from './weekday-indicator.vue'

const selected = ref<number[]>([1, 3, 5]) // M / W / F
</script>

<template>
  <Story title="Data/WeekdayIndicator" :layout="{ type: 'grid', width: 320 }">
    <Variant title="Editable selector">
      <div class="wd-wrap">
        <WeekdayIndicator v-model="selected" />
        <p class="wd-caption">Selected: {{ selected.join(', ') || 'none' }}</p>
      </div>
    </Variant>

    <Variant title="Readonly display (M/W/F)">
      <WeekdayIndicator :model-value="[1, 3, 5]" readonly />
    </Variant>

    <Variant title="Disabled">
      <WeekdayIndicator :model-value="[0, 6]" disabled />
    </Variant>
  </Story>
</template>

<style scoped>
.wd-wrap { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); }
.wd-caption { font-size: var(--text-xs); color: var(--fg-tertiary); margin: 0; }
</style>
