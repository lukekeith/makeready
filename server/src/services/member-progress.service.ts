import { prisma } from '../lib/prisma.js'
import {
  resolveVersionId,
  filterActivitiesToVersion,
  findProgressForActivity,
  buildLineageMap,
  carryForwardMemberProgress,
} from './lesson-version-resolution.js'
import type {
  MemberActivityProgress,
  MemberVideoProgress,
  MemberLessonProgress,
  Prisma,
} from '../generated/prisma/index.js'

// ============================================================================
// Types
// ============================================================================

export type LessonStatus = 'completed' | 'in_progress' | 'not_started' | 'upcoming'

export interface LessonSummary {
  lessonScheduleId: string
  code: string | null
  dayNumber: number
  scheduledDate: Date
  estimatedMinutes: number | null
  status: LessonStatus
  completionPercentage: number
  activitiesCompleted: number
  activitiesTotal: number
  completedAt: Date | null // When the lesson was marked complete (all activities done)
  studyProgram: {
    id: string
    name: string
    coverImageUrl: string | null
  }
  group: {
    id: string
    name: string
  }
}

export interface ActivityProgressDetail {
  id: string
  type: string
  orderNumber: number
  title: string
  estimatedSeconds: number | null
  helpTitle: string | null
  helpDescription: string | null
  helpAlwaysVisible: boolean
  helpIcon: string | null
  readContent: string | null
  videoUrl: string | null
  video: {
    id: string
    title: string | null
    playbackUrl: string | null
    thumbnailUrl: string | null
    duration: number | null
    status: string
  } | null
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
    id: string
    orderNumber: number
    title: string | null
    content: string | null
    isLocked: boolean
    sourceReferenceId: string | null
  }>
  progress: {
    completedAt: Date | null
    startedAt: Date | null
    exegesisVisitedHighlightIds?: string[] | null
  } | null
  videoProgress: {
    watchedSeconds: number
    totalDuration: number | null
    watchPercentage: number
    completedAt: Date | null
  } | null
  notes: Array<{
    id: string
    type: string
    content: string
    createdAt: Date
  }>
}

export interface LessonDetail {
  lessonScheduleId: string
  code: string | null
  dayNumber: number
  scheduledDate: Date
  templateName: string | null
  estimatedMinutes: number | null
  status: LessonStatus
  completionPercentage: number
  completedAt: Date | null // When the lesson was marked complete (all activities done)
  requireResponse: boolean // From enrollment: whether user input is required before step completion
  studyProgram: {
    id: string
    name: string
    description: string | null
    coverImageUrl: string | null
  }
  group: {
    id: string
    name: string
  }
  activities: ActivityProgressDetail[]
}

export interface EnrollmentSummary {
  id: string
  startDate: Date
  endDate: Date
  studyProgram: {
    id: string
    name: string
    days: number
    coverImageUrl: string | null
  }
  group: {
    id: string
    name: string
  }
  progress: {
    totalDays: number
    completedDays: number
    currentDay: number
    daysAhead: number // Positive = ahead, negative = behind
    completionPercentage: number
  }
}

export interface GetMemberLessonsOptions {
  status?: 'all' | 'completed' | 'in_progress' | 'upcoming'
  enrollmentId?: string
  limit?: number
  offset?: number
  isGroupLeader?: boolean
}

export interface PaginatedResult<T> {
  data: T[]
  pagination: {
    total: number
    limit: number
    offset: number
    hasMore: boolean
  }
}

// ============================================================================
// Video Progress Functions
// ============================================================================

/**
 * Save video progress for a member
 * Automatically marks as complete when >= 90% watched
 */
