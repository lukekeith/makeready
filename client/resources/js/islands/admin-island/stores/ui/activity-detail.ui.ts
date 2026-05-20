import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useProgramsDomain } from '../domain/programs.domain'
import type { Activity } from '../domain/programs.domain'

export const useActivityDetailUI = defineStore('activity-detail-ui', () => {
  const domain = useProgramsDomain()

  const editingActivityId = ref<string | null>(null)
  const editingProgramId = ref<string | null>(null)
  const editingLessonId = ref<string | null>(null)
  const isSaving = ref(false)
  const saveError = ref<string | null>(null)

  const currentActivity = computed((): Activity | null => {
    if (!editingActivityId.value || !editingProgramId.value || !editingLessonId.value) return null
    const program = domain.programs.find((p) => p.id === editingProgramId.value)
    const lesson = program?.lessons?.find((l) => l.id === editingLessonId.value)
    return lesson?.activities?.find((a) => a.id === editingActivityId.value) ?? null
  })

  const isReadType = computed(() => currentActivity.value?.activityType === 'READ')
  const isVideoType = computed(() => currentActivity.value?.activityType === 'VIDEO')
  const isYoutubeType = computed(() => currentActivity.value?.activityType === 'YOUTUBE')
  const isStudyMethodType = computed(() => {
    const t = currentActivity.value?.activityType
    return t === 'SOAP' || t === 'OIA' || t === 'DBS' || t === 'HEAR'
  })
  const isUserInputType = computed(() => currentActivity.value?.activityType === 'USER_INPUT')

  function openEditor(activityId: string, programId: string, lessonId: string): void {
    editingActivityId.value = activityId
    editingProgramId.value = programId
    editingLessonId.value = lessonId
    saveError.value = null
  }

  function closeEditor(): void {
    editingActivityId.value = null
    editingProgramId.value = null
    editingLessonId.value = null
    saveError.value = null
  }

  return {
    editingActivityId,
    editingProgramId,
    editingLessonId,
    isSaving,
    saveError,
    currentActivity,
    isReadType,
    isVideoType,
    isYoutubeType,
    isStudyMethodType,
    isUserInputType,
    openEditor,
    closeEditor,
  }
})
