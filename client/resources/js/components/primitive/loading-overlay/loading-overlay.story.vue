<script setup lang="ts">
import { ref } from 'vue'
import LoadingOverlay from './loading-overlay.vue'

const open = ref(true)
</script>

<template>
  <Story title="Feedback/LoadingOverlay" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Cover">
      <div class="demo">
        <button class="toggle" type="button" @click="open = !open">
          {{ open ? 'Hide' : 'Show' }} overlay
        </button>

        <div class="card">
          <p class="card__title">Group roster</p>
          <p class="card__body">
            Members appear here once they accept their invitations. The overlay
            covers this card while data loads.
          </p>
          <LoadingOverlay :open="open" label="Loading roster…" />
        </div>
      </div>
    </Variant>

    <Variant title="Cover — no label">
      <div class="card">
        <p class="card__title">Analytics</p>
        <p class="card__body">Crunching the numbers.</p>
        <LoadingOverlay :open="true" />
      </div>
    </Variant>

    <Variant title="Inline">
      <div class="card card--flush">
        <LoadingOverlay variant="Inline" label="Fetching lessons…" />
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.demo { display: flex; flex-direction: column; gap: var(--space-md); }

.toggle {
  align-self: flex-start;
  padding: var(--space-sm) var(--space-md);
  font-size: var(--text-sm);
  color: var(--fg-primary);
  background: var(--bg-subtle);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  cursor: pointer;
}

.card {
  position: relative;
  padding: var(--space-xl);
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-lg);
  min-height: 160px;
  overflow: hidden;
}

.card--flush { display: flex; align-items: center; justify-content: center; }

.card__title {
  margin: 0 0 var(--space-sm);
  font-size: var(--text-subheading);
  line-height: var(--leading-subheading);
  font-weight: var(--font-weight-semibold);
  color: var(--fg-primary);
}

.card__body {
  margin: 0;
  font-size: var(--text-sm);
  line-height: var(--leading-sm);
  color: var(--fg-secondary);
}
</style>