export async function saveVideoProgress(
  memberId: string,
  lessonScheduleId: string,
  lessonActivityId: string,
  watchedSeconds: number,
  totalDuration: number | null
): Promise<{
  success: boolean
  data?: MemberVideoProgress
  error?: string
}> {
  try {
    // Verify the activity is a VIDEO type
    const scheduledActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id: lessonActivityId },
      include: { video: true },
    })

    if (!scheduledActivity || scheduledActivity.type !== 'VIDEO') {
      return { success: false, error: 'Activity is not a video' }
    }

    // Verify lesson schedule exists and member has access
    const schedule = await prisma.lessonSchedule.findUnique({
      where: { id: lessonScheduleId },
      include: {
        enrollment: {
          include: {
            group: {
              include: {
                members: {
                  where: { memberId, isActive: true },
                },
              },
            },
          },
        },
      },
    })

    if (!schedule) {
      return { success: false, error: 'Lesson schedule not found' }
    }

    if (schedule.enrollment.group.members.length === 0) {
      return { success: false, error: 'Member is not part of this group' }
    }

    // Calculate watch percentage
    const effectiveDuration = totalDuration || scheduledActivity.video?.duration || 0
    const watchPercentage = effectiveDuration > 0
      ? Math.min((watchedSeconds / effectiveDuration) * 100, 100)
      : 0

    // Determine if completed (>= 90%)
    const isComplete = watchPercentage >= 90

    const existingVideoProgress = await prisma.memberVideoProgress.findFirst({
      where: {
        memberId,
        lessonScheduleId,
        scheduledActivityId: lessonActivityId,
      },
    })

    const videoProgressData = {
      watchedSeconds,
      totalDuration: effectiveDuration || null,
      watchPercentage,
      completedAt: isComplete ? new Date() : null,
    }

    const videoProgress = existingVideoProgress
      ? await prisma.memberVideoProgress.update({
          where: { id: existingVideoProgress.id },
          data: videoProgressData,
        })
      : await prisma.memberVideoProgress.create({
          data: {
            memberId,
            lessonScheduleId,
            scheduledActivityId: lessonActivityId,
            ...videoProgressData,
          },
        })

    // Check and update lesson completion status
    await checkAndUpdateLessonCompletion(memberId, lessonScheduleId)

    return { success: true, data: videoProgress }
  } catch (error) {
    console.error('Error saving video progress:', error)
    return { success: false, error: 'Failed to save video progress' }
  }
}

/**
 * Get video progress for a member
 */
export async function getVideoProgress(
  memberId: string,
  lessonActivityId: string,
  lessonScheduleId: string
): Promise<{
  success: boolean
  data?: MemberVideoProgress | null
  error?: string
}> {
  try {
    const progress = await prisma.memberVideoProgress.findFirst({
      where: {
        memberId,
        lessonScheduleId,
        scheduledActivityId: lessonActivityId,
      },
    })

    return { success: true, data: progress }
  } catch (error) {
    console.error('Error fetching video progress:', error)
    return { success: false, error: 'Failed to fetch video progress' }
  }
}

// ============================================================================
// Lesson Progress Functions
// ============================================================================

/**
 * Determine if an activity is complete
 * - VIDEO activities: watchPercentage >= 90 (completedAt set on MemberVideoProgress)
 * - READ activities: completedAt set on MemberActivityProgress
 * - USER_INPUT activities: completedAt set on MemberActivityProgress
 */
function isActivityComplete(
  activityType: string,
  activityProgress: MemberActivityProgress | null,
  videoProgress: MemberVideoProgress | null
): boolean {
  if (activityType === 'VIDEO') {
    return videoProgress?.completedAt !== null && videoProgress?.completedAt !== undefined
  }
  return activityProgress?.completedAt !== null && activityProgress?.completedAt !== undefined
}

/**
 * Check if all activities in a lesson are complete and update MemberLessonProgress
 * This should be called after any activity or video progress is saved
 * @returns The updated MemberLessonProgress record
 */
export async function checkAndUpdateLessonCompletion(
  memberId: string,
  lessonScheduleId: string
): Promise<{
  success: boolean
  data?: MemberLessonProgress
  lessonCompleted?: boolean
  error?: string
}> {
  try {
    // Get the lesson schedule with scheduled activities and member progress
    const schedule = await prisma.lessonSchedule.findUnique({
      where: { id: lessonScheduleId },
      include: {
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
        },
        memberProgress: {
          where: { memberId },
        },
        videoProgress: {
          where: { memberId },
        },
        lessonProgress: {
          where: { memberId },
        },
      },
    })

    if (!schedule) {
      return { success: false, error: 'Lesson schedule not found' }
    }

    // Completion is judged against the version this member actually sees
    const existingPin = schedule.lessonProgress[0]?.pinnedVersionId ?? null
    const resolvedVersionId = resolveVersionId(schedule, existingPin)
    const activities = filterActivitiesToVersion(schedule.scheduledActivities, resolvedVersionId)
    const lineageById = buildLineageMap(schedule.scheduledActivities)
    const activitiesTotal = activities.length

    if (activitiesTotal === 0) {
      // No activities means nothing to complete
      return { success: true, lessonCompleted: false }
    }

    // Count completed activities (lineage-aware: progress may still point at
    // a prior version's copy of the same activity)
    let activitiesCompleted = 0
    for (const activity of activities) {
      const activityProgress = findProgressForActivity(activity, schedule.memberProgress, lineageById)
      const videoProgress = findProgressForActivity(activity, schedule.videoProgress, lineageById)

      if (isActivityComplete(activity.type, activityProgress || null, videoProgress || null)) {
        activitiesCompleted++
      }
    }

    const isLessonComplete = activitiesCompleted === activitiesTotal

    // Upsert the MemberLessonProgress record. Completing pins the member to
    // the version they finished (so later syncs never change their record);
    // un-completing releases the pin so they float to the current version.
    const lessonProgress = await prisma.memberLessonProgress.upsert({
      where: {
        memberId_lessonScheduleId: {
          memberId,
          lessonScheduleId,
        },
      },
      update: {
        completedAt: isLessonComplete ? new Date() : null,
        pinnedVersionId: isLessonComplete ? (existingPin ?? resolvedVersionId) : null,
        lastUpdatedAt: new Date(),
      },
      create: {
        memberId,
        lessonScheduleId,
        completedAt: isLessonComplete ? new Date() : null,
        pinnedVersionId: isLessonComplete ? resolvedVersionId : null,
      },
    })

    return {
      success: true,
      data: lessonProgress,
      lessonCompleted: isLessonComplete,
    }
  } catch (error) {
    console.error('Error checking lesson completion:', error)
    return { success: false, error: 'Failed to check lesson completion' }
  }
}

