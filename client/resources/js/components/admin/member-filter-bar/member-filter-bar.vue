<script setup lang="ts">
import { ref, watch } from 'vue'
import Select from 'primevue/select'
import Button from 'primevue/button'
import Chip from 'primevue/chip'
import InputText from 'primevue/inputtext'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import type { FilterTag } from '../../../islands/admin-island/stores/ui/members-list.ui'

const props = defineProps<{
  filterTags: FilterTag[]
  searchQuery: string
  availableGroups: string[]
  hasActiveFilters: boolean
}>()

const emit = defineEmits<{
  (e: 'add-filter', category: FilterTag['category'], value: string): void
  (e: 'remove-filter', index: number): void
  (e: 'clear-filters'): void
  (e: 'update:search-query', value: string): void
}>()

const localSearch = ref(props.searchQuery)
const selectedGroup = ref<string | null>(null)
const selectedStatus = ref<string | null>(null)
const selectedType = ref<string | null>(null)

const statusOptions = ['Completed', 'In Progress', 'Upcoming']
const typeOptions = ['SOAP', 'VIDEO', 'READ', 'OIA', 'DBS', 'HEAR', 'USER_INPUT']

watch(() => props.searchQuery, (v) => { localSearch.value = v })
watch(localSearch, (v) => { emit('update:search-query', v) })

function handleSearchAdd(): void {
  if (!localSearch.value.trim()) return
  emit('add-filter', 'name', localSearch.value.trim())
  localSearch.value = ''
}

function handleGroupSelect(): void {
  if (selectedGroup.value) { emit('add-filter', 'group', selectedGroup.value); selectedGroup.value = null }
}

function handleStatusSelect(): void {
  if (selectedStatus.value) { emit('add-filter', 'status', selectedStatus.value); selectedStatus.value = null }
}

function handleTypeSelect(): void {
  if (selectedType.value) { emit('add-filter', 'type', selectedType.value); selectedType.value = null }
}

function formatLabel(tag: FilterTag): string {
  const labels: Record<FilterTag['category'], string> = { name: 'Name', group: 'Group', status: 'Status', type: 'Type' }
  return `${labels[tag.category]}: ${tag.value}`
}
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 0.75rem;">
    <!-- Search -->
    <div style="display: flex; align-items: center; gap: 0.5rem;">
      <IconField style="flex: 1;">
        <InputIcon class="pi pi-search" />
        <InputText v-model="localSearch" placeholder="Search members..." fluid @keydown.enter.prevent="handleSearchAdd" />
      </IconField>
      <Button label="Add" severity="secondary" outlined size="small" @click="handleSearchAdd" />
    </div>

    <!-- Dropdowns -->
    <div style="display: flex; flex-wrap: wrap; gap: 0.5rem;">
      <Select v-model="selectedGroup" :options="availableGroups" placeholder="Group" filter @change="handleGroupSelect" :style="{ width: '12rem' }" />
      <Select v-model="selectedStatus" :options="statusOptions" placeholder="Status" @change="handleStatusSelect" :style="{ width: '10rem' }" />
      <Select v-model="selectedType" :options="typeOptions" placeholder="Activity type" @change="handleTypeSelect" :style="{ width: '12rem' }" />
    </div>

    <!-- Filter chips -->
    <div v-if="hasActiveFilters" style="display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem;">
      <Chip v-for="(tag, index) in filterTags" :key="index" :label="formatLabel(tag)" removable @remove="emit('remove-filter', index)" />
      <Button label="Clear all" text size="small" @click="emit('clear-filters')" />
    </div>
  </div>
</template>
