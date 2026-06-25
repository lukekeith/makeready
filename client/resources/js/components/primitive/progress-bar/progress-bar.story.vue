<script setup lang="ts">
import ProgressBar from './progress-bar.vue'
</script>

<template>
  <Story title="Primitives/ProgressBar" :layout="{ type: 'grid', width: 320 }">
    <Variant title="Determinate (Brand)">
      <div class="col">
        <ProgressBar :value="25" />
        <ProgressBar :value="50" />
        <ProgressBar :value="80" />
        <ProgressBar :value="100" />
      </div>
    </Variant>

    <Variant title="Determinate (White)">
      <div class="col">
        <ProgressBar tone="White" :value="35" />
        <ProgressBar tone="White" :value="70" />
      </div>
    </Variant>

    <Variant title="Indeterminate">
      <div class="col">
        <ProgressBar />
        <ProgressBar tone="White" />
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.col { display: flex; flex-direction: column; gap: var(--space-lg); padding: var(--space-md); max-width: 260px; }
</style>
