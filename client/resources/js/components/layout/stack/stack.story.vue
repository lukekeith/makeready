<script setup lang="ts">
import Stack from './stack.vue'

const gaps = ['None', 'Xs', 'Sm', 'Md', 'Lg', 'Xl'] as const
const justifies = ['Start', 'Center', 'End', 'Between', 'Around'] as const
</script>

<template>
  <Story title="Layouts/Stack" :layout="{ type: 'grid', width: 400 }">
    <!-- VStack: direction="Vertical" -->
    <Variant title="VStack (Vertical)">
      <Stack direction="Vertical" gap="Md">
        <div class="box">One</div>
        <div class="box">Two</div>
        <div class="box">Three</div>
      </Stack>
    </Variant>

    <!-- HStack: direction="Horizontal" -->
    <Variant title="HStack (Horizontal)">
      <Stack direction="Horizontal" gap="Md">
        <div class="box">One</div>
        <div class="box">Two</div>
        <div class="box">Three</div>
      </Stack>
    </Variant>

    <!-- gap scale -->
    <Variant
      v-for="g in gaps"
      :key="g"
      :title="`Gap ${g}`"
    >
      <Stack direction="Horizontal" :gap="g">
        <div class="box">A</div>
        <div class="box">B</div>
        <div class="box">C</div>
      </Stack>
    </Variant>

    <!-- justify -->
    <Variant
      v-for="j in justifies"
      :key="j"
      :title="`Justify ${j}`"
    >
      <Stack direction="Horizontal" gap="Sm" :justify="j" class="row-wide">
        <div class="box">A</div>
        <div class="box">B</div>
      </Stack>
    </Variant>

    <!-- align -->
    <Variant title="Align Center (Horizontal)">
      <Stack direction="Horizontal" gap="Sm" align="Center" class="row-tall">
        <div class="box">A</div>
        <div class="box box--big">B</div>
        <div class="box">C</div>
      </Stack>
    </Variant>

    <!-- wrap -->
    <Variant title="Wrap">
      <Stack direction="Horizontal" gap="Sm" wrap class="row-wide">
        <div v-for="n in 8" :key="n" class="box">{{ n }}</div>
      </Stack>
    </Variant>
  </Story>
</template>

<style scoped>
.box {
  background: var(--bg-surface);
  color: var(--fg-primary);
  padding: var(--space-md);
  border-radius: var(--radius-md);
  font-size: var(--text-sm);
}
.box--big { padding: var(--space-xl) var(--space-md); }
.row-wide { width: 100%; }
.row-tall { min-height: 80px; }
</style>
