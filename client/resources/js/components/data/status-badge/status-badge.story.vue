<script setup lang="ts">
import StatusBadge from './status-badge.vue'
import type { Status } from './status-badge.vue'

const statuses: Status[] = [
  'pending',
  'unconfirmed',
  'confirmed',
  'active',
  'completed',
  'expired',
  'revoked',
]
</script>

<template>
  <Story title="Data/StatusBadge" :layout="{ type: 'grid', width: 320 }">
    <Variant
      v-for="s in statuses"
      :key="s"
      :title="s"
    >
      <StatusBadge :status="s" />
    </Variant>

    <Variant title="With dot">
      <div class="row">
        <StatusBadge status="active" dot />
        <StatusBadge status="pending" dot />
        <StatusBadge status="revoked" dot />
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-md); align-items: center; flex-wrap: wrap; padding: var(--space-md); }
</style>
