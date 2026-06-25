<script setup lang="ts">
import Spinner from './spinner.vue'

const sizes = ['Sm', 'Md', 'Lg', 'Xl'] as const
const tones = ['White', 'Primary', 'Purple', 'Dark'] as const
const speeds = ['Slow', 'Normal', 'Fast'] as const
</script>

<template>
  <Story title="Primitives/Spinner" :layout="{ type: 'grid', width: 320 }">
    <Variant title="Sizes">
      <div class="row">
        <Spinner v-for="s in sizes" :key="s" :size="s" />
      </div>
    </Variant>

    <Variant title="Tones">
      <div class="row">
        <Spinner v-for="t in tones" :key="t" :tone="t" size="Lg" />
      </div>
    </Variant>

    <Variant title="Speeds">
      <div class="row">
        <Spinner v-for="sp in speeds" :key="sp" :speed="sp" size="Lg" />
      </div>
    </Variant>

    <Variant title="Default">
      <Spinner />
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-xl); align-items: center; flex-wrap: wrap; padding: var(--space-md); }
</style>
