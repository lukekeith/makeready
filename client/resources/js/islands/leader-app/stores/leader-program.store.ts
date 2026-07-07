import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

// Program detail for the mobile leader app's Program Home modal (the iPhone
// ProgramHomePage), fetched through the shared /admin/api/* proxy. Mirrors the
// iPhone ProgramActions.getProgram(id:) loading:
//   GET /api/programs/:id?lessonLimit=60 → program + lessons (with activities)

export interface SaveProgramFields {
  name: string
  description: string
  isPublished: boolean
  tags: string[]
}

// POST /api/programs/:id/publish-updates → { alreadyUpToDate, version }
// (study-sync: version carries the Claude-generated change summary).
export interface PublishUpdatesResult {
  alreadyUpToDate: boolean
  version: { versionNumber: number; changeSummary: string | null } | null
}

// iOS ExportPreviewData (ProgramHomePage.swift) — parsed from
// GET /api/programs/:id/export-preview → preview.counts / activityTypes.
export interface ExportPreview {
  name: string
  days: number
  activities: number
  reads: number
  videos: number
  userInputs: number
  readBlocks: number
  scriptureRefs: number
  templateName: string
}

// Full activity fields the editors need; structurally compatible with the
// CardLessonActivity icon-box shape ({ activityType, status }).
export interface LeaderActivity {
  id: string
  activityType: string
  status: 'default' | 'incomplete' | 'complete'
  /** Raw server ActivityStatus (e.g. PENDING / COMPLETE) — iOS gates the
   *  swipe "reset" button on `status == .complete` (member participation). */
  rawStatus: string
  title: string
  placeholder: string
  isHelpEnabled: boolean
  helpTitle: string
  helpDescription: string
  youtubeUrl: string
  youtubeStartSeconds: number | null
  youtubeEndSeconds: number | null
  estimatedSeconds: number | null
  /** READ blocks, orderNumber-sorted (empty for other types). */
  readBlocks: LeaderReadBlock[]
  /** Bible passages this activity references (drives the passage picker's
   *  "already used" tinting — iOS AppState.passagesUsedIn). */
  passages: LeaderPassage[]
  /** Linked video relation (VIDEO activities; null otherwise). */
  video: {
    id: string
    title: string
    thumbnailUrl: string | null
    playbackUrl: string | null
    duration: number | null
    isReady: boolean
  } | null
}

export interface LeaderLesson {
  id: string
  day: number
  title?: string
  estimatedMinutes?: number
  activities: LeaderActivity[]
}

export interface LeaderProgramDetail {
  id: string
  name: string
  description: string
  coverImageUrl: string | null
  isPublished: boolean
  creatorId: string | null
  days: number
  tags: string[]
  lessons: LeaderLesson[]
}

/** iOS PassageData — the fields a source reference carries. */
export interface LeaderPassage {
  bookNumber: number
  bookName: string
  chapterStart: number
  chapterEnd: number | null
  verseStart: number
  verseEnd: number
}

interface ApiSourceReference {
  bookNumber?: number | null
  bookName?: string | null
  chapterStart?: number | null
  chapterEnd?: number | null
  verseStart?: number | null
  verseEnd?: number | null
}

function mapPassages(refs: unknown[] | undefined): LeaderPassage[] {
  return (refs ?? [])
    .map((r) => r as ApiSourceReference)
    .filter(
      (r) =>
        r.bookNumber != null && r.bookName != null && r.chapterStart != null && r.verseStart != null && r.verseEnd != null,
    )
    .map((r) => ({
      bookNumber: r.bookNumber as number,
      bookName: r.bookName as string,
      chapterStart: r.chapterStart as number,
      chapterEnd: r.chapterEnd ?? null,
      verseStart: r.verseStart as number,
      verseEnd: r.verseEnd as number,
    }))
}

interface ApiReadBlock {
  id?: string
  orderNumber?: number
  title?: string | null
  content?: string | null
  isLocked?: boolean
  sourceReferenceId?: string | null
  themeId?: string | null
  backgroundImageUrl?: string | null
  backgroundColor?: string | null
  backgroundOverlayOpacity?: number | null
  fontSize?: string | null
  selections?: Array<{ start: number; end: number; style: string }>
}

