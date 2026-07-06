/**
 * Lesson Copy Service
 *
 * Builds the rows that copy a curriculum lesson's activities into an enrolled
 * lesson's activity set (ScheduledLessonActivity + source references + read
 * blocks + exegesis highlights), stamped with the LessonScheduleVersion they
 * belong to and a lineage key for member-progress carry-forward.
 *
 * Shared by enrollment creation, adding a lesson to an existing enrollment,
 * and the study-sync engine when it materializes a new version of an enrolled
 * lesson from updated curriculum.
 */

import { randomUUID } from 'crypto'
import {
  isStableNumberedScriptureMarkdown,
  normalizeScriptureMarkdown,
} from '../utils/scripture-content-normalizer.js'

type ReadBlockOffsetAnnotation =
  | Array<{ start?: unknown; end?: unknown }>
  | null
  | undefined

export function hasReadBlockOffsetAnnotations(
  selections: ReadBlockOffsetAnnotation,
  exegesisHighlights: ReadBlockOffsetAnnotation
): boolean {
  return Boolean((Array.isArray(selections) && selections.length > 0) || (Array.isArray(exegesisHighlights) && exegesisHighlights.length > 0))
}

export function scriptureContentForCopy(
  content: string | null | undefined,
  isScriptureLinked: boolean,
  hasOffsetAnnotations: boolean
): string | null {
  if (!isScriptureLinked) return content ?? null
  if (hasOffsetAnnotations && !isStableNumberedScriptureMarkdown(content)) {
    return content ?? null
  }
  return normalizeScriptureMarkdown(content)
}

/** Curriculum LessonActivity row with the relations the copy needs loaded. */
export interface CurriculumActivityRow {
  id: string
  activityType: string
  orderNumber: number
  title: string
  referenceTitle: string | null
  helpTitle: string | null
  helpDescription: string | null
  helpAlwaysVisible: boolean
  helpIcon: string | null
  readContent: string | null
  videoId: string | null
  videoUrl: string | null
  youtubeUrl?: string | null
  youtubeVideoId?: string | null
  youtubeStartSeconds?: number | null
  youtubeEndSeconds?: number | null
  youtubeThumbnailUrl?: string | null
  estimatedSeconds?: number | null
  sourceReferences: Array<{
    id: string
    sourceType: string
    passageReference: string | null
    bookNumber: number | null
    bookName: string | null
    chapterStart: number | null
    chapterEnd: number | null
    verseStart: number | null
    verseEnd: number | null
  }>
  readBlocks: Array<{
    orderNumber: number
    title: string | null
    content: string | null
    isLocked: boolean
    sourceReferenceId: string | null
    themeId?: string | null
    contentFormat?: string
    backgroundImageUrl?: string | null
    backgroundColor?: string | null
    backgroundOverlayOpacity?: number | null
    fontSize?: string | null
    selections?: unknown
    exegesisHighlights?: Array<{ orderNumber: number; start: number; end: number; noteMarkdown: string }>
  }>
}

export interface LessonCopyRows {
  scheduledActivityData: Array<{
    id: string
    lessonScheduleId: string
    versionId: string
    lineageKey: string
    type: any
    orderNumber: number
    title: string
    referenceTitle: string | null
    helpTitle: string | null
    helpDescription: string | null
    helpAlwaysVisible: boolean
    helpIcon: string | null
    isHelpEnabled: boolean
    readContent: string | null
    videoId: string | null
    videoUrl: string | null
    youtubeUrl: string | null
    youtubeVideoId: string | null
    youtubeStartSeconds: number | null
    youtubeEndSeconds: number | null
    youtubeThumbnailUrl: string | null
    estimatedSeconds: number | null
    sourceLessonActivityId: string
  }>
  sourceRefData: Array<{
    id: string
    scheduledActivityId: string
    sourceType: string
    passageReference: string | null
    bookNumber: number | null
    bookName: string | null
    chapterStart: number | null
    chapterEnd: number | null
    verseStart: number | null
    verseEnd: number | null
  }>
  readBlockData: Array<{
    id: string
    scheduledActivityId: string
    orderNumber: number
    title: string | null
    content: string | null
    isLocked: boolean
    sourceReferenceId: string | null
    themeId: string | null
    contentFormat: string
    backgroundImageUrl: string | null
    backgroundColor: string | null
    backgroundOverlayOpacity: number | null
    fontSize: string | null
    selections: any
  }>
  exegesisHighlightData: Array<{
    id: string
    readBlockId: string
    orderNumber: number
    start: number
    end: number
    noteMarkdown: string
  }>
}

