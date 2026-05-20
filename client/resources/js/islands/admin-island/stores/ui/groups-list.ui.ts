import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRouter } from 'vue-router'
import { useGroupsDomain } from '../domain/groups.domain'

export const useGroupsListUI = defineStore('groups-list-ui', () => {
  const domain = useGroupsDomain()
  const router = useRouter()

  const isCreateFormOpen = ref(false)
  const editingGroupId = ref<string | null>(null)
  const confirmDeleteId = ref<string | null>(null)
  const formError = ref<string | null>(null)

  const tableColumns = computed(() => ['Name', 'Members', 'Privacy'])

  const tableRows = computed(() =>
    domain.groups.map((group) => ({
      id: group.id,
      cells: [
        group.name,
        group.memberCount != null ? String(group.memberCount) : '—',
        group.isPrivate ? 'Private' : 'Public',
      ],
      coverImageUrl: group.coverImageUrl,
      badge: group.isPrivate ? 'Private' : undefined,
    }))
  )

  const editingGroup = computed(() =>
    editingGroupId.value != null
      ? domain.groups.find((g) => g.id === editingGroupId.value) ?? null
      : null
  )

  const confirmDeleteGroup = computed(() =>
    confirmDeleteId.value != null
      ? domain.groups.find((g) => g.id === confirmDeleteId.value) ?? null
      : null
  )

  const isEditing = computed(() => editingGroupId.value !== null)

  function openCreateForm(): void {
    formError.value = null
    editingGroupId.value = null
    isCreateFormOpen.value = true
  }

  function openEditForm(id: string): void {
    formError.value = null
    editingGroupId.value = id
    isCreateFormOpen.value = true
  }

  function closeForm(): void {
    isCreateFormOpen.value = false
    editingGroupId.value = null
    formError.value = null
  }

  function requestDelete(id: string): void {
    confirmDeleteId.value = id
  }

  function cancelDelete(): void {
    confirmDeleteId.value = null
  }

  function navigateToDetail(id: string): void {
    router.push(`/admin/groups/${id}`)
  }

  return {
    isCreateFormOpen,
    editingGroupId,
    confirmDeleteId,
    formError,
    tableColumns,
    tableRows,
    editingGroup,
    confirmDeleteGroup,
    isEditing,
    openCreateForm,
    openEditForm,
    closeForm,
    requestDelete,
    cancelDelete,
    navigateToDetail,
  }
})
