<script setup lang="ts">
import Icon from './icon.vue'

const sizes = ['Xs', 'Sm', 'Md', 'Lg'] as const
const tones = ['Current', 'Primary', 'Secondary', 'Tertiary', 'Brand', 'Accent'] as const
</script>

<template>
  <Story title="Primitives/Icon" :layout="{ type: 'grid', width: 320 }">
    <!-- Sizes -->
    <Variant
      v-for="s in sizes"
      :key="s"
      :title="`Size ${s}`"
    >
      <Icon :size="s">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14" /></svg>
      </Icon>
    </Variant>

    <!-- Tones -->
    <Variant
      v-for="t in tones"
      :key="t"
      :title="`Tone ${t}`"
    >
      <Icon size="Lg" :tone="t">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 2 3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" /></svg>
      </Icon>
    </Variant>

    <!-- Size matrix -->
    <Variant title="All sizes">
      <div class="row">
        <Icon v-for="s in sizes" :key="s" :size="s" tone="Primary">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" /><path d="m9 12 2 2 4-4" /></svg>
        </Icon>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-md); align-items: center; flex-wrap: wrap; padding: var(--space-md); }
</style>
