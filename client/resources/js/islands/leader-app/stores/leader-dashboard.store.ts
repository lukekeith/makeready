import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

// Live dashboard data for the mobile leader app, fetched through the shared
// /admin/api/* proxy (the same endpoints the legacy analytics store uses). The
// four KPIs + two charts mirror the iPhone MainHome ("Home" tab).

export interface BarPoint {
  label: string
  value: number
  color: string
}

export interface HeatPoint {
  week: number // weekday 0-6 (x column)
  day: number // hour-of-day 0-23 (y row)
  value: number
}

const WEEKDAY = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const BRAND = 'rgba(108, 71, 255, 1)' // iOS Color.brandPrimary (#6c47ff)

// Format a 'yyyy-mm-dd' key as a short weekday in LOCAL time (avoid UTC day-shift).
function weekdayLabel(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || '')
  if (!m) return iso || ''
  return WEEKDAY[new Date(+m[1], +m[2] - 1, +m[3]).getDay()]
}

export const useLeaderDashboard = defineStore('leader-dashboard', () => {
  const totalMembers = ref(0)
  const totalGroups = ref(0)
  const totalStudies = ref(0)
  const totalEnrolledLessons = ref(0)
  const weekly = ref<BarPoint[]>([])
  const heatmap = ref<HeatPoint[]>([])
  const isLoading = ref(true)
  const error = ref<string | null>(null)
  let loaded = false

  async function load(force = false): Promise<void> {
    if (loaded && !force) return
    isLoading.value = true
    error.value = null
    try {
      // Core entities + charts in parallel (each tolerant of failure so one bad
      // endpoint doesn't blank the whole dashboard).
      const [groupsRes, programsRes, weeklyRes, heatRes] = await Promise.all([
        axios.get('/admin/api/groups').catch(() => ({ data: { groups: [] } })),
        axios.get('/admin/api/programs').catch(() => ({ data: { programs: [] } })),
        axios.get('/admin/api/activity-logs/stats').catch(() => ({ data: { data: [] } })),
        axios.get('/admin/api/activity-logs/stats/heatmap').catch(() => ({ data: { data: [] } })),
      ])

      const groups = groupsRes.data.groups ?? []
      const programs = programsRes.data.programs ?? []

      totalGroups.value = groups.length
      totalMembers.value = groups.reduce(
        (sum: number, g: { memberCount?: number }) => sum + (g.memberCount ?? 0),
        0,
      )
      totalStudies.value = programs.length

      // programId → lesson-day count, used for the iPhone-style "Enrolled Lessons"
      // KPI (sum of active enrollments' program days).
      const programDays: Record<string, number> = {}
      for (const p of programs) {
        programDays[p.id] = p.days ?? p.lessons?.length ?? 0
      }

      weekly.value = (weeklyRes.data.data ?? []).map(
        (d: { date: string; count?: number }) => ({
          label: weekdayLabel(d.date),
          value: d.count ?? 0,
          color: BRAND,
        }),
      )
      heatmap.value = (heatRes.data.data ?? []).map(
        (b: { day: number; hour: number; count?: number }) => ({
          week: b.day,
          day: b.hour,
          value: b.count ?? 0,
        }),
      )

      // Enrolled lessons = sum of active enrollments' program days, across groups.
      const now = new Date()
      const enrollmentLists = await Promise.all(
        groups.map((g: { id: string }) =>
          axios
            .get(`/admin/api/groups/${g.id}/enrollments`)
            .then((r) => r.data.enrollments ?? [])
            .catch(() => []),
        ),
      )
      let lessons = 0
      for (const list of enrollmentLists) {
        for (const e of list as Array<{ endDate?: string; studyProgramId: string }>) {
          if (e.endDate && new Date(e.endDate) < now) continue
          lessons += programDays[e.studyProgramId] ?? 0
        }
      }
      totalEnrolledLessons.value = lessons
      loaded = true
    } catch (err: unknown) {
      const e = err as { response?: { data?: { message?: string } } }
      error.value = e?.response?.data?.message ?? 'Failed to load dashboard'
    } finally {
      isLoading.value = false
    }
  }

  return {
    totalMembers,
    totalGroups,
    totalStudies,
    totalEnrolledLessons,
    weekly,
    heatmap,
    isLoading,
    error,
    load,
  }
})
