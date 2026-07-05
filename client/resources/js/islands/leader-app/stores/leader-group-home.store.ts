import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import type {
  GroupHomePost,
  GroupHomeNextLesson,
} from '../../../components/card/group-home-leader/group-home-leader.vue'

// Live data for the .groupHome overlay (iPhone GroupHomePage.swift), fetched
// through the shared /admin/api/* proxy. Mirrors the iPhone loading:
//   • Group          → GET /api/groups/:id
//   • Posts          → GET /api/groups/:id/posts?limit=20[&cursor=]
//   • Request badge  → GET /api/groups/:id/join-requests
//   • Next lesson    → GET /api/groups/:id/enrollments → GET /api/enrollments/:id
//                      (earliest !isCompleted schedule >= startOfDay(now) across
//                      active enrollments — GroupHomePage.swift:988-1020)
// Group-load failure surfaces an error state; posts/badge/next-lesson failures
// stay silent (iOS records them console-only — GroupHomePage.swift:911-1028).

export interface GroupHomeGroup {
  id: string
  name: string
  isPrivate: boolean
  memberCount: number
  coverImageUrl: string | null
  // Edit Group form fields (GET /api/groups/:id).
  description: string
  allowInvites: boolean
  memberDirectory: boolean
  ageRange: { min: number | null; max: number | null } | null
  maxMembers: number | null
}

interface ApiPost {
  id: string
  type?: string
  authorName?: string
  authorAvatarUrl?: string | null
  title?: string | null
  content?: string | null
  imageUrl?: string | null
  eventDate?: string | null
  eventLocation?: string | null
  viewCount?: number
  shareCount?: number
  attendeeCount?: number
  createdAt: string
}

interface ApiSchedule {
  id: string
  scheduledDate: string
  isCompleted?: boolean | null
  lesson?: {
    dayNumber?: number
    title?: string | null
    totalEstimatedMinutes?: number | null
    activities?: Array<{ type?: string; orderNumber?: number }>
  } | null
}

// iOS GroupPostCard.relativeTimeComponents — minutes / hours / days ago.
function relativeTime(iso: string): { timeValue: string; timeUnit: string } {
  const seconds = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000)
  if (seconds < 3600) {
    const m = Math.max(1, Math.floor(seconds / 60))
    return { timeValue: String(m), timeUnit: m === 1 ? 'minute ago' : 'minutes ago' }
  }
  if (seconds < 86_400) {
    const h = Math.floor(seconds / 3600)
    return { timeValue: String(h), timeUnit: h === 1 ? 'hour ago' : 'hours ago' }
  }
  const d = Math.floor(seconds / 86_400)
  return { timeValue: String(d), timeUnit: d === 1 ? 'day ago' : 'days ago' }
}

function initialsOf(name: string): string {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? '')
    .join('')
}

function mapPost(p: ApiPost): GroupHomePost {
  const rawType = (p.type ?? 'announcement').toLowerCase()
  const type = (['announcement', 'welcome', 'event'].includes(rawType)
    ? rawType
    : 'announcement') as GroupHomePost['type']
  const rel = relativeTime(p.createdAt)
  const post: GroupHomePost = {
    id: p.id,
    type,
    authorName: p.authorName ?? 'Member',
    initials: initialsOf(p.authorName ?? 'M'),
    avatarUrl: p.authorAvatarUrl ?? '',
    timeValue: rel.timeValue,
    timeUnit: rel.timeUnit,
    text: p.content ?? '',
    media: p.imageUrl ? 'photo' : null,
    viewCount: p.viewCount ?? 0,
    shareCount: p.shareCount ?? 0,
  }
  if (type === 'event' && p.eventDate) {
    const date = new Date(p.eventDate)
    post.eventTitle = p.title ?? ''
    post.eventDay = String(date.getDate())
    post.eventMonth = date.toLocaleDateString('en-US', { month: 'short' }).toUpperCase()
    // iOS event line, e.g. "Tuesday October 28 - 7:00pm".
    const weekday = date.toLocaleDateString('en-US', { weekday: 'long' })
    const month = date.toLocaleDateString('en-US', { month: 'long' })
    const time = date
      .toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })
      .replace(' ', '')
      .toLowerCase()
    post.eventDateTime = `${weekday} ${month} ${date.getDate()} - ${time}`
    post.attendeeCount = p.attendeeCount ?? 0
  }
  return post
}

