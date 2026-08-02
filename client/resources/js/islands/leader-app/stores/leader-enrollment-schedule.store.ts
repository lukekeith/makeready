import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import type { EnrollmentScheduleRow } from '../../../components/card/enrollment-schedule/enrollment-schedule.vue'
import {
  mapActivity,
  type ApiActivity,
  type LeaderActivity,
  type LeaderPassage,
} from './leader-program.store'
import type {
  ActivityEditorActions,
  ExegesisHighlightData,
} from './activity-editor-actions'

// Leader enrollment-schedule store — data for the .enrollmentSchedule modal
// family (iOS EnrollmentSchedulePage / EditEnrollmentDay /
// UnenrollOptionsModal via EnrollmentActions).

export interface ScheduledActivityRow {
  id: string
  type: string
  title: string | null
  passageReference: string | null
  estimatedMinutes: number
  isConfigured: boolean
  videoId: string | null
  videoUrl: string | null
  youtubeUrl: string | null
  readBlocks: Array<{
    title?: string | null
    content?: string | null
    isLocked?: boolean
    selections?: unknown[] | null
  }>
  /** Full editor model (iOS ScheduledActivity.toStudyActivity()) — what the
   *  shared READ/WRITE/YOUTUBE/EXEGESIS editor panes consume. */
  detail: LeaderActivity
}

export interface ScheduleEntry {
  id: string
  lessonId: string
  day: number
  title: string | null
  lessonTitle: string | null
  scheduledDate: string
  estimatedMinutes: number
  activities: ScheduledActivityRow[]
}

export interface EnrollmentScheduleData {
  enrollmentId: string
  programId: string | null
  programName: string | null
  schedules: ScheduleEntry[]
}

// iOS ScheduledActivity.isConfigured (LessonModels.swift:169-200) — verbatim.
function isConfigured(a: {
  type?: string
  passageReference?: string | null
  videoId?: string | null
  videoUrl?: string | null
  prayerPrompt?: string | null
  notes?: string | null
  readContent?: string | null
  youtubeUrl?: string | null
  title?: string | null
  readBlocks?: Array<{ content?: string | null; isLocked?: boolean; selections?: unknown[] | null }>
}): boolean {
  const blocks = a.readBlocks ?? []
  switch (a.type) {
    case 'SCRIPTURE':
    case 'SOAP':
      return !!a.passageReference
    case 'VIDEO':
      return !!a.videoId || !!a.videoUrl
    case 'PRAYER':
      return !!a.prayerPrompt
    case 'REFLECTION':
      return !!a.notes
    case 'READ':
      return blocks.some((b) => !!b.content) || !!a.readContent
    case 'YOUTUBE':
      return !!a.youtubeUrl
    case 'EXEGESIS': {
      // iOS: needs a title, THE locked scripture block with content, and at
      // least one highlight on that block (LessonModels.swift:186-195 —
      // `locked` there is the found locked BLOCK, selections live on it).
      if (!a.title) return false
      const locked = blocks.find((b) => b.isLocked === true)
      if (!locked?.content) return false
      return (locked.selections?.length ?? 0) > 0
    }
    default:
      return true // USER_INPUT and unknown types
  }
}

