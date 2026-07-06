/**
 * Lesson Content Hash Service
 *
 * Produces a canonical, deterministic hash of a curriculum lesson's content.
 * This single definition of "lesson content" powers the study-sync feature:
 *
 * - "Publish updates" hashes every lesson of a program into
 *   StudyProgramVersion.lessonHashes (and stores the canonical objects as the
 *   version snapshot).
 * - Enrollment creation stamps the hash of the copied curriculum lesson onto
 *   the schedule's LessonScheduleVersion.sourceContentHash.
 * - Drift detection = compare the latest program version's lesson hash against
 *   each schedule's currentVersion.sourceContentHash. Equal hash = in sync.
 *
 * Only content-bearing fields participate. Derived/volatile fields (time
 * estimates, oEmbed thumbnails, timestamps, row ids) are excluded so they can
 * never cause false drift. The hash is prefixed with a canonicalization
 * version ("v1:") so the algorithm can evolve without old hashes being
 * misread as drift-free.
 */

import { createHash } from 'crypto'

/** Prisma include shape that loads everything hashLessonContent needs. */
export const LESSON_CONTENT_INCLUDE = {
  activities: {
    orderBy: { orderNumber: 'asc' as const },
    include: {
      sourceReferences: true,
      readBlocks: {
        orderBy: { orderNumber: 'asc' as const },
        include: { exegesisHighlights: { orderBy: { orderNumber: 'asc' as const } } },
      },
    },
  },
} as const

const HASH_VERSION = 'v1'

interface SourceReferenceContent {
  sourceType: string
  passageReference: string | null
  bookNumber: number | null
  bookName: string | null
  chapterStart: number | null
  chapterEnd: number | null
  verseStart: number | null
  verseEnd: number | null
}

interface ReadBlockContent {
  orderNumber: number
  title: string | null
  content: string | null
  isLocked: boolean
  contentFormat: string
  themeId: string | null
  backgroundImageUrl: string | null
  backgroundColor: string | null
  backgroundOverlayOpacity: number | null
  fontSize: string | null
  selections: unknown
  sourceReferenceId: string | null
  exegesisHighlights: Array<{ orderNumber: number; start: number; end: number; noteMarkdown: string }>
}

interface ActivityContent {
  type: string
  orderNumber: number
  title: string
  helpTitle: string | null
  helpDescription: string | null
  helpAlwaysVisible: boolean
  helpIcon: string | null
  placeholder: string | null
  isHelpEnabled: boolean
  referenceTitle: string | null
  readContent: string | null
  videoId: string | null
  themeId: string | null
  youtubeUrl: string | null
  youtubeStartSeconds: number | null
  youtubeEndSeconds: number | null
  sourceReferences: SourceReferenceContent[]
  readBlocks: ReadBlockContent[]
}

export interface LessonContent {
  title: string | null
  activities: ActivityContent[]
}

/** Minimal structural type accepted from Prisma (LessonActivity + relations). */
interface ActivityRow {
  id: string
  activityType: string
  orderNumber: number
  title: string
  helpTitle: string | null
  helpDescription: string | null
  helpAlwaysVisible: boolean
  helpIcon: string | null
  placeholder: string | null
  isHelpEnabled?: boolean
  referenceTitle: string | null
  readContent: string | null
  videoId: string | null
  themeId?: string | null
  youtubeUrl: string | null
  youtubeStartSeconds: number | null
  youtubeEndSeconds: number | null
  sourceReferences?: Array<SourceReferenceContent & { id: string }>
  readBlocks?: Array<{
    orderNumber: number
    title: string | null
    content: string | null
    isLocked: boolean
    contentFormat: string
    themeId: string | null
    backgroundImageUrl: string | null
    backgroundColor: string | null
    backgroundOverlayOpacity: number | null
    fontSize: string | null
    selections: unknown
    sourceReferenceId: string | null
    exegesisHighlights?: Array<{ orderNumber: number; start: number; end: number; noteMarkdown: string }>
  }>
}

