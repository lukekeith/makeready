<script setup lang="ts">
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Skeleton from 'primevue/skeleton'
import Button from 'primevue/button'
import Tag from 'primevue/tag'

interface TableRow {
  id: string
  cells: string[]
  coverImageUrl?: string
  badge?: string
}

interface Props {
  columns: string[]
  rows: TableRow[]
  loading?: boolean
  emptyMessage?: string
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  emptyMessage: 'No items found',
})

const emit = defineEmits<{
  (e: 'row-click', id: string): void
  (e: 'edit', id: string): void
  (e: 'delete', id: string): void
}>()

function onRowClick(event: any): void {
  emit('row-click', event.data.id)
}

function onEdit(id: string, event: MouseEvent): void {
  event.stopPropagation()
  emit('edit', id)
}

function onDelete(id: string, event: MouseEvent): void {
  event.stopPropagation()
  emit('delete', id)
}
</script>

<template>
  <div v-if="loading" style="display: flex; flex-direction: column; gap: 0.5rem;">
    <Skeleton v-for="i in 3" :key="i" height="2.5rem" />
  </div>

  <DataTable
    v-else
    :value="rows"
    :row-hover="true"
    striped-rows
    @row-click="onRowClick"
  >
    <template #empty>{{ emptyMessage }}</template>

    <Column v-for="(col, colIndex) in columns" :key="col" :header="col">
      <template #body="{ data }">
        <template v-if="colIndex === 0">
          <img v-if="data.coverImageUrl" :src="data.coverImageUrl" alt="" style="display: inline-block; width: 2rem; height: 2rem; border-radius: 0.25rem; object-fit: cover; margin-right: 0.5rem; vertical-align: middle;" />
          {{ data.cells[colIndex] }}
        </template>
        <template v-else-if="colIndex === data.cells.length - 1">
          {{ data.cells[colIndex] }}
          <Tag v-if="data.badge" :value="data.badge" severity="secondary" style="margin-left: 0.5rem;" />
        </template>
        <template v-else>{{ data.cells[colIndex] }}</template>
      </template>
    </Column>

    <Column header="Actions" :style="{ width: '6rem' }">
      <template #body="{ data }">
        <div style="display: flex; gap: 0.25rem;">
          <Button icon="pi pi-pencil" severity="secondary" text rounded size="small" @click="onEdit(data.id, $event)" />
          <Button icon="pi pi-trash" severity="danger" text rounded size="small" @click="onDelete(data.id, $event)" />
        </div>
      </template>
    </Column>
  </DataTable>
</template>
