<script setup lang="ts">
import Avatar from './avatar.vue'

const sizes = ['Sm', 'Md', 'Lg', 'Xl'] as const

const photo =
  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop'
</script>

<template>
  <Story title="Primitives/Avatar" :layout="{ type: 'grid', width: 320 }">
    <!-- Sizes (with image) -->
    <Variant
      v-for="s in sizes"
      :key="s"
      :title="s"
    >
      <Avatar :size="s" :src="photo" alt="Avatar" initials="LK" />
    </Variant>

    <!-- Initials fallback (no src) -->
    <Variant title="Initials fallback">
      <div class="row">
        <Avatar size="Sm" initials="LK" />
        <Avatar size="Md" initials="MR" />
        <Avatar size="Lg" initials="AB" />
        <Avatar size="Xl" initials="JD" />
      </div>
    </Variant>

    <!-- Broken image falls back to initials -->
    <Variant title="Broken image → initials">
      <Avatar size="Lg" src="https://example.com/does-not-exist.jpg" initials="XO" />
    </Variant>

    <!-- Loading -->
    <Variant title="Loading">
      <div class="row">
        <Avatar size="Md" initials="LK" loading />
        <Avatar size="Lg" :src="photo" alt="Avatar" initials="LK" loading />
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-md); align-items: center; flex-wrap: wrap; padding: var(--space-md); }
</style>
