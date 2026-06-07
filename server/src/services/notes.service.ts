import { prisma } from '../lib/prisma.js'
import type {
  StudyNote,
  NoteLink,
  MemberActivityProgress,
  Prisma,
} from '../generated/prisma/index.js'
import {
  checkAndUpdateLessonCompletion,
  getMemberLessonDetail,
  type LessonDetail,
} from './member-progress.service.js'

/**
 * Study Notes Service
 * Handles all note operations using the polymorphic NoteLink architecture
 *
 * Note Types (extensible - just add new string values):
 * - OBSERVATION: SOAP "O" - What does this passage say?
 * - APPLICATION: SOAP "A" - How does this apply to my life?
 * - PRAYER: SOAP "P" - Prayer response
 * - JOURNAL: Free-form journal entry
 * - REFLECTION: General reflection
 * - SCRIPTURE_NOTE: Note on specific verse(s)
 * - QUESTION: Question about the passage
 *
 * Link Types (extensible - just add new string values):
 * - LESSON: Link to a Lesson
 * - LESSON_ACTIVITY: Link to a LessonActivity
 * - LESSON_SCHEDULE: Link to a LessonSchedule
 * - ENROLLMENT: Link to an Enrollment
 * - GROUP: Link to a Group
 * - VERSE: Link to a Verse (with metadata)
 * - PROGRAM: Link to a StudyProgram
 */

// ============================================================================
// Constants
// ============================================================================

export const NOTE_TYPES = {
  OBSERVATION: 'OBSERVATION',
  APPLICATION: 'APPLICATION',
  PRAYER: 'PRAYER',
  JOURNAL: 'JOURNAL',
  REFLECTION: 'REFLECTION',
  SCRIPTURE_NOTE: 'SCRIPTURE_NOTE',
  QUESTION: 'QUESTION',
} as const

export const LINK_TYPES = {
  LESSON: 'LESSON',
  LESSON_ACTIVITY: 'LESSON_ACTIVITY',
  LESSON_SCHEDULE: 'LESSON_SCHEDULE',
  ENROLLMENT: 'ENROLLMENT',
  GROUP: 'GROUP',
  VERSE: 'VERSE',
  PROGRAM: 'PROGRAM',
} as const

export type NoteType = (typeof NOTE_TYPES)[keyof typeof NOTE_TYPES] | string
export type LinkType = (typeof LINK_TYPES)[keyof typeof LINK_TYPES] | string

// ============================================================================
// Types
// ============================================================================

export interface StudyNoteWithLinks extends StudyNote {
  links: NoteLink[]
}

export interface NoteResult {
  success: boolean
  data?: StudyNoteWithLinks
  error?: string
}

export interface NotesResult {
  success: boolean
  data?: StudyNoteWithLinks[]
  total?: number
  error?: string
}

export interface ProgressResult {
  success: boolean
  data?: MemberActivityProgress
  error?: string
}

export interface NoteLinkData {
  refType: LinkType
  refId: string
  metadata?: Record<string, unknown>
}

export interface CreateNoteData {
  memberId?: string
  userId?: string
  type: NoteType
  content: string
  links?: NoteLinkData[]
}

export interface UpdateProgressData {
  memberId: string
  lessonScheduleId: string
  lessonActivityId: string
  currentStep?: string // Legacy: mapped to completed if 'COMPLETE'
  notes?: Array<{
    type: NoteType
    content: string
  }>
}

export interface GetNotesOptions {
  memberId?: string
  userId?: string
  type?: NoteType
  // Filter by linked entity
  linkType?: LinkType
  linkRefId?: string
  // Date filters
  startDate?: Date
  endDate?: Date
  // Pagination
  limit?: number
  offset?: number
}

export interface GetNotesWithContextOptions {
  memberId: string
  type?: NoteType
  cursor?: Date
  limit?: number
}

export interface NoteContext {
  program?: { id: string; name: string; description: string | null }
  lesson?: { id: string; dayNumber: number }
  activity?: {
    id: string
    type: string
    title: string | null
  }
  verse?: {
    passageReference: string | null
    bookName: string | null
    chapterStart: number | null
    verseStart: number | null
    chapterEnd: number | null
    verseEnd: number | null
    scriptureText: string | null
  }
  group?: { id: string; name: string }
  lessonSchedule?: { id: string; scheduledDate: Date }
  enrollment?: { id: string; groupId: string }
}