/**
 * Compute lesson completion status
 */
function computeLessonStatus(
  scheduledDate: Date,
  activitiesCompleted: number,
  activitiesTotal: number,
  isGroupLeader: boolean = false
): LessonStatus {
  const today = new Date()
  today.setHours(0, 0, 0, 0)

  const lessonDate = new Date(scheduledDate)
  lessonDate.setHours(0, 0, 0, 0)

  if (activitiesTotal === 0) {
    return lessonDate > today ? 'upcoming' : 'not_started'
  }

  if (activitiesCompleted === activitiesTotal) {
    return 'completed'
  }

  if (activitiesCompleted > 0) {
    return 'in_progress'
  }

  if (lessonDate > today) {
    return isGroupLeader ? 'not_started' : 'upcoming'
  }

  return 'not_started'
}

/**
 * Get all lessons for a member with completion status
 */
export async function getMemberLessons(
  memberId: string,
  options: GetMemberLessonsOptions = {}
): Promise<{
  success: boolean
  data?: PaginatedResult<LessonSummary>
  error?: string
}> {
  try {
    const { status = 'all', enrollmentId, limit = 50, offset = 0, isGroupLeader = false } = options

    // Get member's group memberships
    const memberships = await prisma.groupMember.findMany({
      where: { memberId, isActive: true },
      select: { groupId: true },
    })

    if (memberships.length === 0) {
      return {
        success: true,
        data: {
          data: [],
          pagination: { total: 0, limit, offset, hasMore: false },
        },
      }
    }

    const groupIds = memberships.map((m) => m.groupId)

    // Build where clause for enrollments
    const enrollmentWhere: Prisma.EnrollmentWhereInput = {
      groupId: { in: groupIds },
    }
    if (enrollmentId) {
      enrollmentWhere.id = enrollmentId
    }

    // Get all lesson schedules for member's groups
    const lessonSchedules = await prisma.lessonSchedule.findMany({
      where: {
        enrollment: enrollmentWhere,
      },
      include: {
        lesson: {
          include: {
            studyProgram: {
              select: {
                id: true,
                name: true,
                coverImageUrl: true,
              },
            },
          },
        },
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
        },
        enrollment: {
          select: {
            group: {
              select: {
                id: true,
                name: true,
              },
            },
            // Fallback program branding for schedules whose curriculum lesson
            // was deleted (lesson is null until sync applies the removal)
            studyProgram: {
              select: {
                id: true,
                name: true,
                coverImageUrl: true,
              },
            },
          },
        },
        memberProgress: {
          where: { memberId },
        },
        videoProgress: {
          where: { memberId },
        },
        lessonProgress: {
          where: { memberId },
        },
      },
      orderBy: { scheduledDate: 'desc' },
    })

    // Calculate completion for each lesson
    const lessons: LessonSummary[] = []
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    for (const schedule of lessonSchedules) {
      const hasAnyProgress =
        schedule.memberProgress.length > 0 ||
        schedule.videoProgress.length > 0 ||
        schedule.lessonProgress.length > 0

      // Lessons removed by sync stay visible only where this member has history
      if (schedule.removedAt !== null && !hasAnyProgress) continue

      // Render the version this member sees (pinned at completion ?? current)
      const resolvedVersionId = resolveVersionId(
        schedule,
        schedule.lessonProgress[0]?.pinnedVersionId ?? null
      )
      const activities = filterActivitiesToVersion(schedule.scheduledActivities, resolvedVersionId)
      const lineageById = buildLineageMap(schedule.scheduledActivities)
      const activitiesTotal = activities.length

      // Count completed activities (lineage-aware pre-carry-forward)
      let activitiesCompleted = 0
      for (const activity of activities) {
        const activityProgress = findProgressForActivity(activity, schedule.memberProgress, lineageById)
        const videoProgress = findProgressForActivity(activity, schedule.videoProgress, lineageById)

        if (isActivityComplete(activity.type, activityProgress || null, videoProgress || null)) {
          activitiesCompleted++
        }
      }

      const completionPercentage =
        activitiesTotal > 0 ? Math.round((activitiesCompleted / activitiesTotal) * 100) : 0

      const lessonStatus = computeLessonStatus(
        schedule.scheduledDate,
        activitiesCompleted,
        activitiesTotal,
        isGroupLeader
      )

      // Apply status filter
      if (status !== 'all') {
        if (status === 'completed' && lessonStatus !== 'completed') continue
        if (status === 'in_progress' && lessonStatus !== 'in_progress') continue
        if (status === 'upcoming' && lessonStatus !== 'upcoming' && lessonStatus !== 'not_started')
          continue
      }

      lessons.push({
        lessonScheduleId: schedule.id,
        code: schedule.code,
        dayNumber: schedule.lesson?.dayNumber ?? 0,
        scheduledDate: schedule.scheduledDate,
        estimatedMinutes: schedule.estimatedMinutes,
        status: lessonStatus,
        completionPercentage,
        activitiesCompleted,
        activitiesTotal,
        completedAt: schedule.lessonProgress[0]?.completedAt || null,
        studyProgram: schedule.lesson?.studyProgram ?? schedule.enrollment.studyProgram,
        group: schedule.enrollment.group,
      })
    }

    // Apply pagination
    const total = lessons.length
    const paginatedLessons = lessons.slice(offset, offset + limit)

    return {
      success: true,
      data: {
        data: paginatedLessons,
        pagination: {
          total,
          limit,
          offset,
          hasMore: offset + limit < total,
        },
      },
    }
  } catch (error) {
    console.error('Error fetching member lessons:', error)
    return { success: false, error: 'Failed to fetch lessons' }
  }
}