/**
 * Build the insert rows for copying curriculum activities into one enrolled
 * lesson version. Rows are returned (not inserted) so callers can batch
 * many lessons into single createMany calls.
 */
export function buildLessonCopyRows(params: {
  lessonScheduleId: string
  versionId: string
  activities: CurriculumActivityRow[]
}): LessonCopyRows {
  const { lessonScheduleId, versionId, activities } = params

  const rows: LessonCopyRows = {
    scheduledActivityData: [],
    sourceRefData: [],
    readBlockData: [],
    exegesisHighlightData: [],
  }

  for (const activity of activities) {
    const saId = randomUUID()
    rows.scheduledActivityData.push({
      id: saId,
      lessonScheduleId,
      versionId,
      lineageKey: activity.id,
      type: activity.activityType,
      orderNumber: activity.orderNumber,
      title: activity.title,
      referenceTitle: activity.referenceTitle,
      helpTitle: activity.helpTitle,
      helpDescription: activity.helpDescription,
      helpAlwaysVisible: activity.helpAlwaysVisible,
      helpIcon: activity.helpIcon,
      isHelpEnabled: true,
      readContent: activity.readContent,
      videoId: activity.videoId,
      videoUrl: activity.videoUrl,
      youtubeUrl: activity.youtubeUrl ?? null,
      youtubeVideoId: activity.youtubeVideoId ?? null,
      youtubeStartSeconds: activity.youtubeStartSeconds ?? null,
      youtubeEndSeconds: activity.youtubeEndSeconds ?? null,
      youtubeThumbnailUrl: activity.youtubeThumbnailUrl ?? null,
      estimatedSeconds: activity.estimatedSeconds ?? null,
      sourceLessonActivityId: activity.id,
    })

    // Copy source references with link to scheduled activity (preserve mapping)
    const sourceRefIdMap = new Map<string, string>()
    for (const ref of activity.sourceReferences) {
      const newId = randomUUID()
      sourceRefIdMap.set(ref.id, newId)
      rows.sourceRefData.push({
        id: newId,
        scheduledActivityId: saId,
        sourceType: ref.sourceType,
        passageReference: ref.passageReference,
        bookNumber: ref.bookNumber,
        bookName: ref.bookName,
        chapterStart: ref.chapterStart,
        chapterEnd: ref.chapterEnd,
        verseStart: ref.verseStart,
        verseEnd: ref.verseEnd,
      })
    }

    // Copy read blocks with link to scheduled activity (preserve mapping + copy presentation fields)
    for (const block of activity.readBlocks) {
      const newBlockId = randomUUID()

      const exegesisHighlights = block.exegesisHighlights

      const derivedSelections = exegesisHighlights && exegesisHighlights.length > 0
        ? exegesisHighlights.map((h) => ({ start: h.start, end: h.end, style: 'highlight' }))
        : ((block.selections as any) ?? null)

      const sourceReferenceId = block.sourceReferenceId
        ? (sourceRefIdMap.get(block.sourceReferenceId) ?? null)
        : null
      const content = scriptureContentForCopy(
        block.content,
        sourceReferenceId != null,
        hasReadBlockOffsetAnnotations(block.selections as ReadBlockOffsetAnnotation, exegesisHighlights)
      )

      rows.readBlockData.push({
        id: newBlockId,
        scheduledActivityId: saId,
        orderNumber: block.orderNumber,
        title: block.title,
        content,
        isLocked: block.isLocked,
        sourceReferenceId,
        themeId: block.themeId ?? null,
        contentFormat: block.contentFormat ?? 'markdown',
        backgroundImageUrl: block.backgroundImageUrl ?? null,
        backgroundColor: block.backgroundColor ?? null,
        backgroundOverlayOpacity: block.backgroundOverlayOpacity ?? null,
        fontSize: block.fontSize ?? null,
        selections: derivedSelections,
      })

      // Copy exegesis highlights (table) — IDs will differ between program vs scheduled copies
      if (exegesisHighlights && exegesisHighlights.length > 0) {
        for (const h of exegesisHighlights) {
          rows.exegesisHighlightData.push({
            id: randomUUID(),
            readBlockId: newBlockId,
            orderNumber: h.orderNumber,
            start: h.start,
            end: h.end,
            noteMarkdown: h.noteMarkdown,
          })
        }
      }
    }
  }

  return rows
}
