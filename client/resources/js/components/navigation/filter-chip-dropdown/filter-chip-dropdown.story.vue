<script setup lang="ts">
import { ref } from 'vue'
import FilterChipDropdown from './filter-chip-dropdown.vue'
import FlowLayout from '../../layout/flow-layout/flow-layout.vue'

const status = ref('active')
const statusOptions = [
  { value: 'all', label: 'All' },
  { value: 'active', label: 'Active' },
  { value: 'archived', label: 'Archived' },
]

const sort = ref('recent')
const sortOptions = [
  { value: 'recent', label: 'Most recent' },
  { value: 'name', label: 'Name (A–Z)' },
  { value: 'progress', label: 'Progress' },
]
</script>

<template>
  <Story title="Navigation/FilterChipDropdown" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Two chips">
      <div class="wrap">
        <FlowLayout>
          <FilterChipDropdown label="Status" v-model="status" :options="statusOptions" />
          <FilterChipDropdown label="Sort" v-model="sort" :options="sortOptions" />
        </FlowLayout>
        <p class="caption">status={{ status }} · sort={{ sort }}</p>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.wrap { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); min-height: 220px; }
.caption { margin: 0; color: var(--fg-secondary); font-size: var(--text-sm); }
</style>