/**
 * Get detailed lesson info including activities with progress and notes
 */
export async function getMemberLessonDetail(
  memberId: string,
  lessonScheduleId: string,
  isGroupLeader: boolean = false
): Promise<{
  success: boolean
  data?: LessonDetail
  error?: string
}> {
  try {
    // Verify member has access to this lesson
    const schedule = await prisma.lessonSchedule.findUnique({
      where: { id: lessonScheduleId },
      include: {
        lesson: {
          include: {
            studyProgram: {
              select: {
                id: true,
                name: true,
                description: true,
                coverImageUrl: true,
              },
            },
          },
        },
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
          include: {
            video: true,
            sourceReferences: true,
            readBlocks: {
              orderBy: { orderNumber: 'asc' },
              include: {
                theme: { select: { id: true, slug: true, name: true, definition: true } },
                exegesisHighlights: { orderBy: { orderNumber: 'asc' } },
              },
            },
          },
        },
        enrollment: {
          select: {
            requireResponse: true,
            group: {
              include: {
                members: {
                  where: { memberId, isActive: true },
                },
              },
            },
            // Fallback program branding for schedules whose curriculum lesson
            // was deleted (lesson is null until sync applies the removal)
            studyProgram: {
              select: {
                id: true,
                name: true,
                description: true,
                coverImageUrl: true,
              },
            },
          },
        },
        memberProgress: {
          where: { memberId },
        },
        videoProgress: {
          where: { memberId },
        },
        lessonProgress: {
          where: { memberId },
        },
      },
    })

    if (!schedule) {
      return { success: false, error: 'Lesson not found' }
    }

    if (schedule.enrollment.group.members.length === 0) {
      return { success: false, error: 'Member is not part of this group' }
    }

    // Resolve the version this member sees (pinned at completion ?? current)
    const pinnedVersionId = schedule.lessonProgress[0]?.pinnedVersionId ?? null
    const resolvedVersionId = resolveVersionId(schedule, pinnedVersionId)
    const resolvedActivities = filterActivitiesToVersion(
      schedule.scheduledActivities,
      resolvedVersionId
    )

    // Unpinned member on a synced schedule: lazily carry partial progress
    // forward from prior-version copies (matched by lineage), then work with
    // fresh progress rows
    if (pinnedVersionId === null) {
      const carried = await carryForwardMemberProgress({
        memberId,
        lessonScheduleId,
        resolvedActivities,
        allActivities: schedule.scheduledActivities,
        memberProgress: schedule.memberProgress,
        videoProgress: schedule.videoProgress,
      })
      if (carried) {
        schedule.memberProgress = await prisma.memberActivityProgress.findMany({
          where: { memberId, lessonScheduleId },
        })
        schedule.videoProgress = await prisma.memberVideoProgress.findMany({
          where: { memberId, lessonScheduleId },
        })
      }
    }

    // Check and update lesson completion status
    await checkAndUpdateLessonCompletion(memberId, lessonScheduleId)

    // Re-fetch lessonProgress after potential update
    const updatedLessonProgress = await prisma.memberLessonProgress.findUnique({
      where: {
        memberId_lessonScheduleId: {
          memberId,
          lessonScheduleId,
        },
      },
    })

    // Get notes for this lesson's scheduled activities
    const scheduledActivityIds = schedule.scheduledActivities.map((a) => a.id)
    const notes = await prisma.studyNote.findMany({
      where: {
        memberId,
        isActive: true,
        links: {
          some: {
            refType: 'SCHEDULED_ACTIVITY',
            refId: { in: scheduledActivityIds },
          },
        },
      },
      include: {
        links: true,
      },
      orderBy: { createdAt: 'desc' },
    })

    // Build activity details from the resolved version's activities
    const activities: ActivityProgressDetail[] = []
    let activitiesCompleted = 0

    for (const activity of resolvedActivities) {
      const activityProgress = schedule.memberProgress.find(
        (p) => p.scheduledActivityId === activity.id
      )
      const videoProgress = schedule.videoProgress.find(
        (p) => p.scheduledActivityId === activity.id
      )

      const activityNotes = notes.filter((note) =>
        note.links.some(
          (link) => link.refType === 'SCHEDULED_ACTIVITY' && link.refId === activity.id
        )
      )

      if (isActivityComplete(activity.type, activityProgress || null, videoProgress || null)) {
        activitiesCompleted++
      }

      activities.push({
        id: activity.id,
        type: activity.type,
        orderNumber: activity.orderNumber,
        title: activity.title,
        estimatedSeconds: activity.estimatedSeconds,
        helpTitle: activity.helpTitle,
        helpDescription: activity.helpDescription,
        helpAlwaysVisible: activity.helpAlwaysVisible,
        helpIcon: activity.helpIcon,
        readContent: activity.readContent,
        videoUrl: activity.videoUrl,
        video: activity.video
          ? {
              id: activity.video.id,
              title: activity.video.title,
              playbackUrl: activity.video.playbackUrl,
              thumbnailUrl: activity.video.thumbnailUrl,
              duration: activity.video.duration,
              status: activity.video.status,
            }
          : null,
        sourceReferences: activity.sourceReferences.map((ref) => ({
          id: ref.id,
          sourceType: ref.sourceType,
          passageReference: ref.passageReference,
          bookNumber: ref.bookNumber,
          bookName: ref.bookName,
          chapterStart: ref.chapterStart,
          chapterEnd: ref.chapterEnd,
          verseStart: ref.verseStart,
          verseEnd: ref.verseEnd,
        })),
        readBlocks: activity.readBlocks.map((block) => ({
          id: block.id,
          orderNumber: block.orderNumber,
          title: block.title,
          content: block.content,
          contentFormat: (block as any).contentFormat,
          isLocked: block.isLocked,
          sourceReferenceId: block.sourceReferenceId,
          themeId: block.themeId,
          backgroundImageUrl: (block as any).backgroundImageUrl ?? null,
          backgroundColor: (block as any).backgroundColor ?? null,
          backgroundOverlayOpacity: (block as any).backgroundOverlayOpacity ?? null,
          fontSize: (block as any).fontSize ?? null,
          selections: (block as any).selections ?? null,
          exegesisHighlights: (block as any).exegesisHighlights
            ? (block as any).exegesisHighlights.map((h: any) => ({
                id: h.id,
                orderNumber: h.orderNumber,
                start: h.start,
                end: h.end,
                noteMarkdown: h.noteMarkdown,
              }))
            : [],
          theme: block.theme
            ? {
                id: block.theme.id,
                slug: block.theme.slug,
                name: block.theme.name,
                definition: block.theme.definition,
              }
            : null,
        })),
        progress: activityProgress
          ? {
              completedAt: activityProgress.completedAt,
              startedAt: activityProgress.startedAt,
              exegesisVisitedHighlightIds: (activityProgress as any).exegesisVisitedHighlightIds ?? null,
            }
          : null,
        videoProgress: videoProgress
          ? {
              watchedSeconds: videoProgress.watchedSeconds,
              totalDuration: videoProgress.totalDuration,
              watchPercentage: videoProgress.watchPercentage,
              completedAt: videoProgress.completedAt,
            }
          : null,
        notes: activityNotes.map((note) => ({
          id: note.id,
          type: note.type,
          content: note.content,
          createdAt: note.createdAt,
        })),
      })
    }

    const activitiesTotal = resolvedActivities.length
    const completionPercentage =
      activitiesTotal > 0 ? Math.round((activitiesCompleted / activitiesTotal) * 100) : 0

    const lessonStatus = computeLessonStatus(
      schedule.scheduledDate,
      activitiesCompleted,
      activitiesTotal,
      isGroupLeader
    )

    return {
      success: true,
      data: {
        lessonScheduleId: schedule.id,
        code: schedule.code,
        dayNumber: schedule.lesson?.dayNumber ?? 0,
        scheduledDate: schedule.scheduledDate,
        templateName: schedule.templateName,
        estimatedMinutes: schedule.estimatedMinutes,
        status: lessonStatus,
        completionPercentage,
        completedAt: updatedLessonProgress?.completedAt || null,
        requireResponse: schedule.enrollment.requireResponse,
        studyProgram: schedule.lesson?.studyProgram ?? schedule.enrollment.studyProgram,
        group: {
          id: schedule.enrollment.group.id,
          name: schedule.enrollment.group.name,
        },
        activities,
      },
    }
  } catch (error) {
    console.error('Error fetching lesson detail:', error)
    return { success: false, error: 'Failed to fetch lesson detail' }
  }
}

