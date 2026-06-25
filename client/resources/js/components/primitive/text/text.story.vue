<script setup lang="ts">
import Text from './text.vue'

const variants = [
  'Display', 'Title', 'Heading', 'Subheading', 'Lead', 'Body', 'BodyStrong', 'Caption', 'Overline',
] as const

const tones = [
  'Primary', 'Secondary', 'Tertiary', 'Brand', 'Accent', 'Error', 'Success',
] as const
</script>

<template>
  <Story title="Primitives/Text" :layout="{ type: 'grid', width: 360 }">
    <!-- Variant matrix -->
    <Variant
      v-for="v in variants"
      :key="v"
      :title="v"
    >
      <Text :variant="v">The quick brown fox ({{ v }})</Text>
    </Variant>

    <!-- Tones -->
    <Variant title="Tones">
      <div class="col">
        <Text v-for="t in tones" :key="t" variant="Body" :tone="t">{{ t }} tone</Text>
      </div>
    </Variant>

    <!-- Polymorphic `as` -->
    <Variant title="As heading element">
      <Text variant="Heading" as="h2">Rendered as &lt;h2&gt;</Text>
    </Variant>
  </Story>
</template>

<style scoped>
.col { display: flex; flex-direction: column; gap: var(--space-sm); padding: var(--space-md); }
</style>
