import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRoute } from 'vue-router'
import { useProgramsDomain } from '../domain/programs.domain'

export const useProgramDetailUI = defineStore('program-detail-ui', () => {
  const domain = useProgramsDomain()
  const route = useRoute()

  const activeTab = ref('lessons')
  const editingLessonId = ref<string | null>(null)
  const confirmDeleteLessonId = ref<string | null>(null)
  const isUploadingCover = ref(false)
  const isSavingMetadata = ref(false)
  const metadataError = ref<string | null>(null)
  const expandedLessonId = ref<string | null>(null)
  const confirmDeleteActivityId = ref<string | null>(null)

  const currentProgram = computed(() => {
    const id = route.params.id as string | undefined
    if (!id) return undefined
    return domain.programs.find((p) => p.id === id)
  })

  const pageTitle = computed(() => currentProgram.value?.name ?? 'Program')

  const lessons = computed(() => currentProgram.value?.lessons ?? [])

  const editingLesson = computed(() =>
    editingLessonId.value != null
      ? lessons.value.find((l) => l.id === editingLessonId.value) ?? null
      : null
  )

  const confirmDeleteLesson = computed(() =>
    confirmDeleteLessonId.value != null
      ? lessons.value.find((l) => l.id === confirmDeleteLessonId.value) ?? null
      : null
  )

  const metadataFormValues = computed(() => {
    const p = currentProgram.value
    if (!p) return {}
    return {
      name: p.name ?? '',
      description: p.description ?? '',
    }
  })

  const metadataFields = computed(() => [
    {
      key: 'name',
      label: 'Program Name',
      type: 'text' as const,
      required: true,
    },
    {
      key: 'description',
      label: 'Description',
      type: 'textarea' as const,
    },
  ])

  function openEditLesson(id: string): void {
    editingLessonId.value = id
  }

  function closeEditLesson(): void {
    editingLessonId.value = null
  }

  function requestDeleteLesson(id: string): void {
    confirmDeleteLessonId.value = id
  }

  function cancelDeleteLesson(): void {
    confirmDeleteLessonId.value = null
  }

  const activitiesForExpandedLesson = computed(() => {
    if (!expandedLessonId.value || !currentProgram.value?.lessons) return []
    const lesson = currentProgram.value.lessons.find((l) => l.id === expandedLessonId.value)
    return lesson?.activities ?? []
  })

  const confirmDeleteActivity = computed(() => {
    if (!confirmDeleteActivityId.value) return null
    for (const lesson of currentProgram.value?.lessons ?? []) {
      const act = lesson.activities?.find((a) => a.id === confirmDeleteActivityId.value)
      if (act) return act
    }
    return null
  })

  function toggleExpandLesson(lessonId: string): void {
    expandedLessonId.value = expandedLessonId.value === lessonId ? null : lessonId
  }

  function requestDeleteActivity(id: string): void {
    confirmDeleteActivityId.value = id
  }

  function cancelDeleteActivity(): void {
    confirmDeleteActivityId.value = null
  }

  return {
    activeTab,
    editingLessonId,
    confirmDeleteLessonId,
    isUploadingCover,
    isSavingMetadata,
    metadataError,
    expandedLessonId,
    confirmDeleteActivityId,
    currentProgram,
    pageTitle,
    lessons,
    editingLesson,
    confirmDeleteLesson,
    activitiesForExpandedLesson,
    confirmDeleteActivity,
    metadataFormValues,
    metadataFields,
    openEditLesson,
    closeEditLesson,
    requestDeleteLesson,
    cancelDeleteLesson,
    toggleExpandLesson,
    requestDeleteActivity,
    cancelDeleteActivity,
  }
})
