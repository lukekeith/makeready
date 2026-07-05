import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

// Live data for the mobile leader app's Groups page (the iPhone MemberHomePage:
// Groups / Members / Enrolled tabs), fetched through the shared /admin/api/*
// proxy. Mirrors the iPhone GroupActions / EnrollmentActions loading:
//   • Groups   → GET /api/groups (the org's groups the leader manages)
//   • Members  → GET /api/groups/:id/members + /join-requests for every group,
//                deduped by user, with the set of group names each belongs to
//   • Enrolled → GET /api/groups/:id/enrollments for every group

export interface LeaderGroup {
  id: string
  name: string
  memberCount: number
  isPrivate: boolean
  coverImageUrl: string | null
}

export interface LeaderMember {
  id: string
  userId: string
  firstName: string
  lastName: string
  name: string
  avatarUrl: string | null
  joinedLabel: string
  groups: string[]
}

export interface LeaderRequest {
  id: string
}

export interface LeaderEnrollment {
  id: string
  studyTitle: string
  groupName: string
  dateRange: string
  lessonsLeft: number
  studyImageURL: string | null
}

interface ApiGroup {
  id: string
  name: string
  memberCount?: number
  isPrivate?: boolean
  coverImageUrl?: string | null
}
interface ApiMember {
  id: string
  userId: string
  name: string
  avatarUrl?: string | null
  groupId: string
  joinedAt: string
}
interface ApiEnrollment {
  id: string
  startDate: string
  endDate?: string | null
  studyProgram?: { name?: string; days?: number; coverImageUrl?: string | null } | null
  _count?: { lessonSchedules?: number }
}

const MONTH_DAY = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' })
const MONTH_DAY_YEAR = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })

function firstNameOf(name: string): string {
  return name.trim().split(/\s+/)[0] ?? name
}
function lastNameOf(name: string): string {
  const parts = name.trim().split(/\s+/)
  return parts.length > 1 ? parts.slice(1).join(' ') : ''
}
function daysBetween(from: Date, to: Date): number {
  return Math.max(0, Math.floor((to.getTime() - from.getTime()) / 86_400_000))
}