/** iOS ActivityReadBlock — the READ editor's block model. */
export interface LeaderReadBlock {
  id: string
  orderNumber: number
  title: string
  content: string
  isLocked: boolean
  sourceReferenceId: string | null
  themeId: string | null
  backgroundImageUrl: string | null
  backgroundColor: string | null
  backgroundOverlayOpacity: number | null
  /** xs/s/m/lg/xl; null == the "m" default (round-trips as null). */
  fontSize: string | null
  selections: Array<{ start: number; end: number; style: string }>
}

function mapReadBlock(b: ApiReadBlock, index: number): LeaderReadBlock {
  return {
    id: b.id ?? `block-${index}`,
    orderNumber: b.orderNumber ?? index + 1,
    title: b.title ?? '',
    content: b.content ?? '',
    isLocked: Boolean(b.isLocked),
    sourceReferenceId: b.sourceReferenceId ?? null,
    themeId: b.themeId ?? null,
    backgroundImageUrl: b.backgroundImageUrl ?? null,
    backgroundColor: b.backgroundColor ?? null,
    backgroundOverlayOpacity: b.backgroundOverlayOpacity ?? null,
    fontSize: b.fontSize ?? null,
    selections: b.selections ?? [],
  }
}

interface ApiActivity {
  id: string
  activityType?: string
  status?: string | null
  title?: string | null
  placeholder?: string | null
  isHelpEnabled?: boolean
  helpTitle?: string | null
  helpDescription?: string | null
  readContent?: string | null
  readBlocks?: ApiReadBlock[] | null
  passageReference?: string | null
  videoId?: string | null
  videoUrl?: string | null
  youtubeUrl?: string | null
  youtubeStartSeconds?: number | null
  youtubeEndSeconds?: number | null
  estimatedSeconds?: number | null
  sourceReferences?: unknown[]
  video?: {
    id: string
    title?: string | null
    thumbnailUrl?: string | null
    playbackUrl?: string | null
    duration?: number | null
    status?: string | null
  } | null
}

interface ApiLesson {
  id: string
  dayNumber: number
  title?: string | null
  estimatedMinutes?: number | null
  activities?: ApiActivity[]
}

// Exact port of iOS StudyActivity.isConfigured (Pages/Manage/Program/Models/
// StudyModels.swift) — the single source of truth for activity readiness on
// Program Home / EditDay. Configured → filled icon box; unconfigured → the
// brand-outlined box that drives the lesson's animated not-ready border.
function isConfigured(a: ApiActivity): boolean {
  const nonEmpty = (v?: string | null) => Boolean(v && v.length > 0)
  switch (a.activityType ?? 'READ') {
    case 'VIDEO':
      return nonEmpty(a.videoId) || nonEmpty(a.videoUrl)
    case 'YOUTUBE':
      return nonEmpty(a.youtubeUrl)
    case 'READ':
      // When the payload carries the block list (even empty), block content is
      // the only readiness signal; legacy readContent is only a fallback for
      // data that predates readBlocks.
      if (Array.isArray(a.readBlocks)) {
        return a.readBlocks.some((b) => nonEmpty(b.content))
      }
      return nonEmpty(a.readContent)
    case 'EXEGESIS': {
      if (!nonEmpty(a.title)) return false
      const locked = (a.readBlocks ?? []).find((b) => b.isLocked)
      if (!locked || !nonEmpty(locked.content)) return false
      // Highlights (block.selections) — like the iPhone, an exegesis without
      // highlights is not ready. (The program payload doesn't carry them yet,
      // so iOS renders the same "not ready" state from this endpoint.)
      return (locked.selections?.length ?? 0) > 0
    }
    case 'USER_INPUT':
      return nonEmpty(a.title)
    case 'SOAP':
    case 'OIA':
    case 'DBS':
    case 'HEAR':
      return nonEmpty(a.passageReference)
    default:
      return true
  }
}

function activityStatus(a: ApiActivity): 'default' | 'incomplete' | 'complete' {
  return isConfigured(a) ? 'complete' : 'incomplete'
}

