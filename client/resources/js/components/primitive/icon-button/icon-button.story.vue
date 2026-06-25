<script setup lang="ts">
import IconButton from './icon-button.vue'

const variants = ['Default', 'Brand', 'White', 'Blur'] as const
const sizes = ['Sm', 'Md', 'Lg', 'Xl48', 'Xl64'] as const
</script>

<template>
  <Story title="Primitives/IconButton" :layout="{ type: 'grid', width: 320 }">
    <!-- Variant matrix -->
    <Variant
      v-for="v in variants"
      :key="v"
      :title="v"
    >
      <IconButton :variant="v" :aria-label="v">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14" /></svg>
      </IconButton>
    </Variant>

    <!-- Sizes -->
    <Variant title="Sizes">
      <div class="row">
        <IconButton v-for="s in sizes" :key="s" variant="Default" :size="s" :aria-label="`Size ${s}`">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14" /></svg>
        </IconButton>
      </div>
    </Variant>

    <!-- States -->
    <Variant title="States">
      <div class="row">
        <IconButton variant="Brand" aria-label="Default state">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
        </IconButton>
        <IconButton variant="Brand" loading aria-label="Loading state">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
        </IconButton>
        <IconButton variant="Brand" disabled aria-label="Disabled state">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
        </IconButton>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-md); align-items: center; flex-wrap: wrap; padding: var(--space-md); }
</style>