export interface NoteWithContext {
  id: string
  type: string
  content: string
  createdAt: Date
  updatedAt: Date
  context: NoteContext
}

export interface NotesWithContextResult {
  success: boolean
  data?: NoteWithContext[]
  nextCursor?: string | null
  hasMore?: boolean
  error?: string
}

export interface GetNotesForEntityOptions {
  refType: LinkType
  refId: string
  type?: NoteType
  limit?: number
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Determine the current SOAP step based on completed steps
 * Returns 'COMPLETE' if all content steps are done, otherwise returns first incomplete step
 */
export function determineCurrentStep(completedSteps: string[]): string {
  const contentSteps = ['READ_SCRIPTURE', 'OBSERVE', 'APPLICATION', 'PRAYER']

  // All content steps done = COMPLETE
  if (contentSteps.every((s) => completedSteps.includes(s))) {
    return 'COMPLETE'
  }

  // Return first incomplete step
  return contentSteps.find((s) => !completedSteps.includes(s)) || 'COMPLETE'
}

/**
 * Map note type to corresponding SOAP step
 * Returns null if note type doesn't map to a step
 */
export function noteTypeToStep(noteType: string): string | null {
  const mapping: Record<string, string> = {
    OBSERVATION: 'OBSERVE',
    APPLICATION: 'APPLICATION',
    PRAYER: 'PRAYER',
  }
  return mapping[noteType] || null
}

/**
 * Fetch scripture text for a passage from the Verse table
 * Used to store in metadata for LLM context
 */
async function fetchScriptureText(
  bookNumber: number,
  chapterStart: number,
  verseStart: number,
  chapterEnd?: number,
  verseEnd?: number,
  translationCode: string = 'KJV'
): Promise<string | null> {
  try {
    const translation = await prisma.translation.findUnique({
      where: { code: translationCode },
    })

    if (!translation) {
      console.warn(`Translation ${translationCode} not found`)
      return null
    }

    const effectiveChapterEnd = chapterEnd ?? chapterStart
    const effectiveVerseEnd = verseEnd ?? verseStart

    // For single chapter passages
    if (chapterStart === effectiveChapterEnd) {
      const verses = await prisma.verse.findMany({
        where: {
          translationId: translation.id,
          bookNumber,
          chapter: chapterStart,
          verse: {
            gte: verseStart,
            lte: effectiveVerseEnd,
          },
        },
        orderBy: [{ chapter: 'asc' }, { verse: 'asc' }],
        select: { text: true },
      })

      return verses.map((v) => v.text).join(' ')
    }

    // For multi-chapter passages
    const verses = await prisma.verse.findMany({
      where: {
        translationId: translation.id,
        bookNumber,
        OR: [
          { chapter: chapterStart, verse: { gte: verseStart } },
          { chapter: { gt: chapterStart, lt: effectiveChapterEnd } },
          { chapter: effectiveChapterEnd, verse: { lte: effectiveVerseEnd } },
        ],
      },
      orderBy: [{ chapter: 'asc' }, { verse: 'asc' }],
      select: { text: true },
    })

    return verses.map((v) => v.text).join(' ')
  } catch (error) {
    console.error('Error fetching scripture text:', error)
    return null
  }
}

/**
 * Get verse reference data from an activity's source references
 * Works with both LessonActivity and ScheduledLessonActivity
 */
async function getActivityVerseMetadata(activityId: string): Promise<{
  bookNumber?: number
  bookName?: string
  chapterStart?: number
  chapterEnd?: number
  verseStart?: number
  verseEnd?: number
  passageReference?: string
  scriptureText?: string
} | null> {
  const sourceRef = await prisma.activitySourceReference.findFirst({
    where: {
      scheduledActivityId: activityId,
      sourceType: 'SCRIPTURE',
    },
  })

  if (!sourceRef || !sourceRef.bookNumber) return null

  // Fetch scripture text for LLM context
  let scriptureText: string | undefined
  if (sourceRef.chapterStart && sourceRef.verseStart) {
    const text = await fetchScriptureText(
      sourceRef.bookNumber,
      sourceRef.chapterStart,
      sourceRef.verseStart,
      sourceRef.chapterEnd ?? undefined,
      sourceRef.verseEnd ?? undefined
    )
    if (text) scriptureText = text
  }

  return {
    bookNumber: sourceRef.bookNumber ?? undefined,
    bookName: sourceRef.bookName ?? undefined,
    chapterStart: sourceRef.chapterStart ?? undefined,
    chapterEnd: sourceRef.chapterEnd ?? undefined,
    verseStart: sourceRef.verseStart ?? undefined,
    verseEnd: sourceRef.verseEnd ?? undefined,
    passageReference: sourceRef.passageReference ?? undefined,
    scriptureText,
  }
}

// ============================================================================
// Note CRUD Operations
// ============================================================================

/**
 * Create a new note with polymorphic links
 */
export async function createNote(data: CreateNoteData): Promise<NoteResult> {
  try {
    // Validate owner - must have either memberId or userId
    if (!data.memberId && !data.userId) {
      return {
        success: false,
        error: 'Note must have either memberId or userId',
      }
    }

    // Create note with links in a transaction
    const note = await prisma.$transaction(async (tx) => {
      // Create the note
      const createdNote = await tx.studyNote.create({
        data: {
          memberId: data.memberId,
          userId: data.userId,
          type: data.type,
          content: data.content,
        },
      })

      // Create links if provided
      if (data.links && data.links.length > 0) {
        await tx.noteLink.createMany({
          data: data.links.map((link) => ({
            noteId: createdNote.id,
            refType: link.refType,
            refId: link.refId,
            metadata: link.metadata as Prisma.InputJsonValue,
          })),
        })
      }

      // Return note with links
      return tx.studyNote.findUnique({
        where: { id: createdNote.id },
        include: { links: true },
      })
    })

    return { success: true, data: note as StudyNoteWithLinks }
  } catch (error) {
    console.error('Error creating note:', error)
    return { success: false, error: 'Failed to create note' }
  }
}

/**
 * Get notes with filtering options
 */
export async function getNotes(options: GetNotesOptions): Promise<NotesResult> {
  try {
    const {
      memberId,
      userId,
      type,
      linkType,
      linkRefId,
      startDate,
      endDate,
      limit = 50,
      offset = 0,
    } = options

    // Build where clause
    const where: Prisma.StudyNoteWhereInput = { isActive: true }

    if (memberId) where.memberId = memberId
    if (userId) where.userId = userId
    if (type) where.type = type

    // Filter by linked entity
    if (linkType && linkRefId) {
      where.links = {
        some: {
          refType: linkType,
          refId: linkRefId,
        },
      }
    }

    if (startDate || endDate) {
      where.createdAt = {}
      if (startDate) where.createdAt.gte = startDate
      if (endDate) where.createdAt.lte = endDate
    }

    // Query with pagination
    const [notes, total] = await Promise.all([
      prisma.studyNote.findMany({
        where,
        include: { links: true },
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
      }),
      prisma.studyNote.count({ where }),
    ])

    return {
      success: true,
      data: notes as StudyNoteWithLinks[],
      total,
    }
  } catch (error) {
    console.error('Error fetching notes:', error)
    return { success: false, error: 'Failed to fetch notes' }
  }
}

/**
 * Get all notes linked to a specific entity
 */
export async function getNotesForEntity(
  options: GetNotesForEntityOptions
): Promise<NotesResult> {
  try {
    const { refType, refId, type, limit = 100 } = options

    const where: Prisma.StudyNoteWhereInput = {
      isActive: true,
      links: {
        some: {
          refType,
          refId,
        },
      },
    }

    if (type) where.type = type

    const notes = await prisma.studyNote.findMany({
      where,
      include: { links: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    })

    return {
      success: true,
      data: notes as StudyNoteWithLinks[],
      total: notes.length,
    }
  } catch (error) {
    console.error('Error fetching notes for entity:', error)
    return { success: false, error: 'Failed to fetch notes' }
  }
}

/**
 * Get notes with resolved context from linked entities
 * Uses cursor-based pagination and batch resolution to avoid N+1 queries
 */
export async function getNotesWithContext(
  options: GetNotesWithContextOptions
): Promise<NotesWithContextResult> {
  try {
    const { memberId, type, cursor, limit = 20 } = options
    const take = Math.min(limit, 100)

    const where: Prisma.StudyNoteWhereInput = {
      isActive: true,
      memberId,
    }

    if (type) where.type = type

    if (cursor) {
      where.createdAt = { lt: cursor }
    }

    // Fetch one extra to determine hasMore
    const notes = await prisma.studyNote.findMany({
      where,
      include: { links: true },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
    })

    const hasMore = notes.length > take
    const pageNotes = hasMore ? notes.slice(0, take) : notes

    // Collect all unique refIds grouped by refType
    const refIdsByType = new Map<string, Set<string>>()
    for (const note of pageNotes) {
      for (const link of (note as StudyNoteWithLinks).links) {
        if (!refIdsByType.has(link.refType)) {
          refIdsByType.set(link.refType, new Set())
        }
        refIdsByType.get(link.refType)!.add(link.refId)
      }
    }

    // Batch-resolve linked entities
    const [programs, lessons, activities, schedules, enrollments, groups] =
      await Promise.all([
        refIdsByType.has(LINK_TYPES.PROGRAM)
          ? prisma.studyProgram.findMany({
              where: { id: { in: [...refIdsByType.get(LINK_TYPES.PROGRAM)!] } },
              select: { id: true, name: true, description: true },
            })
          : [],
        refIdsByType.has(LINK_TYPES.LESSON)
          ? prisma.lesson.findMany({
              where: { id: { in: [...refIdsByType.get(LINK_TYPES.LESSON)!] } },
              select: { id: true, dayNumber: true },
            })
          : [],
        refIdsByType.has(LINK_TYPES.LESSON_ACTIVITY)
          ? prisma.lessonActivity.findMany({
              where: {
                id: { in: [...refIdsByType.get(LINK_TYPES.LESSON_ACTIVITY)!] },
              },
              select: {
                id: true,
                activityType: true,
                title: true,
              },
            })
          : [],
        refIdsByType.has(LINK_TYPES.LESSON_SCHEDULE)
          ? prisma.lessonSchedule.findMany({
              where: {
                id: {
                  in: [...refIdsByType.get(LINK_TYPES.LESSON_SCHEDULE)!],
                },
              },
              select: { id: true, scheduledDate: true },
            })
          : [],
        refIdsByType.has(LINK_TYPES.ENROLLMENT)
          ? prisma.enrollment.findMany({
              where: {
                id: { in: [...refIdsByType.get(LINK_TYPES.ENROLLMENT)!] },
              },
              select: { id: true, groupId: true },
            })
          : [],
        refIdsByType.has(LINK_TYPES.GROUP)
          ? prisma.group.findMany({
              where: { id: { in: [...refIdsByType.get(LINK_TYPES.GROUP)!] } },
              select: { id: true, name: true },
            })
          : [],
      ])

    // Build lookup maps
    const programMap = new Map(programs.map((p) => [p.id, p]))
    const lessonMap = new Map(lessons.map((l) => [l.id, l]))
    const activityMap = new Map(activities.map((a) => [a.id, a]))
    const scheduleMap = new Map(schedules.map((s) => [s.id, s]))
    const enrollmentMap = new Map(enrollments.map((e) => [e.id, e]))
    const groupMap = new Map(groups.map((g) => [g.id, g]))

    // Build response with context
    const data: NoteWithContext[] = pageNotes.map((note) => {
      const context: NoteContext = {}
      const noteWithLinks = note as StudyNoteWithLinks

      for (const link of noteWithLinks.links) {
        switch (link.refType) {
          case LINK_TYPES.PROGRAM: {
            const p = programMap.get(link.refId)
            if (p) context.program = p
            break
          }
          case LINK_TYPES.LESSON: {
            const l = lessonMap.get(link.refId)
            if (l) context.lesson = l
            break
          }
          case LINK_TYPES.LESSON_ACTIVITY: {
            const a = activityMap.get(link.refId)
            if (a) context.activity = { id: a.id, type: a.activityType, title: a.title }
            break
          }
          case LINK_TYPES.VERSE: {
            const metadata = link.metadata as Record<string, unknown> | null
            if (metadata) {
              context.verse = {
                passageReference:
                  (metadata.passageReference as string) ?? null,
                bookName: (metadata.bookName as string) ?? null,
                chapterStart: (metadata.chapterStart as number) ?? null,
                verseStart: (metadata.verseStart as number) ?? null,
                chapterEnd: (metadata.chapterEnd as number) ?? null,
                verseEnd: (metadata.verseEnd as number) ?? null,
                scriptureText: (metadata.scriptureText as string) ?? null,
              }
            }
            break
          }
          case LINK_TYPES.GROUP: {
            const g = groupMap.get(link.refId)
            if (g) context.group = g
            break
          }
          case LINK_TYPES.LESSON_SCHEDULE: {
            const s = scheduleMap.get(link.refId)
            if (s) context.lessonSchedule = s
            break
          }
          case LINK_TYPES.ENROLLMENT: {
            const e = enrollmentMap.get(link.refId)
            if (e) context.enrollment = e
            break
          }
        }
      }

      return {
        id: note.id,
        type: note.type,
        content: note.content,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        context,
      }
    })

    const nextCursor =
      hasMore && pageNotes.length > 0
        ? pageNotes[pageNotes.length - 1].createdAt.toISOString()
        : null

    return { success: true, data, nextCursor, hasMore }
  } catch (error) {
    console.error('Error fetching notes with context:', error)
    return { success: false, error: 'Failed to fetch notes with context' }
  }
}

/**
 * Get a single note by ID
 */
export async function getNote(noteId: string): Promise<NoteResult> {
  try {
    const note = await prisma.studyNote.findUnique({
      where: { id: noteId },
      include: { links: true },
    })

    if (!note) {
      return { success: false, error: 'Note not found' }
    }

    return { success: true, data: note as StudyNoteWithLinks }
  } catch (error) {
    console.error('Error fetching note:', error)
    return { success: false, error: 'Failed to fetch note' }
  }
}

/**
 * Update a note's content
 */
export async function updateNote(
  noteId: string,
  content: string
): Promise<NoteResult> {
  try {
    const note = await prisma.studyNote.update({
      where: { id: noteId },
      data: { content, updatedAt: new Date() },
      include: { links: true },
    })

    return { success: true, data: note as StudyNoteWithLinks }
  } catch (error) {
    console.error('Error updating note:', error)
    return { success: false, error: 'Failed to update note' }
  }
}

/**
 * Add a link to an existing note
 */
export async function addNoteLink(
  noteId: string,
  link: NoteLinkData
): Promise<NoteResult> {
  try {
    await prisma.noteLink.create({
      data: {
        noteId,
        refType: link.refType,
        refId: link.refId,
        metadata: link.metadata as Prisma.InputJsonValue,
      },
    })

    const note = await prisma.studyNote.findUnique({
      where: { id: noteId },
      include: { links: true },
    })

    return { success: true, data: note as StudyNoteWithLinks }
  } catch (error) {
    console.error('Error adding note link:', error)
    return { success: false, error: 'Failed to add note link' }
  }
}

/**
 * Remove a link from a note
 */
export async function removeNoteLink(
  noteId: string,
  refType: LinkType,
  refId: string
): Promise<NoteResult> {
  try {
    await prisma.noteLink.delete({
      where: {
        noteId_refType_refId: { noteId, refType, refId },
      },
    })

    const note = await prisma.studyNote.findUnique({
      where: { id: noteId },
      include: { links: true },
    })

    return { success: true, data: note as StudyNoteWithLinks }
  } catch (error) {
    console.error('Error removing note link:', error)
    return { success: false, error: 'Failed to remove note link' }
  }
}

/**
 * Soft delete a note
 */
export async function deleteNote(noteId: string): Promise<NoteResult> {
  try {
    const note = await prisma.studyNote.update({
      where: { id: noteId },
      data: { isActive: false },
      include: { links: true },
    })

    return { success: true, data: note as StudyNoteWithLinks }
  } catch (error) {
    console.error('Error deleting note:', error)
    return { success: false, error: 'Failed to delete note' }
  }
}

// ============================================================================
// Activity Progress Operations
// ============================================================================

/**
 * Save activity progress and create notes in a single transaction
 * This is the main endpoint for saving SOAP progress
 */
export async function saveActivityProgress(
  data: UpdateProgressData
): Promise<{
  success: boolean
  progress?: MemberActivityProgress
  notes?: StudyNoteWithLinks[]
  error?: string
}> {
  try {
    const { memberId, lessonScheduleId, lessonActivityId, currentStep, notes } =
      data

    const scheduledActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id: lessonActivityId },
      include: {
        lessonSchedule: {
          include: {
            enrollment: true,
            lesson: {
              include: { studyProgram: true },
            },
          },
        },
      },
    })