// iOS CardLesson date line: weekday(.wide), month(.abbreviated), day, year.
function formatDateLine(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

function isReleased(iso: string): boolean {
  const d = new Date(iso)
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  return day.getTime() <= today.getTime()
}

interface RawScheduledActivity {
  id: string
  /** Scheduled payloads use `type`; program-shaped echoes `activityType`. */
  type?: string
  activityType?: string
  title?: string | null
  passageReference?: string | null
  videoId?: string | null
  videoUrl?: string | null
  youtubeUrl?: string | null
  estimatedMinutes?: number | null
  readBlocks?: ScheduledActivityRow['readBlocks'] | null
}

// Build a row (slim display fields + the full editor `detail`) from a raw
// scheduled-activity payload — used for the initial load AND for the
// `scheduledActivity` echo most mutation endpoints return.
function mapScheduledActivity(a: Record<string, unknown>): ScheduledActivityRow {
  const raw = a as unknown as RawScheduledActivity
  const type = raw.type ?? raw.activityType ?? 'READ'
  const detail = mapActivity({ ...(a as unknown as ApiActivity), activityType: type })
  return {
    id: raw.id,
    type,
    title: raw.title ?? null,
    passageReference: raw.passageReference ?? null,
    estimatedMinutes: raw.estimatedMinutes ?? 0,
    isConfigured: isConfigured({ ...raw, type }),
    videoId: raw.videoId ?? null,
    videoUrl: raw.videoUrl ?? null,
    youtubeUrl: raw.youtubeUrl ?? null,
    readBlocks: raw.readBlocks ?? [],
    detail,
  }
}

// Refresh a row in place: from a server echo when present, otherwise
// re-derive the slim display fields from an optimistically-patched detail.
function refreshRow(row: ScheduledActivityRow, api?: Record<string, unknown>): void {
  if (api) {
    const mapped = mapScheduledActivity(api)
    if ((api as { estimatedMinutes?: unknown }).estimatedMinutes == null) {
      mapped.estimatedMinutes = row.estimatedMinutes
    }
    Object.assign(row, mapped)
    return
  }
  const d = row.detail
  row.title = d.title || null
  row.youtubeUrl = d.youtubeUrl || null
  row.readBlocks = d.readBlocks.map((b) => ({
    title: b.title,
    content: b.content,
    isLocked: b.isLocked,
    selections: b.selections,
  }))
  row.isConfigured = isConfigured({
    type: row.type,
    title: d.title || null,
    passageReference: row.passageReference,
    videoId: row.videoId,
    videoUrl: row.videoUrl,
    youtubeUrl: d.youtubeUrl || null,
    readBlocks: row.readBlocks,
  })
}

export const useLeaderEnrollmentSchedule = defineStore('leader-enrollment-schedule', () => {
  const data = ref<EnrollmentScheduleData | null>(null)
  const loading = ref(false)
  const error = ref('')
  // completion-stats: scheduledActivityId → completedCount, + memberCount.
  const memberCount = ref(0)
  const completedByActivity = ref<Map<string, number>>(new Map())
  const statsLoaded = ref(false)

  async function loadDetails(enrollmentId: string, showLoading = true): Promise<void> {
    if (showLoading) loading.value = true
    try {
      const res = await axios.get(`/admin/api/enrollments/${enrollmentId}`)
      const e = res.data?.enrollment
      if (!e) throw new Error(res.data?.error ?? 'Failed to load enrollment')
      const schedules: ScheduleEntry[] = (e.lessonSchedules ?? []).map(
        (s: {
          id: string
          title?: string | null
          scheduledDate: string
          lesson?: {
            id?: string
            dayNumber?: number
            title?: string | null
            estimatedMinutes?: number | null
          } | null
          scheduledActivities?: Array<Record<string, unknown>> | null
        }) => ({
          id: s.id,
          lessonId: s.lesson?.id ?? '',
          day: s.lesson?.dayNumber ?? 0,
          title: s.title ?? null,
          lessonTitle: s.lesson?.title ?? null,
          scheduledDate: s.scheduledDate,
          estimatedMinutes: s.lesson?.estimatedMinutes ?? 0,
          activities: (s.scheduledActivities ?? []).map((a) => mapScheduledActivity(a)),
        })
      )
      data.value = {
        enrollmentId,
        programId: e.studyProgramId ?? e.studyProgram?.id ?? null,
        programName: e.studyProgram?.name ?? null,
        schedules,
      }
      error.value = ''
    } catch (err) {
      // iOS: a background-refresh failure keeps cached content, console-only.
      if (!data.value) {
        error.value = err instanceof Error ? err.message : 'Failed to load enrollment'
      }
    } finally {
      loading.value = false
    }
  }

  async function loadCompletionStats(enrollmentId: string): Promise<void> {
    try {
      const res = await axios.get(`/admin/api/enrollments/${enrollmentId}/completion-stats`)
      const stats = res.data?.stats
      if (!stats) return
      memberCount.value = stats.memberCount ?? 0
      const map = new Map<string, number>()
      for (const lesson of stats.lessons ?? []) {
        for (const a of lesson.activities ?? []) {
          map.set(a.scheduledActivityId, a.completedCount ?? 0)
        }
      }
      completedByActivity.value = map
      statsLoaded.value = true
    } catch {
      // Stats are progressive enhancement (icons fall back to .incomplete).
    }
  }

  // Twin rows (iOS cardLessonData): per-activity fill from stats when loaded.
  function scheduleRows(): EnrollmentScheduleRow[] {
    return (data.value?.schedules ?? []).map((s) => ({
      id: s.id,
      day: s.day,
      title: s.title ?? s.lessonTitle ?? undefined,
      date: formatDateLine(s.scheduledDate),
      estimatedMinutes: s.estimatedMinutes,
      released: isReleased(s.scheduledDate),
      activities: s.activities.map((a) =>
        statsLoaded.value && memberCount.value > 0
          ? {
              activityType: a.type,
              fill: (completedByActivity.value.get(a.id) ?? 0) / memberCount.value,
            }
          : { activityType: a.type, status: 'incomplete' as const }
      ),
    }))
  }

  // iOS addScheduledLesson: next unscheduled lesson = lowest dayNumber of the
  // program's lessons not already scheduled; "already scheduled" → the
  // all-lessons-scheduled info case.
  async function addScheduledLesson(enrollmentId: string): Promise<'added' | 'allScheduled'> {
    const d = data.value
    if (!d?.programId) throw new Error("Couldn't add the lesson")
    const prog = await axios.get(`/admin/api/programs/${d.programId}?lessonLimit=100`)
    const lessons: Array<{ id: string; dayNumber?: number }> =
      prog.data?.program?.lessons ?? prog.data?.lessons ?? []
    const scheduled = new Set(d.schedules.map((s) => s.lessonId))
    const next = lessons
      .filter((l) => !scheduled.has(l.id))
      .sort((a, b) => (a.dayNumber ?? 0) - (b.dayNumber ?? 0))[0]
    if (!next) return 'allScheduled'
    const res = await axios.post(`/admin/api/enrollments/${enrollmentId}/schedules`, {
      lessonId: next.id,
    })
    if (res.data?.success === false) {
      throw new Error(res.data?.error ?? "Couldn't add the lesson")
    }
    await loadDetails(enrollmentId, false)
    return 'added'
  }

  async function deleteSchedule(enrollmentId: string, scheduleId: string): Promise<void> {
    await axios.delete(`/admin/api/enrollments/${enrollmentId}/schedules/${scheduleId}`)
    await loadDetails(enrollmentId, false)
  }

  async function saveScheduleTitle(
    enrollmentId: string,
    scheduleId: string,
    title: string
  ): Promise<void> {
    await axios.patch(`/admin/api/enrollments/${enrollmentId}/schedules/${scheduleId}`, {
      title,
    })
    const s = data.value?.schedules.find((x) => x.id === scheduleId)
    if (s) s.title = title
  }

  // ── Scheduled-activity CRUD (EditEnrollmentDay) ──
  async function addActivity(
    enrollmentId: string,
    scheduleId: string,
    type: string
  ): Promise<void> {
    const title = type.charAt(0) + type.slice(1).toLowerCase()
    await axios.post(
      `/admin/api/enrollments/${enrollmentId}/schedules/${scheduleId}/activities`,
      { type, title }
    )
    await loadDetails(enrollmentId, false)
  }

  async function deleteActivity(enrollmentId: string, activityId: string): Promise<void> {
    await axios.delete(`/admin/api/scheduled-activities/${activityId}`)
    await loadDetails(enrollmentId, false)
  }

  async function clearActivity(enrollmentId: string, activityId: string): Promise<void> {
    await axios.post(`/admin/api/scheduled-activities/${activityId}/reset`)
    await loadDetails(enrollmentId, false)
  }

  async function reorderActivities(
    enrollmentId: string,
    scheduleId: string,
    activityOrder: string[]
  ): Promise<void> {
    await axios.post(
      `/admin/api/enrollments/${enrollmentId}/schedules/${scheduleId}/reorder-activities`,
      { activityOrder }
    )
  }

  // ── Scheduled-activity CONTENT editors (iOS `.enrollment` action providers
  //    → EnrollmentActions → /api/scheduled-activities/…) ──

  function findActivityRow(activityId: string): {
    schedule: ScheduleEntry
    row: ScheduledActivityRow
  } | null {
    for (const s of data.value?.schedules ?? []) {
      const row = s.activities.find((a) => a.id === activityId)
      if (row) return { schedule: s, row }
    }
    return null
  }

  function applyActivityEcho(
    activityId: string,
    api?: unknown,
    patch?: (d: LeaderActivity) => LeaderActivity
  ): void {
    const found = findActivityRow(activityId)
    if (!found) return
    if (api && typeof api === 'object') {
      refreshRow(found.row, api as Record<string, unknown>)
      return
    }
    if (patch) {
      found.row.detail = patch(found.row.detail)
      refreshRow(found.row)
    }
  }

  /** PATCH /api/scheduled-activities/:id (title/help/youtube/video fields). */
  async function updateScheduledActivityFields(
    activityId: string,
    fields: Record<string, unknown>
  ): Promise<void> {
    const res = await axios.patch(`/admin/api/scheduled-activities/${activityId}`, fields)
    if (res.data?.success === false) {
      throw new Error(res.data?.error ?? 'Failed to update activity')
    }
    const api = res.data?.scheduledActivity
    if (api) applyActivityEcho(activityId, api)
    else applyActivityEcho(activityId, undefined, (d) => ({ ...d, ...fields }))
  }

  async function createScheduledReadBlock(
    activityId: string,
    fields: { title?: string; content?: string; isLocked: boolean; orderNumber?: number }
  ): Promise<void> {
    const res = await axios.post(
      `/admin/api/scheduled-activities/${activityId}/read-blocks`,
      fields
    )
    applyActivityEcho(activityId, res.data?.scheduledActivity)
  }

  async function updateScheduledReadBlock(
    activityId: string,
    blockId: string,
    fields: Record<string, unknown>
  ): Promise<void> {
    // Optimistic-first (iOS writes AppState before the PATCH) — selections,
    // themes and styles render instantly.
    applyActivityEcho(activityId, undefined, (d) => ({
      ...d,
      readBlocks: d.readBlocks.map((b) => (b.id === blockId ? { ...b, ...fields } : b)),
    }))
    const res = await axios.patch(
      `/admin/api/scheduled-activities/${activityId}/read-blocks/${blockId}`,
      fields
    )
    // This endpoint returns {success, block} only; remap if a full activity
    // ever comes back.
    applyActivityEcho(activityId, res.data?.scheduledActivity)
  }

  async function deleteScheduledReadBlock(activityId: string, blockId: string): Promise<void> {
    // 400s when deleting the LAST block (scheduled-only rule) — propagate so
    // the pane can show the server's message.
    const res = await axios.delete(
      `/admin/api/scheduled-activities/${activityId}/read-blocks/${blockId}`
    )
    const api = res.data?.scheduledActivity
    if (api) applyActivityEcho(activityId, api)
    else
      applyActivityEcho(activityId, undefined, (d) => ({
        ...d,
        readBlocks: d.readBlocks.filter((b) => b.id !== blockId),
      }))
  }

  async function reorderScheduledReadBlocks(
    activityId: string,
    blockIds: string[]
  ): Promise<void> {
    applyActivityEcho(activityId, undefined, (d) => ({
      ...d,
      readBlocks: blockIds
        .map((id, i) => {
          const b = d.readBlocks.find((x) => x.id === id)
          return b ? { ...b, orderNumber: i + 1 } : null
        })
        .filter((b): b is LeaderActivity['readBlocks'][number] => b !== null),
    }))
    const res = await axios.patch(
      `/admin/api/scheduled-activities/${activityId}/read-blocks/reorder`,
      { blockIds }
    )
    applyActivityEcho(activityId, res.data?.scheduledActivity)
  }

  async function addScheduledSourceReference(
    activityId: string,
    passage: LeaderPassage & { reference: string },
    content?: string | null
  ): Promise<void> {
    const body: Record<string, unknown> = {
      sourceType: 'BIBLE_PASSAGE',
      passageReference: passage.reference,
      bookNumber: passage.bookNumber,
      bookName: passage.bookName,
      chapterStart: passage.chapterStart,
      verseStart: passage.verseStart,
      verseEnd: passage.verseEnd,
    }
    if (passage.chapterEnd != null) body.chapterEnd = passage.chapterEnd
    if (content) body.content = content
    const res = await axios.post(
      `/admin/api/scheduled-activities/${activityId}/source-references`,
      body
    )
    if (!res.data?.success) throw new Error(res.data?.error ?? 'Failed to add passage')
    applyActivityEcho(activityId, res.data?.scheduledActivity)
  }

  async function fetchScheduledExegesisHighlights(
    activityId: string
  ): Promise<ExegesisHighlightData[]> {
    const res = await axios.get(
      `/admin/api/scheduled-activities/${activityId}/exegesis-highlights`
    )
    const raw: Array<{ id: string; start: number; end: number; noteMarkdown?: string | null }> =
      res.data?.highlights ?? []
    return raw.map((h) => ({
      id: h.id,
      start: h.start,
      end: h.end,
      noteMarkdown: h.noteMarkdown ?? '',
    }))
  }

  async function createScheduledExegesisHighlight(
    activityId: string,
    blockId: string,
    range: { start: number; end: number },
    noteMarkdown = ''
  ): Promise<ExegesisHighlightData | null> {
    const res = await axios.post(
      `/admin/api/scheduled-activities/${activityId}/exegesis-highlights`,
      { readBlockId: blockId, start: range.start, end: range.end, noteMarkdown }
    )
    const h = res.data?.highlight
    if (!res.data?.success || !h) return null
    // Mirror the server's selections re-sync locally — the created highlight
    // absorbs everything it overlapped (union span), so drop those runs.
    applyActivityEcho(activityId, undefined, (d) => ({
      ...d,
      readBlocks: d.readBlocks.map((b) =>
        b.id === blockId
          ? {
              ...b,
              selections: [
                ...b.selections.filter((s) => s.end <= h.start || s.start >= h.end),
                { start: h.start, end: h.end, style: 'highlight' },
              ],
            }
          : b
      ),
    }))
    return { id: h.id, start: h.start, end: h.end, noteMarkdown: h.noteMarkdown ?? '' }
  }

  async function updateScheduledExegesisHighlightNote(
    activityId: string,
    highlightId: string,
    noteMarkdown: string
  ): Promise<void> {
    await axios.patch(
      `/admin/api/scheduled-activities/${activityId}/exegesis-highlights/${highlightId}`,
      { noteMarkdown }
    )
  }

  async function deleteScheduledExegesisHighlight(
    activityId: string,
    blockId: string,
    highlight: { id: string; start: number; end: number }
  ): Promise<void> {
    await axios.delete(
      `/admin/api/scheduled-activities/${activityId}/exegesis-highlights/${highlight.id}`
    )
    applyActivityEcho(activityId, undefined, (d) => ({
      ...d,
      readBlocks: d.readBlocks.map((b) =>
        b.id === blockId
          ? {
              ...b,
              selections: b.selections.filter(
                (s) => !(s.start === highlight.start && s.end === highlight.end)
              ),
            }
          : b
      ),
    }))
  }

  /** iOS EnrollmentActions.updateScheduledActivityVideo — {videoId, videoUrl}
   *  ONLY (no status, unlike the program path). */
  async function updateScheduledActivityVideo(
    activityId: string,
    videoId: string,
    videoUrl: string | null
  ): Promise<void> {
    await updateScheduledActivityFields(activityId, { videoId, videoUrl })
  }

  async function removeScheduledActivityVideo(activityId: string): Promise<void> {
    await updateScheduledActivityFields(activityId, { videoId: null, videoUrl: null })
  }

  /** The `.enrollment` ActivityEditorActions variant for the shared READ /
   *  EXEGESIS editor panes (iOS ReadActivityActionProvider.enrollment /
   *  ExegesisActivityActionProvider.enrollment). updateLessonTitle is
   *  intentionally absent — iOS passes no onLessonTitleUpdate, so the
   *  set-titles modal's Lesson toggle silently no-ops. */
  function scheduledActivityActions(
    scheduleId: string,
    activityId: string
  ): ActivityEditorActions {
    const schedule = () => data.value?.schedules.find((s) => s.id === scheduleId)
    return {
      context: 'enrollment',
      supportsBlockStyling: false,
      updateActivity: (fields) => updateScheduledActivityFields(activityId, fields),
      createReadBlock: (fields) => createScheduledReadBlock(activityId, fields),
      updateReadBlock: (blockId, fields) =>
        updateScheduledReadBlock(activityId, blockId, fields),
      deleteReadBlock: (blockId) => deleteScheduledReadBlock(activityId, blockId),
      reorderReadBlocks: (blockIds) => reorderScheduledReadBlocks(activityId, blockIds),
      addSourceReference: (passage, content) =>
        addScheduledSourceReference(activityId, passage, content),
      fetchExegesisHighlights: () => fetchScheduledExegesisHighlights(activityId),
      createExegesisHighlight: (blockId, range, noteMarkdown) =>
        createScheduledExegesisHighlight(activityId, blockId, range, noteMarkdown),
      updateExegesisHighlightNote: (highlightId, noteMarkdown) =>
        updateScheduledExegesisHighlightNote(activityId, highlightId, noteMarkdown),
      deleteExegesisHighlight: (blockId, highlight) =>
        deleteScheduledExegesisHighlight(activityId, blockId, highlight),
      usedPassages: () =>
        (schedule()?.activities ?? []).flatMap((a) => a.detail.passages),
      lessonTitle: () => schedule()?.title || schedule()?.lessonTitle || 'Untitled lesson',
      lessonActivityCount: () => schedule()?.activities.length ?? 0,
    }
  }

  async function loadLessonInvite(scheduleId: string): Promise<string | null> {
    const res = await axios.get(`/admin/api/lesson-schedules/${scheduleId}/invite`)
    return res.data?.invite?.url ?? res.data?.invite?.inviteUrl ?? null
  }

  // ── Unenroll (UnenrollOptionsModal) ──
  async function loadUnenrollInfo(enrollmentId: string): Promise<{
    totalLessons: number
    lessonsWithData: number
    cleanLessons: number
    canFullyUnenroll: boolean
  }> {
    const res = await axios.get(`/admin/api/enrollments/${enrollmentId}/unenroll-info`)
    const d = res.data?.data
    if (!d) throw new Error(res.data?.error ?? 'Failed to load enrollment status')
    return {
      totalLessons: d.totalLessons ?? 0,
      lessonsWithData: d.lessonsWithData ?? 0,
      cleanLessons: d.cleanLessons ?? 0,
      canFullyUnenroll: Boolean(d.canFullyUnenroll),
    }
  }

  async function deleteEnrollment(enrollmentId: string): Promise<void> {
    await axios.delete(`/admin/api/enrollments/${enrollmentId}`)
  }

  async function cancelFutureLessons(enrollmentId: string): Promise<void> {
    await axios.post(`/admin/api/enrollments/${enrollmentId}/cancel-future`)
  }

  return {
    data,
    loading,
    error,
    statsLoaded,
    loadDetails,
    loadCompletionStats,
    scheduleRows,
    addScheduledLesson,
    deleteSchedule,
    saveScheduleTitle,
    addActivity,
    deleteActivity,
    clearActivity,
    reorderActivities,
    updateScheduledActivityFields,
    updateScheduledActivityVideo,
    removeScheduledActivityVideo,
    scheduledActivityActions,
    loadLessonInvite,
    loadUnenrollInfo,
    deleteEnrollment,
    cancelFutureLessons,
  }
})
