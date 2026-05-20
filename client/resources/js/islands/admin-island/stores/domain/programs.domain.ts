import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import JSZip from 'jszip'

export interface Lesson {
  id: string
  dayNumber: number
  title: string
  programId: string
  activities?: Activity[]
}

export interface ActivitySourceReference {
  id: string
  lessonActivityId?: string
  sourceType?: string
  passageReference?: string
  bookNumber?: number
  bookName?: string
  chapterStart?: number
  chapterEnd?: number
  verseStart?: number
  verseEnd?: number
  createdAt?: string
  updatedAt?: string
}

export interface ActivityReadBlock {
  id: string
  lessonActivityId?: string
  orderNumber: number
  title?: string
  content?: string
  isLocked: boolean
  sourceReferenceId?: string
  createdAt?: string
  updatedAt?: string
}

export interface Activity {
  id: string
  lessonId?: string
  activityType: string
  status: string
  orderNumber: number
  title?: string
  isHelpEnabled?: boolean
  helpTitle?: string
  helpDescription?: string
  helpIcon?: string
  readContent?: string
  sourceReferences?: ActivitySourceReference[]
  readBlocks?: ActivityReadBlock[]
  videoId?: string
  videoUrl?: string
  youtubeUrl?: string
  youtubeVideoId?: string
  youtubeStartSeconds?: number | null
  youtubeEndSeconds?: number | null
  youtubeThumbnailUrl?: string
  passageReference?: string
  createdAt?: string
  updatedAt?: string
}

export interface UpdateActivityPayload {
  title?: string
  readContent?: string
  isHelpEnabled?: boolean
  helpTitle?: string
  helpDescription?: string
  helpIcon?: string
  videoId?: string
  videoUrl?: string
  passageReference?: string
  bookNumber?: number
  bookName?: string
  chapterStart?: number
  verseStart?: number
  verseEnd?: number
}

export interface Program {
  id: string
  name: string
  description?: string
  coverImageUrl?: string
  isPublished: boolean
  days?: number
  lessons?: Lesson[]
  _count?: { enrollments: number }
}

export interface Template {
  id: string
  name: string
}

export interface CreateProgramPayload {
  name: string
  templateId: string
  days: number
  description?: string
  isPublished?: boolean
}

export interface UpdateProgramPayload {
  name?: string
  description?: string
  isPublished?: boolean
  days?: number
  coverImageUrl?: string
}

export interface ExportPreviewData {
  name: string
  days: number
  activities: number
  reads: number
  videos: number
  userInputs: number
  readBlocks: number
  scriptureRefs: number
  templateName?: string
}

export interface ImportResult {
  program: Program
  warnings: string[]
}

export const ACTIVITY_TYPE_LABELS: Record<string, string> = {
  'SOAP': 'SOAP',
  'OIA': 'OIA',
  'DBS': 'DBS',
  'HEAR': 'HEAR',
  'VIDEO': 'Video',
  'YOUTUBE': 'YouTube',
  'USER_INPUT': 'Study',
  'READ': 'Read',
  'EXEGESIS': 'Exegesis',
}

