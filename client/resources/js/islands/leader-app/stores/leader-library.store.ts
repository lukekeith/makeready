import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

// Live data for the mobile leader app's Library page (the iPhone MainLibrary:
// Programs / Media tabs), fetched through the shared /admin/api/* proxy.
// Mirrors the iPhone ProgramActions / MediaActions loading:
//   • Programs → GET /api/programs (org-scoped) + GET /api/group-leaders
//                (creatorId → author display name)
//   • Media    → GET /api/organizations/:orgId/media/library (org id resolved
//                from the leader's groups); search re-queries with ?q=
//   • Invite   → POST /api/invites + POST /api/qrcode/generate (the AddMenu →
//                Invite member → QR Code share flow)

export interface LeaderProgram {
  id: string
  title: string
  description: string
  days: number
  tags: string[]
  enrollmentCount: number
  authorName: string
  relativeDate: string
  published: boolean
  coverUrl: string | null
  createdAt: number
  /** iOS StudyProgram.isEditable gating — swipe-to-delete is creator-only. */
  creatorId: string | null
}

export interface LeaderMediaItem {
  id: string
  title: string
  type: string // 'photo' | 'video' | 'document' | 'audio'
  thumbnailUrl: string | null
  duration: number | null
  usageCount: number
  /** Epoch ms — the iOS time filter is a client-side createdAt cutoff. */
  createdAt: number
}

interface ApiProgram {
  id: string
  name: string
  description?: string | null
  days?: number
  coverImageUrl?: string | null
  creatorId?: string | null
  isPublished?: boolean
  createdAt?: string
  tags?: string[]
  _count?: { enrollments?: number }
}

interface ApiLeader {
  id: string
  firstName?: string | null
  lastName?: string | null
  programCount?: number
  mediaCount?: number
}

/** GET /api/group-leaders row, kept for the Leaders filter panels. */
export interface FilterLeader {
  id: string
  name: string
  programCount: number
  mediaCount: number
}

// iOS enum rawValues — these exact strings are what FilterState persists to
// /api/preferences (shared with the iPhone for the same user), so they must
// match MainLibrary.swift verbatim.
export const PROGRAM_SORTS = ['Newest first', 'Most popular', 'A - Z'] as const
export const MEDIA_SORTS = ['Newest first', 'Most used', 'A - Z'] as const
export const MEDIA_TYPES = ['All', 'Video', 'Images', 'Audio'] as const
export const MEDIA_TIMES = ['All time', 'Last 7 days', 'Last 30 days', 'Last 90 days'] as const

// MediaTypeFilter.apiValue (MainLibrary.swift): All → omit, Images → "photo".
const MEDIA_TYPE_API: Record<string, string | null> = {
  All: null,
  Video: 'video',
  Images: 'photo',
  Audio: 'audio',
}

// MediaTimeFilter.cutoffDate — client-side, days back from now.
const MEDIA_TIME_DAYS: Record<string, number | null> = {
  'All time': null,
  'Last 7 days': 7,
  'Last 30 days': 30,
  'Last 90 days': 90,
}

export function mediaTimeCutoff(time: string): number | null {
  const days = MEDIA_TIME_DAYS[time] ?? null
  return days == null ? null : Date.now() - days * 86_400_000
}

interface ApiMediaItem {
  id: string
  title?: string | null
  url?: string | null
  type?: string
  thumbnailUrl?: string | null
  duration?: number | null
  usageCount?: number
  createdAt?: string
}

// iPhone CardProgramFull uses RelativeDateTimeFormatter ("2 months ago").
const RELATIVE = new Intl.RelativeTimeFormat('en-US', { numeric: 'always' })
function relativeTime(iso?: string): string {
  if (!iso) return ''
  const seconds = Math.round((new Date(iso).getTime() - Date.now()) / 1000)
  const abs = Math.abs(seconds)
  if (abs < 60) return RELATIVE.format(seconds, 'second')
  if (abs < 3600) return RELATIVE.format(Math.trunc(seconds / 60), 'minute')
  if (abs < 86_400) return RELATIVE.format(Math.trunc(seconds / 3600), 'hour')
  if (abs < 604_800) return RELATIVE.format(Math.trunc(seconds / 86_400), 'day')
  if (abs < 2_629_800) return RELATIVE.format(Math.trunc(seconds / 604_800), 'week')
  if (abs < 31_557_600) return RELATIVE.format(Math.trunc(seconds / 2_629_800), 'month')
  return RELATIVE.format(Math.trunc(seconds / 31_557_600), 'year')
}

