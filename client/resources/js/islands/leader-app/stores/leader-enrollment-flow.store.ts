import { defineStore } from 'pinia'
import axios from 'axios'

// Leader enrollment-flow store — data for the EnrollmentFlow wizard
// (iOS EnrollmentFlowModal + EnrollmentActions).
//
//   • group pickers    → GET /api/groups          (iOS GroupActions.loadGroups)
//   • program pickers  → GET /api/programs        (iOS ProgramActions.loadPrograms)
//   • group context    → GET /api/groups/:id/enrollments + per-active
//                        GET /api/enrollments/:id (iOS EnrollmentFlowModal
//                        .loadEnrollmentsIfNeeded → existingEnrollments +
//                        existingLessonDates)
//   • create           → POST /api/enrollments    (iOS EnrollmentActions
//                        .createEnrollment — server computes the schedule)

export interface FlowGroup {
  id: string
  name: string
  description?: string
  memberCount: number
  enrollmentCount?: number
  imageUrl?: string
  isPrivate?: boolean
}

export interface FlowProgram {
  id: string
  name: string
  description?: string
  days: number
  imageUrl?: string
  isPublished: boolean
}

export interface GroupEnrollmentContext {
  /** Actively-enrolled program ids → their enrollment end date (ISO). */
  activeByProgramId: Map<string, string | null>
  /** startOfDay date keys ("yyyy-MM-dd", local) of every scheduled lesson
   *  across the group's active enrollments (iOS existingLessonDates). */
  existingLessonDates: string[]
}

const DAY_KEYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const

export interface CreateEnrollmentInput {
  groupId: string
  studyProgramId: string
  /** "yyyy-MM-dd" local date key — sent as local-midnight ISO. */
  startDateKey: string
  /** Enabled weekdays 0=Sun…6=Sat. */
  enabledDays: number[]
  requireResponse: boolean
  syncMode: 'OFF' | 'AUTO' | 'APPROVAL'
  /** "HH:mm". */
  smsTime?: string
}

function localDayKey(iso: string): string {
  const d = new Date(iso)
  const pad = (n: number) => (n < 10 ? `0${n}` : `${n}`)
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export const useLeaderEnrollmentFlow = defineStore('leader-enrollment-flow', () => {
  async function loadGroups(): Promise<FlowGroup[]> {
    const res = await axios.get('/admin/api/groups')
    const raw: Array<{
      id: string
      name?: string | null
      description?: string | null
      coverImageUrl?: string | null
      isPrivate?: boolean | null
      memberCount?: number | null
      activeEnrollmentCount?: number | null
    }> = res.data?.groups ?? []
    return raw.map((g) => ({
      id: g.id,
      name: g.name ?? 'Group',
      description: g.description ?? undefined,
      memberCount: g.memberCount ?? 0,
      enrollmentCount: g.activeEnrollmentCount ?? undefined,
      imageUrl: g.coverImageUrl ?? undefined,
      isPrivate: g.isPrivate ?? undefined,
    }))
  }

  async function loadPrograms(): Promise<FlowProgram[]> {
    const res = await axios.get('/admin/api/programs')
    const raw: Array<{
      id: string
      name?: string | null
      description?: string | null
      days?: number | null
      coverImageUrl?: string | null
      isPublished?: boolean | null
    }> = res.data?.programs ?? []
    return raw.map((p) => ({
      id: p.id,
      name: p.name ?? 'Study',
      description: p.description ?? undefined,
      days: p.days ?? 0,
      imageUrl: p.coverImageUrl ?? undefined,
      isPublished: Boolean(p.isPublished),
    }))
  }

  // iOS loadEnrollmentsIfNeeded: failure degrades to empty context (the
  // wizard proceeds; cards become selectable) — callers catch accordingly.
  async function loadGroupContext(groupId: string): Promise<GroupEnrollmentContext> {
    const res = await axios.get(`/admin/api/groups/${groupId}/enrollments`)
    const enrollments: Array<{
      id: string
      endDate?: string | null
      studyProgramId?: string | null
      studyProgram?: { id?: string | null } | null
    }> = res.data?.enrollments ?? []
    const now = Date.now()
    const active = enrollments.filter((e) =>
      e.endDate ? new Date(e.endDate).getTime() > now : true
    )
    const activeByProgramId = new Map<string, string | null>()
    for (const e of active) {
      const pid = e.studyProgramId ?? e.studyProgram?.id
      if (pid) activeByProgramId.set(pid, e.endDate ?? null)
    }
    const dates = new Set<string>()
    await Promise.all(
      active.map(async (e) => {
        try {
          const d = await axios.get(`/admin/api/enrollments/${e.id}`)
          const schedules: Array<{ scheduledDate?: string | null }> =
            d.data?.enrollment?.lessonSchedules ?? d.data?.lessonSchedules ?? []
          for (const s of schedules) {
            if (s.scheduledDate) dates.add(localDayKey(s.scheduledDate))
          }
        } catch {
          // Per-enrollment detail failure: skip its dates (console-only on iOS).
        }
      })
    )
    return { activeByProgramId, existingLessonDates: [...dates] }
  }

  async function createEnrollment(input: CreateEnrollmentInput): Promise<void> {
    const [y, m, d] = input.startDateKey.split('-').map(Number)
    const startDate = new Date(y, m - 1, d) // local midnight, like iOS Date
    const body = {
      groupId: input.groupId,
      studyProgramId: input.studyProgramId,
      startDate: startDate.toISOString(),
      // iOS dayMap sorted 0…6 → ["Sun","Mon",…] order.
      enabledDays: [...input.enabledDays].sort().map((i) => DAY_KEYS[i]),
      requireResponse: input.requireResponse,
      syncMode: input.syncMode,
      ...(input.smsTime ? { smsTime: input.smsTime } : {}),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || undefined,
    }
    const res = await axios.post('/admin/api/enrollments', body)
    if (res.data?.success === false) {
      throw new Error(res.data?.error ?? 'Failed to create enrollment')
    }
  }

  return { loadGroups, loadPrograms, loadGroupContext, createEnrollment }
})
