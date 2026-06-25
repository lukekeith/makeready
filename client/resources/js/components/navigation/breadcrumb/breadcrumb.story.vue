<script setup lang="ts">
import { ref } from 'vue'
import Breadcrumb from './breadcrumb.vue'

const items = [
  { label: 'Programs', href: '/programs' },
  { label: 'Genesis Study', href: '/programs/genesis' },
  { label: 'Lesson 3' },
]

const lastNavigated = ref<number | null>(null)
</script>

<template>
  <Story title="Navigation/Breadcrumb" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Three levels">
      <div class="wrap">
        <Breadcrumb :items="items" @navigate="lastNavigated = $event" />
        <p class="caption">
          Last navigate index: {{ lastNavigated ?? '—' }}
        </p>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.wrap { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); }
.caption { margin: 0; color: var(--fg-secondary); font-size: var(--text-sm); }
</style>