export interface LessonRow {
  title: string | null
  activities: ActivityRow[]
}

/**
 * Extract the canonical content object for a curriculum lesson.
 * Also used as the per-lesson entry in StudyProgramVersion.snapshot.
 */
export function canonicalLessonContent(lesson: LessonRow): LessonContent {
  const activities = [...lesson.activities]
    .sort((a, b) => a.orderNumber - b.orderNumber)
    .map((activity): ActivityContent => {
      // Read-block source references point at ActivitySourceReference rows by
      // id; ids differ between curriculum and enrolled copies, so blocks
      // reference them by position within the activity's (sorted) ref list.
      const sortedRefs = [...(activity.sourceReferences ?? [])].sort(refCompare)
      const refIndexById = new Map(sortedRefs.map((ref, index) => [ref.id, index]))

      return {
        type: activity.activityType,
        orderNumber: activity.orderNumber,
        title: activity.title,
        helpTitle: activity.helpTitle,
        helpDescription: activity.helpDescription,
        helpAlwaysVisible: activity.helpAlwaysVisible,
        helpIcon: activity.helpIcon,
        placeholder: activity.placeholder,
        isHelpEnabled: activity.isHelpEnabled ?? true,
        referenceTitle: activity.referenceTitle,
        readContent: activity.readContent,
        videoId: activity.videoId,
        themeId: activity.themeId ?? null,
        youtubeUrl: activity.youtubeUrl,
        youtubeStartSeconds: activity.youtubeStartSeconds,
        youtubeEndSeconds: activity.youtubeEndSeconds,
        sourceReferences: sortedRefs.map(({ id: _id, ...content }) => content),
        readBlocks: [...(activity.readBlocks ?? [])]
          .sort((a, b) => a.orderNumber - b.orderNumber)
          .map((block): ReadBlockContent => ({
            orderNumber: block.orderNumber,
            title: block.title,
            content: block.content,
            isLocked: block.isLocked,
            contentFormat: block.contentFormat,
            themeId: block.themeId,
            backgroundImageUrl: block.backgroundImageUrl,
            backgroundColor: block.backgroundColor,
            backgroundOverlayOpacity: block.backgroundOverlayOpacity,
            fontSize: block.fontSize,
            selections: block.selections ?? null,
            sourceReferenceId:
              block.sourceReferenceId != null
                ? `ref:${refIndexById.get(block.sourceReferenceId) ?? 'unknown'}`
                : null,
            exegesisHighlights: [...(block.exegesisHighlights ?? [])]
              .sort((a, b) => a.orderNumber - b.orderNumber)
              .map((h) => ({
                orderNumber: h.orderNumber,
                start: h.start,
                end: h.end,
                noteMarkdown: h.noteMarkdown,
              })),
          })),
      }
    })

  return { title: lesson.title, activities }
}

/** Canonical content hash for a curriculum lesson, e.g. "v1:3fa9c2…". */
export function hashLessonContent(lesson: LessonRow): string {
  const canonical = stableStringify(canonicalLessonContent(lesson))
  return `${HASH_VERSION}:${createHash('sha256').update(canonical).digest('hex')}`
}

function refCompare(a: SourceReferenceContent, b: SourceReferenceContent): number {
  return (
    (a.bookNumber ?? 0) - (b.bookNumber ?? 0) ||
    (a.chapterStart ?? 0) - (b.chapterStart ?? 0) ||
    (a.verseStart ?? 0) - (b.verseStart ?? 0) ||
    (a.passageReference ?? '').localeCompare(b.passageReference ?? '')
  )
}

/** JSON.stringify with recursively sorted object keys for determinism. */
function stableStringify(value: unknown): string {
  return JSON.stringify(sortKeysDeep(value))
}

function sortKeysDeep(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeysDeep)
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value as Record<string, unknown>)
        .sort()
        .map((key) => [key, sortKeysDeep((value as Record<string, unknown>)[key])])
    )
  }
  return value
}
