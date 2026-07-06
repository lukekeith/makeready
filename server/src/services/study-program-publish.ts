/**
 * Study Program Publish Service (study-sync)
 *
 * "Publish updates" cuts an immutable StudyProgramVersion — the unit of
 * downstream enrollment sync. A version stores:
 *  - lessonHashes: per-lesson canonical content hashes (drives per-lesson sync)
 *  - snapshot: the full canonical lesson content at publish time (audit + diff)
 *  - changedLessonIds: what changed vs the previous version (null on baseline)
 *  - changeSummary: Claude-generated plain-language summary for group leaders
 *
 * Publishing is idempotent from the caller's perspective: republishing an
 * unchanged program returns the latest version with alreadyUpToDate=true
 * instead of cutting a new one (this is what keeps "25 edits, N publishes"
 * from producing N identical versions).
 */

import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import {
  canonicalLessonContent,
  hashLessonContent,
  LESSON_CONTENT_INCLUDE,
} from './lesson-content-hash.js'
import { summarizeProgramChanges } from './claude.js'
import { launchProgramVersionFanOut } from './enrollment-sync.js'

export class PublishConflictError extends Error {
  constructor() {
    super('Another publish for this program is in progress. Try again.')
    this.name = 'PublishConflictError'
  }
}

export interface SnapshotLesson {
  id: string
  dayNumber: number
  title: string | null
  contentHash: string
  content: unknown
  /**
   * Curriculum LessonActivity ids aligned index-for-index with
   * content.activities (both sorted by orderNumber). Ids live outside the
   * hashed content — they are lineage metadata the sync engine stamps onto
   * materialized copies, not part of "what the lesson says".
   */
  activityIds?: string[]
}

export interface ChangedLessonIds {
  added: string[]
  changed: string[]
  removed: string[]
  moved: string[]
}

export interface PublishResult {
  alreadyUpToDate: boolean
  version: {
    id: string
    versionNumber: number
    publishedAt: Date
    changeSummary: string | null
    changedLessonIds: ChangedLessonIds | null
  }
}

/**
 * Returns the day number of a READ activity that has no read blocks, or null
 * if the program is publishable. Shared guard for first publish and
 * "Publish updates" — broken read activities must never reach members.
 */
export async function findIncompleteReadActivityDay(programId: string): Promise<number | null> {
  const emptyReadActivity = await prisma.lessonActivity.findFirst({
    where: {
      activityType: 'READ',
      lesson: { studyProgramId: programId },
      readBlocks: { none: {} },
    },
    select: { lesson: { select: { dayNumber: true } } },
  })
  return emptyReadActivity?.lesson?.dayNumber ?? null
}

/**
 * Cut a new StudyProgramVersion for the program (or report alreadyUpToDate).
 *
 * @param generateSummary set false to skip the Claude call (baseline publish
 *   from the isPublished transition uses this — there is nothing to diff).
 */
