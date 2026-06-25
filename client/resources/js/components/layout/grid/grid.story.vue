<script setup lang="ts">
import Grid from './grid.vue'
</script>

<template>
  <Story title="Layouts/Grid" :layout="{ type: 'grid', width: 400 }">
    <!-- Fixed 2-col grid -->
    <Variant title="2 columns">
      <Grid cols="2" gap="Md">
        <div v-for="n in 4" :key="n" class="card">Card {{ n }}</div>
      </Grid>
    </Variant>

    <!-- Fixed 3-col grid -->
    <Variant title="3 columns">
      <Grid cols="3" gap="Sm">
        <div v-for="n in 6" :key="n" class="card">{{ n }}</div>
      </Grid>
    </Variant>

    <!-- Auto-fill mini-card grid -->
    <Variant title="Auto-fill (mini cards)">
      <Grid cols="Auto" gap="Md">
        <div v-for="n in 6" :key="n" class="card card--mini">Item {{ n }}</div>
      </Grid>
    </Variant>

    <!-- Gap scale -->
    <Variant title="Gap Lg">
      <Grid cols="2" gap="Lg">
        <div v-for="n in 4" :key="n" class="card">Card {{ n }}</div>
      </Grid>
    </Variant>
  </Story>
</template>

<style scoped>
.card {
  background: var(--bg-surface);
  color: var(--fg-primary);
  padding: var(--space-md);
  border-radius: var(--radius-md);
  font-size: var(--text-sm);
  text-align: center;
}
.card--mini {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 72px;
}
</style>