// ============================================================================
// Enrollment Progress Functions
// ============================================================================

/**
 * Get all enrollments for a member with progress summary
 */
export async function getMemberEnrollments(
  memberId: string
): Promise<{
  success: boolean
  data?: EnrollmentSummary[]
  error?: string
}> {
  try {
    // Get member's group memberships
    const memberships = await prisma.groupMember.findMany({
      where: { memberId, isActive: true },
      select: { groupId: true },
    })

    if (memberships.length === 0) {
      return { success: true, data: [] }
    }

    const groupIds = memberships.map((m) => m.groupId)

    // Get all enrollments for member's groups
    const enrollments = await prisma.enrollment.findMany({
      where: {
        groupId: { in: groupIds },
      },
      include: {
        studyProgram: {
          select: {
            id: true,
            name: true,
            days: true,
            coverImageUrl: true,
          },
        },
        group: {
          select: {
            id: true,
            name: true,
          },
        },
        lessonSchedules: {
          where: { removedAt: null },
          include: {
            scheduledActivities: {
              orderBy: { orderNumber: 'asc' },
            },
            memberProgress: {
              where: { memberId },
            },
            videoProgress: {
              where: { memberId },
            },
            lessonProgress: {
              where: { memberId },
            },
          },
          orderBy: { scheduledDate: 'asc' },
        },
      },
      orderBy: { startDate: 'desc' },
    })

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const enrollmentSummaries: EnrollmentSummary[] = enrollments.map((enrollment) => {
      const totalDays = enrollment.lessonSchedules.length
      let completedDays = 0
      let currentDay = 0

      for (let i = 0; i < enrollment.lessonSchedules.length; i++) {
        const schedule = enrollment.lessonSchedules[i]
        const scheduleDate = new Date(schedule.scheduledDate)
        scheduleDate.setHours(0, 0, 0, 0)

        // Determine current day (most recent past day or today's day)
        if (scheduleDate <= today) {
          currentDay = i + 1
        }

        // Count completed days (all activities of the member's resolved version complete)
        const resolvedVersionId = resolveVersionId(
          schedule,
          schedule.lessonProgress[0]?.pinnedVersionId ?? null
        )
        const activities = filterActivitiesToVersion(schedule.scheduledActivities, resolvedVersionId)
        const lineageById = buildLineageMap(schedule.scheduledActivities)
        let allComplete = activities.length > 0

        for (const activity of activities) {
          const activityProgress = findProgressForActivity(activity, schedule.memberProgress, lineageById)
          const videoProgress = findProgressForActivity(activity, schedule.videoProgress, lineageById)

          if (!isActivityComplete(activity.type, activityProgress || null, videoProgress || null)) {
            allComplete = false
            break
          }
        }

        if (allComplete && activities.length > 0) {
          completedDays++
        }
      }

      // Calculate days ahead/behind
      // If current day is 5 and completed is 7, they're +2 days ahead
      // If current day is 5 and completed is 3, they're -2 days behind
      const daysAhead = completedDays - currentDay

      const completionPercentage =
        totalDays > 0 ? Math.round((completedDays / totalDays) * 100) : 0

      return {
        id: enrollment.id,
        startDate: enrollment.startDate,
        endDate: enrollment.endDate,
        studyProgram: enrollment.studyProgram,
        group: enrollment.group,
        progress: {
          totalDays,
          completedDays,
          currentDay,
          daysAhead,
          completionPercentage,
        },
      }
    })

    return { success: true, data: enrollmentSummaries }
  } catch (error) {
    console.error('Error fetching member enrollments:', error)
    return { success: false, error: 'Failed to fetch enrollments' }
  }
}

