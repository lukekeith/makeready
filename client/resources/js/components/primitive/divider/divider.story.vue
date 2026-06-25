<script setup lang="ts">
import Divider from './divider.vue'
</script>

<template>
  <Story title="Primitives/Divider" :layout="{ type: 'grid', width: 360 }">
    <!-- Horizontal -->
    <Variant title="Horizontal">
      <div class="stack">
        <span class="label">Above</span>
        <Divider orientation="Horizontal" />
        <span class="label">Below</span>
      </div>
    </Variant>

    <!-- Horizontal inset -->
    <Variant title="Horizontal inset">
      <div class="stack">
        <span class="label">Above</span>
        <Divider orientation="Horizontal" inset />
        <span class="label">Below</span>
      </div>
    </Variant>

    <!-- Vertical -->
    <Variant title="Vertical">
      <div class="row">
        <span class="label">Left</span>
        <Divider orientation="Vertical" />
        <span class="label">Right</span>
      </div>
    </Variant>

    <!-- Vertical inset -->
    <Variant title="Vertical inset">
      <div class="row">
        <span class="label">Left</span>
        <Divider orientation="Vertical" inset />
        <span class="label">Right</span>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.stack { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); }
.row { display: flex; align-items: stretch; gap: var(--space-md); height: 48px; padding: var(--space-md); }
.label { color: var(--fg-secondary); font-size: var(--text-sm); line-height: var(--leading-sm); }
</style>
