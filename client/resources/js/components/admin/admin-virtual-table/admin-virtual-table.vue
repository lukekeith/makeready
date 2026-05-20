<script setup lang="ts">
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Skeleton from 'primevue/skeleton'
import Avatar from 'primevue/avatar'
import Tag from 'primevue/tag'
import Message from 'primevue/message'
import type { UnifiedMember } from '../../../islands/admin-island/stores/domain/all-members.domain'

const props = defineProps<{
  data: UnifiedMember[]
  isLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'row-click', userId: string): void
}>()

function onRowClick(event: any): void {
  emit('row-click', event.data.userId)
}

function formatRelativeTime(dateStr: string): string {
  if (!dateStr) return '—'
  const date = new Date(dateStr)
  if (isNaN(date.getTime())) return '—'
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMinutes = Math.floor(diffMs / (1000 * 60))
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))
  if (diffMinutes < 1) return 'just now'
  if (diffMinutes < 60) return `${diffMinutes}m ago`
  if (diffHours < 24) return `${diffHours}h ago`
  if (diffDays < 30) return `${diffDays}d ago`
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}
</script>

<template>
  <div>
    <Message v-if="$slots.warning" severity="warn" :closable="false" style="margin-bottom: 0.5rem;">
      <slot name="warning" />
    </Message>

    <div v-if="isLoading" style="display: flex; flex-direction: column; gap: 0.75rem;">
      <div v-for="i in 8" :key="i" style="display: flex; align-items: center; gap: 1rem; padding: 0.5rem 0;">
        <Skeleton shape="circle" size="2rem" />
        <Skeleton width="10rem" height="1rem" />
        <Skeleton width="6rem" height="1rem" />
        <Skeleton width="5rem" height="1rem" />
      </div>
    </div>

    <DataTable
      v-else
      :value="data"
      :row-hover="true"
      scrollable
      scroll-height="600px"
      :virtualScrollerOptions="{ itemSize: 56 }"
      striped-rows
      @row-click="onRowClick"
    >
      <template #empty>No members match your filters</template>

      <Column header="" :style="{ width: '3.5rem' }">
        <template #body="{ data: member }">
          <Avatar v-if="member.avatarUrl" :image="member.avatarUrl" shape="circle" />
          <Avatar v-else :label="member.name ? member.name.charAt(0).toUpperCase() : '?'" shape="circle" />
        </template>
      </Column>

      <Column field="name" header="Name" />

      <Column header="Groups">
        <template #body="{ data: member }">
          <div style="display: flex; flex-wrap: wrap; gap: 0.25rem;">
            <Tag v-for="g in member.groups" :key="g.groupId" :value="g.groupName" severity="secondary" />
          </div>
        </template>
      </Column>

      <Column header="Last Active">
        <template #body="{ data: member }">
          <span style="color: var(--p-text-muted-color);">{{ formatRelativeTime(member.lastActive) }}</span>
        </template>
      </Column>
    </DataTable>
  </div>
</template>