const LESSON_DATE = new Intl.DateTimeFormat('en-US', {
  weekday: 'long',
  month: 'short',
  day: 'numeric',
  year: 'numeric',
})

export const useLeaderGroupHome = defineStore('leader-group-home', () => {
  const group = ref<GroupHomeGroup | null>(null)
  const posts = ref<GroupHomePost[]>([])
  const postsLoading = ref(false)
  const hasMorePosts = ref(false)
  const showRequestBadge = ref(false)
  const nextLesson = ref<GroupHomeNextLesson | null>(null)
  const nextLessonScheduleId = ref<string | null>(null)
  const nextLessonStudyName = ref('')
  const nextLessonSubtitle = ref('')
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Group invite (GET /api/groups/:id/invite) — prefetched by loadGroupHome so
  // the invite pane rides the slide warm (iOS GroupHomePage.swift:887).
  const invite = ref<{
    groupId: string
    groupName: string
    code: string
    inviteUrl: string
    qrCode: string
  } | null>(null)
  const inviteError = ref<string | null>(null)

  // Members pane (GroupMembersPage) — rows pre-shaped for the twin.
  const memberRows = ref<
    Array<{ id: string; userId: string; firstName: string; lastName: string; avatarUrl?: string; dateLabel: string }>
  >([])
  const requestRows = ref<
    Array<{ id: string; firstName: string; lastName: string; avatarUrl?: string; dateLabel: string }>
  >([])
  const membersLoading = ref(false)
  const membersError = ref<string | null>(null)

  let nextCursor: string | null = null
  let loadingMore = false
  let currentGroupId: string | null = null

  function reset(): void {
    group.value = null
    posts.value = []
    postsLoading.value = false
    hasMorePosts.value = false
    showRequestBadge.value = false
    nextLesson.value = null
    nextLessonScheduleId.value = null
    nextLessonStudyName.value = ''
    nextLessonSubtitle.value = ''
    error.value = null
    invite.value = null
    inviteError.value = null
    memberRows.value = []
    requestRows.value = []
    membersError.value = null
    nextCursor = null
  }

  async function loadGroupHome(groupId: string): Promise<void> {
    reset()
    currentGroupId = groupId
    loading.value = true
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}`)
      const g = res.data.group ?? res.data
      group.value = {
        id: g.id,
        name: g.name ?? 'Group',
        isPrivate: Boolean(g.isPrivate),
        memberCount: g.memberCount ?? 0,
        coverImageUrl: g.coverImageUrl ?? null,
        description: g.description ?? '',
        allowInvites: Boolean(g.allowInvites),
        memberDirectory: Boolean(g.memberDirectory),
        ageRange: g.ageRange ?? null,
        maxMembers: g.maxMembers ?? null,
      }
    } catch (err) {
      const e = err as { response?: { data?: { error?: string; message?: string } } }
      error.value =
        e?.response?.data?.error ?? e?.response?.data?.message ?? 'Failed to load the group'
      loading.value = false
      return
    }
    loading.value = false

    // The rest loads in parallel; failures are silent (iOS console-only).
    void loadPosts(groupId)
    void loadRequestBadge(groupId)
    void loadNextLesson(groupId)
    void loadGroupInvite(groupId)
  }

  // iOS GroupActions.loadGroupInvite — cached; the pane's error state only
  // shows when nothing is cached (background-refresh failures are silent).
  async function loadGroupInvite(groupId: string): Promise<void> {
    inviteError.value = null
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/invite`)
      const inv = res.data.invite
      if (inv) {
        invite.value = {
          groupId: inv.groupId,
          groupName: inv.groupName ?? '',
          code: inv.code ?? '',
          inviteUrl: inv.inviteUrl ?? '',
          qrCode: inv.qrCode ?? '',
        }
      }
    } catch (err) {
      if (!invite.value) {
        const e = err as { response?: { data?: { error?: string } } }
        inviteError.value = e?.response?.data?.error ?? 'Something went wrong'
      }
      // Silent when cached data exists (iOS :305-312).
    }
  }

  async function loadPosts(groupId: string): Promise<void> {
    postsLoading.value = true
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/posts?limit=20`)
      posts.value = (res.data.posts ?? []).map(mapPost)
      nextCursor = res.data.nextCursor ?? null
      hasMorePosts.value = Boolean(nextCursor)
    } catch {
      // Silent: iOS records console-only; the empty state stands.
    } finally {
      postsLoading.value = false
    }
  }

  async function loadMorePosts(): Promise<void> {
    if (!currentGroupId || !nextCursor || loadingMore) return
    loadingMore = true
    try {
      const res = await axios.get(
        `/admin/api/groups/${currentGroupId}/posts?limit=20&cursor=${encodeURIComponent(nextCursor)}`,
      )
      posts.value = [...posts.value, ...(res.data.posts ?? []).map(mapPost)]
      nextCursor = res.data.nextCursor ?? null
      hasMorePosts.value = Boolean(nextCursor)
    } catch {
      // Silent: pagination failure leaves the list as-is.
    } finally {
      loadingMore = false
    }
  }

  const MEMBER_DATE = new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })

  function formatMemberDate(iso: string | null | undefined): string {
    if (!iso) return ''
    return MEMBER_DATE.format(new Date(iso))
  }

  // Keeps both the person.2 badge AND the members pane's Requests rows in sync
  // (iOS routes everything through pendingJoinRequestsByGroupId the same way).
  async function loadRequestBadge(groupId: string): Promise<void> {
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/join-requests`)
      const requests: Array<{
        id: string
        createdAt?: string
        member?: { firstName?: string; lastName?: string; avatarUrl?: string | null }
      }> = res.data.requests ?? []
      requestRows.value = requests.map((r) => ({
        id: r.id,
        firstName: r.member?.firstName ?? '',
        lastName: r.member?.lastName ?? '',
        avatarUrl: r.member?.avatarUrl ?? undefined,
        dateLabel: formatMemberDate(r.createdAt),
      }))
      showRequestBadge.value = requests.length > 0
    } catch {
      // Silent.
    }
  }

  // iOS GroupMembersPage loadData — members sorted client-side by name.
  async function loadGroupMembers(groupId: string): Promise<void> {
    membersLoading.value = !memberRows.value.length
    membersError.value = null
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/members`)
      const members: Array<{
        id: string
        userId?: string
        name?: string
        avatarUrl?: string | null
        joinedAt?: string
      }> = res.data.members ?? []
      memberRows.value = members
        .map((m) => {
          const parts = (m.name ?? '').trim().split(/\s+/)
          return {
            id: m.id,
            userId: m.userId ?? '',
            firstName: parts[0] ?? '',
            lastName: parts.slice(1).join(' '),
            avatarUrl: m.avatarUrl ?? undefined,
            dateLabel: formatMemberDate(m.joinedAt),
          }
        })
        .sort((a, b) =>
          `${a.firstName} ${a.lastName}`.toLowerCase().localeCompare(`${b.firstName} ${b.lastName}`.toLowerCase()),
        )
    } catch (err) {
      if (!memberRows.value.length && !requestRows.value.length) {
        const e = err as { response?: { data?: { error?: string } } }
        membersError.value = e?.response?.data?.error ?? 'Something went wrong'
      }
      // Silent when cached rows exist (iOS :407-409).
    } finally {
      membersLoading.value = false
    }
  }

  async function loadNextLesson(groupId: string): Promise<void> {
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/enrollments`)
      const enrollments: Array<{
        id: string
        isActive?: boolean
        studyProgram?: { name?: string } | null
      }> = (res.data.enrollments ?? []).filter(
        (e: { isActive?: boolean }) => e.isActive !== false,
      )
      if (!enrollments.length) return

      const details = await Promise.all(
        enrollments.map(async (e) => {
          const d = await axios.get(`/admin/api/enrollments/${e.id}`)
          const schedules: ApiSchedule[] =
            d.data.enrollment?.lessonSchedules ?? d.data.lessonSchedules ?? []
          return { enrollment: e, schedules }
        }),
      )

      // iOS: earliest schedule with isCompleted != true && date >= startOfDay(now).
      const startOfDay = new Date()
      startOfDay.setHours(0, 0, 0, 0)
      let best: { enrollment: (typeof enrollments)[number]; schedule: ApiSchedule } | null = null
      for (const { enrollment, schedules } of details) {
        for (const schedule of schedules) {
          if (schedule.isCompleted === true) continue
          const when = new Date(schedule.scheduledDate)
          if (when < startOfDay) continue
          if (!best || when < new Date(best.schedule.scheduledDate)) best = { enrollment, schedule }
        }
      }
      if (!best) return

      const lesson = best.schedule.lesson ?? {}
      const activities = [...(lesson.activities ?? [])]
        .sort((a, b) => (a.orderNumber ?? 0) - (b.orderNumber ?? 0))
        .map((a) => ({ activityType: a.type ?? 'READ', status: 'incomplete' as const }))
      // CardLesson lesson-mode bag (iOS cardLessonData — GroupHomePage.swift:680-700).
      nextLesson.value = {
        mode: 'lesson',
        day: lesson.dayNumber,
        title: lesson.title ?? '',
        date: LESSON_DATE.format(new Date(best.schedule.scheduledDate)),
        estimatedMinutes: lesson.totalEstimatedMinutes ?? undefined,
        activities,
      }
      nextLessonScheduleId.value = best.schedule.id
      nextLessonStudyName.value = best.enrollment.studyProgram?.name ?? 'Study'
      const menuDate = new Date(best.schedule.scheduledDate).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
      })
      nextLessonSubtitle.value = `Day ${lesson.dayNumber ?? 0} - ${menuDate}`
    } catch {
      // Silent.
    }
  }

  // iOS saveGroup → PATCH /api/groups/:id (groups.ts:890). Web sends
  // memberDirectory (server accepts it since the 2026-07-04 zod fix) and
  // maxMembers: null for "Unlimited" (iOS omits the key — a quirk that makes
  // Unlimited unsaveable; web does it right, flagged at verify).
  async function saveGroup(patch: {
    name: string
    description: string
    isPrivate: boolean
    allowInvites: boolean
    memberDirectory: boolean
    ageRange: { min: number; max: number }
    maxMembers: number | null
  }): Promise<void> {
    if (!currentGroupId) return
    const res = await axios.patch(`/admin/api/groups/${currentGroupId}`, patch)
    const g = res.data.group ?? {}
    if (group.value) {
      group.value = {
        ...group.value,
        name: g.name ?? patch.name,
        description: g.description ?? patch.description,
        isPrivate: Boolean(g.isPrivate ?? patch.isPrivate),
        allowInvites: Boolean(g.allowInvites ?? patch.allowInvites),
        memberDirectory: Boolean(g.memberDirectory ?? patch.memberDirectory),
        ageRange: g.ageRange ?? patch.ageRange,
        maxMembers: g.maxMembers !== undefined ? g.maxMembers : patch.maxMembers,
      }
    }
  }

  // iOS uploadCoverImage → POST /api/groups/:id/cover-image, JSON base64
  // {imageData, contentType} (APIClient.uploadImage; groups.ts:1153).
  async function uploadCover(imageData: string, contentType: string): Promise<void> {
    if (!currentGroupId) return
    const base64 = imageData.includes(',') ? imageData.split(',')[1] : imageData
    const res = await axios.post(`/admin/api/groups/${currentGroupId}/cover-image`, {
      imageData: base64,
      contentType,
    })
    if (group.value && res.data.coverImageUrl) {
      group.value = { ...group.value, coverImageUrl: res.data.coverImageUrl }
    }
  }

  // iOS handleOpenLesson: GET the lesson invite and open its URL.
  async function loadLessonInviteUrl(scheduleId: string): Promise<string> {
    const res = await axios.get(`/admin/api/lesson-schedules/${scheduleId}/invite`)
    const url = res.data.invite?.inviteUrl ?? res.data.inviteUrl
    if (!url) throw new Error('No invite URL')
    return url
  }

  return {
    group,
    posts,
    postsLoading,
    hasMorePosts,
    showRequestBadge,
    nextLesson,
    nextLessonScheduleId,
    nextLessonStudyName,
    nextLessonSubtitle,
    loading,
    error,
    invite,
    inviteError,
    memberRows,
    requestRows,
    membersLoading,
    membersError,
    loadGroupHome,
    loadGroupInvite,
    loadGroupMembers,
    loadMorePosts,
    loadLessonInviteUrl,
    saveGroup,
    uploadCover,
  }
})
