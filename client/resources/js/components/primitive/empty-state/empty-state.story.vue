<script setup lang="ts">
import EmptyState from './empty-state.vue'
import Button from '../button/button.vue'

const sizes = ['Sm', 'Default', 'Lg'] as const
const aligns = ['Center', 'Left'] as const
</script>

<template>
  <Story title="Feedback/EmptyState" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Empty list">
      <EmptyState
        title="No groups yet"
        description="Create your first group to start inviting members and assigning studies."
      >
        <template #icon>
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        </template>
        <template #action>
          <Button variant="Primary">Create group</Button>
        </template>
      </EmptyState>
    </Variant>

    <Variant title="Sizes">
      <div class="stack">
        <EmptyState
          v-for="s in sizes"
          :key="s"
          :size="s"
          :title="`Size: ${s}`"
          description="An empty state at this size."
        >
          <template #icon>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
              <rect x="3" y="3" width="18" height="18" rx="2" />
              <path d="M3 9h18M9 21V9" />
            </svg>
          </template>
        </EmptyState>
      </div>
    </Variant>

    <Variant title="Alignments">
      <div class="stack">
        <EmptyState
          v-for="a in aligns"
          :key="a"
          :align="a"
          :title="`Align: ${a}`"
          description="Notice the icon, text, and action alignment."
        >
          <template #icon>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
              <path d="M14 2v6h6" />
            </svg>
          </template>
          <template #action>
            <Button variant="Primary" size="Sm">Add item</Button>
          </template>
        </EmptyState>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.stack { display: flex; flex-direction: column; gap: var(--space-xl); }
</style>