export const useProgramsDomain = defineStore('programs-domain', () => {
  const programs = ref<Program[]>([])
  const templates = ref<Template[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadPrograms(): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      const res = await axios.get('/admin/api/programs')
      programs.value = res.data.programs ?? []
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load programs'
    } finally {
      isLoading.value = false
    }
  }

  async function loadTemplates(): Promise<void> {
    if (templates.value.length > 0) return
    error.value = null
    try {
      const res = await axios.get('/admin/api/templates')
      templates.value = res.data.templates ?? []
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load templates'
    }
  }

  async function getProgram(id: string): Promise<void> {
    error.value = null
    try {
      const res = await axios.get(`/admin/api/programs/${id}?lessonPage=1&lessonLimit=30`)
      const fetched: Program = res.data.program
      const idx = programs.value.findIndex((p) => p.id === id)
      if (idx !== -1) {
        programs.value.splice(idx, 1, fetched)
      } else {
        programs.value.push(fetched)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load program'
    }
  }

  async function createProgram(payload: CreateProgramPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.post('/admin/api/programs', payload)
      programs.value.push(res.data.program)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to create program'
      throw err
    }
  }

  async function updateProgram(id: string, payload: UpdateProgramPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.patch(`/admin/api/programs/${id}`, payload)
      const updated: Program = res.data.program
      const idx = programs.value.findIndex((p) => p.id === id)
      if (idx !== -1) {
        programs.value.splice(idx, 1, updated)
      } else {
        programs.value.push(updated)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to update program'
      throw err
    }
  }

  async function deleteProgram(id: string): Promise<void> {
    error.value = null
    try {
      await axios.delete(`/admin/api/programs/${id}`)
      programs.value = programs.value.filter((p) => p.id !== id)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete program'
      throw err
    }
  }

  async function uploadCoverImage(id: string, file: File): Promise<void> {
    error.value = null
    try {
      const formData = new FormData()
      formData.append('image', file)
      const res = await axios.post(`/admin/api/programs/${id}/cover-image`, formData)
      const coverImageUrl: string = res.data.coverImageUrl
      const idx = programs.value.findIndex((p) => p.id === id)
      if (idx !== -1) {
        programs.value.splice(idx, 1, { ...programs.value[idx], coverImageUrl })
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to upload cover image'
      throw err
    }
  }

  async function addLesson(programId: string): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(`/admin/api/programs/${programId}/lessons`, {})
      const newLesson: Lesson = res.data.lesson
      const program = programs.value.find((p) => p.id === programId)
      if (program) {
        if (!program.lessons) program.lessons = []
        program.lessons.push(newLesson)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to add lesson'
      throw err
    }
  }

  async function updateLessonTitle(
    programId: string,
    lessonId: string,
    title: string
  ): Promise<void> {
    error.value = null
    try {
      await axios.patch(`/admin/api/programs/${programId}/lessons/${lessonId}`, { title })
      const program = programs.value.find((p) => p.id === programId)
      if (program?.lessons) {
        const lesson = program.lessons.find((l) => l.id === lessonId)
        if (lesson) lesson.title = title
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to update lesson title'
      throw err
    }
  }

  async function deleteLesson(programId: string, lessonId: string): Promise<void> {
    error.value = null
    try {
      await axios.delete(`/admin/api/programs/${programId}/lessons/${lessonId}`)
      await getProgram(programId)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete lesson'
      throw err
    }
  }

  async function reorderLessons(programId: string, lessonIds: string[]): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(`/admin/api/programs/${programId}/reorder-lessons`, {
        lessonOrder: lessonIds,
      })
      const updated: Program = res.data.program
      const idx = programs.value.findIndex((p) => p.id === programId)
      if (idx !== -1) {
        programs.value.splice(idx, 1, updated)
      } else {
        programs.value.push(updated)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to reorder lessons'
      throw err
    }
  }

  // Helper to replace an activity in local state by id
  function replaceActivity(programId: string, lessonId: string, activityId: string, updated: Activity): void {
    const program = programs.value.find((p) => p.id === programId)
    const lesson = program?.lessons?.find((l) => l.id === lessonId)
    if (lesson?.activities) {
      const idx = lesson.activities.findIndex((a) => a.id === activityId)
      if (idx !== -1) lesson.activities.splice(idx, 1, updated)
    }
  }

  // Source: ProgramActions.swift lines 453-475 (addActivity)
  async function addActivity(
    programId: string,
    lessonId: string,
    activityType: string,
    title: string
  ): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(
        `/admin/api/programs/${programId}/lessons/${lessonId}/activities`,
        { activityType, title }
      )
      const newActivity: Activity = res.data.activity
      const program = programs.value.find((p) => p.id === programId)
      const lesson = program?.lessons?.find((l) => l.id === lessonId)
      if (lesson) {
        if (!lesson.activities) lesson.activities = []
        lesson.activities.push(newActivity)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to add activity'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 527-561 (updateActivityContent)
  // CRITICAL: always send status: "COMPLETE" unconditionally
  async function updateActivity(
    activityId: string,
    programId: string,
    lessonId: string,
    payload: UpdateActivityPayload
  ): Promise<void> {
    error.value = null
    try {
      const res = await axios.patch(`/admin/api/activities/${activityId}`, {
        ...payload,
        status: 'COMPLETE',
      })
      const updated: Activity = res.data.activity
      replaceActivity(programId, lessonId, activityId, updated)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to update activity'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 509-523 (deleteActivity)
  async function deleteActivity(
    activityId: string,
    programId: string,
    lessonId: string
  ): Promise<void> {
    error.value = null
    try {
      await axios.delete(`/admin/api/activities/${activityId}`)
      const program = programs.value.find((p) => p.id === programId)
      const lesson = program?.lessons?.find((l) => l.id === lessonId)
      if (lesson?.activities) {
        lesson.activities = lesson.activities.filter((a) => a.id !== activityId)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete activity'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 478-506 (reorderActivities)
  async function reorderActivities(
    programId: string,
    lessonId: string,
    activityIds: string[]
  ): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(
        `/admin/api/programs/${programId}/lessons/${lessonId}/reorder-activities`,
        { activityOrder: activityIds }
      )
      const reordered: Activity[] = res.data.activities
      const program = programs.value.find((p) => p.id === programId)
      const lesson = program?.lessons?.find((l) => l.id === lessonId)
      if (lesson) lesson.activities = reordered
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to reorder activities'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 749-764 (resetActivity)
  async function resetActivity(
    activityId: string,
    programId: string,
    lessonId: string
  ): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(`/admin/api/activities/${activityId}/reset`)
      const reset: Activity = res.data.activity
      replaceActivity(programId, lessonId, activityId, reset)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to reset activity'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 614-651 (createReadBlock)
  async function addReadBlock(
    activityId: string,
    programId: string,
    lessonId: string,
    title: string,
    content: string,
    orderNumber: number,
    isLocked: boolean
  ): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(
        `/admin/api/activities/${activityId}/read-blocks`,
        { title, content, orderNumber, isLocked }
      )
      if (res.data.activity) {
        replaceActivity(programId, lessonId, activityId, res.data.activity)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to add read block'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 656-688 (updateReadBlock)
  // NOTE: server returns only { success: true } — update local state manually
  async function updateReadBlock(
    activityId: string,
    blockId: string,
    content: string | null,
    programId: string,
    lessonId: string
  ): Promise<void> {
    error.value = null
    try {
      await axios.patch(
        `/admin/api/activities/${activityId}/read-blocks/${blockId}`,
        { content: content }
      )
      // Server returns only { success: true } — update local state manually
      const program = programs.value.find((p) => p.id === programId)
      const lesson = program?.lessons?.find((l) => l.id === lessonId)
      const activity = lesson?.activities?.find((a) => a.id === activityId)
      if (activity?.readBlocks) {
        const block = activity.readBlocks.find((b) => b.id === blockId)
        if (block) block.content = content ?? undefined
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to update read block'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 693-715 (deleteReadBlock)
  async function deleteReadBlock(
    activityId: string,
    blockId: string,
    programId: string,
    lessonId: string
  ): Promise<void> {
    error.value = null
    try {
      const res = await axios.delete(
        `/admin/api/activities/${activityId}/read-blocks/${blockId}`
      )
      if (res.data.activity) {
        replaceActivity(programId, lessonId, activityId, res.data.activity)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete read block'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 720-745 (reorderReadBlocks)
  async function reorderReadBlocks(
    activityId: string,
    programId: string,
    lessonId: string,
    blockIds: string[]
  ): Promise<void> {
    error.value = null
    try {
      const res = await axios.patch(
        `/admin/api/activities/${activityId}/read-blocks/reorder`,
        { blockIds }
      )
      if (res.data.activity) {
        replaceActivity(programId, lessonId, activityId, res.data.activity)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to reorder read blocks'
      throw err
    }
  }

  // Source: ProgramActions.swift lines 566-607 (addSourceReference)
  async function addSourceReference(
    activityId: string,
    programId: string,
    lessonId: string,
    passageReference: string,
    bookNumber: number,
    bookName: string,
    chapterStart: number,
    verseStart: number,
    verseEnd: number,
    chapterEnd?: number
  ): Promise<void> {
    error.value = null
    try {
      const body: Record<string, any> = {
        sourceType: 'BIBLE_PASSAGE',
        passageReference,
        bookNumber,
        bookName,
        chapterStart,
        verseStart,
        verseEnd,
      }
      if (chapterEnd !== undefined) body.chapterEnd = chapterEnd

      const res = await axios.post(
        `/admin/api/activities/${activityId}/source-references`,
        body
      )
      if (res.data.activity) {
        replaceActivity(programId, lessonId, activityId, res.data.activity)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to add source reference'
      throw err
    }
  }

  async function getExportPreview(id: string): Promise<ExportPreviewData> {
    error.value = null
    try {
      const res = await axios.get(`/admin/api/programs/${id}/export-preview`)
      const data = res.data
      const manifest = data.manifest ?? data
      const program = manifest.program ?? manifest
      const lessons = program.lessons ?? []
      let activities = 0, reads = 0, videos = 0, userInputs = 0, readBlocks = 0, scriptureRefs = 0
      for (const lesson of lessons) {
        for (const act of lesson.activities ?? []) {
          activities++
          if (act.activityType === 'READ') reads++
          else if (act.activityType === 'VIDEO') videos++
          else if (act.activityType === 'USER_INPUT') userInputs++
          readBlocks += (act.readBlocks?.length ?? 0)
          scriptureRefs += (act.sourceReferences?.length ?? 0)
        }
      }
      return {
        name: program.name ?? 'Unknown',
        days: lessons.length,
        activities, reads, videos, userInputs, readBlocks, scriptureRefs,
        templateName: program.template?.name,
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load export preview'
      throw err
    }
  }

  async function parseImportFile(file: File): Promise<ExportPreviewData> {
    try {
      const zip = await JSZip.loadAsync(file)
      const manifestEntry = zip.file('manifest.json')
      if (!manifestEntry) {
        throw new Error('This file is not a compatible MakeReady study program. The file must be a .makeready export containing a valid manifest.')
      }
      const manifestText = await manifestEntry.async('text')
      let manifest: any
      try {
        manifest = JSON.parse(manifestText)
      } catch {
        throw new Error('This file is not a compatible MakeReady study program. The manifest is not valid JSON.')
      }
      if (manifest.format !== 'makeready-program-v1' || manifest.version !== 1) {
        throw new Error('This file format is not supported. Please use a file exported from MakeReady.')
      }
      const program = manifest.program ?? {}
      const lessons = program.lessons ?? []
      let activities = 0, reads = 0, videos = 0, userInputs = 0, readBlocks = 0, scriptureRefs = 0
      for (const lesson of lessons) {
        for (const act of lesson.activities ?? []) {
          activities++
          if (act.activityType === 'READ') reads++
          else if (act.activityType === 'VIDEO') videos++
          else if (act.activityType === 'USER_INPUT') userInputs++
          readBlocks += (act.readBlocks?.length ?? 0)
          scriptureRefs += (act.sourceReferences?.length ?? 0)
        }
      }
      return {
        name: program.name ?? 'Unknown',
        days: lessons.length,
        activities, reads, videos, userInputs, readBlocks, scriptureRefs,
        templateName: program.template?.name,
      }
    } catch (err: any) {
      if (err.message?.includes('MakeReady') || err.message?.includes('not supported')) throw err
      throw new Error('This file is not a compatible MakeReady study program. The file must be a .makeready export containing a valid manifest.')
    }
  }

  async function exportProgram(id: string): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(`/admin/api/programs/${id}/export`, {}, { responseType: 'blob' })
      const blob = new Blob([res.data], { type: 'application/zip' })
      const url = URL.createObjectURL(blob)
      const program = programs.value.find((p) => p.id === id)
      const filename = program ? `${program.name.replace(/[^a-z0-9]/gi, '-').toLowerCase()}.makeready` : 'program-export.makeready'
      const a = document.createElement('a')
      a.href = url
      a.download = filename
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to export program'
      throw err
    }
  }

  async function importProgram(file: File): Promise<ImportResult> {
    error.value = null
    try {
      const formData = new FormData()
      formData.append('file', file)
      const res = await axios.post('/admin/api/programs/import', formData)
      await loadPrograms()
      return {
        program: res.data.program,
        warnings: res.data.warnings ?? [],
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to import program'
      throw err
    }
  }

  return {
    programs,
    templates,
    isLoading,
    error,
    ACTIVITY_TYPE_LABELS,
    loadPrograms,
    loadTemplates,
    getProgram,
    createProgram,
    updateProgram,
    deleteProgram,
    uploadCoverImage,
    addLesson,
    updateLessonTitle,
    deleteLesson,
    reorderLessons,
    addActivity,
    updateActivity,
    deleteActivity,
    reorderActivities,
    resetActivity,
    addReadBlock,
    updateReadBlock,
    deleteReadBlock,
    reorderReadBlocks,
    addSourceReference,
    getExportPreview,
    parseImportFile,
    exportProgram,
    importProgram,
  }
})
