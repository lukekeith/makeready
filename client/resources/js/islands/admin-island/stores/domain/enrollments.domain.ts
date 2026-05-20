import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

export interface Enrollment {
  id: string
  groupId: string
  studyProgramId: string
  startDate: string
  endDate: string
  enabledDays: string
  smsTime?: string
  timezone?: string
  requireResponse?: boolean
  createdAt: string
  updatedAt: string
}

export interface EnrollmentWithProgram extends Enrollment {
  studyProgram?: {
    id: string
    name: string
    coverImageUrl?: string
  }
}

export interface LessonSchedule {
  id: string
  enrollmentId: string
  scheduledDate: string
  title?: string
  lesson?: {
    dayNumber: number
    title: string
  }
}

export interface EnrollmentDetails extends Enrollment {
  studyProgram?: {
    id: string
    name: string
    coverImageUrl?: string
  }
  lessonSchedules: LessonSchedule[]
}

export interface UnenrollInfo {
  totalLessons: number
  lessonsWithData: number
  cleanLessons: number
}

export interface CreateEnrollmentPayload {
  groupId: string
  studyProgramId: string
  startDate: string
  enabledDays: string[]
  smsTime?: string
  timezone?: string
  requireResponse?: boolean
}

export const useEnrollmentsDomain = defineStore('enrollments-domain', () => {
  const enrollmentsByGroup = ref<Record<string, EnrollmentWithProgram[]>>({})
  const enrollmentDetails = ref<Record<string, EnrollmentDetails>>({})
  const isLoading = ref(false)
  const error = ref<string | null>(null)
  const loadedGroupIds = ref(new Set<string>())

  async function loadEnrollments(groupId: string, force = false): Promise<void> {
    if (loadedGroupIds.value.has(groupId) && !force) return
    isLoading.value = true
    error.value = null
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/enrollments`)
      enrollmentsByGroup.value[groupId] = res.data.enrollments ?? []
      loadedGroupIds.value.add(groupId)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load enrollments'
    } finally {
      isLoading.value = false
    }
  }

  async function loadEnrollmentDetail(enrollmentId: string): Promise<void> {
    error.value = null
    try {
      const res = await axios.get(`/admin/api/enrollments/${enrollmentId}`)
      enrollmentDetails.value[enrollmentId] = res.data.enrollment
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load enrollment detail'
    }
  }

  async function createEnrollment(payload: CreateEnrollmentPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.post('/admin/api/enrollments', payload)
      const newEnrollment: EnrollmentWithProgram = res.data.enrollment
      if (!enrollmentsByGroup.value[payload.groupId]) {
        enrollmentsByGroup.value[payload.groupId] = []
      }
      enrollmentsByGroup.value[payload.groupId].push(newEnrollment)
      // Invalidate cache so next load fetches fresh data
      loadedGroupIds.value.delete(payload.groupId)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to create enrollment'
      throw err
    }
  }

  async function deleteEnrollment(enrollmentId: string, groupId: string): Promise<void> {
    error.value = null
    try {
      await axios.delete(`/admin/api/enrollments/${enrollmentId}`)
      if (enrollmentsByGroup.value[groupId]) {
        enrollmentsByGroup.value[groupId] = enrollmentsByGroup.value[groupId].filter(
          (e) => e.id !== enrollmentId,
        )
      }
      delete enrollmentDetails.value[enrollmentId]
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete enrollment'
      throw err
    }
  }

  async function cancelFuture(enrollmentId: string, groupId: string): Promise<void> {
    error.value = null
    try {
      await axios.post(`/admin/api/enrollments/${enrollmentId}/cancel-future`, {})
      // Reload enrollment detail to reflect updated schedules
      await loadEnrollmentDetail(enrollmentId)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to cancel future lessons'
      throw err
    }
  }

  async function getUnenrollInfo(enrollmentId: string): Promise<UnenrollInfo> {
    const res = await axios.get(`/admin/api/enrollments/${enrollmentId}/unenroll-info`)
    return res.data.data
  }

  async function updateScheduleTitle(
    enrollmentId: string,
    scheduleId: string,
    title: string,
  ): Promise<void> {
    error.value = null
    try {
      await axios.patch(`/admin/api/enrollments/${enrollmentId}/schedules/${scheduleId}`, { title })
      // Update local state directly since API returns only { success }
      const detail = enrollmentDetails.value[enrollmentId]
      if (detail) {
        const schedule = detail.lessonSchedules.find((s) => s.id === scheduleId)
        if (schedule) {
          schedule.title = title
        }
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to update schedule title'
      throw err
    }
  }

  async function addSchedule(enrollmentId: string): Promise<void> {
    error.value = null
    try {
      await axios.post(`/admin/api/enrollments/${enrollmentId}/schedules`, {})
      // Reload detail to get server-assigned date and new schedule
      await loadEnrollmentDetail(enrollmentId)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to add schedule'
      throw err
    }
  }

  async function deleteSchedule(enrollmentId: string, scheduleId: string): Promise<void> {
    error.value = null
    try {
      await axios.delete(`/admin/api/enrollments/${enrollmentId}/schedules/${scheduleId}`)
      const detail = enrollmentDetails.value[enrollmentId]
      if (detail) {
        detail.lessonSchedules = detail.lessonSchedules.filter((s) => s.id !== scheduleId)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete schedule'
      throw err
    }
  }

  return {
    enrollmentsByGroup,
    enrollmentDetails,
    isLoading,
    error,
    loadedGroupIds,
    loadEnrollments,
    loadEnrollmentDetail,
    createEnrollment,
    deleteEnrollment,
    cancelFuture,
    getUnenrollInfo,
    updateScheduleTitle,
    addSchedule,
    deleteSchedule,
  }
})
