<script setup lang="ts">
import FlowLayout from './flow-layout.vue'

const tags = [
  'Faith', 'Hope', 'Love', 'Grace', 'Mercy', 'Prayer', 'Scripture',
  'Worship', 'Community', 'Discipleship', 'Service', 'Gospel',
]
const gaps = ['Xs', 'Sm', 'Md'] as const
</script>

<template>
  <Story title="Layouts/FlowLayout" :layout="{ type: 'grid', width: 400 }">
    <!-- Wrapping chips -->
    <Variant title="Wrapping chips">
      <FlowLayout gap="Sm">
        <span v-for="t in tags" :key="t" class="chip">{{ t }}</span>
      </FlowLayout>
    </Variant>

    <!-- Gap scale -->
    <Variant
      v-for="g in gaps"
      :key="g"
      :title="`Gap ${g}`"
    >
      <FlowLayout :gap="g">
        <span v-for="t in tags.slice(0, 6)" :key="t" class="chip">{{ t }}</span>
      </FlowLayout>
    </Variant>
  </Story>
</template>

<style scoped>
.chip {
  background: var(--bg-surface);
  color: var(--fg-secondary);
  padding: var(--space-xs) var(--space-md);
  border-radius: var(--radius-full);
  font-size: var(--text-sm);
}
</style>