    if (!scheduledActivity) {
      return { success: false, error: 'Activity not found' }
    }

    const schedule = scheduledActivity.lessonSchedule

    if (!schedule) {
      return { success: false, error: 'Lesson schedule not found' }
    }

    // Verify member belongs to the group
    const membership = await prisma.groupMember.findFirst({
      where: {
        memberId,
        groupId: schedule.enrollment.groupId,
        isActive: true,
      },
    })

    if (!membership) {
      return {
        success: false,
        error: 'Member is not part of this group',
      }
    }

    // In the new model, each activity IS a step. Progress is just completedAt.
    const isComplete = currentStep === 'COMPLETE'

    // Get verse metadata for notes
    const verseMetadata = await getActivityVerseMetadata(lessonActivityId)

    // Use transaction to save progress and notes atomically
    const result = await prisma.$transaction(async (tx) => {
      // Try to find existing progress
      const existingProgress = await tx.memberActivityProgress.findFirst({
        where: { memberId, lessonScheduleId, scheduledActivityId: lessonActivityId },
      })

      const progress = existingProgress
        ? await tx.memberActivityProgress.update({
            where: { id: existingProgress.id },
            data: {
              completedAt: isComplete ? new Date() : null,
              lastUpdatedAt: new Date(),
            },
          })
        : await tx.memberActivityProgress.create({
            data: {
              memberId,
              lessonScheduleId,
              scheduledActivityId: lessonActivityId,
              completedAt: isComplete ? new Date() : null,
            },
          })

      // Create notes with links
      const createdNotes: StudyNoteWithLinks[] = []
      if (notes && notes.length > 0) {
        for (const noteData of notes) {
          // Skip empty notes
          if (!noteData.content || noteData.content.trim() === '') {
            continue
          }

          // Create the note
          const note = await tx.studyNote.create({
            data: {
              memberId,
              type: noteData.type,
              content: noteData.content,
            },
          })

          // Create links for context
          const lessonId = scheduledActivity.lessonSchedule.lesson.id
          const programId = scheduledActivity.lessonSchedule.lesson.studyProgram.id

          const links: Prisma.NoteLinkCreateManyInput[] = [
            { noteId: note.id, refType: 'SCHEDULED_ACTIVITY', refId: lessonActivityId },
            { noteId: note.id, refType: LINK_TYPES.LESSON_SCHEDULE, refId: lessonScheduleId },
            { noteId: note.id, refType: LINK_TYPES.ENROLLMENT, refId: schedule.enrollment.id },
            { noteId: note.id, refType: LINK_TYPES.GROUP, refId: schedule.enrollment.groupId },
            { noteId: note.id, refType: LINK_TYPES.LESSON, refId: lessonId },
            { noteId: note.id, refType: LINK_TYPES.PROGRAM, refId: programId },
          ]

          // Add verse link with metadata if available
          if (verseMetadata) {
            links.push({
              noteId: note.id,
              refType: LINK_TYPES.VERSE,
              refId: `${verseMetadata.bookNumber}-${verseMetadata.chapterStart}-${verseMetadata.verseStart}`,
              metadata: verseMetadata as Prisma.InputJsonValue,
            })
          }

          await tx.noteLink.createMany({ data: links })

          // Fetch note with links
          const noteWithLinks = await tx.studyNote.findUnique({
            where: { id: note.id },
            include: { links: true },
          })

          if (noteWithLinks) {
            createdNotes.push(noteWithLinks as StudyNoteWithLinks)
          }
        }
      }

      return { progress, notes: createdNotes }
    })

