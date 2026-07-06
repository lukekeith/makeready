/**
 * Lesson Time Estimate Service
 *
 * Calculates estimated completion time for lessons based on their activities.
 * - VIDEO: Uses video.duration (seconds)
 * - READ: Word count ÷ 200 WPM
 * - USER_INPUT: Fixed 3 minutes
 *
 * Stores the result as `estimatedMinutes` on Lesson and LessonSchedule models.
 */

import { prisma } from '../lib/prisma.js'

const READING_WPM = 200
const USER_INPUT_SECONDS = 180 // 3 minutes

/**
 * Strip markdown formatting to get plain text for word counting.
 */
function stripMarkdown(md: string): string {
  return md
    .replace(/```[\s\S]*?```/g, '') // fenced code blocks
    .replace(/`[^`]*`/g, '') // inline code
    .replace(/!\[.*?\]\(.*?\)/g, '') // images
    .replace(/\[([^\]]*)\]\(.*?\)/g, '$1') // links → keep text
    .replace(/^#{1,6}\s+/gm, '') // headings
    .replace(/[*_~]/g, '') // bold, italic, strikethrough
    .replace(/^>\s+/gm, '') // blockquotes
    .replace(/^[-*+]\s+/gm, '') // unordered list markers
    .replace(/^\d+\.\s+/gm, '') // ordered list markers
    .replace(/\|/g, '') // table pipes
    .replace(/---+/g, '') // horizontal rules
    .replace(/\n+/g, ' ') // collapse newlines
    .trim()
}

/**
 * Count words in a markdown string.
 */
function countWords(text: string): number {
  const stripped = stripMarkdown(text)
  if (!stripped) return 0
  return stripped.split(/\s+/).filter(Boolean).length
}

/**
 * Calculate time estimate in seconds for a single activity.
 */
export function activityEstimateSeconds(activity: {
  activityType: string
  readContent?: string | null
  readBlocks?: Array<{ content: string | null }>
  video?: { duration: number | null } | null
  youtubeStartSeconds?: number | null
  youtubeEndSeconds?: number | null
}): number {
  switch (activity.activityType) {
    case 'VIDEO':
      return activity.video?.duration ?? 0

    case 'YOUTUBE': {
      // If start/end are set, use the clip duration
      if (activity.youtubeStartSeconds != null && activity.youtubeEndSeconds != null) {
        return Math.max(0, activity.youtubeEndSeconds - activity.youtubeStartSeconds)
      }
      // No clip boundaries — no reliable estimate without API key
      return 0
    }

    case 'READ':
    case 'EXEGESIS': {
      let totalWords = 0
      if (activity.readBlocks && activity.readBlocks.length > 0) {
        for (const block of activity.readBlocks) {
          if (block.content) totalWords += countWords(block.content)
        }
      } else if (activity.readContent) {
        totalWords = countWords(activity.readContent)
      }
      return Math.ceil((totalWords / READING_WPM) * 60)
    }

    case 'USER_INPUT':
      return USER_INPUT_SECONDS

    default:
      return 0
  }
}

/**
 * Recalculate and persist the time estimate for a Lesson.
 * Returns the new estimatedMinutes value.
 */
export async function recalculateLessonEstimate(lessonId: string): Promise<number | null> {
  const activities = await prisma.lessonActivity.findMany({
    where: { lessonId },
    select: {
      id: true,
      activityType: true,
      readContent: true,
      readBlocks: { select: { content: true } },
      video: { select: { duration: true } },
      youtubeStartSeconds: true,
      youtubeEndSeconds: true,
    },
  })

  if (activities.length === 0) {
    await prisma.lesson.update({
      where: { id: lessonId },
      data: { estimatedMinutes: null },
    })
    return null
  }

  // Calculate and store per-activity estimates
  let totalSeconds = 0
  for (const activity of activities) {
    const seconds = activityEstimateSeconds(activity)
    totalSeconds += seconds
    await prisma.lessonActivity.update({
      where: { id: activity.id },
      data: { estimatedSeconds: seconds > 0 ? seconds : null },
    })
  }

  const estimatedMinutes = totalSeconds > 0 ? Math.max(1, Math.ceil(totalSeconds / 60)) : null

  await prisma.lesson.update({
    where: { id: lessonId },
    data: { estimatedMinutes },
  })

  return estimatedMinutes
}

/**
 * Recalculate and persist the time estimate for a LessonSchedule (enrolled lesson).
 * Returns the new estimatedMinutes value.
 */
export async function recalculateScheduledLessonEstimate(
  lessonScheduleId: string
): Promise<number | null> {
  // Only the current version's activities count toward the estimate —
  // synced schedules also carry prior versions' rows for pinned members
  const schedule = await prisma.lessonSchedule.findUnique({
    where: { id: lessonScheduleId },
    select: { currentVersionId: true },
  })
  const activities = await prisma.scheduledLessonActivity.findMany({
    where: {
      lessonScheduleId,
      ...(schedule?.currentVersionId
        ? { OR: [{ versionId: schedule.currentVersionId }, { versionId: null }] }
        : {}),
    },
    select: {
      id: true,
      type: true,
      readContent: true,
      readBlocks: { select: { content: true } },
      video: { select: { duration: true } },
      youtubeStartSeconds: true,
      youtubeEndSeconds: true,
    },
  })

  if (activities.length === 0) {
    await prisma.lessonSchedule.update({
      where: { id: lessonScheduleId },
      data: { estimatedMinutes: null },
    })
    return null
  }

  // Calculate and store per-activity estimates
  let totalSeconds = 0
  for (const activity of activities) {
    const seconds = activityEstimateSeconds({ ...activity, activityType: activity.type })
    totalSeconds += seconds
    await prisma.scheduledLessonActivity.update({
      where: { id: activity.id },
      data: { estimatedSeconds: seconds > 0 ? seconds : null },
    })
  }

  const estimatedMinutes = totalSeconds > 0 ? Math.max(1, Math.ceil(totalSeconds / 60)) : null

  await prisma.lessonSchedule.update({
    where: { id: lessonScheduleId },
    data: { estimatedMinutes },
  })

  return estimatedMinutes
}
