import { ref } from 'vue'
import { defineStore } from 'pinia'

// Shell store — populated by Phase 14 (Activity History)
export const useMemberActivityDomain = defineStore('member-activity-domain', () => {
  const lessonHistory = ref<any[]>([])
  const enrollmentProgress = ref<any[]>([])
  const activityLog = ref<any[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  return { lessonHistory, enrollmentProgress, activityLog, isLoading, error }
})