    // Check and update lesson completion status after saving activity progress
    await checkAndUpdateLessonCompletion(memberId, lessonScheduleId)

    return {
      success: true,
      progress: result.progress,
      notes: result.notes,
    }
  } catch (error) {
    console.error('Error saving activity progress:', error)
    const errorMessage = error instanceof Error ? error.message : 'Failed to save progress'
    return { success: false, error: errorMessage }
  }
}

/**
 * Get activity progress for a member
 */
export async function getActivityProgress(
  memberId: string,
  lessonActivityId: string,
  lessonScheduleId: string
): Promise<ProgressResult> {
  try {
    const progress = await prisma.memberActivityProgress.findFirst({
      where: {
        memberId,
        lessonScheduleId,
        scheduledActivityId: lessonActivityId,
      },
    })

    if (!progress) {
      return { success: false, error: 'Progress not found' }
    }

    return { success: true, data: progress }
  } catch (error) {
    console.error('Error fetching progress:', error)
    return { success: false, error: 'Failed to fetch progress' }
  }
}

// ============================================================================
// Server-Side SOAP Activity Step Completion
// ============================================================================

export interface SubmitActivityResponseData {
  memberId: string
  lessonScheduleId: string
  lessonActivityId: string
  note?: {
    type: string
    content: string
  }
  // 'complete' marks a non-input activity (READ/VIDEO/YOUTUBE/EXEGESIS) done once
  // the member finishes its content. requireResponse only gates USER_INPUT.
  action?: 'start' | 'skip_to_complete' | 'complete'
  isGroupLeader?: boolean
}

