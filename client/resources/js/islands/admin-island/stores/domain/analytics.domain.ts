import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import { useGroupsDomain } from './groups.domain'

export interface HeatmapBucket {
  day: number // 0-6 (Sunday-Saturday)
  hour: number // 0-23
  count: number
}

export interface DayActivityCount {
  date: string // 'yyyy-MM-dd'
  count: number
}

export interface CalendarEvent {
  date: string
  title: string
  groupName: string
  enrollmentId: string
}

export const useAnalyticsDomain = defineStore('analytics-domain', () => {
  const heatmapData = ref<HeatmapBucket[]>([])
  const weeklyData = ref<DayActivityCount[]>([])
  const calendarEvents = ref<CalendarEvent[]>([])
  const isLoading = ref(false)
  const isCalendarLoading = ref(false)
  const error = ref<string | null>(null)
  const activeEnrollmentCount = ref(0)

  async function loadHeatmap(): Promise<void> {
    try {
      const res = await axios.get('/admin/api/activity-logs/stats/heatmap')
      heatmapData.value = res.data.data ?? []
    } catch {
      // Non-blocking — leave heatmapData empty
    }
  }

  async function loadWeeklyStats(): Promise<void> {
    try {
      const res = await axios.get('/admin/api/activity-logs/stats')
      weeklyData.value = res.data.data ?? []
    } catch {
      // Non-blocking — leave weeklyData empty
    }
  }

  async function loadCalendarEvents(): Promise<void> {
    isCalendarLoading.value = true
    try {
      const groupsDomain = useGroupsDomain()
      await groupsDomain.loadGroups()

      // Build a group lookup map for groupName resolution
      const groupMap: Record<string, string> = {}
      for (const g of groupsDomain.groups) {
        groupMap[g.id] = g.name
      }

      // Load enrollments for all groups in parallel
      const enrollmentResults = await Promise.all(
        groupsDomain.groups.map((g) =>
          axios
            .get(`/admin/api/groups/${g.id}/enrollments`)
            .catch(() => ({ data: { enrollments: [] } }))
        )
      )

      // Collect all enrollments
      const allEnrollments = enrollmentResults.flatMap(
        (r: any) => r.data.enrollments ?? []
      )

      // Cap at 50 to prevent unbounded N+1 cascade
      const cappedEnrollments = allEnrollments.slice(0, 50)

      // Count active enrollments (endDate >= today)
      const now = new Date()
      activeEnrollmentCount.value = allEnrollments.filter((e: any) => {
        if (!e.endDate) return false
        return new Date(e.endDate) >= now
      }).length

      // Load enrollment details in parallel
      const details = await Promise.all(
        cappedEnrollments.map((e: any) =>
          axios
            .get(`/admin/api/enrollments/${e.id}`)
            .catch(() => ({ data: { enrollment: { lessonSchedules: [] } } }))
        )
      )

      // Collect all upcoming scheduled lessons
      const events: CalendarEvent[] = []
      for (let i = 0; i < cappedEnrollments.length; i++) {
        const enrollment = cappedEnrollments[i] as any
        const detail = (details[i] as any).data?.enrollment
        const schedules = detail?.lessonSchedules ?? []
        const groupName = groupMap[enrollment.groupId] ?? enrollment.groupId ?? ''

        for (const schedule of schedules) {
          if (!schedule.scheduledDate) continue
          if (new Date(schedule.scheduledDate) < now) continue
          events.push({
            date: schedule.scheduledDate,
            title: schedule.lessonTitle ?? schedule.title ?? 'Lesson',
            groupName,
            enrollmentId: enrollment.id,
          })
        }
      }

      // Sort ascending by date
      events.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0))
      calendarEvents.value = events
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load calendar'
    } finally {
      isCalendarLoading.value = false
    }
  }

  async function loadAll(): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      // Load heatmap and weekly stats in parallel
      await Promise.all([loadHeatmap(), loadWeeklyStats()])
    } finally {
      isLoading.value = false
    }
    // Calendar loads asynchronously — non-blocking for initial render
    loadCalendarEvents()
  }

  return {
    heatmapData,
    weeklyData,
    calendarEvents,
    isLoading,
    isCalendarLoading,
    error,
    activeEnrollmentCount,
    loadHeatmap,
    loadWeeklyStats,
    loadCalendarEvents,
    loadAll,
  }
})