function mapActivity(a: ApiActivity): LeaderActivity {
  return {
    id: a.id,
    activityType: a.activityType ?? 'READ',
    status: activityStatus(a),
    rawStatus: a.status ?? 'PENDING',
    title: a.title ?? '',
    placeholder: a.placeholder ?? '',
    isHelpEnabled: Boolean(a.isHelpEnabled),
    helpTitle: a.helpTitle ?? '',
    helpDescription: a.helpDescription ?? '',
    youtubeUrl: a.youtubeUrl ?? '',
    youtubeStartSeconds: a.youtubeStartSeconds ?? null,
    youtubeEndSeconds: a.youtubeEndSeconds ?? null,
    estimatedSeconds: a.estimatedSeconds ?? null,
    readBlocks: (a.readBlocks ?? [])
      .map(mapReadBlock)
      .sort((x, y) => x.orderNumber - y.orderNumber),
    passages: mapPassages(a.sourceReferences),
    video: a.video
      ? {
          id: a.video.id,
          title: a.video.title ?? 'Untitled Video',
          thumbnailUrl: a.video.thumbnailUrl ?? null,
          playbackUrl: a.video.playbackUrl ?? null,
          duration: a.video.duration ?? null,
          isReady: (a.video.status ?? '') === 'ready',
        }
      : null,
  }
}

function mapLesson(l: ApiLesson): LeaderLesson {
  return {
    id: l.id,
    day: l.dayNumber,
    title: l.title ?? undefined,
    estimatedMinutes: l.estimatedMinutes ?? 0,
    activities: (l.activities ?? []).map(mapActivity),
  }
}

