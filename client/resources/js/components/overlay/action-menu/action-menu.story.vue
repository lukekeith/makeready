<script setup lang="ts">
import { ref } from 'vue'
import ActionMenu, { type ActionMenuAction } from './action-menu.vue'
import Button from '../../primitive/button/button.vue'

const open = ref(false)
const lastSelected = ref<string | null>(null)

const actions: ActionMenuAction[] = [
  { key: 'edit', label: 'Edit', icon: 'edit' },
  { key: 'share', label: 'Share', icon: 'share' },
  { key: 'delete', label: 'Delete', icon: 'delete', destructive: true },
]

function onSelect(key: string) {
  lastSelected.value = key
}
</script>

<template>
  <Story title="Overlays/ActionMenu" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Edit / Share / Delete">
      <Button @click="open = true">Open menu</Button>
      <p style="margin-top: var(--space-md); color: var(--fg-tertiary); font-size: var(--text-sm);">
        Last selected: {{ lastSelected ?? '—' }}
      </p>

      <ActionMenu
        v-model:open="open"
        title="Manage item"
        :actions="actions"
        @select="onSelect"
      >
        <template #icon="{ action }">
          <svg
            v-if="action.icon === 'edit'"
            width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
          >
            <path d="M12 20h9" />
            <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z" />
          </svg>
          <svg
            v-else-if="action.icon === 'share'"
            width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
          >
            <circle cx="18" cy="5" r="3" />
            <circle cx="6" cy="12" r="3" />
            <circle cx="18" cy="19" r="3" />
            <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" />
            <line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
          </svg>
          <svg
            v-else-if="action.icon === 'delete'"
            width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
          >
            <polyline points="3 6 5 6 21 6" />
            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
          </svg>
        </template>
      </ActionMenu>
    </Variant>
  </Story>
</template>