export async function publishProgramVersion(params: {
  programId: string
  userId: string
  generateSummary?: boolean
}): Promise<PublishResult> {
  const { programId, userId, generateSummary = true } = params

  const program = await prisma.studyProgram.findUniqueOrThrow({
    where: { id: programId },
    include: {
      lessons: {
        orderBy: { dayNumber: 'asc' },
        include: LESSON_CONTENT_INCLUDE,
      },
    },
  })

  const snapshotLessons: SnapshotLesson[] = program.lessons.map((lesson) => ({
    id: lesson.id,
    dayNumber: lesson.dayNumber,
    title: lesson.title,
    contentHash: hashLessonContent(lesson as any),
    content: canonicalLessonContent(lesson as any),
    activityIds: [...lesson.activities]
      .sort((a, b) => a.orderNumber - b.orderNumber)
      .map((a) => a.id),
  }))

  const latest = await prisma.studyProgramVersion.findFirst({
    where: { studyProgramId: programId },
    orderBy: { versionNumber: 'desc' },
  })

  const previousLessons: SnapshotLesson[] | null = latest
    ? ((latest.snapshot as any)?.lessons ?? [])
    : null

  // No-op detection: identical lesson set, hashes, and day ordering
  if (previousLessons && isSameContent(previousLessons, snapshotLessons)) {
    return {
      alreadyUpToDate: true,
      version: {
        id: latest!.id,
        versionNumber: latest!.versionNumber,
        publishedAt: latest!.publishedAt,
        changeSummary: latest!.changeSummary,
        changedLessonIds: (latest!.changedLessonIds as unknown as ChangedLessonIds) ?? null,
      },
    }
  }

  const changedLessonIds = previousLessons ? diffLessons(previousLessons, snapshotLessons) : null

  // Best-effort Claude summary — never blocks the publish
  let changeSummary: string | null = null
  if (generateSummary && previousLessons && changedLessonIds) {
    const prevById = new Map(previousLessons.map((l) => [l.id, l]))
    const nextById = new Map(snapshotLessons.map((l) => [l.id, l]))
    changeSummary = await summarizeProgramChanges({
      programName: program.name,
      addedLessons: changedLessonIds.added.map((id) => pickDayTitle(nextById.get(id)!)),
      removedLessons: changedLessonIds.removed.map((id) => pickDayTitle(prevById.get(id)!)),
      movedLessons: changedLessonIds.moved.map((id) => ({
        title: nextById.get(id)!.title,
        fromDay: prevById.get(id)!.dayNumber,
        toDay: nextById.get(id)!.dayNumber,
      })),
      changedLessons: changedLessonIds.changed.map((id) => ({
        dayNumber: nextById.get(id)!.dayNumber,
        title: nextById.get(id)!.title,
        before: prevById.get(id)!.content,
        after: nextById.get(id)!.content,
      })),
    })
  }

  const versionNumber = (latest?.versionNumber ?? 0) + 1
  const lessonHashes = Object.fromEntries(snapshotLessons.map((l) => [l.id, l.contentHash]))

  try {
    const [version] = await prisma.$transaction([
      prisma.studyProgramVersion.create({
        data: {
          studyProgramId: programId,
          versionNumber,
          publishedById: userId,
          changeSummary,
          snapshot: { lessons: snapshotLessons } as unknown as Prisma.InputJsonValue,
          lessonHashes: lessonHashes as unknown as Prisma.InputJsonValue,
          changedLessonIds: changedLessonIds
            ? (changedLessonIds as unknown as Prisma.InputJsonValue)
            : Prisma.JsonNull,
        },
      }),
      prisma.studyProgram.update({
        where: { id: programId },
        data: { currentVersionNumber: versionNumber, updatedById: userId },
      }),
    ])

    // Fan the new version out to AUTO-sync enrollments in the background —
    // publish returns immediately; EnrollmentSyncRun rows record per-enrollment
    // progress and make failures retryable.
    launchProgramVersionFanOut(programId, versionNumber)

    return {
      alreadyUpToDate: false,
      version: {
        id: version.id,
        versionNumber: version.versionNumber,
        publishedAt: version.publishedAt,
        changeSummary: version.changeSummary,
        changedLessonIds,
      },
    }
  } catch (error) {
    // Unique (studyProgramId, versionNumber) — a concurrent publish won the race
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      throw new PublishConflictError()
    }
    throw error
  }
}

function isSameContent(prev: SnapshotLesson[], next: SnapshotLesson[]): boolean {
  if (prev.length !== next.length) return false
  const prevById = new Map(prev.map((l) => [l.id, l]))
  return next.every((lesson) => {
    const before = prevById.get(lesson.id)
    return (
      before !== undefined &&
      before.contentHash === lesson.contentHash &&
      before.dayNumber === lesson.dayNumber
    )
  })
}

function diffLessons(prev: SnapshotLesson[], next: SnapshotLesson[]): ChangedLessonIds {
  const prevById = new Map(prev.map((l) => [l.id, l]))
  const nextById = new Map(next.map((l) => [l.id, l]))

  const added = next.filter((l) => !prevById.has(l.id)).map((l) => l.id)
  const removed = prev.filter((l) => !nextById.has(l.id)).map((l) => l.id)
  const changed = next
    .filter((l) => {
      const before = prevById.get(l.id)
      return before !== undefined && before.contentHash !== l.contentHash
    })
    .map((l) => l.id)
  // Moved = same content, different day (content changes already cover the rest)
  const moved = next
    .filter((l) => {
      const before = prevById.get(l.id)
      return (
        before !== undefined &&
        before.contentHash === l.contentHash &&
        before.dayNumber !== l.dayNumber
      )
    })
    .map((l) => l.id)

  return { added, changed, removed, moved }
}

function pickDayTitle(lesson: SnapshotLesson): { dayNumber: number; title: string | null } {
  return { dayNumber: lesson.dayNumber, title: lesson.title }
}