export const useLeaderProgram = defineStore('leader-program', () => {
  const program = ref<LeaderProgramDetail | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  function message(err: unknown, fallback: string): string {
    const e = err as { response?: { data?: { error?: string; message?: string } } }
    return e?.response?.data?.error ?? e?.response?.data?.message ?? fallback
  }

  async function loadProgram(id: string): Promise<void> {
    // Fresh modal → fresh load (the modal remounts per presentation).
    program.value = null
    loading.value = true
    error.value = null
    try {
      const res = await axios.get(`/admin/api/programs/${id}`, {
        params: { lessonLimit: 60 },
      })
      const p = res.data.program
      if (!p) throw new Error(res.data?.error ?? 'Program not found')
      const lessons: ApiLesson[] = p.lessons ?? []
      program.value = {
        id: p.id,
        name: p.name ?? '',
        description: p.description ?? '',
        coverImageUrl: p.coverImageUrl ?? null,
        isPublished: Boolean(p.isPublished),
        creatorId: p.creatorId ?? null,
        days: p.days ?? 0,
        tags: p.tags ?? [],
        lessons: lessons
          .slice()
          .sort((a, b) => a.dayNumber - b.dayNumber)
          .map(mapLesson),
      }
    } catch (err) {
      error.value = message(err, 'Failed to load program')
    } finally {
      loading.value = false
    }
  }

  // ── Settings (Edit Program pane) — mirrors iPhone saveProgram(): optimistic
  //    upsert, PATCH, then tag diff sync; revert on failure. ──

  async function saveProgram(id: string, fields: SaveProgramFields): Promise<void> {
    const previous = program.value
    if (program.value?.id === id) {
      program.value = {
        ...program.value,
        name: fields.name,
        description: fields.description,
        isPublished: fields.isPublished,
        tags: fields.tags,
      }
    }
    try {
      await axios.patch(`/admin/api/programs/${id}`, {
        name: fields.name,
        description: fields.description,
        isPublished: fields.isPublished,
      })
      const oldTags = (previous?.tags ?? []).map((t) => t.toLowerCase())
      const newTags = fields.tags.map((t) => t.toLowerCase())
      const added = newTags.filter((t) => !oldTags.includes(t))
      const removed = oldTags.filter((t) => !newTags.includes(t))
      if (added.length) await axios.post(`/admin/api/programs/${id}/tags`, { tags: added })
      if (removed.length) await axios.delete(`/admin/api/programs/${id}/tags`, { data: { tags: removed } })
    } catch (err) {
      program.value = previous
      throw new Error(message(err, 'Failed to save program'))
    }
  }

  // Cover upload — the server takes a base64 data URL (POST …/cover-image
  // { imageData, contentType }) and returns the stored coverImageUrl.
  async function uploadCover(id: string, dataUrl: string, contentType: string): Promise<void> {
    const res = await axios.post(`/admin/api/programs/${id}/cover-image`, {
      imageData: dataUrl,
      contentType,
    })
    const url: string | undefined = res.data?.coverImageUrl
    if (!url) throw new Error(res.data?.error ?? 'Failed to upload cover image')
    if (program.value?.id === id) {
      program.value = { ...program.value, coverImageUrl: url }
    }
  }

  // ── Lessons + activities (EditDay pane) — mirror ProgramActions+Lessons /
  //    +Activities: mutate the server, then update the loaded program in place. ──

  async function addLesson(programId: string): Promise<void> {
    const res = await axios.post(`/admin/api/programs/${programId}/lessons`, {})
    const lesson = res.data?.lesson
    if (!lesson) throw new Error(res.data?.error ?? 'Failed to add lesson')
    if (program.value?.id === programId) {
      const lessons = [...program.value.lessons, mapLesson(lesson)]
      lessons.sort((a, b) => a.day - b.day)
      program.value = { ...program.value, lessons }
    }
  }

  async function updateLessonTitle(programId: string, lessonId: string, title: string): Promise<void> {
    await axios.patch(`/admin/api/programs/${programId}/lessons/${lessonId}`, {
      title: title || null,
    })
    patchLesson(lessonId, (l) => ({ ...l, title: title || undefined }))
  }

  async function addActivity(programId: string, lessonId: string, type: string): Promise<void> {
    // Content types need a starter title (USER_INPUT / YOUTUBE may be untitled).
    const title =
      type === 'USER_INPUT' || type === 'YOUTUBE' ? undefined : 'New activity'
    const res = await axios.post(
      `/admin/api/programs/${programId}/lessons/${lessonId}/activities`,
      { activityType: type, ...(title ? { title } : {}) },
    )
    const activity = res.data?.activity
    if (!activity) throw new Error(res.data?.error ?? 'Failed to add activity')
    patchLesson(lessonId, (l) => ({ ...l, activities: [...l.activities, mapActivity(activity)] }))
  }

  async function updateActivity(
    lessonId: string,
    activityId: string,
    fields: Record<string, unknown>,
  ): Promise<void> {
    const res = await axios.patch(`/admin/api/activities/${activityId}`, fields)
    const activity = res.data?.activity
    patchLesson(lessonId, (l) => ({
      ...l,
      activities: l.activities.map((a) =>
        a.id === activityId ? (activity ? mapActivity(activity) : { ...a, ...fields }) : a,
      ),
    }))
  }

  // ── READ blocks (iOS ProgramActions+Activities read-block methods) ──
  //
  // Server returns the updated activity on delete/reorder (and usually on
  // create/update); when present we remap it wholesale, otherwise we patch
  // the one block locally (iOS optimistic-write pattern).

  function replaceActivity(lessonId: string, activity: ApiActivity | undefined, activityId: string, patch?: (a: LeaderActivity) => LeaderActivity): void {
    patchLesson(lessonId, (l) => ({
      ...l,
      activities: l.activities.map((a) => {
        if (a.id !== activityId) return a
        if (activity) return mapActivity(activity)
        return patch ? patch(a) : a
      }),
    }))
  }

  async function createReadBlock(
    lessonId: string,
    activityId: string,
    fields: { title?: string; content?: string; isLocked: boolean; orderNumber?: number },
  ): Promise<void> {
    const res = await axios.post(`/admin/api/activities/${activityId}/read-blocks`, fields)
    replaceActivity(lessonId, res.data?.activity, activityId)
  }

  async function updateReadBlock(
    lessonId: string,
    activityId: string,
    blockId: string,
    fields: Record<string, unknown>,
  ): Promise<void> {
    // iOS writes style/selection changes into AppState BEFORE the PATCH
    // (optimistic) — mirror that so highlights/themes render instantly.
    replaceActivity(lessonId, undefined, activityId, (a) => ({
      ...a,
      readBlocks: a.readBlocks.map((b) => (b.id === blockId ? { ...b, ...fields } : b)),
    }))
    const res = await axios.patch(
      `/admin/api/activities/${activityId}/read-blocks/${blockId}`,
      fields,
    )
    // Server usually returns {success, block}; remap only if it sent the
    // full activity back.
    replaceActivity(lessonId, res.data?.activity, activityId)
  }

  async function deleteReadBlock(
    lessonId: string,
    activityId: string,
    blockId: string,
  ): Promise<void> {
    const res = await axios.delete(`/admin/api/activities/${activityId}/read-blocks/${blockId}`)
    replaceActivity(lessonId, res.data?.activity, activityId, (a) => ({
      ...a,
      readBlocks: a.readBlocks.filter((b) => b.id !== blockId),
    }))
  }

  async function reorderReadBlocks(
    lessonId: string,
    activityId: string,
    blockIds: string[],
  ): Promise<void> {
    // iOS renumbers optimistically then persists.
    replaceActivity(lessonId, undefined, activityId, (a) => ({
      ...a,
      readBlocks: blockIds
        .map((id, i) => {
          const b = a.readBlocks.find((x) => x.id === id)
          return b ? { ...b, orderNumber: i + 1 } : null
        })
        .filter((b): b is LeaderReadBlock => b !== null),
    }))
    const res = await axios.patch(`/admin/api/activities/${activityId}/read-blocks/reorder`, {
      blockIds,
    })
    replaceActivity(lessonId, res.data?.activity, activityId)
  }

  // iOS ProgramActions.addSourceReference — POST creates the source reference
  // AND a locked read block server-side (orderNumber 1, existing blocks shift
  // +1), returning the full updated activity.
  async function addSourceReference(
    lessonId: string,
    activityId: string,
    passage: LeaderPassage & { reference: string },
    content?: string | null,
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
    const res = await axios.post(`/admin/api/activities/${activityId}/source-references`, body)
    if (!res.data?.success) throw new Error(res.data?.error ?? 'Failed to add passage')
    replaceActivity(lessonId, res.data?.activity, activityId)
  }

  // ── EXEGESIS highlights (iOS ProgramActions+Activities exegesis methods) ──
  // Highlight geometry lives in its own table; the server re-syncs the locked
  // block's `selections` ({start,end,style:'highlight'}) after every
  // create/delete, so we refresh the block locally the same way.

  async function fetchExegesisHighlights(
    activityId: string,
  ): Promise<Array<{ id: string; start: number; end: number; noteMarkdown: string }>> {
    const res = await axios.get(`/admin/api/activities/${activityId}/exegesis-highlights`)
    const raw: Array<{ id: string; start: number; end: number; noteMarkdown?: string | null }> =
      res.data?.highlights ?? []
    return raw.map((h) => ({ id: h.id, start: h.start, end: h.end, noteMarkdown: h.noteMarkdown ?? '' }))
  }

  async function createExegesisHighlight(
    lessonId: string,
    activityId: string,
    blockId: string,
    range: { start: number; end: number },
    noteMarkdown = '',
  ): Promise<{ id: string; start: number; end: number; noteMarkdown: string } | null> {
    const res = await axios.post(`/admin/api/activities/${activityId}/exegesis-highlights`, {
      readBlockId: blockId,
      start: range.start,
      end: range.end,
      noteMarkdown,
    })
    const h = res.data?.highlight
    if (!res.data?.success || !h) return null
    // Mirror the server's selections sync locally (style:'highlight').
    replaceActivity(lessonId, undefined, activityId, (a) => ({
      ...a,
      readBlocks: a.readBlocks.map((b) =>
        b.id === blockId
          ? {
              ...b,
              selections: [...b.selections, { start: range.start, end: range.end, style: 'highlight' }],
            }
          : b,
      ),
    }))
    return { id: h.id, start: h.start, end: h.end, noteMarkdown: h.noteMarkdown ?? '' }
  }

  async function updateExegesisHighlightNote(
    activityId: string,
    highlightId: string,
    noteMarkdown: string,
  ): Promise<void> {
    await axios.patch(`/admin/api/activities/${activityId}/exegesis-highlights/${highlightId}`, {
      noteMarkdown,
    })
  }

  async function deleteExegesisHighlight(
    lessonId: string,
    activityId: string,
    blockId: string,
    highlight: { id: string; start: number; end: number },
  ): Promise<void> {
    await axios.delete(`/admin/api/activities/${activityId}/exegesis-highlights/${highlight.id}`)
    replaceActivity(lessonId, undefined, activityId, (a) => ({
      ...a,
      readBlocks: a.readBlocks.map((b) =>
        b.id === blockId
          ? {
              ...b,
              selections: b.selections.filter(
                (s) => !(s.start === highlight.start && s.end === highlight.end),
              ),
            }
          : b,
      ),
    }))
  }

  // ── VIDEO activities (iOS ProgramActions.updateActivityVideo / remove) ──

  /** GET /api/videos/me — the leader's uploaded videos (isActive only). */
  async function loadMyVideos(): Promise<
    Array<{ id: string; title: string; thumbnailUrl: string | null; playbackUrl: string | null; duration: number | null; isReady: boolean }>
  > {
    const res = await axios.get('/admin/api/videos/me')
    const raw: Array<{ id: string; title?: string | null; thumbnailUrl?: string | null; playbackUrl?: string | null; duration?: number | null; status?: string | null }> =
      res.data?.data ?? []
    return raw.map((v) => ({
      id: v.id,
      title: v.title ?? 'Untitled Video',
      thumbnailUrl: v.thumbnailUrl ?? null,
      playbackUrl: v.playbackUrl ?? null,
      duration: v.duration ?? null,
      isReady: (v.status ?? '') === 'ready',
    }))
  }

  /** iOS updateActivityVideo — link a library video to the activity. */
  async function updateActivityVideo(
    lessonId: string,
    activityId: string,
    videoId: string,
    videoUrl: string | null,
  ): Promise<void> {
    await updateActivity(lessonId, activityId, {
      videoId,
      videoUrl,
      status: 'COMPLETE',
    })
  }

  /** iOS removeActivityVideo — PATCH nulls + status PENDING. */
  async function removeActivityVideo(lessonId: string, activityId: string): Promise<void> {
    await updateActivity(lessonId, activityId, {
      videoId: null,
      videoUrl: null,
      status: 'PENDING',
    })
  }

  // ── Program enrollments (iOS getProgramEnrollments, Enrollments tab) ──
  //
  // GET /api/programs/:id/enrollments → { enrollments } ordered startDate
  // desc. dateRange mirrors iOS ModelFormatters.monthDay ("MMM d".uppercased,
  // LOCAL tz): "JAN 1 - FEB 1"; a missing end date shows the start only.

  function enrollmentDateRange(startIso?: string | null, endIso?: string | null): string {
    const fmt = (iso: string) =>
      new Date(iso)
        .toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        .toUpperCase()
    if (!startIso) return ''
    return endIso ? `${fmt(startIso)} - ${fmt(endIso)}` : fmt(startIso)
  }

  async function loadProgramEnrollments(programId: string): Promise<
    Array<{ id: string; name: string; subtitle?: string; imageUrl?: string; dateRange: string }>
  > {
    const res = await axios.get(`/admin/api/programs/${programId}/enrollments`)
    const raw: Array<{
      id: string
      startDate?: string | null
      endDate?: string | null
      group?: {
        name?: string | null
        coverImageUrl?: string | null
        creator?: { name?: string | null } | null
      } | null
    }> = res.data?.enrollments ?? []
    return raw.map((e) => ({
      id: e.id,
      name: e.group?.name ?? 'Unknown Group',
      subtitle: e.group?.creator?.name ?? undefined,
      imageUrl: e.group?.coverImageUrl ?? undefined,
      dateRange: enrollmentDateRange(e.startDate, e.endDate),
    }))
  }

  // GET /api/themes — loaded once (iOS AppState.textThemes at startup).
  let themesCache: Array<{ id: string; name: string; slug: string; description?: string }> | null =
    null
  async function loadThemes(): Promise<NonNullable<typeof themesCache>> {
    if (themesCache) return themesCache
    const res = await axios.get('/admin/api/themes')
    themesCache = (res.data?.themes ?? []) as NonNullable<typeof themesCache>
    return themesCache
  }

  // ── Create Program (iOS ProgramActions.createProgram) ──

  // Templates for the create form's "Lesson template" picker (iOS
  // loadTemplates → orderedTemplates: sorted alphabetically by name).
  async function loadTemplates(): Promise<Array<{ id: string; name: string }>> {
    const res = await axios.get('/admin/api/templates')
    const templates: Array<{ id: string; name?: string | null }> = res.data?.templates ?? []
    return templates
      .map((t) => ({ id: t.id, name: t.name ?? '' }))
      .sort((a, b) => a.name.localeCompare(b.name))
  }

  // POST /api/programs — the response already contains the fully-built program
  // (lessons auto-created from the template, activities copied per lesson), so
  // we seed the store directly and Program Home renders with no extra fetch.
  async function createProgram(fields: {
    name: string
    templateId: string
    days: number
    isPublished: boolean
    description?: string
  }): Promise<string> {
    const body: Record<string, unknown> = {
      name: fields.name,
      templateId: fields.templateId,
      days: fields.days,
      isPublished: fields.isPublished,
    }
    if (fields.description) body.description = fields.description
    const res = await axios.post('/admin/api/programs', body)
    const p = res.data?.program
    if (!res.data?.success || !p) {
      throw new Error(message({ response: { data: res.data } }, 'Failed to create program'))
    }
    const lessons: ApiLesson[] = p.lessons ?? []
    program.value = {
      id: p.id,
      name: p.name ?? '',
      description: p.description ?? '',
      coverImageUrl: p.coverImageUrl ?? null,
      isPublished: Boolean(p.isPublished),
      creatorId: p.creatorId ?? null,
      days: p.days ?? 0,
      tags: p.tags ?? [],
      lessons: lessons
        .slice()
        .sort((a, b) => a.dayNumber - b.dayNumber)
        .map(mapLesson),
    }
    return p.id as string
  }

  // Best-effort tag sync after create (iOS: try? addTags — failure is silent).
  async function addTags(programId: string, tags: string[]): Promise<void> {
    if (!tags.length) return
    try {
      await axios.post(`/admin/api/programs/${programId}/tags`, { tags })
      if (program.value?.id === programId) {
        program.value = { ...program.value, tags }
      }
    } catch {
      // iOS swallows tag-sync failures on create.
    }
  }

  // ── Publish toggle (iOS togglePublishStatus) — optimistic flip, PATCH
  //    { isPublished }, revert on failure. The zero-activity publish gate is
  //    the CALLER's job (iOS checks lessonsWithoutActivities before calling). ──
  async function setPublished(id: string, publish: boolean): Promise<void> {
    const previous = program.value
    if (program.value?.id === id) {
      program.value = { ...program.value, isPublished: publish }
    }
    try {
      await axios.patch(`/admin/api/programs/${id}`, { isPublished: publish })
    } catch (err) {
      program.value = previous
      throw new Error(
        message(err, publish ? "Couldn't publish the study" : "Couldn't unpublish the study"),
      )
    }
  }

  // ── Publish updates (study-sync phase 6) — cut a new StudyProgramVersion
  //    from the current curriculum. AUTO enrollments apply it via the server
  //    fan-out; APPROVAL/OFF enrollments get a notification. A no-change
  //    publish returns alreadyUpToDate without cutting a version. ──
  async function publishUpdates(id: string): Promise<PublishUpdatesResult> {
    try {
      const res = await axios.post(`/admin/api/programs/${id}/publish-updates`)
      return {
        alreadyUpToDate: Boolean(res.data?.alreadyUpToDate),
        version: res.data?.version ?? null,
      }
    } catch (err) {
      throw new Error(message(err, "Couldn't publish updates"))
    }
  }

  // ── Export (iOS loadExportPreview + exportProgramData) ──

  async function loadExportPreview(id: string): Promise<ExportPreview> {
    const res = await axios.get(`/admin/api/programs/${id}/export-preview`)
    const preview = res.data?.preview
    if (!preview) throw new Error(res.data?.error ?? 'Failed to load export preview')
    const counts = preview.counts ?? {}
    const types = counts.activityTypes ?? {}
    return {
      name: preview.name ?? 'Program',
      days: counts.lessons ?? 0,
      activities: counts.activities ?? 0,
      reads: types.READ ?? 0,
      videos: types.VIDEO ?? 0,
      userInputs: types.USER_INPUT ?? 0,
      readBlocks: counts.readBlocks ?? 0,
      scriptureRefs: counts.scriptureReferences ?? 0,
      templateName: preview.template?.name ?? '',
    }
  }

  // POST …/export returns the binary .makeready ZIP — the Laravel proxy
  // special-cases '/export' POSTs and streams it through with the upstream
  // Content-Type/Content-Disposition preserved.
  async function exportProgram(id: string): Promise<{ blob: Blob; filename: string }> {
    const res = await axios.post(`/admin/api/programs/${id}/export`, null, {
      responseType: 'blob',
    })
    const disposition: string = res.headers?.['content-disposition'] ?? ''
    const match = /filename="?([^";]+)"?/.exec(disposition)
    const fallback = `${program.value?.name ?? 'program'}.makeready`
    return { blob: res.data as Blob, filename: match?.[1] ?? fallback }
  }

  // ── Swipe/drag mutations (iOS SwipeableCard + Dragula flows) ──

  // iOS ProgramActions+Lessons.deleteLesson: server removes the lesson and
  // renumbers the rest; mirror locally (400 "Cannot delete the last lesson"
  // when it's the only one — surfaced to the caller).
  async function deleteLesson(programId: string, lessonId: string): Promise<void> {
    try {
      await axios.delete(`/admin/api/programs/${programId}/lessons/${lessonId}`)
    } catch (err) {
      throw new Error(message(err, 'Failed to delete lesson'))
    }
    if (program.value?.id === programId) {
      const lessons = program.value.lessons
        .filter((l) => l.id !== lessonId)
        .map((l, i) => ({ ...l, day: i + 1 }))
      program.value = { ...program.value, lessons, days: lessons.length }
    }
  }

  // iOS persistLessonOrder: optimistic local reorder, then POST; reload to
  // restore the server's order on failure.
  async function reorderLessons(programId: string, lessonIds: string[]): Promise<void> {
    if (program.value?.id === programId) {
      const byId = new Map(program.value.lessons.map((l) => [l.id, l]))
      const lessons = lessonIds
        .map((id) => byId.get(id))
        .filter((l): l is LeaderLesson => Boolean(l))
        .map((l, i) => ({ ...l, day: i + 1 }))
      program.value = { ...program.value, lessons }
    }
    try {
      await axios.post(`/admin/api/programs/${programId}/reorder-lessons`, {
        lessonOrder: lessonIds,
      })
    } catch (err) {
      await loadProgram(programId)
      throw new Error(message(err, 'Failed to reorder lessons'))
    }
  }

  async function deleteActivity(lessonId: string, activityId: string): Promise<void> {
    try {
      await axios.delete(`/admin/api/activities/${activityId}`)
    } catch (err) {
      throw new Error(message(err, 'Failed to delete activity'))
    }
    patchLesson(lessonId, (l) => ({
      ...l,
      activities: l.activities.filter((a) => a.id !== activityId),
    }))
  }

  // iOS resetActivity — also backs the "Clear" swipe action (both hit the
  // same reset endpoint; see EditDay.clearActivity).
  async function resetActivity(lessonId: string, activityId: string): Promise<void> {
    let activity: ApiActivity | undefined
    try {
      const res = await axios.post(`/admin/api/activities/${activityId}/reset`)
      activity = res.data?.activity
    } catch (err) {
      throw new Error(message(err, 'Failed to reset activity'))
    }
    if (activity) {
      const mapped = mapActivity(activity)
      patchLesson(lessonId, (l) => ({
        ...l,
        activities: l.activities.map((a) => (a.id === activityId ? mapped : a)),
      }))
    }
  }

  // iOS persistActivityOrder: optimistic reorder, then POST.
  async function reorderActivities(
    programId: string,
    lessonId: string,
    activityIds: string[],
  ): Promise<void> {
    patchLesson(lessonId, (l) => {
      const byId = new Map(l.activities.map((a) => [a.id, a]))
      return {
        ...l,
        activities: activityIds
          .map((id) => byId.get(id))
          .filter((a): a is LeaderActivity => Boolean(a)),
      }
    })
    try {
      await axios.post(
        `/admin/api/programs/${programId}/lessons/${lessonId}/reorder-activities`,
        { activityOrder: activityIds },
      )
    } catch (err) {
      await loadProgram(programId)
      throw new Error(message(err, 'Failed to reorder activities'))
    }
  }

  // YouTube title lookup (iOS fetchYouTubeMetadataTitle).
  async function fetchYoutubeTitle(url: string): Promise<string | null> {
    try {
      const res = await axios.post('/admin/api/youtube/metadata', { url })
      return res.data?.title ?? res.data?.metadata?.title ?? null
    } catch {
      return null
    }
  }

  function patchLesson(lessonId: string, patch: (l: LeaderLesson) => LeaderLesson): void {
    if (!program.value) return
    program.value = {
      ...program.value,
      lessons: program.value.lessons.map((l) => (l.id === lessonId ? patch(l) : l)),
    }
  }

  return {
    program,
    loading,
    error,
    loadProgram,
    saveProgram,
    uploadCover,
    loadTemplates,
    createProgram,
    addTags,
    setPublished,
    publishUpdates,
    loadExportPreview,
    exportProgram,
    addLesson,
    updateLessonTitle,
    addActivity,
    updateActivity,
    deleteLesson,
    reorderLessons,
    deleteActivity,
    resetActivity,
    reorderActivities,
    fetchYoutubeTitle,
    createReadBlock,
    updateReadBlock,
    addSourceReference,
    fetchExegesisHighlights,
    createExegesisHighlight,
    updateExegesisHighlightNote,
    deleteExegesisHighlight,
    deleteReadBlock,
    reorderReadBlocks,
    loadThemes,
    loadMyVideos,
    updateActivityVideo,
    removeActivityVideo,
    loadProgramEnrollments,
  }
})