export interface SubmitActivityResponseResult {
  success: boolean
  lesson?: LessonDetail
  error?: string
}

/**
 * Submit an activity response with server-side step completion logic
 *
 * This is the new approach where the server determines step completion:
 * - action: 'start' → Mark READ_SCRIPTURE complete
 * - note provided → Save note, mark corresponding step complete
 * - action: 'skip_to_complete' (only if !requireResponse) → Mark all complete
 *
 * Returns the full lesson state after processing.
 */
export async function submitActivityResponse(
  data: SubmitActivityResponseData
): Promise<SubmitActivityResponseResult> {
  try {
    const { memberId, lessonScheduleId, lessonActivityId, note, action, isGroupLeader } = data

    // 1. Try to find as scheduled activity first, then fall back to lesson activity
    const scheduledActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id: lessonActivityId },
      include: {
        lessonSchedule: {
          include: {
            enrollment: true,
            lesson: { include: { studyProgram: true } },
          },
        },
      },
    })

    if (!scheduledActivity) {
      return { success: false, error: 'Activity not found' }
    }

    // 2. Get lesson schedule with enrollment for requireResponse setting
    const schedule = scheduledActivity.lessonSchedule

    if (!schedule) {
      return { success: false, error: 'Lesson schedule not found' }
    }

    // 3. Verify member belongs to the group
    const membership = await prisma.groupMember.findFirst({
      where: {
        memberId,
        groupId: schedule.enrollment.groupId,
        isActive: true,
      },
    })

    if (!membership) {
      return { success: false, error: 'Member is not part of this group' }
    }

    // 4. In the new template model, each activity IS a step.
    // action: 'start' → mark the activity as started (not yet complete)
    // action: 'complete' → mark a non-input activity (READ/VIDEO/YOUTUBE/EXEGESIS)
    //   complete once its content is finished. requireResponse only governs
    //   USER_INPUT activities, so it never blocks these.
    // action: 'skip_to_complete' → mark the activity as complete (if requireResponse is false)
    // note provided → save note and mark activity as complete
    const requireResponse = schedule.enrollment.requireResponse
    const isUserInput = scheduledActivity.type === 'USER_INPUT'
    let shouldComplete = false

    if (action === 'complete') {
      // USER_INPUT activities are completed by submitting a note (or skipping
      // when responses aren't required), not by a bare 'complete'.
      if (isUserInput && requireResponse && !isGroupLeader) {
        return {
          success: false,
          error: 'This activity requires a response',
        }
      }
      shouldComplete = true
    }

    if (action === 'skip_to_complete') {
      if (requireResponse && !isGroupLeader) {
        return {
          success: false,
          error: 'Cannot skip to complete when responses are required',
        }
      }
      shouldComplete = true
    }

    // 5. Process note if provided
    if (note && note.content.trim()) {
      const lessonId = scheduledActivity.lessonSchedule.lesson.id
      const programId = scheduledActivity.lessonSchedule.lesson.studyProgram.id

      await prisma.$transaction(async (tx) => {
        const createdStudyNote = await tx.studyNote.create({
          data: {
            memberId,
            type: note.type,
            content: note.content,
          },
        })

        // Get verse metadata for note links
        const verseMetadata = await getActivityVerseMetadata(lessonActivityId)

        // Create links for context
        const links: Prisma.NoteLinkCreateManyInput[] = [
          { noteId: createdStudyNote.id, refType: 'SCHEDULED_ACTIVITY', refId: lessonActivityId },
          { noteId: createdStudyNote.id, refType: LINK_TYPES.LESSON_SCHEDULE, refId: lessonScheduleId },
          { noteId: createdStudyNote.id, refType: LINK_TYPES.ENROLLMENT, refId: schedule.enrollment.id },
          { noteId: createdStudyNote.id, refType: LINK_TYPES.GROUP, refId: schedule.enrollment.groupId },
          { noteId: createdStudyNote.id, refType: LINK_TYPES.LESSON, refId: lessonId },
          { noteId: createdStudyNote.id, refType: LINK_TYPES.PROGRAM, refId: programId },
        ]

        // Add verse link with metadata if available
        if (verseMetadata) {
          links.push({
            noteId: createdStudyNote.id,
            refType: LINK_TYPES.VERSE,
            refId: `${verseMetadata.bookNumber}-${verseMetadata.chapterStart}-${verseMetadata.verseStart}`,
            metadata: verseMetadata as Prisma.InputJsonValue,
          })
        }

        await tx.noteLink.createMany({ data: links })
      })

      // Submitting a note completes the USER_INPUT activity
      shouldComplete = true
    }

    // 6. Update progress record
    const existingProgress = await prisma.memberActivityProgress.findFirst({
      where: { memberId, lessonScheduleId, scheduledActivityId: lessonActivityId },
    })

    if (existingProgress) {
      await prisma.memberActivityProgress.update({
        where: { id: existingProgress.id },
        data: {
          completedAt: shouldComplete ? new Date() : existingProgress.completedAt,
          lastUpdatedAt: new Date(),
        },
      })
    } else {
      await prisma.memberActivityProgress.create({
        data: {
          memberId,
          lessonScheduleId,
          scheduledActivityId: lessonActivityId,
          completedAt: shouldComplete ? new Date() : null,
        },
      })
    }

    // 7. Check and update lesson completion status
    await checkAndUpdateLessonCompletion(memberId, lessonScheduleId)

    // 8. Return full lesson state
    const lessonResult = await getMemberLessonDetail(memberId, lessonScheduleId)

    if (!lessonResult.success || !lessonResult.data) {
      return {
        success: false,
        error: lessonResult.error || 'Failed to fetch lesson detail',
      }
    }

    return {
      success: true,
      lesson: lessonResult.data,
    }
  } catch (error) {
    console.error('Error submitting activity response:', error)
    const errorMessage =
      error instanceof Error ? error.message : 'Failed to submit activity response'
    return { success: false, error: errorMessage }
  }
}

