<script setup lang="ts">
import Badge from './badge.vue'

const tones = [
  'Default', 'Primary', 'Secondary', 'Indigo', 'Destructive', 'Success', 'Warning', 'Outline',
] as const
</script>

<template>
  <Story title="Primitives/Badge" :layout="{ type: 'grid', width: 320 }">
    <!-- Tone matrix -->
    <Variant
      v-for="t in tones"
      :key="t"
      :title="t"
    >
      <Badge :tone="t">{{ t }}</Badge>
    </Variant>

    <!-- Sizes -->
    <Variant title="Sizes">
      <div class="row">
        <Badge tone="Primary" size="Sm">Small</Badge>
        <Badge tone="Primary" size="Md">Medium</Badge>
        <Badge tone="Primary" size="Lg">Large</Badge>
      </div>
    </Variant>

    <!-- With dot -->
    <Variant title="With dot">
      <div class="row">
        <Badge tone="Success" dot>Active</Badge>
        <Badge tone="Warning" dot>Pending</Badge>
        <Badge tone="Destructive" dot>Failed</Badge>
        <Badge tone="Outline" dot>Draft</Badge>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-md); align-items: center; flex-wrap: wrap; padding: var(--space-md); }
</style>