export const useLeaderGroups = defineStore('leader-groups', () => {
  const groups = ref<LeaderGroup[]>([])
  const members = ref<LeaderMember[]>([])
  const requests = ref<LeaderRequest[]>([])
  const enrollments = ref<LeaderEnrollment[]>([])

  const groupsLoading = ref(false)
  const membersLoading = ref(false)
  const enrolledLoading = ref(false)
  const groupsError = ref<string | null>(null)
  const membersError = ref<string | null>(null)
  const enrolledError = ref<string | null>(null)

  let groupsLoaded = false
  let membersLoaded = false
  let enrolledLoaded = false

  function message(err: unknown, fallback: string): string {
    const e = err as { response?: { data?: { error?: string; message?: string } } }
    return e?.response?.data?.error ?? e?.response?.data?.message ?? fallback
  }

  // Groups must be loaded before members/enrollments (both fan out per group).
  async function ensureGroups(force = false): Promise<void> {
    if (groupsLoaded && !force) return
    const res = await axios.get('/admin/api/groups')
    const raw: ApiGroup[] = res.data.groups ?? []
    groups.value = raw.map((g) => ({
      id: g.id,
      name: g.name,
      memberCount: g.memberCount ?? 0,
      isPrivate: Boolean(g.isPrivate),
      coverImageUrl: g.coverImageUrl ?? null,
    }))
    groupsLoaded = true
  }

  async function loadGroups(force = false): Promise<void> {
    if (groupsLoaded && !force) return
    groupsLoading.value = true
    groupsError.value = null
    try {
      await ensureGroups(force)
    } catch (err) {
      groupsError.value = message(err, 'Failed to load groups')
    } finally {
      groupsLoading.value = false
    }
  }

  async function loadMembers(force = false): Promise<void> {
    if (membersLoaded && !force) return
    membersLoading.value = true
    membersError.value = null
    try {
      await ensureGroups(force)

      // Members + pending join requests for every group, in parallel.
      const memberLists = await Promise.all(
        groups.value.map((g) =>
          axios
            .get(`/admin/api/groups/${g.id}/members`)
            .then((r) => (r.data.members ?? []) as ApiMember[])
            .catch(() => [] as ApiMember[]),
        ),
      )
      const requestLists = await Promise.all(
        groups.value.map((g) =>
          axios
            .get(`/admin/api/groups/${g.id}/join-requests`)
            .then((r) => (r.data.requests ?? []) as Array<{ id: string }>)
            .catch(() => [] as Array<{ id: string }>),
        ),
      )

      const groupNameById = new Map(groups.value.map((g) => [g.id, g.name]))
      const flat = memberLists.flat()

      // The set of group names each user belongs to (group chips on the card).
      const groupsByUser = new Map<string, Set<string>>()
      for (const m of flat) {
        const set = groupsByUser.get(m.userId) ?? new Set<string>()
        const gName = groupNameById.get(m.groupId)
        if (gName) set.add(gName)
        groupsByUser.set(m.userId, set)
      }

      // Dedupe by userId (a member can be in several groups), keep first seen.
      const seen = new Set<string>()
      const deduped: LeaderMember[] = []
      for (const m of flat) {
        if (seen.has(m.userId)) continue
        seen.add(m.userId)
        deduped.push({
          id: m.id,
          userId: m.userId,
          firstName: firstNameOf(m.name),
          lastName: lastNameOf(m.name),
          name: m.name,
          avatarUrl: m.avatarUrl ?? null,
          joinedLabel: m.joinedAt ? MONTH_DAY_YEAR.format(new Date(m.joinedAt)) : '',
          groups: [...(groupsByUser.get(m.userId) ?? [])].sort(),
        })
      }
      deduped.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))

      members.value = deduped
      requests.value = requestLists.flat()
      membersLoaded = true
    } catch (err) {
      membersError.value = message(err, 'Failed to load members')
    } finally {
      membersLoading.value = false
    }
  }

  async function loadEnrolled(force = false): Promise<void> {
    if (enrolledLoaded && !force) return
    enrolledLoading.value = true
    enrolledError.value = null
    try {
      await ensureGroups(force)
      const now = new Date()

      const perGroup = await Promise.all(
        groups.value.map((g) =>
          axios
            .get(`/admin/api/groups/${g.id}/enrollments`)
            .then((r) => ((r.data.enrollments ?? []) as ApiEnrollment[]).map((e) => ({ e, groupName: g.name })))
            .catch(() => [] as Array<{ e: ApiEnrollment; groupName: string }>),
        ),
      )

      const rows: Array<{ row: LeaderEnrollment; start: number }> = []
      for (const { e, groupName } of perGroup.flat()) {
        const start = new Date(e.startDate)
        const end = e.endDate ? new Date(e.endDate) : null
        const totalLessons = e.studyProgram?.days ?? e._count?.lessonSchedules ?? 0
        const lessonsLeft = Math.max(0, totalLessons - daysBetween(start, now))
        rows.push({
          start: start.getTime(),
          row: {
            id: e.id,
            studyTitle: e.studyProgram?.name ?? 'Study',
            groupName,
            dateRange: end ? `${MONTH_DAY.format(start)} - ${MONTH_DAY.format(end)}` : MONTH_DAY.format(start),
            lessonsLeft,
            studyImageURL: e.studyProgram?.coverImageUrl ?? null,
          },
        })
      }
      // Newest start first, matching the iPhone Enrolled tab ordering.
      rows.sort((a, b) => b.start - a.start)
      enrollments.value = rows.map((r) => r.row)
      enrolledLoaded = true
    } catch (err) {
      enrolledError.value = message(err, 'Failed to load enrollments')
    } finally {
      enrolledLoading.value = false
    }
  }

  return {
    groups,
    members,
    requests,
    enrollments,
    groupsLoading,
    membersLoading,
    enrolledLoading,
    groupsError,
    membersError,
    enrolledError,
    loadGroups,
    loadMembers,
    loadEnrolled,
  }
})