// ============================================================================
// LLM Query Helpers
// ============================================================================

/**
 * Get notes formatted for LLM consumption
 * Returns notes with scripture context from VERSE link metadata
 */
export async function getNotesForLLM(
  memberId?: string,
  userId?: string,
  options: {
    enrollmentId?: string
    type?: NoteType
    startDate?: Date
    endDate?: Date
    limit?: number
  } = {}
): Promise<{
  success: boolean
  data?: Array<{
    type: string
    content: string
    passageReference: string | null
    scriptureText: string | null
    createdAt: Date
  }>
  error?: string
}> {
  try {
    const where: Prisma.StudyNoteWhereInput = { isActive: true }

    if (memberId) where.memberId = memberId
    if (userId) where.userId = userId
    if (options.type) where.type = options.type

    // Filter by enrollment if provided
    if (options.enrollmentId) {
      where.links = {
        some: {
          refType: LINK_TYPES.ENROLLMENT,
          refId: options.enrollmentId,
        },
      }
    }

    if (options.startDate || options.endDate) {
      where.createdAt = {}
      if (options.startDate) where.createdAt.gte = options.startDate
      if (options.endDate) where.createdAt.lte = options.endDate
    }

    const notes = await prisma.studyNote.findMany({
      where,
      include: {
        links: {
          where: { refType: LINK_TYPES.VERSE },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: options.limit ?? 100,
    })

    // Transform to LLM-friendly format
    const data = notes.map((note) => {
      const verseLink = note.links[0]
      const metadata = verseLink?.metadata as Record<string, unknown> | null

      return {
        type: note.type,
        content: note.content,
        passageReference: (metadata?.passageReference as string) ?? null,
        scriptureText: (metadata?.scriptureText as string) ?? null,
        createdAt: note.createdAt,
      }
    })

    return { success: true, data }
  } catch (error) {
    console.error('Error fetching notes for LLM:', error)
    return { success: false, error: 'Failed to fetch notes' }
  }
}
