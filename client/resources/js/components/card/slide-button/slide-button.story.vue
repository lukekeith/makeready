<script setup lang="ts">
import SlideButton from './slide-button.vue'
</script>

<template>
  <Story title="Cards/SlideButton" :layout="{ type: 'grid', width: 200 }">
    <Variant title="Normal">
      <div class="row">
        <SlideButton label="Edit" style="Normal">
          <template #icon><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" /></svg></template>
        </SlideButton>
      </div>
    </Variant>
    <Variant title="Neutral">
      <div class="row">
        <SlideButton label="Pin" style="Neutral">
          <template #icon><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 17v5M9 10.76V5a3 3 0 0 1 6 0v5.76" /></svg></template>
        </SlideButton>
      </div>
    </Variant>
    <Variant title="Destructive">
      <div class="row">
        <SlideButton label="Delete" style="Destructive">
          <template #icon><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6" /></svg></template>
        </SlideButton>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-sm); height: 72px; padding: var(--space-md); }
</style>
