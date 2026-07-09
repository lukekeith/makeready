import { prisma } from '../lib/prisma.js'
import { getMemberLessonDetail } from './member-progress.service.js'
import {
  summarizeLessonCompletion,
  CLAUDE_MODELS,
  type LessonCompletionInput,
} from './claude.js'

// ============================================================================
// AI Lesson Summaries
//
// When a member completes a lesson, we generate two AI summaries with Claude:
//  - lessonSummary: what the lesson and its contents taught (always present)
//  - memberSummary: what the member learned, judged from their input; null
//    when the member entered nothing substantive (analytics relies on null)
//
// Summaries are generated once per (member, lessonSchedule) and stored in
// ai_lesson_summaries. The completion page requests them on load.
// ============================================================================

export interface AiLessonSummaryResult {
  success: boolean
  status?: number
  error?: string
  summary?: {
    lessonSummary: string
    memberSummary: string | null
    createdAt: Date
  }
}

/**
 * Return the stored AI summary for this member + lesson, generating and
 * storing it on first request. Access control and completion state are
 * delegated to getMemberLessonDetail, which verifies group membership and
 * refreshes MemberLessonProgress.completedAt.
 */
export async function getOrCreateAiLessonSummary(
  memberId: string,
  lessonScheduleId: string
): Promise<AiLessonSummaryResult> {
  const existing = await prisma.aiLessonSummary.findUnique({
    where: { memberId_lessonScheduleId: { memberId, lessonScheduleId } },
  })
  if (existing) {
    return {
      success: true,
      summary: {
        lessonSummary: existing.lessonSummary,
        memberSummary: existing.memberSummary,
        createdAt: existing.createdAt,
      },
    }
  }

  // Assemble the lesson exactly as the member experienced it (resolved
  // version, ordered activities, their notes). Also verifies access.
  const detail = await getMemberLessonDetail(memberId, lessonScheduleId)
  if (!detail.success || !detail.data) {
    return {
      success: false,
      status: detail.error === 'Lesson not found' ? 404 : 403,
      error: detail.error ?? 'Access denied',
    }
  }

  if (!detail.data.completedAt) {
    return { success: false, status: 409, error: 'Lesson is not complete yet' }
  }

  const input: LessonCompletionInput = {
    studyProgramName: detail.data.studyProgram.name,
    dayNumber: detail.data.dayNumber,
    lessonTitle: detail.data.templateName,
    activities: detail.data.activities.map((activity) => ({
      type: activity.type,
      title: activity.title,
      helpTitle: activity.helpTitle,
      helpDescription: activity.helpDescription,
      readContent: activity.readContent,
      videoTitle: activity.video?.title ?? null,
      sourceReferences: activity.sourceReferences.map((ref) => ({
        passageReference: ref.passageReference,
      })),
      readBlocks: activity.readBlocks.map((block) => ({
        title: block.title,
        content: block.content,
      })),
      memberNotes: activity.notes.map((note) => ({
        type: note.type,
        content: note.content,
      })),
    })),
  }

  const generated = await summarizeLessonCompletion(input)
  if (!generated) {
    return { success: false, status: 503, error: 'Summary generation unavailable' }
  }

  // Upsert so a concurrent first request can't violate the unique constraint
  const saved = await prisma.aiLessonSummary.upsert({
    where: { memberId_lessonScheduleId: { memberId, lessonScheduleId } },
    create: {
      memberId,
      lessonScheduleId,
      lessonSummary: generated.lessonSummary,
      memberSummary: generated.memberSummary,
      model: CLAUDE_MODELS.opus48,
    },
    update: {},
  })

  return {
    success: true,
    summary: {
      lessonSummary: saved.lessonSummary,
      memberSummary: saved.memberSummary,
      createdAt: saved.createdAt,
    },
  }
}
