<script setup lang="ts">
import Kpi from './kpi.vue'
</script>

<template>
  <Story title="Data/Kpi" :layout="{ type: 'grid', width: 320 }">
    <Variant title="Row of KPIs">
      <div class="kpi-row">
        <Kpi value="27" label="Members" :trend="{ dir: 'up', value: '+4' }">
          <template #icon>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /></svg>
          </template>
        </Kpi>
        <Kpi value="92%" label="Active" :trend="{ dir: 'down', value: '-3%' }" />
        <Kpi value="14" label="Sessions" :trend="{ dir: 'flat', value: '0' }" />
      </div>
    </Variant>

    <Variant title="No trend, no icon">
      <Kpi value="$1,240" label="Donations" />
    </Variant>

    <Variant title="With icon, trend up">
      <Kpi value="312" label="Lessons completed" :trend="{ dir: 'up', value: '+18' }">
        <template #icon>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" /><path d="M22 4L12 14.01l-3-3" /></svg>
        </template>
      </Kpi>
    </Variant>
  </Story>
</template>

<style scoped>
.kpi-row { display: flex; gap: var(--space-md); align-items: stretch; flex-wrap: wrap; padding: var(--space-md); }
.kpi-row > * { flex: 1 1 0; min-width: 0; }
</style>
