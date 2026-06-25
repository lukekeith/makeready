<script setup lang="ts">
import Spacer from './spacer.vue'
import Stack from '../stack/stack.vue'

const sizes = ['Xs', 'Sm', 'Md', 'Lg', 'Xl'] as const
</script>

<template>
  <Story title="Layouts/Spacer" :layout="{ type: 'grid', width: 400 }">
    <!-- Flexible spacer pushing two buttons apart in an HStack -->
    <Variant title="Flex (pushes apart in HStack)">
      <Stack direction="Horizontal" gap="None" class="bar">
        <button class="btn">Back</button>
        <Spacer size="Flex" />
        <button class="btn">Next</button>
      </Stack>
    </Variant>

    <!-- Fixed spacers between blocks (vertical) -->
    <Variant
      v-for="s in sizes"
      :key="s"
      :title="`Fixed ${s} (between blocks)`"
    >
      <Stack direction="Vertical" gap="None">
        <div class="block">Block A</div>
        <Spacer :size="s" />
        <div class="block">Block B</div>
      </Stack>
    </Variant>
  </Story>
</template>

<style scoped>
.bar { width: 100%; }
.btn {
  background: var(--bg-surface);
  color: var(--fg-primary);
  padding: var(--space-sm) var(--space-lg);
  border-radius: var(--radius-md);
  border: 0;
  font-size: var(--text-sm);
}
.block {
  background: var(--bg-surface);
  color: var(--fg-primary);
  padding: var(--space-md);
  border-radius: var(--radius-md);
  font-size: var(--text-sm);
  text-align: center;
}
</style>