/**
 * Get detailed enrollment progress with day-by-day breakdown
 */
export async function getEnrollmentProgress(
  memberId: string,
  enrollmentId: string
): Promise<{
  success: boolean
  data?: {
    enrollment: EnrollmentSummary
    lessons: Array<{
      dayNumber: number
      lessonScheduleId: string
      scheduledDate: Date
      status: LessonStatus
      completionPercentage: number
    }>
  }
  error?: string
}> {
  try {
    // Verify member has access
    const enrollment = await prisma.enrollment.findUnique({
      where: { id: enrollmentId },
      include: {
        studyProgram: {
          select: {
            id: true,
            name: true,
            days: true,
            coverImageUrl: true,
          },
        },
        group: {
          include: {
            members: {
              where: { memberId, isActive: true },
            },
          },
        },
        lessonSchedules: {
          include: {
            lesson: {
              select: { dayNumber: true },
            },
            scheduledActivities: {
              orderBy: { orderNumber: 'asc' },
            },
            memberProgress: {
              where: { memberId },
            },
            videoProgress: {
              where: { memberId },
            },
          },
          orderBy: { scheduledDate: 'asc' },
        },
      },
    })

    if (!enrollment) {
      return { success: false, error: 'Enrollment not found' }
    }

    if (enrollment.group.members.length === 0) {
      return { success: false, error: 'Member is not part of this group' }
    }

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const totalDays = enrollment.lessonSchedules.length
    let completedDays = 0
    let currentDay = 0

    const lessons = enrollment.lessonSchedules.map((schedule, i) => {
      const scheduleDate = new Date(schedule.scheduledDate)
      scheduleDate.setHours(0, 0, 0, 0)

      if (scheduleDate <= today) {
        currentDay = i + 1
      }

      const resolvedVersionId = resolveVersionId(schedule, null)
      const activities = filterActivitiesToVersion(schedule.scheduledActivities, resolvedVersionId)
      const lineageById = buildLineageMap(schedule.scheduledActivities)
      const activitiesTotal = activities.length
      let activitiesCompleted = 0

      for (const activity of activities) {
        const activityProgress = findProgressForActivity(activity, schedule.memberProgress, lineageById)
        const videoProgress = findProgressForActivity(activity, schedule.videoProgress, lineageById)

        if (isActivityComplete(activity.type, activityProgress || null, videoProgress || null)) {
          activitiesCompleted++
        }
      }

      if (activitiesCompleted === activitiesTotal && activitiesTotal > 0) {
        completedDays++
      }

      const completionPercentage =
        activitiesTotal > 0 ? Math.round((activitiesCompleted / activitiesTotal) * 100) : 0

      const status = computeLessonStatus(
        schedule.scheduledDate,
        activitiesCompleted,
        activitiesTotal
      )

      return {
        dayNumber: (schedule.lesson as any).dayNumber,
        lessonScheduleId: schedule.id,
        scheduledDate: schedule.scheduledDate,
        status,
        completionPercentage,
      }
    })

    const daysAhead = completedDays - currentDay
    const completionPercentage =
      totalDays > 0 ? Math.round((completedDays / totalDays) * 100) : 0

    return {
      success: true,
      data: {
        enrollment: {
          id: enrollment.id,
          startDate: enrollment.startDate,
          endDate: enrollment.endDate,
          studyProgram: enrollment.studyProgram,
          group: {
            id: enrollment.group.id,
            name: enrollment.group.name,
          },
          progress: {
            totalDays,
            completedDays,
            currentDay,
            daysAhead,
            completionPercentage,
          },
        },
        lessons,
      },
    }
  } catch (error) {
    console.error('Error fetching enrollment progress:', error)
    return { success: false, error: 'Failed to fetch enrollment progress' }
  }
}

