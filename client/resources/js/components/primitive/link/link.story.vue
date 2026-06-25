<script setup lang="ts">
import Link from './link.vue'

const variants = ['Default', 'Muted', 'Inline'] as const
</script>

<template>
  <Story title="Primitives/Link" :layout="{ type: 'grid', width: 360 }">
    <!-- Variant matrix -->
    <Variant
      v-for="v in variants"
      :key="v"
      :title="v"
    >
      <Link :variant="v" href="#">{{ v }} link</Link>
    </Variant>

    <!-- Inline in a paragraph -->
    <Variant title="Inline in paragraph">
      <p class="prose">
        Read the <Link variant="Inline" href="#">study guide</Link> before the meeting.
      </p>
    </Variant>

    <!-- External target -->
    <Variant title="External target">
      <Link variant="Default" href="https://example.com" target="_blank">Opens in new tab</Link>
    </Variant>
  </Story>
</template>

<style scoped>
.prose { color: var(--fg-secondary); font-size: var(--text-md); line-height: var(--leading-md); padding: var(--space-md); }
</style>
