import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRouter } from 'vue-router'
import { useProgramsDomain } from '../domain/programs.domain'

export const useProgramsListUI = defineStore('programs-list-ui', () => {
  const domain = useProgramsDomain()
  const router = useRouter()

  const isCreateFormOpen = ref(false)
  const editingProgramId = ref<string | null>(null)
  const confirmDeleteId = ref<string | null>(null)
  const formError = ref<string | null>(null)
  const isImporting = ref(false)
  const importError = ref<string | null>(null)

  const isEditing = computed(() => editingProgramId.value !== null)

  const tableColumns = computed(() => ['Name', 'Lessons', 'Status'])

  const tableRows = computed(() =>
    domain.programs.map((program) => {
      let lessonCount: string
      if (program.lessons !== undefined) {
        lessonCount = program.lessons.length + ' lessons'
      } else if (program._count?.lessons !== undefined) {
        lessonCount = program._count.lessons + ' lessons'
      } else {
        lessonCount = '--'
      }

      return {
        id: program.id,
        cells: [program.name, lessonCount, program.isPublished ? 'Published' : 'Draft'],
        coverImageUrl: program.coverImageUrl,
        badge: program.isPublished ? 'Published' : 'Draft',
      }
    })
  )

  const editingProgram = computed(() =>
    editingProgramId.value != null
      ? domain.programs.find((p) => p.id === editingProgramId.value) ?? null
      : null
  )

  const confirmDeleteProgram = computed(() =>
    confirmDeleteId.value != null
      ? domain.programs.find((p) => p.id === confirmDeleteId.value) ?? null
      : null
  )

  const templateOptions = computed(() =>
    domain.templates.map((t) => ({ value: t.id, label: t.name }))
  )

  function openCreateForm(): void {
    formError.value = null
    editingProgramId.value = null
    isCreateFormOpen.value = true
  }

  function openEditForm(id: string): void {
    formError.value = null
    editingProgramId.value = id
    isCreateFormOpen.value = true
  }

  function closeForm(): void {
    isCreateFormOpen.value = false
    editingProgramId.value = null
    formError.value = null
  }

  function requestDelete(id: string): void {
    confirmDeleteId.value = id
  }

  function cancelDelete(): void {
    confirmDeleteId.value = null
  }

  function navigateToDetail(id: string): void {
    router.push(`/admin/programs/${id}`)
  }

  async function handleImport(file: File): Promise<void> {
    isImporting.value = true
    importError.value = null
    try {
      await domain.importProgram(file)
    } catch (err: any) {
      importError.value = err?.response?.data?.message ?? 'Failed to import program'
    } finally {
      isImporting.value = false
    }
  }

  return {
    isCreateFormOpen,
    editingProgramId,
    confirmDeleteId,
    formError,
    isEditing,
    tableColumns,
    tableRows,
    editingProgram,
    confirmDeleteProgram,
    templateOptions,
    openCreateForm,
    openEditForm,
    closeForm,
    requestDelete,
    cancelDelete,
    navigateToDetail,
    isImporting,
    importError,
    handleImport,
  }
})