// ============================================================================
// Group Studies Functions
// ============================================================================

export interface GroupStudyLesson {
  lessonScheduleId: string
  lessonId: string
  dayNumber: number
  scheduledDate: Date
  status: 'completed' | 'in_progress' | 'available'
  activityCount: number
  completedActivityCount: number
  completedAt: Date | null
}

export interface GroupStudyEnrollment {
  id: string
  studyProgram: {
    id: string
    name: string
    description: string | null
    coverImageUrl: string | null
    totalDays: number
  }
  startDate: Date
  endDate: Date | null
  availableLessons: GroupStudyLesson[]
  totalLessons: number
  availableLessonCount: number
  completedLessonCount: number
}

export interface GroupStudiesResponse {
  group: {
    id: string
    name: string
    coverImageUrl: string | null
  }
  enrollments: GroupStudyEnrollment[]
}

/**
 * Get available studies for a specific group
 * Returns enrollments with lessons scheduled for today or earlier
 */
export async function getGroupStudies(
  memberId: string,
  groupId: string,
  isGroupLeader: boolean = false
): Promise<{
  success: boolean
  data?: GroupStudiesResponse
  error?: string
}> {
  try {
    // Verify member is active in this group
    const membership = await prisma.groupMember.findFirst({
      where: {
        groupId,
        memberId,
        isActive: true,
      },
    })

    if (!membership) {
      return { success: false, error: 'Not a member of this group' }
    }

    // Get group info
    const group = await prisma.group.findUnique({
      where: { id: groupId },
      select: {
        id: true,
        name: true,
        coverImageUrl: true,
      },
    })

    if (!group) {
      return { success: false, error: 'Group not found' }
    }

    // Get today's date at midnight for comparison
    const today = new Date()
    today.setHours(23, 59, 59, 999) // End of today

    // Get all enrollments for this group with lesson schedules
    const enrollments = await prisma.enrollment.findMany({
      where: {
        groupId,
      },
      include: {
        studyProgram: {
          select: {
            id: true,
            name: true,
            description: true,
            coverImageUrl: true,
            days: true,
          },
        },
        lessonSchedules: {
          include: {
            lesson: {
              select: { id: true, dayNumber: true },
            },
            scheduledActivities: {
              orderBy: { orderNumber: 'asc' },
            },
            memberProgress: {
              where: { memberId },
            },
            videoProgress: {
              where: { memberId },
            },
            lessonProgress: {
              where: { memberId },
            },
          },
          orderBy: { scheduledDate: 'asc' },
        },
      },
      orderBy: { startDate: 'desc' },
    })

    const enrollmentResults: GroupStudyEnrollment[] = []

    for (const enrollment of enrollments) {
      const availableLessons: GroupStudyLesson[] = []
      let completedLessonCount = 0

      for (const schedule of enrollment.lessonSchedules) {
        const scheduleDate = new Date(schedule.scheduledDate)

        // Only include lessons scheduled for today or earlier (group leaders see all)
        if (isGroupLeader || scheduleDate <= today) {
          const resolvedVersionId = resolveVersionId(schedule, null)
          const activities = filterActivitiesToVersion(schedule.scheduledActivities, resolvedVersionId)
          const lineageById = buildLineageMap(schedule.scheduledActivities)
          const activityCount = activities.length
          let completedActivityCount = 0

          for (const activity of activities) {
            const activityProgress = findProgressForActivity(activity, schedule.memberProgress, lineageById)
            const videoProgress = findProgressForActivity(activity, schedule.videoProgress, lineageById)

            if (isActivityComplete(activity.type, activityProgress || null, videoProgress || null)) {
              completedActivityCount++
            }
          }

          // Determine lesson status
          let status: 'completed' | 'in_progress' | 'available'
          if (completedActivityCount === activityCount && activityCount > 0) {
            status = 'completed'
            completedLessonCount++
          } else if (completedActivityCount > 0) {
            status = 'in_progress'
          } else {
            status = 'available'
          }

          if (!schedule.lesson) continue // orphaned schedule: curriculum lesson deleted, sync pending

          availableLessons.push({
            lessonScheduleId: schedule.id,
            lessonId: schedule.lesson.id,
            dayNumber: schedule.lesson.dayNumber,
            scheduledDate: schedule.scheduledDate,
            status,
            activityCount,
            completedActivityCount,
            completedAt: schedule.lessonProgress[0]?.completedAt || null,
          })
        }
      }

      enrollmentResults.push({
        id: enrollment.id,
        studyProgram: {
          id: enrollment.studyProgram.id,
          name: enrollment.studyProgram.name,
          description: enrollment.studyProgram.description,
          coverImageUrl: enrollment.studyProgram.coverImageUrl,
          totalDays: enrollment.studyProgram.days,
        },
        startDate: enrollment.startDate,
        endDate: enrollment.endDate,
        availableLessons,
        totalLessons: enrollment.lessonSchedules.length,
        availableLessonCount: availableLessons.length,
        completedLessonCount,
      })
    }

    return {
      success: true,
      data: {
        group,
        enrollments: enrollmentResults,
      },
    }
  } catch (error) {
    console.error('Error fetching group studies:', error)
    return { success: false, error: 'Failed to fetch group studies' }
  }
}