export const useLeaderLibrary = defineStore('leader-library', () => {
  const programs = ref<LeaderProgram[]>([])
  const media = ref<LeaderMediaItem[]>([])

  const programsLoading = ref(false)
  const mediaLoading = ref(false)
  const programsError = ref<string | null>(null)
  const mediaError = ref<string | null>(null)

  let programsLoaded = false
  let mediaLoaded = false
  let orgId: string | null = null
  let fullMedia: LeaderMediaItem[] | null = null

  // ── Filter + sort state (iOS FilterState, scopes library.programs/.media) ──
  // Tags/leaders/type re-FETCH server-side (iOS onChange → forceRefresh);
  // sort + media time are client-side. Values are iOS enum rawValues.
  const programTags = ref<string[]>([])
  const programLeaders = ref<string[]>([])
  const programSort = ref<string>('Newest first')
  const mediaTags = ref<string[]>([])
  const mediaLeaders = ref<string[]>([])
  const mediaType = ref<string>('All')
  const mediaTime = ref<string>('All time')
  const mediaSort = ref<string>('Newest first')

  // Filter option lists.
  const allProgramTags = ref<string[]>([])
  const allMediaTags = ref<string[]>([])
  const filterLeaders = ref<FilterLeader[]>([])

  let currentUserId: string | null = null

  function message(err: unknown, fallback: string): string {
    const e = err as { response?: { data?: { error?: string; message?: string } } }
    return e?.response?.data?.error ?? e?.response?.data?.message ?? fallback
  }

  async function loadPrograms(force = false): Promise<void> {
    if (programsLoaded && !force) return
    programsLoading.value = true
    programsError.value = null
    try {
      // iOS fetchPrograms: ?tag=<csv> (ANY-match) + ?leaders=<csv> (creatorId IN).
      const params: Record<string, string> = {}
      if (programTags.value.length) params.tag = programTags.value.join(',')
      if (programLeaders.value.length) params.leaders = programLeaders.value.join(',')
      const [programsRes, leadersRes] = await Promise.all([
        axios.get('/admin/api/programs', { params }),
        axios.get('/admin/api/group-leaders').catch(() => ({ data: { leaders: [] } })),
      ])
      const raw: ApiProgram[] = programsRes.data.programs ?? []
      const leaders: ApiLeader[] = leadersRes.data.leaders ?? []
      const nameById = new Map(
        leaders.map((l) => [l.id, [l.firstName, l.lastName].filter(Boolean).join(' ')]),
      )
      filterLeaders.value = leaders.map((l) => ({
        id: l.id,
        name: [l.firstName, l.lastName].filter(Boolean).join(' ') || 'Unknown',
        programCount: l.programCount ?? 0,
        mediaCount: l.mediaCount ?? 0,
      }))
      const rows = raw.map((p) => ({
        id: p.id,
        title: p.name,
        description: p.description ?? '',
        days: p.days ?? 0,
        tags: p.tags ?? [],
        enrollmentCount: p._count?.enrollments ?? 0,
        authorName: (p.creatorId && nameById.get(p.creatorId)) || '',
        relativeDate: relativeTime(p.createdAt),
        published: Boolean(p.isPublished),
        coverUrl: p.coverImageUrl ?? null,
        createdAt: p.createdAt ? new Date(p.createdAt).getTime() : 0,
        creatorId: p.creatorId ?? null,
      }))
      // iPhone default sort: "Newest first" (createdAt desc).
      rows.sort((a, b) => b.createdAt - a.createdAt)
      programs.value = rows
      programsLoaded = true
    } catch (err) {
      programsError.value = message(err, 'Failed to load study programs')
    } finally {
      programsLoading.value = false
    }
  }

  // The media-library endpoint is org-scoped; the leader's org id comes from
  // their groups (every group row carries organizationId).
  async function ensureOrgId(): Promise<string | null> {
    if (orgId) return orgId
    const res = await axios.get('/admin/api/groups')
    const groups: Array<{ organizationId?: string | null }> = res.data.groups ?? []
    orgId = groups.find((g) => g.organizationId)?.organizationId ?? null
    return orgId
  }

  function mapMedia(raw: ApiMediaItem[]): LeaderMediaItem[] {
    return raw.map((m) => ({
      id: m.id,
      title: m.title ?? '',
      type: m.type ?? 'photo',
      // Photos fall back to the original asset when no thumbnail was derived
      // (matches the iPhone MediaThumbnailCell).
      thumbnailUrl: m.thumbnailUrl ?? (m.type === 'photo' ? m.url ?? null : null),
      duration: m.duration ?? null,
      usageCount: m.usageCount ?? 0,
      createdAt: m.createdAt ? new Date(m.createdAt).getTime() : 0,
    }))
  }

  async function loadMedia(force = false): Promise<void> {
    if (mediaLoaded && !force) return
    mediaLoading.value = true
    mediaError.value = null
    try {
      const org = await ensureOrgId()
      if (!org) {
        media.value = []
        fullMedia = []
        mediaLoaded = true
        return
      }
      const res = await axios.get(`/admin/api/organizations/${org}/media/library`, {
        params: { limit: 100, ...mediaFilterParams() },
      })
      fullMedia = mapMedia(res.data.data ?? [])
      media.value = fullMedia
      mediaLoaded = true
    } catch (err) {
      mediaError.value = message(err, 'Failed to load media library')
    } finally {
      mediaLoading.value = false
    }
  }

  // Server-side media search (the iPhone debounces 300ms then hits ?q=).
  async function searchMedia(query: string): Promise<void> {
    const q = query.trim()
    if (!q) {
      if (fullMedia) media.value = fullMedia
      else await loadMedia()
      return
    }
    mediaLoading.value = true
    mediaError.value = null
    try {
      const org = await ensureOrgId()
      if (!org) {
        media.value = []
        return
      }
      const res = await axios.get(`/admin/api/organizations/${org}/media/library`, {
        params: { limit: 100, q, ...mediaFilterParams() },
      })
      media.value = mapMedia(res.data.data ?? [])
    } catch (err) {
      mediaError.value = message(err, 'Search failed')
    } finally {
      mediaLoading.value = false
    }
  }

  // iOS MediaActions.fetchLibrary: &type= &tags=<csv> &leaders=<csv>.
  function mediaFilterParams(): Record<string, string> {
    const params: Record<string, string> = {}
    const apiType = MEDIA_TYPE_API[mediaType.value]
    if (apiType) params.type = apiType
    if (mediaTags.value.length) params.tags = mediaTags.value.join(',')
    if (mediaLeaders.value.length) params.leaders = mediaLeaders.value.join(',')
    return params
  }

  // ── Filter options (tags count-desc from the server; leaders via programs) ──

  async function loadFilterOptions(): Promise<void> {
    const [pTags, mTags] = await Promise.all([
      axios.get('/admin/api/programs/tags').catch(() => ({ data: { tags: [] } })),
      axios.get('/admin/api/media/tags').catch(() => ({ data: { tags: [] } })),
    ])
    allProgramTags.value = (pTags.data.tags ?? []).map((t: { tag: string }) => t.tag)
    allMediaTags.value = (mTags.data.tags ?? []).map((t: { tag: string }) => t.tag)
  }

  // ── FilterState persistence (iOS FilterState.swift, shared prefs keys) ──
  //
  // GET /api/preferences/filters.<scope> → { value, isDefault }; applied only
  // when an explicit preference exists, otherwise leaders default to the
  // current user ("My content"). PUT is debounced 1500ms with the exact iOS
  // JSON shape so both platforms read each other's state.

  const saveTimers: Record<string, number> = {}

  function scheduleSave(scope: 'library.programs' | 'library.media'): void {
    window.clearTimeout(saveTimers[scope])
    saveTimers[scope] = window.setTimeout(() => {
      const value =
        scope === 'library.programs'
          ? { tags: programTags.value, leaders: programLeaders.value, sort: programSort.value }
          : {
              tags: mediaTags.value,
              leaders: mediaLeaders.value,
              sort: mediaSort.value,
              mediaType: mediaType.value,
              timeFilter: mediaTime.value,
            }
      axios
        .put(`/admin/api/preferences/filters.${scope}`, { value: JSON.stringify(value) })
        .catch(() => {}) // Silent: preference persistence is best-effort (iOS ditto)
    }, 1500)
  }

  async function loadFilters(userId: string | null): Promise<void> {
    currentUserId = userId
    const load = async (scope: string) => {
      try {
        const res = await axios.get(`/admin/api/preferences/filters.${scope}`)
        if (res.data?.isDefault || !res.data?.value) return null
        return JSON.parse(res.data.value) as {
          tags?: string[]
          leaders?: string[]
          sort?: string
          mediaType?: string
          timeFilter?: string
        }
      } catch {
        return null // Silent: fall back to defaults, matching iOS load failure
      }
    }
    const [p, m] = await Promise.all([load('library.programs'), load('library.media')])
    if (p) {
      programTags.value = p.tags ?? []
      programLeaders.value = p.leaders ?? []
      if (p.sort && (PROGRAM_SORTS as readonly string[]).includes(p.sort)) programSort.value = p.sort
    } else if (currentUserId) {
      // iOS default: no explicit preference → "My content".
      programLeaders.value = [currentUserId]
    }
    if (m) {
      mediaTags.value = m.tags ?? []
      mediaLeaders.value = m.leaders ?? []
      if (m.sort && (MEDIA_SORTS as readonly string[]).includes(m.sort)) mediaSort.value = m.sort
      if (m.mediaType && (MEDIA_TYPES as readonly string[]).includes(m.mediaType)) mediaType.value = m.mediaType
      if (m.timeFilter && (MEDIA_TIMES as readonly string[]).includes(m.timeFilter)) mediaTime.value = m.timeFilter
    } else if (currentUserId) {
      mediaLeaders.value = [currentUserId]
    }
  }

  // Ready photos for the read-block MediaLibraryPicker (iOS
  // MediaLibraryPicker.photoItems: type == photo, createdAt desc).
  async function loadPhotos(): Promise<
    Array<{ id: string; url: string; thumbnailUrl: string | null }>
  > {
    const org = await ensureOrgId()
    if (!org) return []
    const res = await axios.get(`/admin/api/organizations/${org}/media/library`, {
      params: { limit: 100, type: 'photo' },
    })
    const raw: Array<ApiMediaItem & { url?: string | null }> = res.data.data ?? []
    return raw
      .filter((m) => m.url)
      .map((m) => ({ id: m.id, url: m.url as string, thumbnailUrl: m.thumbnailUrl ?? null }))
  }

  // iOS MediaActions.uploadPhoto — base64 JSON POST (not multipart). The
  // server (media.ts upload) generates 1200/400/150 JPEG variants on R2 and
  // CREATES an org Media row, so the photo also lands in the media library.
  async function uploadPhoto(
    title: string,
    base64Jpeg: string,
  ): Promise<{ id: string; url: string; thumbnailUrl: string | null }> {
    const org = await ensureOrgId()
    if (!org) throw new Error('No organization found')
    const res = await axios.post(`/admin/api/organizations/${org}/media/upload`, {
      type: 'photo',
      title,
      imageData: base64Jpeg,
    })
    const data = res.data?.data
    if (!res.data?.success || !data?.url) {
      throw new Error(res.data?.error ?? 'Failed to upload photo')
    }
    return { id: data.id, url: data.url, thumbnailUrl: data.thumbnailUrl ?? null }
  }

  // ── Invite + QR (AddMenu → Invite member → QR Code → ShareInviteSheet) ──

  async function createInvite(): Promise<string> {
    const res = await axios.post('/admin/api/invites', {})
    const code: string | undefined = res.data?.invite?.code
    if (!code) throw new Error(res.data?.error ?? 'Failed to create invite')
    return code
  }

  // Server-generated QR (same params the iPhone InviteActions.generateQRCode
  // sends); returns a base64 PNG data URL.
  async function generateQr(data: string, size: number, includeLogo: boolean): Promise<string> {
    const res = await axios.post('/admin/api/qrcode/generate', {
      data,
      color: '#6c47ff',
      backgroundColor: '#ffffff',
      size,
      errorCorrectionLevel: 'M',
      includeLogo,
    })
    const qr: string | undefined = res.data?.qrCode
    if (!qr) throw new Error(res.data?.error ?? 'Failed to generate QR code')
    return qr
  }

  // iOS MainLibrary.deleteProgram → DELETE /api/programs/:id (server soft
  // delete: isActive=false); remove locally on success.
  async function deleteProgram(id: string): Promise<void> {
    try {
      await axios.delete(`/admin/api/programs/${id}`)
    } catch (err) {
      throw new Error(message(err, 'Failed to delete program'))
    }
    programs.value = programs.value.filter((p) => p.id !== id)
  }

  return {
    programs,
    media,
    programsLoading,
    mediaLoading,
    programsError,
    mediaError,
    loadPrograms,
    loadMedia,
    searchMedia,
    deleteProgram,
    createInvite,
    generateQr,
    loadPhotos,
    uploadPhoto,
    // Filters + sort
    programTags,
    programLeaders,
    programSort,
    mediaTags,
    mediaLeaders,
    mediaType,
    mediaTime,
    mediaSort,
    allProgramTags,
    allMediaTags,
    filterLeaders,
    loadFilterOptions,
    loadFilters,
    scheduleSave,
  }
})
