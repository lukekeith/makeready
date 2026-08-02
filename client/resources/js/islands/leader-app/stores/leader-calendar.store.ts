import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

// Leader calendar store — web port of iOS HomeActions.loadCalendarEvents
// (the MainCalendar tab). iOS sends NO date range and NO timezone: it fans out
// over every manageable group, then every enrollment, then each enrollment's
// full detail, and filters/buckets client-side. Ported verbatim, including the
// today+future filter and the LOCAL-timezone date keys.

export interface CalendarEvent {
  id: string
  /** Local 'yyyy-MM-dd' bucket key (iOS uses the device timezone). */
  date: string
  /** Lesson dayNumber — the CardLesson DAY badge. */
  day: number
  /** iOS event title = the STUDY PROGRAM NAME. */
  title: string
  estimatedMinutes?: number
  activities: Array<{ activityType: string }>
  /** iOS stamps every calendar event #6c47ff. */
  color: string
  /** Resolves a tap → the lesson action menu (iOS lessonScheduleMap). */
  scheduleId: string
  enrollmentId: string
  /** ISO instant, used only for the intra-day sort (iOS startTime). */
  startTime: string
}

/** iOS CalendarFormatters.dateKey — "yyyy-MM-dd" in the DEVICE timezone. */
function localDateKey(iso: string): string {
  const d = new Date(iso)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate()
  ).padStart(2, '0')}`
}

function startOfToday(): Date {
  const n = new Date()
  return new Date(n.getFullYear(), n.getMonth(), n.getDate())
}

export const useLeaderCalendar = defineStore('leader-calendar', () => {
  const events = ref<CalendarEvent[]>([])
  const loading = ref(false)
  const loaded = ref(false)
  const error = ref('')

  /**
   * iOS loadCalendarEvents: groups → enrollments → enrollment details, then
   * `filter { scheduledDate >= startOfDay(today) }`. Past lessons are never
   * kept, and `isCompleted` is deliberately ignored (iOS shows no completed
   * treatment on this screen).
   */
  async function load(forceRefresh = false): Promise<void> {
    if (loaded.value && !forceRefresh) return
    // Cache-first: with events already loaded the refresh is silent, matching
    // iOS (.loading only when there is no cache, else .refreshing).
    if (!loaded.value) loading.value = true
    try {
      const groupsRes = await axios.get('/admin/api/groups')
      const groups: Array<{ id: string }> = groupsRes.data?.groups ?? []

      const enrollmentIds: string[] = []
      for (const g of groups) {
        try {
          const res = await axios.get(`/admin/api/groups/${g.id}/enrollments`)
          for (const e of res.data?.enrollments ?? []) {
            if (e?.id) enrollmentIds.push(e.id)
          }
        } catch {
          // One unreadable group must not blank the whole calendar.
        }
      }

      const today = startOfToday()
      const collected: CalendarEvent[] = []

      for (const enrollmentId of enrollmentIds) {
        try {
          const res = await axios.get(`/admin/api/enrollments/${enrollmentId}`)
          const enrollment = res.data?.enrollment
          if (!enrollment) continue
          const programName: string = enrollment.studyProgram?.name ?? 'Study'
          for (const schedule of enrollment.lessonSchedules ?? []) {
            if (!schedule?.scheduledDate) continue
            if (new Date(schedule.scheduledDate) < today) continue
            const activities = (schedule.lesson?.activities ?? schedule.scheduledActivities ?? [])
              .map((a: { type?: string; activityType?: string }) => ({
                activityType: a.activityType ?? a.type ?? 'READ',
              }))
            collected.push({
              id: schedule.id,
              date: localDateKey(schedule.scheduledDate),
              day: schedule.lesson?.dayNumber ?? 1,
              title: programName,
              estimatedMinutes: schedule.lesson?.totalEstimatedMinutes ?? undefined,
              activities,
              color: '#6c47ff',
              scheduleId: schedule.id,
              enrollmentId,
              startTime: schedule.scheduledDate,
            })
          }
        } catch {
          // Skip enrollments that 404 for this leader (iOS does the same).
        }
      }

      // iOS sorts within a date bucket by startTime, then title.
      collected.sort((a, b) =>
        a.startTime === b.startTime
          ? a.title.localeCompare(b.title)
          : a.startTime.localeCompare(b.startTime)
      )

      events.value = collected
      loaded.value = true
      error.value = ''
    } catch (err) {
      // iOS records the load failure console-only — no banner, cached content
      // stays on screen. Surface only when there is nothing to show.
      if (events.value.length === 0) {
        error.value = err instanceof Error ? err.message : 'Failed to load the calendar'
      }
    } finally {
      loading.value = false
    }
  }

  function eventById(id: string): CalendarEvent | null {
    return events.value.find((e) => e.id === id) ?? null
  }

  /** iOS EnrollmentActions.loadLessonInvite — only `inviteUrl` is consumed. */
  async function loadLessonInvite(scheduleId: string): Promise<string | null> {
    const res = await axios.get(`/admin/api/lesson-schedules/${scheduleId}/invite`)
    return res.data?.invite?.inviteUrl ?? res.data?.invite?.url ?? null
  }

  /** iOS deleteLessonSchedule, then a forced calendar reload. */
  async function deleteLessonSchedule(
    enrollmentId: string,
    scheduleId: string
  ): Promise<void> {
    await axios.delete(`/admin/api/enrollments/${enrollmentId}/schedules/${scheduleId}`)
    await load(true)
  }

  return { events, loading, loaded, error, load, eventById, loadLessonInvite, deleteLessonSchedule }
})
