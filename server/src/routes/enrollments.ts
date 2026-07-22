import { Router } from 'express'
import { z } from 'zod'
import { randomUUID } from 'crypto'
import QRCode from 'qrcode'
import { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { generateStudyCode } from '../lib/study-code.js'
import { logSuccess, logFailure } from '../lib/activity-log.js'
import { ActivityTypes } from '../lib/activity-types.js'
import { trackActivity } from '../services/activity.js'
import { recalculateScheduledLessonEstimate } from '../services/lesson-estimate.service.js'
import { getUserOrgId } from '../services/media-library.js'
import { getEnrollmentCompletionStats } from '../services/enrollment-analytics.service.js'
import { normalizeScriptureMarkdown, normalizeScriptureVerses } from '../utils/scripture-content-normalizer.js'
import { hashLessonContent } from '../services/lesson-content-hash.js'
import { buildLessonCopyRows, type LessonCopyRows } from '../services/lesson-copy.js'
import { syncEnrollmentToLatest, SyncNotPossibleError } from '../services/enrollment-sync.js'
import { computePendingChanges } from '../services/enrollment-sync-changes.js'
import { resolveNotificationsByDedupeKey } from '../services/notification.js'
import { filterActivitiesToVersion } from '../services/lesson-version-resolution.js'
import { generateScheduleDates } from '../services/enrollment-schedule.js'
import {
  canManageOrgContent,
  enrollmentManageFilter,
  groupManageFilter,
  canManageGroupId,
} from '../services/permission.js'

const router = Router()

// ============================================================================
// Enrollment CRUD
// ============================================================================

/**
 * @openapi
 * /api/enrollments:
 *   post:
 *     tags: [Enrollments]
 *     summary: Create an enrollment
 *     description: |
 *       Enrolls a group in a study program. Creates lesson schedules, calendar events, and welcome post.
 *       Lesson dates are calculated based on enabled days (e.g., Mon, Wed, Fri).
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - groupId
 *               - studyProgramId
 *               - startDate
 *               - enabledDays
 *             properties:
 *               groupId:
 *                 type: string
 *                 format: uuid
 *               studyProgramId:
 *                 type: string
 *                 format: uuid
 *               startDate:
 *                 type: string
 *                 format: date-time
 *               enabledDays:
 *                 type: array
 *                 items:
 *                   type: string
 *                   enum: [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
 *                 minItems: 1
 *               smsTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *                 description: Time for SMS notifications (HH:MM)
 *               timezone:
 *                 type: string
 *               requireResponse:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Enrollment created
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 enrollment:
 *                   $ref: '#/components/schemas/Enrollment'
 *       400:
 *         description: Validation error or program has no lessons
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Group or program not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/enrollments', requireAuth, async (req, res) => {
  try {
    // Log incoming request for debugging
    console.log('📥 Enrollment request received:', JSON.stringify(req.body, null, 2))
    console.log('   User ID:', (req.user as any)?.id)

    const schema = z.object({
      groupId: z.string().uuid(),
      studyProgramId: z.string().uuid(),
      startDate: z.string().datetime(),
      enabledDays: z.array(z.enum(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])).min(1),
      smsTime: z.string().regex(/^\d{2}:\d{2}$/).optional(), // "HH:MM" format
      timezone: z.string().optional(),
      requireResponse: z.boolean().optional(), // Override program default (inherits from program if not specified)
      syncMode: z.enum(['OFF', 'AUTO', 'APPROVAL']).optional(), // "Sync to study": how this enrollment tracks published curriculum updates
    })

    const body = schema.parse(req.body)
    const userId = (req.user as any).id

    console.log('📝 Creating enrollment...')

    // Verify group exists and user has access
    const group = await prisma.group.findFirst({
      where: {
        id: body.groupId,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Verify study program exists and is active
    // Note: Any active program can be used for enrollment (not restricted to creator)
    const program = await prisma.studyProgram.findFirst({
      where: {
        id: body.studyProgramId,
        isActive: true,
      },
      include: {
        template: { select: { id: true, name: true } },
        lessons: {
          orderBy: { dayNumber: 'asc' },
          include: {
            activities: {
              orderBy: { orderNumber: 'asc' },
              include: {
                sourceReferences: true,
                readBlocks: {
                  orderBy: { orderNumber: 'asc' },
                  include: {
                    theme: { select: { id: true, slug: true, name: true } },
                    exegesisHighlights: { orderBy: { orderNumber: 'asc' } },
                  },
                },
              },
            },
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Study program not found' })
    }

    if (!program.isPublished) {
      return res.status(400).json({
        success: false,
        error: 'Cannot enroll in a draft program. The program must be published first.'
      })
    }

    // Validate program has lessons
    if (program.lessons.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Cannot enroll in a study program with no lessons. Please add lessons to the program first.'
      })
    }

    // Calculate lesson schedule dates — one per lesson on the enabled weekdays,
    // walking forward from the start date (shared with the edit/reschedule path).
    const startDate = new Date(body.startDate)
    const scheduleDates = generateScheduleDates(startDate, body.enabledDays, program.lessons.length)
    const endDate = scheduleDates[scheduleDates.length - 1]

    // Pre-generate IDs and codes to use batch operations (avoids PgBouncer transaction timeout)
    const enrollmentId = randomUUID()

    // Generate unique codes for each lesson schedule (for deep linking via SMS)
    const generatedCodes = new Set<string>()
    const generateUniqueCodeForBatch = (): string => {
      let code = generateStudyCode()
      while (generatedCodes.has(code)) {
        code = generateStudyCode()
      }
      generatedCodes.add(code)
      return code
    }

    const scheduleData = program.lessons.map((lesson, i) => ({
      id: randomUUID(),
      code: generateUniqueCodeForBatch(), // 6-char alphanumeric for SMS deep linking
      enrollmentId,
      lessonId: lesson.id,
      scheduledDate: scheduleDates[i],
      lesson, // Keep reference for event creation
    }))

    // Create enrollment with lesson schedules, events, and welcome post
    // Using sequential operations — if any step fails after enrollment creation,
    // we delete the enrollment (cascade handles cleanup)
    console.log(`🔄 Starting enrollment creation for group ${body.groupId}, program ${body.studyProgramId}`)
    console.log(`   Lessons to schedule: ${program.lessons.length}, dates generated: ${scheduleDates.length}`)

    try {
      // Step 1: Create the enrollment
      console.log('   Step 1: Creating enrollment record...')
      await prisma.enrollment.create({
        data: {
          id: enrollmentId,
          groupId: body.groupId,
          studyProgramId: body.studyProgramId,
          startDate,
          endDate,
          enabledDays: JSON.stringify(body.enabledDays),
          smsTime: body.smsTime,
          timezone: body.timezone,
          requireResponse: body.requireResponse ?? program.requireResponse, // Inherit from program if not specified
          // Default new enrollments to AUTO so curriculum updates a leader
          // publishes flow to the group automatically — without this, added
          // days never reached members unless the leader also toggled sync on
          // per enrollment (monday#12268576962).
          syncMode: body.syncMode ?? 'AUTO',
          // The copy is made from live curriculum, which reflects at least the
          // latest published version — so the enrollment starts drift-free.
          syncedProgramVersionNumber: program.currentVersionNumber ?? null,
          createdById: userId,
        },
      })
      console.log('   Step 1: Complete')

      // Step 2: Batch create lesson schedules
      console.log('   Step 2: Creating lesson schedules...')
      await prisma.lessonSchedule.createMany({
        data: scheduleData.map(({ id, code, enrollmentId, lessonId, scheduledDate, lesson }) => ({
          id,
          code,
          enrollmentId,
          lessonId,
          scheduledDate,
          templateId: program.template?.id ?? null,
          templateName: program.template?.name ?? null,
          title: (lesson as any).title ?? null,
          estimatedMinutes: (lesson as any).estimatedMinutes ?? null,
        })),
      })
      console.log('   Step 2: Complete')

      // Step 2b: Create the v1 LessonScheduleVersion for each schedule, then copy
      // lesson activities into scheduled lesson activities (flat copy for zero-join
      // reads) stamped with versionId + lineageKey for study-sync.
      console.log('   Step 2b: Creating lesson versions and scheduled activities...')

      const versionIdBySchedule = new Map<string, string>(scheduleData.map((sd) => [sd.id, randomUUID()]))
      await prisma.lessonScheduleVersion.createMany({
        data: scheduleData.map((sd) => ({
          id: versionIdBySchedule.get(sd.id)!,
          lessonScheduleId: sd.id,
          versionNumber: 1,
          programVersionNumber: program.currentVersionNumber ?? null,
          sourceContentHash: hashLessonContent(sd.lesson as any),
        })),
      })

      // Point each schedule at its v1 (post-insert update because the FKs are circular)
      await Promise.all(
        scheduleData.map((sd) =>
          prisma.lessonSchedule.update({
            where: { id: sd.id },
            data: { currentVersionId: versionIdBySchedule.get(sd.id)! },
          })
        )
      )

      const scheduledActivityData: LessonCopyRows['scheduledActivityData'] = []
      const sourceRefData: LessonCopyRows['sourceRefData'] = []
      const readBlockData: LessonCopyRows['readBlockData'] = []
      const exegesisHighlightData: LessonCopyRows['exegesisHighlightData'] = []

      for (const sd of scheduleData) {
        const lesson = sd.lesson as typeof program.lessons[0]
        const rows = buildLessonCopyRows({
          lessonScheduleId: sd.id,
          versionId: versionIdBySchedule.get(sd.id)!,
          activities: lesson.activities as any,
        })
        scheduledActivityData.push(...rows.scheduledActivityData)
        sourceRefData.push(...rows.sourceRefData)
        readBlockData.push(...rows.readBlockData)
        exegesisHighlightData.push(...rows.exegesisHighlightData)
      }

      if (scheduledActivityData.length > 0) {
        await prisma.scheduledLessonActivity.createMany({ data: scheduledActivityData })
      }

      if (sourceRefData.length > 0) {
        await prisma.activitySourceReference.createMany({ data: sourceRefData })
      }

      if (readBlockData.length > 0) {
        await prisma.activityReadBlock.createMany({ data: readBlockData })
      }

      if (exegesisHighlightData.length > 0) {
        await prisma.exegesisHighlight.createMany({ data: exegesisHighlightData })
      }

      console.log(
        `   Step 2b: Complete - ${scheduledActivityData.length} scheduled activities, ` +
          `${sourceRefData.length} source refs, ${readBlockData.length} read blocks, ` +
          `${exegesisHighlightData.length} exegesis highlights created`
      )

      // Step 3: Batch create events for calendar display
      console.log('   Step 3: Creating calendar events...')
      await prisma.event.createMany({
        data: scheduleData.map(({ id: lessonScheduleId, lesson, scheduledDate }) => ({
          groupId: body.groupId,
          type: 'LESSON' as const,
          title: `Day ${lesson.dayNumber}: ${program.name}`,
          description: program.description,
          date: scheduledDate,
          startTime: body.smsTime,
          lessonScheduleId,
          enrollmentId,
          dayNumber: lesson.dayNumber,
        })),
      })
      console.log('   Step 3: Complete')

      // Step 4: Create welcome post for the group feed
      console.log('   Step 4: Creating welcome post...')
      const firstLessonDate = scheduleDates[0]
      const formattedStartDate = firstLessonDate.toLocaleDateString('en-US', {
        weekday: 'long',
        month: 'long',
        day: 'numeric',
      })
      const smsTimeFormatted = body.smsTime
        ? new Date(`2000-01-01T${body.smsTime}`).toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true,
          })
        : 'the scheduled time'

      await prisma.post.create({
        data: {
          groupId: body.groupId,
          authorId: userId, // Set the group leader as the author
          type: 'WELCOME',
          title: `${program.name} starts ${formattedStartDate}!`,
          content: `${group.name} is beginning the ${program.name} study program! Your first lesson link will be texted to you on ${formattedStartDate} at ${smsTimeFormatted}. Get ready for ${program.days} days of growth together!`,
          imageUrl: program.coverImageUrl,
          enrollmentId,
        },
      })
      console.log('   Step 4: Complete - Welcome post created')
    } catch (stepError) {
      // If any step fails after enrollment was created, clean up
      console.error('   ❌ Error during enrollment creation, cleaning up...', stepError)
      try {
        await prisma.enrollment.delete({ where: { id: enrollmentId } })
        console.log('   🧹 Cleaned up partial enrollment')
      } catch {
        // Enrollment might not have been created yet
      }
      throw stepError
    }

    // Step 5: Fetch enrollment summary (outside transaction)
    // OPTIMIZATION: Only return essential data, not all lessonSchedules
    // Client can fetch full schedules on-demand if needed
    console.log('   Step 5: Fetching enrollment summary...')
    const enrollment = await prisma.enrollment.findUnique({
      where: { id: enrollmentId },
      select: {
        id: true,
        groupId: true,
        studyProgramId: true,
        startDate: true,
        endDate: true,
        enabledDays: true,
        smsTime: true,
        timezone: true,
        createdAt: true,
        updatedAt: true,
        createdById: true,
        group: {
          select: {
            id: true,
            name: true,
            coverImageUrl: true,
          },
        },
        studyProgram: {
          select: {
            id: true,
            name: true,
            description: true,
            days: true,
            coverImageUrl: true,
          },
        },
        _count: {
          select: {
            lessonSchedules: true,
            events: true,
          },
        },
      },
    })

    console.log(`📚 Created enrollment ${enrollment?.id} for group ${body.groupId} in program ${body.studyProgramId}`)

    // Log successful enrollment
    logSuccess(ActivityTypes.JOIN.ENROLLMENT_CREATED, req, {
      userId,
      groupId: body.groupId,
      groupName: group.name,
      enrollmentId: enrollment?.id,
      studyProgramId: body.studyProgramId,
      programName: program.name,
    })

    if (enrollment) {
      trackActivity({
        actorId: userId,
        action: 'CREATED',
        resourceType: 'ENROLLMENT',
        resourceId: enrollment.id,
        resourceName: `${program.name} in ${group.name}`,
        organizationId: group.organizationId,
        groupId: body.groupId,
      })
    }

    res.json({ success: true, enrollment })
  } catch (error) {
    if (error instanceof z.ZodError) {
      console.error('❌ Enrollment validation error:', JSON.stringify(error.errors, null, 2))
      console.error('   Request body was:', JSON.stringify(req.body, null, 2))
      return res.status(400).json({ success: false, error: error.errors })
    }
    // Log full error details for debugging
    const errorMessage = error instanceof Error ? error.message : String(error)
    const errorStack = error instanceof Error ? error.stack : undefined
    console.error('Error creating enrollment:', {
      message: errorMessage,
      stack: errorStack,
      body: req.body,
      userId: (req.user as any)?.id
    })

    // Log failed enrollment
    logFailure(ActivityTypes.JOIN.ENROLLMENT_FAILED, req, {
      userId: (req.user as any)?.id,
      groupId: req.body?.groupId,
      studyProgramId: req.body?.studyProgramId,
      errorMessage,
    })
    // Return detailed error message for debugging (remove in production if needed)
    res.status(500).json({ success: false, error: `Failed to create enrollment: ${errorMessage}` })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get enrollment by ID
 *     description: Returns enrollment details with lesson schedules.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Enrollment details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 enrollment:
 *                   $ref: '#/components/schemas/Enrollment'
 *       404:
 *         description: Enrollment not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/enrollments/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const enrollment = await prisma.enrollment.findFirst({
      where: {
        id,
        ...(await enrollmentManageFilter(userId)),
      },
      include: {
        group: {
          select: {
            id: true,
            name: true,
            coverImageUrl: true,
            _count: {
              select: { members: true },
            },
          },
        },
        studyProgram: {
          select: {
            id: true,
            name: true,
            description: true,
            days: true,
            coverImageUrl: true,
          },
        },
        lessonSchedules: {
          orderBy: { scheduledDate: 'asc' },
          include: {
            lesson: {
              select: { id: true, dayNumber: true, title: true, studyProgramId: true, createdAt: true, updatedAt: true },
            },
            scheduledActivities: {
              orderBy: { orderNumber: 'asc' },
              include: {
                sourceReferences: true,
                readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
              },
            },
          },
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // Transform response: nest scheduledActivities inside lesson.activities
    // so iPhone app can read schedule.lesson.activities
    const transformed = {
      ...enrollment,
      lessonSchedules: enrollment.lessonSchedules.map((schedule) => {
        const { scheduledActivities, ...rest } = schedule
        return {
          ...rest,
          scheduledActivities,
          lesson: {
            ...schedule.lesson,
            activities: scheduledActivities,
          },
        }
      }),
    }

    res.json({ success: true, enrollment: transformed })
  } catch (error) {
    console.error('Error fetching enrollment:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch enrollment' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/study-enrollment:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get active study enrollment for a group (member view)
 *     description: |
 *       Returns the current enrollment with lesson completion status for the member.
 *       Uses MemberActivityProgress to determine lesson completions.
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Member ID to check completion status for
 *     responses:
 *       200:
 *         description: Study enrollment details with lesson completion status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 enrollment:
 *                   type: object
 *                   nullable: true
 *                   properties:
 *                     id:
 *                       type: string
 *                     studyId:
 *                       type: string
 *                     studyTitle:
 *                       type: string
 *                     totalLessons:
 *                       type: integer
 *                     completedLessons:
 *                       type: integer
 *                     firstDate:
 *                       type: string
 *                       format: date-time
 *                     lastDate:
 *                       type: string
 *                       format: date-time
 *                     activeDays:
 *                       type: array
 *                       items:
 *                         type: integer
 *                     lessons:
 *                       type: array
 *                       items:
 *                         type: object
 *       400:
 *         description: Missing memberId query parameter
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Member not found in group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/groups/:groupId/study-enrollment', async (req, res) => {
  try {
    const { groupId } = req.params
    const { memberId } = req.query

    if (!memberId || typeof memberId !== 'string') {
      return res.status(400).json({ success: false, error: 'memberId is required' })
    }

    // Verify member exists and is in this group
    const member = await prisma.member.findFirst({
      where: {
        id: memberId,
        groupMemberships: {
          some: {
            groupId,
            isActive: true,
          },
        },
      },
    })

    if (!member) {
      return res.status(404).json({ success: false, error: 'Member not found in group' })
    }

    // Get the active enrollment for this group (most recent)
    const enrollment = await prisma.enrollment.findFirst({
      // Exclude enrollments whose study program was soft-deleted (isActive:false)
      // so a deleted study stops rendering in the member/leader lists (monday#12415690223).
      where: { groupId, studyProgram: { isActive: true } },
      orderBy: { createdAt: 'desc' },
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
          orderBy: { scheduledDate: 'asc' },
          include: {
            lesson: {
              select: {
                id: true,
                dayNumber: true,
                title: true,
              },
            },
            scheduledActivities: {
              orderBy: { orderNumber: 'asc' },
              select: {
                id: true,
                type: true,
                title: true,
                estimatedSeconds: true,
                sourceReferences: {
                  take: 1,
                  select: { passageReference: true },
                },
              },
            },
          },
        },
      },
    })

    if (!enrollment) {
      return res.json({ success: true, enrollment: null })
    }

    // Per-activity completion keyed by scheduledActivityId — drives the LessonCard
    // activity cubes (filled = completed) and the lesson-state computation.
    const activityProgress = await prisma.memberActivityProgress.findMany({
      where: {
        memberId,
        lessonScheduleId: {
          in: enrollment.lessonSchedules.map(ls => ls.id),
        },
        completedAt: {
          not: null,
        },
      },
      select: {
        lessonScheduleId: true,
        scheduledActivityId: true,
        completedAt: true,
      },
    })

    const completedActivityIds = new Set<string>()
    const completionMap = new Map<string, Date>()
    for (const progress of activityProgress) {
      if (progress.scheduledActivityId) {
        completedActivityIds.add(progress.scheduledActivityId)
      }
      if (progress.completedAt) {
        const existing = completionMap.get(progress.lessonScheduleId)
        if (!existing || progress.completedAt < existing) {
          completionMap.set(progress.lessonScheduleId, progress.completedAt)
        }
      }
    }

    let activeDays: number[] = []
    try {
      const enabledDaysStr = enrollment.enabledDays as string
      const dayNames = JSON.parse(enabledDaysStr) as string[]
      const dayMap: { [key: string]: number } = {
        'Sun': 0, 'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6
      }
      activeDays = dayNames.map(d => dayMap[d]).filter(d => d !== undefined)
    } catch {
      activeDays = [1, 2, 3, 4, 5]
    }

    const formattedEnrollment = {
      id: enrollment.id,
      studyId: enrollment.studyProgramId,
      studyTitle: enrollment.studyProgram.name,
      studyDescription: enrollment.studyProgram.description || '',
      coverImageUrl: enrollment.studyProgram.coverImageUrl,
      totalLessons: enrollment.studyProgram.days,
      completedLessons: completionMap.size,
      firstDate: enrollment.startDate.toISOString(),
      lastDate: enrollment.endDate.toISOString(),
      activeDays,
      lessons: enrollment.lessonSchedules.map(ls => {
        const versionActivities = filterActivitiesToVersion(ls.scheduledActivities, ls.currentVersionId)
        const firstActivity = versionActivities[0]
        const passageRef = firstActivity?.sourceReferences?.[0]?.passageReference
        const activities = versionActivities.map(a => ({
          type: a.type,
          completed: completedActivityIds.has(a.id),
        }))
        const totalSeconds = versionActivities.reduce((sum, a) => sum + (a.estimatedSeconds || 0), 0)
        const estimatedMinutes = ls.estimatedMinutes
          ?? (totalSeconds > 0 ? Math.max(1, Math.round(totalSeconds / 60)) : null)
        return {
          id: ls.id,
          dayNumber: ls.lesson?.dayNumber ?? 0,
          title: ls.lesson?.title || ls.title || passageRef || firstActivity?.title || `Day ${ls.lesson?.dayNumber ?? 0}`,
          templateName: ls.templateName,
          scheduledDate: ls.scheduledDate.toISOString(),
          estimatedMinutes,
          activities,
          completedAt: completionMap.get(ls.id)?.toISOString() || undefined,
        }
      }),
    }

    res.json({ success: true, enrollment: formattedEnrollment })
  } catch (error) {
    console.error('Error fetching study enrollment:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch study enrollment' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/study-enrollments:
 *   get:
 *     tags: [Enrollments]
 *     summary: List all of a group's study enrollments for a member (member-facing)
 *     description: >
 *       Returns every study program the group is enrolled in, each with its
 *       lesson schedule and the member's per-lesson completion, so the group
 *       home can render a card (with current/next lesson) per study.
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: memberId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: List of enrollments
 */
router.get('/groups/:groupId/study-enrollments', async (req, res) => {
  try {
    const { groupId } = req.params
    const { memberId } = req.query

    if (!memberId || typeof memberId !== 'string') {
      return res.status(400).json({ success: false, error: 'memberId is required' })
    }

    // Verify member exists and is in this group
    const member = await prisma.member.findFirst({
      where: {
        id: memberId,
        groupMemberships: { some: { groupId, isActive: true } },
      },
    })

    if (!member) {
      return res.status(404).json({ success: false, error: 'Member not found in group' })
    }

    const enrollments = await prisma.enrollment.findMany({
      // Exclude enrollments whose study program was soft-deleted (isActive:false)
      // so a deleted study stops rendering in the member/leader lists (monday#12415690223).
      where: { groupId, studyProgram: { isActive: true } },
      orderBy: { createdAt: 'desc' },
      include: {
        studyProgram: {
          select: { id: true, name: true, description: true, coverImageUrl: true, days: true },
        },
        lessonSchedules: {
          orderBy: { scheduledDate: 'asc' },
          include: {
            lesson: { select: { id: true, dayNumber: true, title: true } },
          },
        },
      },
    })

    const formatted = await Promise.all(
      enrollments.map(async enrollment => {
        const scheduleIds = enrollment.lessonSchedules.map(ls => ls.id)

        // Earliest activity completion per lesson schedule → drives "complete" state
        const progress = scheduleIds.length
          ? await prisma.memberActivityProgress.findMany({
              where: {
                memberId,
                lessonScheduleId: { in: scheduleIds },
                completedAt: { not: null },
              },
              select: { lessonScheduleId: true, completedAt: true },
            })
          : []

        const completionMap = new Map<string, Date>()
        for (const p of progress) {
          if (!p.completedAt) continue
          const existing = completionMap.get(p.lessonScheduleId)
          if (!existing || p.completedAt < existing) {
            completionMap.set(p.lessonScheduleId, p.completedAt)
          }
        }

        return {
          id: enrollment.id,
          studyId: enrollment.studyProgramId,
          studyTitle: enrollment.studyProgram.name,
          studyDescription: enrollment.studyProgram.description || '',
          coverImageUrl: enrollment.studyProgram.coverImageUrl,
          totalLessons: enrollment.studyProgram.days,
          completedLessons: completionMap.size,
          lessons: enrollment.lessonSchedules.map(ls => ({
            id: ls.id,
            dayNumber: ls.lesson?.dayNumber ?? 0,
            title: ls.lesson?.title || ls.title || `Day ${ls.lesson?.dayNumber ?? 0}`,
            scheduledDate: ls.scheduledDate.toISOString(),
            completedAt: completionMap.get(ls.id)?.toISOString() || undefined,
          })),
        }
      })
    )

    res.json({ success: true, enrollments: formatted })
  } catch (error) {
    console.error('Error fetching study enrollments:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch study enrollments' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/study-enrollment/{enrollmentId}:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get specific study enrollment details
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Enrollment details
 */
router.get('/groups/:groupId/study-enrollment/:enrollmentId', async (req, res) => {
  try {
    const { groupId, enrollmentId } = req.params
    const { memberId } = req.query

    if (!memberId || typeof memberId !== 'string') {
      return res.status(400).json({ success: false, error: 'memberId is required' })
    }

    const member = await prisma.member.findFirst({
      where: {
        id: memberId,
        groupMemberships: {
          some: { groupId, isActive: true },
        },
      },
    })

    if (!member) {
      return res.status(404).json({ success: false, error: 'Member not found in group' })
    }

    const enrollment = await prisma.enrollment.findFirst({
      where: { id: enrollmentId, groupId },
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
          orderBy: { scheduledDate: 'asc' },
          include: {
            lesson: {
              select: { id: true, dayNumber: true, title: true, studyProgramId: true, createdAt: true, updatedAt: true },
            },
            scheduledActivities: {
              orderBy: { orderNumber: 'asc' },
              select: {
                id: true,
                type: true,
                title: true,
                estimatedSeconds: true,
                sourceReferences: {
                  take: 1,
                  select: { passageReference: true },
                },
              },
            },
          },
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // Per-activity completion keyed by scheduledActivityId — drives the LessonCard
    // activity cubes (filled = completed) and the lesson-state computation.
    const activityProgress = await prisma.memberActivityProgress.findMany({
      where: {
        memberId,
        lessonScheduleId: { in: enrollment.lessonSchedules.map(ls => ls.id) },
        completedAt: { not: null },
      },
      select: { lessonScheduleId: true, scheduledActivityId: true, completedAt: true },
    })

    // Set of completed scheduledActivityIds, plus a lesson→earliest-completion map
    // (kept for the legacy `completedAt` field and `completedLessons` count).
    const completedActivityIds = new Set<string>()
    const completionMap = new Map<string, Date>()
    for (const progress of activityProgress) {
      if (progress.scheduledActivityId) {
        completedActivityIds.add(progress.scheduledActivityId)
      }
      if (progress.completedAt) {
        const existing = completionMap.get(progress.lessonScheduleId)
        if (!existing || progress.completedAt < existing) {
          completionMap.set(progress.lessonScheduleId, progress.completedAt)
        }
      }
    }

    let activeDays: number[] = []
    try {
      const enabledDaysStr = enrollment.enabledDays as string
      const dayNames = JSON.parse(enabledDaysStr) as string[]
      const dayMap: { [key: string]: number } = {
        'Sun': 0, 'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6
      }
      activeDays = dayNames.map(d => dayMap[d]).filter(d => d !== undefined)
    } catch {
      activeDays = [1, 2, 3, 4, 5]
    }

    const formattedEnrollment = {
      id: enrollment.id,
      studyId: enrollment.studyProgramId,
      studyTitle: enrollment.studyProgram.name,
      studyDescription: enrollment.studyProgram.description || '',
      coverImageUrl: enrollment.studyProgram.coverImageUrl,
      totalLessons: enrollment.studyProgram.days,
      completedLessons: completionMap.size,
      firstDate: enrollment.startDate.toISOString(),
      lastDate: enrollment.endDate.toISOString(),
      activeDays,
      lessons: enrollment.lessonSchedules.map(ls => {
        const versionActivities = filterActivitiesToVersion(ls.scheduledActivities, ls.currentVersionId)
        const firstActivity = versionActivities[0]
        const passageRef = firstActivity?.sourceReferences?.[0]?.passageReference
        const activities = versionActivities.map(a => ({
          type: a.type,
          completed: completedActivityIds.has(a.id),
        }))
        const totalSeconds = versionActivities.reduce((sum, a) => sum + (a.estimatedSeconds || 0), 0)
        const estimatedMinutes = ls.estimatedMinutes
          ?? (totalSeconds > 0 ? Math.max(1, Math.round(totalSeconds / 60)) : null)
        return {
          id: ls.id,
          dayNumber: ls.lesson?.dayNumber ?? 0,
          title: ls.lesson?.title || ls.title || passageRef || firstActivity?.title || `Day ${ls.lesson?.dayNumber ?? 0}`,
          templateName: ls.templateName,
          scheduledDate: ls.scheduledDate.toISOString(),
          estimatedMinutes,
          activities,
          completedAt: completionMap.get(ls.id)?.toISOString() || undefined,
        }
      }),
    }

    res.json({ success: true, enrollment: formattedEnrollment })
  } catch (error) {
    console.error('Error fetching study enrollment:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch study enrollment' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/enrollments:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get all enrollments for a group
 *     description: Returns all enrollments for a group, ordered by creation date descending.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: List of enrollments
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 enrollments:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Enrollment'
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/groups/:groupId/enrollments', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id

    // Verify group access
    const group = await prisma.group.findFirst({
      where: {
        id: groupId,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    const enrollments = await prisma.enrollment.findMany({
      // Exclude enrollments whose study program was soft-deleted (isActive:false)
      // so a deleted study stops rendering in the member/leader lists (monday#12415690223).
      where: { groupId, studyProgram: { isActive: true } },
      orderBy: { createdAt: 'desc' },
      include: {
        studyProgram: {
          select: {
            id: true,
            name: true,
            description: true,
            days: true,
            coverImageUrl: true,
          },
        },
        _count: {
          select: { lessonSchedules: true },
        },
      },
    })

    res.json({ success: true, enrollments })
  } catch (error) {
    console.error('Error fetching group enrollments:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch enrollments' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/next-study:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get the next scheduled study for a group
 *     description: |
 *       Returns the next upcoming or today's scheduled lesson for a group.
 *       Searches across all active enrollments and returns the soonest lesson
 *       that hasn't been completed.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Next study found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 study:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     code:
 *                       type: string
 *                     dayNumber:
 *                       type: integer
 *                     scheduledDate:
 *                       type: string
 *                       format: date-time
 *                     studyProgram:
 *                       $ref: '#/components/schemas/Program'
 *                     activities:
 *                       type: array
 *                       items:
 *                         type: object
 *       204:
 *         description: No upcoming studies
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/groups/:groupId/next-study', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id

    // Verify group access (user must be creator)
    const group = await prisma.group.findFirst({
      where: {
        id: groupId,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Get today's date at midnight for comparison
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    // Find the next scheduled lesson across all enrollments for this group
    const nextLesson = await prisma.lessonSchedule.findFirst({
      where: {
        enrollment: {
          groupId,
        },
        scheduledDate: {
          gte: today, // Today or future
        },
      },
      orderBy: {
        scheduledDate: 'asc', // Get the soonest one
      },
      include: {
        lesson: {
          include: {
            studyProgram: {
              select: {
                id: true,
                name: true,
                description: true,
                days: true,
                coverImageUrl: true,
                requireResponse: true,
              },
            },
          },
        },
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
          select: {
            id: true,
            type: true,
            orderNumber: true,
            title: true,
            videoUrl: true,
            sourceReferences: {
              select: { passageReference: true },
            },
          },
        },
        enrollment: {
          select: {
            id: true,
            requireResponse: true,
            startDate: true,
            endDate: true,
          },
        },
      },
    })

    if (!nextLesson) {
      // No upcoming lessons - return 204 No Content
      return res.status(204).send()
    }

    // Format response
    const study = {
      id: nextLesson.id,
      code: nextLesson.code,
      dayNumber: nextLesson.lesson?.dayNumber ?? 0,
      scheduledDate: nextLesson.scheduledDate,
      enrollment: nextLesson.enrollment,
      studyProgram: nextLesson.lesson?.studyProgram ?? null,
      activities: filterActivitiesToVersion(nextLesson.scheduledActivities, nextLesson.currentVersionId),
    }

    res.json({ success: true, study })
  } catch (error) {
    console.error('Error fetching next study:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch next study' })
  }
})

/**
 * @openapi
 * /api/programs/{programId}/enrollments:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get all enrollments for a study program
 *     description: Returns all enrollments for a study program, showing which groups are enrolled.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: programId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: List of enrollments with group info
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 enrollments:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Enrollment'
 *       404:
 *         description: Program not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/programs/:programId/enrollments', requireAuth, async (req, res) => {
  try {
    const { programId } = req.params
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    // Verify the program exists and is viewable by this user. Viewing is
    // org-scoped (any group leader can VIEW any program in their org), matching
    // GET /programs/:id — not creator-only, which is reserved for mutations.
    const accessFilter = userOrgId ? { organizationId: userOrgId } : { creatorId: userId }
    const program = await prisma.studyProgram.findFirst({
      where: {
        id: programId,
        ...accessFilter,
        isActive: true,
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const enrollments = await prisma.enrollment.findMany({
      where: { studyProgramId: programId },
      orderBy: { startDate: 'desc' },
      include: {
        group: {
          select: {
            id: true,
            name: true,
            coverImageUrl: true,
            _count: {
              select: { members: true },
            },
            creator: {
              select: { name: true },
            },
          },
        },
      },
    })

    res.json({ success: true, enrollments })
  } catch (error) {
    console.error('Error fetching program enrollments:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch enrollments' })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}/completion-stats:
 *   get:
 *     tags: [Enrollments]
 *     summary: Group completion analytics for an enrollment
 *     description: >
 *       Active member count plus per-lesson and per-activity distinct-member
 *       completion counts for the enrollment. Used to render group-completion
 *       fill on lesson-card activity blocks (fraction = completedCount / memberCount).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Completion stats
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean, example: true }
 *                 stats:
 *                   type: object
 *                   properties:
 *                     memberCount: { type: integer }
 *                     lessons:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           lessonScheduleId: { type: string }
 *                           completedCount: { type: integer }
 *                           activities:
 *                             type: array
 *                             items:
 *                               type: object
 *                               properties:
 *                                 scheduledActivityId: { type: string }
 *                                 completedCount: { type: integer }
 *       404:
 *         description: Enrollment not found
 */
router.get('/enrollments/:id/completion-stats', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    // Verify the enrollment exists and its program is viewable in this user's org.
    // Org-scoped viewing, matching GET /programs/:programId/enrollments — not creator-only.
    const accessFilter = userOrgId ? { organizationId: userOrgId } : { creatorId: userId }
    const enrollment = await prisma.enrollment.findFirst({
      where: {
        id,
        studyProgram: { ...accessFilter, isActive: true },
      },
      select: { id: true },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const stats = await getEnrollmentCompletionStats(id)
    res.json({ success: true, stats })
  } catch (error) {
    console.error('Error fetching enrollment completion stats:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch completion stats' })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}:
 *   patch:
 *     tags: [Enrollments]
 *     summary: Update enrollment settings
 *     description: Updates enrollment settings such as requireResponse, smsTime, and timezone.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               requireResponse:
 *                 type: boolean
 *               smsTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *                 description: Time for SMS notifications (HH:MM)
 *               timezone:
 *                 type: string
 *     responses:
 *       200:
 *         description: Enrollment updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 enrollment:
 *                   $ref: '#/components/schemas/Enrollment'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Enrollment not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.patch('/enrollments/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      requireResponse: z.boolean().optional(),
      smsTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
      timezone: z.string().optional(),
      syncMode: z.enum(['OFF', 'AUTO', 'APPROVAL']).optional(), // "Sync to study" setting
    })

    const body = schema.parse(req.body)

    // Verify ownership
    const enrollment = await prisma.enrollment.findFirst({
      where: {
        id,
        ...(await enrollmentManageFilter(userId)),
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // Update enrollment
    const updated = await prisma.enrollment.update({
      where: { id },
      data: {
        ...(body.requireResponse !== undefined && { requireResponse: body.requireResponse }),
        ...(body.smsTime !== undefined && { smsTime: body.smsTime }),
        ...(body.timezone !== undefined && { timezone: body.timezone }),
        ...(body.syncMode !== undefined && { syncMode: body.syncMode }),
        updatedById: userId,
      },
      include: {
        studyProgram: {
          select: {
            id: true,
            name: true,
            days: true,
          },
        },
        group: {
          select: {
            id: true,
            name: true,
            organizationId: true,
          },
        },
      },
    })

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'ENROLLMENT',
      resourceId: id,
      resourceName: `${updated.studyProgram.name} in ${updated.group.name}`,
      organizationId: updated.group.organizationId,
      groupId: updated.group.id,
    })

    // Changing the sync mode IS the decision the "updates available"
    // notification asks for — resolve it (applying resolves it in the sync
    // engine; this covers the "leave it off / switch modes" choice).
    if (body.syncMode !== undefined && updated.createdById) {
      await resolveNotificationsByDedupeKey(updated.createdById, `study-sync-updates:${id}`)
    }

    console.log(`✏️ Updated enrollment ${id}`)

    res.json({ success: true, enrollment: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating enrollment:', error)
    res.status(500).json({ success: false, error: 'Failed to update enrollment' })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}/sync:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get study-sync status for an enrollment
 *     description: |
 *       Reports the enrollment's sync mode, the program version its lessons
 *       reflect, whether the program has published newer versions (drift),
 *       and the pending versions' AI change summaries so a leader can decide
 *       whether to apply them. Also returns recent sync runs.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sync status
 *       404:
 *         description: Enrollment not found
 */
router.get('/enrollments/:id/sync', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const enrollment = await prisma.enrollment.findFirst({
      where: { id, ...(await enrollmentManageFilter(userId)) },
      select: {
        id: true,
        syncMode: true,
        syncedProgramVersionNumber: true,
        studyProgram: { select: { id: true, name: true, currentVersionNumber: true } },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const syncedVersion = enrollment.syncedProgramVersionNumber ?? 0
    const currentVersion = enrollment.studyProgram.currentVersionNumber ?? null
    const hasDrift = currentVersion !== null && currentVersion > syncedVersion

    const [pendingVersions, recentRuns] = await Promise.all([
      hasDrift
        ? prisma.studyProgramVersion.findMany({
            where: {
              studyProgramId: enrollment.studyProgram.id,
              versionNumber: { gt: syncedVersion },
            },
            orderBy: { versionNumber: 'desc' },
            select: {
              versionNumber: true,
              publishedAt: true,
              changeSummary: true,
              changedLessonIds: true,
            },
          })
        : Promise.resolve([]),
      prisma.enrollmentSyncRun.findMany({
        where: { enrollmentId: id },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          targetProgramVersionNumber: true,
          status: true,
          error: true,
          startedAt: true,
          completedAt: true,
        },
      }),
    ])

    res.json({
      success: true,
      sync: {
        syncMode: enrollment.syncMode,
        syncedProgramVersionNumber: enrollment.syncedProgramVersionNumber,
        currentVersionNumber: currentVersion,
        hasDrift,
        pendingVersions,
        recentRuns,
      },
    })
  } catch (error) {
    console.error('Error fetching enrollment sync status:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch sync status' })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}/sync/changes:
 *   get:
 *     tags: [Enrollments]
 *     summary: Per-lesson pending changes for the Review Changes screen
 *     description: |
 *       Quantified diff between the enrollment's lessons and the program's
 *       latest published version — one row per changed lesson (new / updated /
 *       removed) with activity-level counts, plus totals. Rows carry the
 *       selection `key` accepted by POST /sync/apply for per-lesson approval.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Pending changes
 *       404:
 *         description: Enrollment not found
 */
router.get('/enrollments/:id/sync/changes', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const enrollment = await prisma.enrollment.findFirst({
      where: { id, ...(await enrollmentManageFilter(userId)) },
      select: { id: true, syncMode: true },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const pending = await computePendingChanges(id)
    res.json({ success: true, ...pending })
  } catch (error) {
    console.error('Error computing enrollment sync changes:', error)
    res.status(500).json({ success: false, error: 'Failed to compute pending changes' })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}/sync/apply:
 *   post:
 *     tags: [Enrollments]
 *     summary: Apply the latest published program version to this enrollment
 *     description: |
 *       Brings the enrollment's lessons up to the program's latest published
 *       version (all-or-nothing). Used by APPROVAL-mode acceptance and manual
 *       catch-up for OFF-mode enrollments with drift. Members who completed a
 *       lesson stay pinned to the version they completed; everyone else sees
 *       the new content. Idempotent — reapplying is a no-op.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sync applied (or already up to date)
 *       400:
 *         description: Program has no published version
 *       404:
 *         description: Enrollment not found
 */
router.post('/enrollments/:id/sync/apply', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const body = z
      .object({
        // Selective approval (Review Changes): only these lesson changes
        // apply. Omitted → full catch-up (original all-or-nothing behavior).
        lessonKeys: z.array(z.string()).optional(),
      })
      .parse(req.body ?? {})

    const enrollment = await prisma.enrollment.findFirst({
      where: { id, ...(await enrollmentManageFilter(userId)) },
      select: {
        id: true,
        groupId: true,
        studyProgram: { select: { name: true } },
        group: { select: { name: true, organizationId: true } },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const outcome = await syncEnrollmentToLatest({
      enrollmentId: id,
      triggeredById: userId,
      lessonKeys: body.lessonKeys ?? null,
    })

    if (!outcome.alreadySynced) {
      trackActivity({
        actorId: userId,
        action: 'UPDATED',
        resourceType: 'ENROLLMENT',
        resourceId: id,
        resourceName: `${enrollment.studyProgram.name} in ${enrollment.group.name}`,
        organizationId: enrollment.group.organizationId,
        groupId: enrollment.groupId,
        metadata: { studySync: outcome },
      })
    }

    res.json({ success: true, ...outcome })
  } catch (error) {
    if (error instanceof SyncNotPossibleError) {
      return res.status(400).json({ success: false, error: error.message })
    }
    console.error('Error applying enrollment sync:', error)
    res.status(500).json({ success: false, error: 'Failed to apply sync' })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}:
 *   delete:
 *     tags: [Enrollments]
 *     summary: Delete an enrollment
 *     description: Deletes an enrollment and cascades to all lesson schedules.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Enrollment deleted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *       404:
 *         description: Enrollment not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.delete('/enrollments/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    // Verify ownership
    const enrollment = await prisma.enrollment.findFirst({
      where: {
        id,
        ...(await enrollmentManageFilter(userId)),
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // Delete enrollment (cascades to lesson schedules)
    await prisma.enrollment.delete({ where: { id } })

    console.log(`🗑️ Deleted enrollment ${id}`)

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting enrollment:', error)
    res.status(500).json({ success: false, error: 'Failed to delete enrollment' })
  }
})

// ============================================================================
// Public Lesson View (for SMS links)
// ============================================================================

/**
 * @openapi
 * /api/lessons/code/{code}:
 *   get:
 *     tags: [Enrollments]
 *     summary: Look up lesson by study code
 *     description: |
 *       Public endpoint for SMS deep linking. Looks up a lesson by its 6-character code.
 *       Returns lesson details including activities and program info.
 *     parameters:
 *       - in: path
 *         name: code
 *         required: true
 *         schema:
 *           type: string
 *           pattern: '^[A-Za-z0-9]{6}$'
 *         description: 6-character study code from SMS
 *     responses:
 *       200:
 *         description: Lesson found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 lesson:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     code:
 *                       type: string
 *                     dayNumber:
 *                       type: integer
 *                     scheduledDate:
 *                       type: string
 *                       format: date-time
 *                     studyProgram:
 *                       $ref: '#/components/schemas/Program'
 *                     activities:
 *                       type: array
 *                       items:
 *                         type: object
 *                     group:
 *                       $ref: '#/components/schemas/Group'
 *       400:
 *         description: Invalid code format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Study not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/lessons/code/:code', async (req, res) => {
  try {
    const { code } = req.params
    const normalizedCode = code.toUpperCase().trim()

    // Validate code format (6 alphanumeric characters)
    if (!/^[A-Z0-9]{6}$/.test(normalizedCode)) {
      return res.status(400).json({ success: false, error: 'Invalid study code format' })
    }

    const schedule = await prisma.lessonSchedule.findFirst({
      where: {
        code: normalizedCode,
      },
      include: {
        lesson: {
          include: {
            studyProgram: {
              select: {
                id: true,
                name: true,
                description: true,
                days: true,
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
            readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
          },
        },
        enrollment: {
          select: {
            groupId: true,
            group: {
              select: {
                id: true,
                code: true,
                name: true,
                coverImageUrl: true,
                organizationId: true,
                creator: {
                  select: {
                    name: true,
                    picture: true,
                  },
                },
              },
            },
          },
        },
      },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Study not found' })
    }

    res.json({
      success: true,
      lesson: {
        id: schedule.lesson?.id ?? null,
        code: schedule.code,
        dayNumber: schedule.lesson?.dayNumber ?? 0,
        scheduledDate: schedule.scheduledDate,
        templateName: schedule.templateName,
        studyProgram: schedule.lesson?.studyProgram ?? null,
        activities: filterActivitiesToVersion(schedule.scheduledActivities, schedule.currentVersionId),
        group: schedule.enrollment.group,
      },
    })
  } catch (error) {
    console.error('Error looking up lesson by code:', error)
    res.status(500).json({ success: false, error: 'Failed to look up study' })
  }
})

/**
 * @openapi
 * /api/lessons/view/{scheduleId}:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get scheduled lesson details for member viewing
 *     description: |
 *       Public endpoint. Returns lesson details including activities and program info
 *       for a specific lesson schedule. Used for member lesson viewing.
 *     parameters:
 *       - in: path
 *         name: scheduleId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Lesson details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 lesson:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     code:
 *                       type: string
 *                     dayNumber:
 *                       type: integer
 *                     scheduledDate:
 *                       type: string
 *                       format: date-time
 *                     studyProgram:
 *                       $ref: '#/components/schemas/Program'
 *                     activities:
 *                       type: array
 *                       items:
 *                         type: object
 *                     group:
 *                       $ref: '#/components/schemas/Group'
 *       404:
 *         description: Lesson not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/lessons/view/:scheduleId', async (req, res) => {
  try {
    const { scheduleId } = req.params

    const schedule = await prisma.lessonSchedule.findUnique({
      where: { id: scheduleId },
      include: {
        lesson: {
          include: {
            studyProgram: {
              select: {
                id: true,
                name: true,
                description: true,
                days: true,
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
            readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
          },
        },
        enrollment: {
          select: {
            groupId: true,
            group: {
              select: {
                id: true,
                code: true,
                name: true,
                coverImageUrl: true,
                organizationId: true,
                creator: {
                  select: {
                    name: true,
                    picture: true,
                  },
                },
              },
            },
          },
        },
      },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Lesson not found' })
    }

    res.json({
      success: true,
      lesson: {
        id: schedule.lesson?.id ?? null,
        code: schedule.code, // 6-char alphanumeric for deep linking
        dayNumber: schedule.lesson?.dayNumber ?? 0,
        scheduledDate: schedule.scheduledDate,
        templateName: schedule.templateName,
        studyProgram: schedule.lesson?.studyProgram ?? null,
        activities: filterActivitiesToVersion(schedule.scheduledActivities, schedule.currentVersionId),
        group: schedule.enrollment.group,
      },
    })
  } catch (error) {
    console.error('Error fetching lesson:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch lesson' })
  }
})

/**
 * @openapi
 * /api/lessons/today/{enrollmentId}:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get today's lesson for an enrollment
 *     description: |
 *       Public endpoint. Returns the lesson scheduled for today for a given enrollment.
 *       Compares against today's date at midnight.
 *     parameters:
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Today's lesson details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 lesson:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     code:
 *                       type: string
 *                     dayNumber:
 *                       type: integer
 *                     scheduledDate:
 *                       type: string
 *                       format: date-time
 *                     studyProgram:
 *                       $ref: '#/components/schemas/Program'
 *                     activities:
 *                       type: array
 *                       items:
 *                         type: object
 *       404:
 *         description: No lesson scheduled for today
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/lessons/today/:enrollmentId', async (req, res) => {
  try {
    const { enrollmentId } = req.params

    // Get today's date at midnight
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)

    const schedule = await prisma.lessonSchedule.findFirst({
      where: {
        enrollmentId,
        scheduledDate: {
          gte: today,
          lt: tomorrow,
        },
      },
      include: {
        lesson: {
          include: {
            studyProgram: {
              select: {
                id: true,
                name: true,
                description: true,
                days: true,
              },
            },
          },
        },
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
          include: {
            video: true,
            sourceReferences: true,
            readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
          },
        },
      },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'No lesson scheduled for today' })
    }

    res.json({
      success: true,
      lesson: {
        id: schedule.lesson?.id ?? null,
        code: schedule.code, // 6-char alphanumeric for deep linking
        dayNumber: schedule.lesson?.dayNumber ?? 0,
        scheduledDate: schedule.scheduledDate,
        templateName: schedule.templateName,
        studyProgram: schedule.lesson?.studyProgram ?? null,
        activities: filterActivitiesToVersion(schedule.scheduledActivities, schedule.currentVersionId),
      },
    })
  } catch (error) {
    console.error('Error fetching today\'s lesson:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch lesson' })
  }
})

// ============================================================================
// Lesson Invite API (for group leaders to share lesson links)
// ============================================================================

/**
 * @openapi
 * /api/lesson-schedules/{id}/invite:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get invite information for a lesson schedule
 *     description: |
 *       Returns invite details including a QR code for sharing lesson links.
 *       Used by group leaders to share lesson links with members.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Lesson schedule ID
 *     responses:
 *       200:
 *         description: Invite information with QR code
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 invite:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     code:
 *                       type: string
 *                     dayNumber:
 *                       type: integer
 *                     scheduledDate:
 *                       type: string
 *                       format: date-time
 *                     passageReference:
 *                       type: string
 *                       nullable: true
 *                     studyProgram:
 *                       type: object
 *                     group:
 *                       type: object
 *                     inviteUrl:
 *                       type: string
 *                       format: uri
 *                     qrCode:
 *                       type: string
 *                       description: Base64 data URL of QR code image
 *       403:
 *         description: Not authorized (user is not group creator)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Lesson schedule not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/lesson-schedules/:id/invite', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    // Fetch lesson schedule with related data
    const schedule = await prisma.lessonSchedule.findUnique({
      where: { id },
      include: {
        lesson: {
          include: {
            studyProgram: {
              select: {
                id: true,
                name: true,
                description: true,
                days: true,
                coverImageUrl: true,
              },
            },
          },
        },
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
          take: 1, // Just get first activity for passage reference
          include: {
            sourceReferences: {
              take: 1,
              select: { passageReference: true },
            },
          },
        },
        enrollment: {
          include: {
            group: {
              select: {
                id: true,
                code: true,
                name: true,
                coverImageUrl: true,
                creatorId: true,
                organizationId: true,
              },
            },
          },
        },
      },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
    }

    // Group creator OR an owner/role-holder in the group's org may manage it.
    if (!(await canManageOrgContent(userId, schedule.enrollment.group.organizationId, schedule.enrollment.group.creatorId))) {
      return res.status(403).json({ success: false, error: 'Not authorized' })
    }

    // Generate invite URL using lesson schedule ID
    const inviteUrl = `https://app.makeready.org/join/study/${schedule.id}`

    // Generate QR code as base64 data URL
    const qrCodeDataUrl = await QRCode.toDataURL(inviteUrl, {
      width: 512,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#FFFFFF',
      },
    })

    // Get passage reference from first scheduled activity
    const firstActivity = filterActivitiesToVersion(schedule.scheduledActivities, schedule.currentVersionId)[0]
    const passageReference = firstActivity?.sourceReferences?.[0]?.passageReference || null

    res.json({
      success: true,
      invite: {
        id: schedule.id,
        lessonScheduleId: schedule.id, // Deprecated: use 'id' instead
        code: schedule.code,
        dayNumber: schedule.lesson?.dayNumber ?? 0,
        scheduledDate: schedule.scheduledDate,
        templateName: schedule.templateName,
        passageReference,
        studyProgram: schedule.lesson
          ? {
              id: schedule.lesson.studyProgram.id,
              name: schedule.lesson.studyProgram.name,
              days: schedule.lesson.studyProgram.days,
              coverImageUrl: schedule.lesson.studyProgram.coverImageUrl,
            }
          : null,
        group: {
          id: schedule.enrollment.group.id,
          code: schedule.enrollment.group.code,
          name: schedule.enrollment.group.name,
          coverImageUrl: schedule.enrollment.group.coverImageUrl,
        },
        inviteUrl,
        qrCode: qrCodeDataUrl,
      },
    })
  } catch (error) {
    console.error('Error generating lesson invite:', error)
    res.status(500).json({ success: false, error: 'Failed to generate invite' })
  }
})

// ============================================================================
// Events API (for calendar display)
// ============================================================================

/**
 * @openapi
 * /api/groups/{groupId}/events:
 *   get:
 *     tags: [Events]
 *     summary: Get all events for a group's calendar
 *     description: Returns events for a group within a date range, ordered by date ascending.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Start of date range (defaults to today)
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: End of date range (defaults to 30 days from start)
 *     responses:
 *       200:
 *         description: List of events
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 events:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       type:
 *                         type: string
 *                       title:
 *                         type: string
 *                       description:
 *                         type: string
 *                       date:
 *                         type: string
 *                         format: date-time
 *                       startTime:
 *                         type: string
 *                       endTime:
 *                         type: string
 *                       dayNumber:
 *                         type: integer
 *                       lessonScheduleId:
 *                         type: string
 *                       enrollmentId:
 *                         type: string
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/groups/:groupId/events', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id

    // Parse date range from query
    const startDate = req.query.startDate
      ? new Date(req.query.startDate as string)
      : new Date()
    startDate.setHours(0, 0, 0, 0)

    const endDate = req.query.endDate
      ? new Date(req.query.endDate as string)
      : new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000) // 30 days from start

    // Verify group access
    const group = await prisma.group.findFirst({
      where: {
        id: groupId,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Get events for the group within date range
    // OPTIMIZATION: Only return calendar-essential fields
    // Deep nested data (activities) can be fetched on-demand when user taps an event
    const events = await prisma.event.findMany({
      where: {
        groupId,
        isActive: true,
        date: {
          gte: startDate,
          lte: endDate,
        },
      },
      orderBy: { date: 'asc' },
      select: {
        id: true,
        type: true,
        title: true,
        description: true,
        date: true,
        startTime: true,
        endTime: true,
        dayNumber: true,
        lessonScheduleId: true,
        enrollmentId: true,
        // Only include essential program info for display
        enrollment: {
          select: {
            studyProgram: {
              select: {
                id: true,
                name: true,
              },
            },
          },
        },
      },
    })

    res.json({ success: true, events })
  } catch (error) {
    console.error('Error fetching group events:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch events' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/events:
 *   post:
 *     tags: [Events]
 *     summary: Create a custom event for a group
 *     description: Creates a custom calendar event (not LESSON type, which are auto-created).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - type
 *               - title
 *               - date
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [MEETING, ONLINE, DEADLINE, SOCIAL, OTHER]
 *               title:
 *                 type: string
 *                 maxLength: 200
 *               description:
 *                 type: string
 *                 maxLength: 2000
 *               date:
 *                 type: string
 *                 format: date-time
 *               startTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *               endTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *     responses:
 *       200:
 *         description: Event created
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 event:
 *                   type: object
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/groups/:groupId/events', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      type: z.enum(['MEETING', 'ONLINE', 'DEADLINE', 'SOCIAL', 'OTHER']), // LESSON events are created automatically
      title: z.string().min(1).max(200),
      description: z.string().max(2000).optional(),
      date: z.string().datetime(),
      startTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
      endTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
    })

    const body = schema.parse(req.body)

    // Verify group access
    const group = await prisma.group.findFirst({
      where: {
        id: groupId,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    const event = await prisma.event.create({
      data: {
        groupId,
        type: body.type,
        title: body.title,
        description: body.description,
        date: new Date(body.date),
        startTime: body.startTime,
        endTime: body.endTime,
      },
    })

    console.log(`📅 Created event ${event.id} for group ${groupId}`)

    res.json({ success: true, event })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error creating event:', error)
    res.status(500).json({ success: false, error: 'Failed to create event' })
  }
})

/**
 * @openapi
 * /api/events/{id}:
 *   delete:
 *     tags: [Events]
 *     summary: Delete an event
 *     description: Deletes a calendar event. User must own the group the event belongs to.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Event deleted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *       404:
 *         description: Event not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.delete('/events/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    // Verify ownership through group
    const event = await prisma.event.findFirst({
      where: { id },
      include: {
        group: {
          select: { creatorId: true, organizationId: true },
        },
      },
    })

    if (!event || !(await canManageOrgContent(userId, event.group.organizationId, event.group.creatorId))) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    await prisma.event.delete({ where: { id } })

    console.log(`🗑️ Deleted event ${id}`)

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting event:', error)
    res.status(500).json({ success: false, error: 'Failed to delete event' })
  }
})

// ============================================================================
// Scheduled Activity Updates
// ============================================================================

/**
 * @openapi
 * /api/scheduled-activities/{id}:
 *   patch:
 *     tags: [Enrollments]
 *     summary: Update a scheduled activity
 *     description: |
 *       Allows group leaders to toggle help visibility on a scheduled activity.
 *       Verifies ownership through the chain: activity -> lesson schedule -> enrollment -> group -> creator.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               isHelpEnabled:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Scheduled activity updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 scheduledActivity:
 *                   type: object
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Scheduled activity not found or not authorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.patch('/scheduled-activities/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      type: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']).optional(),
      title: z.string().min(1).max(200).optional(),
      referenceTitle: z.string().max(200).nullable().optional(),
      helpTitle: z.string().max(200).nullable().optional(),
      helpDescription: z.string().max(2000).nullable().optional(),
      helpAlwaysVisible: z.boolean().optional(),
      isHelpEnabled: z.boolean().optional(),
      readContent: z.string().nullable().optional(),
      videoId: z.string().uuid().nullable().optional(),
      videoUrl: z.string().url().nullable().optional(),
    })

    const body = schema.parse(req.body)

    // Verify ownership: activity -> lessonSchedule -> enrollment -> createdById
    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        lessonSchedule: {
          include: {
            enrollment: true,
          },
        },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    // If setting videoId, validate the video exists
    if (body.videoId) {
      const video = await prisma.video.findFirst({
        where: { id: body.videoId, userId, isActive: true },
      })
      if (!video) {
        return res.status(404).json({ success: false, error: 'Video not found' })
      }
    }

    await prisma.scheduledLessonActivity.update({
      where: { id },
      data: body,
    })

    // Backward compat: sync readContent to read blocks
    if (body.readContent !== undefined) {
      const existingBlocks = await prisma.activityReadBlock.findMany({
        where: { scheduledActivityId: id },
        orderBy: { orderNumber: 'asc' },
      })
      if (existingBlocks.length === 0) {
        await prisma.activityReadBlock.create({
          data: {
            scheduledActivityId: id,
            orderNumber: 1,
            content: body.readContent,
            isLocked: false,
          },
        })
      } else if (existingBlocks.length === 1 && !existingBlocks[0].isLocked) {
        await prisma.activityReadBlock.update({
          where: { id: existingBlocks[0].id },
          data: { content: body.readContent },
        })
      }
    }

    const result = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        video: true,
        sourceReferences: true,
        readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
      },
    })

    // Recalculate lesson schedule time estimate
    await recalculateScheduledLessonEstimate(activity.lessonScheduleId)

    res.json({ success: true, scheduledActivity: result })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to update scheduled activity' })
  }
})

// ============================================================================
// Scheduled Activity CRUD (List, Add, Delete)
// ============================================================================

/**
 * @openapi
 * /api/enrollments/{enrollmentId}/schedules/{scheduleId}/activities:
 *   get:
 *     tags: [Enrollments]
 *     summary: List activities for a scheduled lesson
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: scheduleId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of scheduled activities
 *       404:
 *         description: Not found
 */
router.get(
  '/enrollments/:enrollmentId/schedules/:scheduleId/activities',
  requireAuth,
  async (req, res) => {
    try {
      const { enrollmentId, scheduleId } = req.params
      const userId = (req.user as any).id

      // Verify enrollment access
      const enrollment = await prisma.enrollment.findFirst({
        where: { id: enrollmentId, ...(await enrollmentManageFilter(userId)) },
      })

      if (!enrollment) {
        return res.status(404).json({ success: false, error: 'Enrollment not found' })
      }

      // Verify schedule belongs to enrollment
      const schedule = await prisma.lessonSchedule.findFirst({
        where: { id: scheduleId, enrollmentId },
      })

      if (!schedule) {
        return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
      }

      const activities = await prisma.scheduledLessonActivity.findMany({
        where: { lessonScheduleId: scheduleId },
        orderBy: { orderNumber: 'asc' },
        include: {
          video: true,
          sourceReferences: true,
          readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
        },
      })

      res.json({ success: true, activities })
    } catch (error) {
      console.error('Error fetching scheduled activities:', error)
      res.status(500).json({ success: false, error: 'Failed to fetch activities' })
    }
  }
)

/**
 * @openapi
 * /api/enrollments/{enrollmentId}/schedules/{scheduleId}/activities:
 *   post:
 *     tags: [Enrollments]
 *     summary: Add an activity to a scheduled lesson
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: scheduleId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [type, title]
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [USER_INPUT, READ, VIDEO]
 *               title:
 *                 type: string
 *               helpTitle:
 *                 type: string
 *               helpDescription:
 *                 type: string
 *               videoId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       200:
 *         description: Activity created
 *       404:
 *         description: Not found
 */
router.post(
  '/enrollments/:enrollmentId/schedules/:scheduleId/activities',
  requireAuth,
  async (req, res) => {
    try {
      const { enrollmentId, scheduleId } = req.params
      const userId = (req.user as any).id

      const schema = z.object({
        type: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']),
        title: z.string().min(1).max(200),
        referenceTitle: z.string().max(200).nullable().optional(),
        helpTitle: z.string().max(200).nullable().optional(),
        helpDescription: z.string().max(2000).nullable().optional(),
        helpAlwaysVisible: z.boolean().optional().default(false),
        readContent: z.string().nullable().optional(),
        videoId: z.string().uuid().optional(),
      })

      const body = schema.parse(req.body)

      // Verify enrollment access
      const enrollment = await prisma.enrollment.findFirst({
        where: { id: enrollmentId, ...(await enrollmentManageFilter(userId)) },
      })

      if (!enrollment) {
        return res.status(404).json({ success: false, error: 'Enrollment not found' })
      }

      // Get schedule, then the max order number within its current version
      // (rows from pinned historical versions don't participate in ordering)
      const schedule = await prisma.lessonSchedule.findFirst({
        where: { id: scheduleId, enrollmentId },
      })

      if (!schedule) {
        return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
      }

      const lastActivity = await prisma.scheduledLessonActivity.findFirst({
        where: { lessonScheduleId: scheduleId, versionId: schedule.currentVersionId },
        orderBy: { orderNumber: 'desc' },
      })

      // Validate video reference
      if (body.type === 'VIDEO' && body.videoId) {
        const video = await prisma.video.findFirst({
          where: { id: body.videoId, userId, isActive: true },
        })
        if (!video) {
          return res.status(404).json({ success: false, error: 'Video not found' })
        }
      }

      const nextOrder = lastActivity?.orderNumber
        ? lastActivity.orderNumber + 1
        : 1

      const activity = await prisma.scheduledLessonActivity.create({
        data: {
          lessonScheduleId: scheduleId,
          versionId: schedule.currentVersionId, // Leader-added custom activity joins the current version (no lineageKey — it has no curriculum source)
          type: body.type,
          orderNumber: nextOrder,
          title: body.title,
          referenceTitle: body.referenceTitle ?? null,
          helpTitle: body.helpTitle ?? null,
          helpDescription: body.helpDescription ?? null,
          helpAlwaysVisible: body.helpAlwaysVisible ?? false,
          isHelpEnabled: true,
          readContent: body.readContent ?? null,
          videoId: body.type === 'VIDEO' ? body.videoId ?? null : null,
          videoUrl: null,
          sourceLessonActivityId: null,
        },
        include: {
          video: true,
          sourceReferences: true,
          readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
        },
      })

      // Auto-create a default empty read block for READ activities
      if (body.type === 'READ') {
        await prisma.activityReadBlock.create({
          data: {
            scheduledActivityId: activity.id,
            orderNumber: 1,
            content: body.readContent ?? null,
            isLocked: false,
          },
        })
      }

      // Re-fetch to include the newly created block
      const result = body.type === 'READ'
        ? await prisma.scheduledLessonActivity.findUnique({
            where: { id: activity.id },
            include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
          })
        : activity

      res.json({ success: true, scheduledActivity: result })
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: error.errors })
      }
      console.error('Error creating scheduled activity:', error)
      res.status(500).json({ success: false, error: 'Failed to create activity' })
    }
  }
)

/**
 * @openapi
 * /api/scheduled-activities/{id}:
 *   delete:
 *     tags: [Enrollments]
 *     summary: Delete a scheduled activity
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Activity deleted
 *       400:
 *         description: Cannot delete last activity
 *       404:
 *         description: Not found
 */
router.delete('/scheduled-activities/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        lessonSchedule: {
          include: {
            enrollment: true,
            scheduledActivities: true,
          },
        },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    // Only activities in the same version count as siblings — rows from other
    // (pinned historical) versions must never be counted or renumbered.
    const versionSiblings = activity.lessonSchedule.scheduledActivities.filter(
      (a) => a.versionId === activity.versionId
    )
    if (versionSiblings.length <= 1) {
      return res.status(400).json({
        success: false,
        error: 'Cannot delete the last activity in a scheduled lesson',
      })
    }

    await prisma.$transaction(async (tx) => {
      await tx.scheduledLessonActivity.delete({ where: { id } })

      await tx.scheduledLessonActivity.updateMany({
        where: {
          lessonScheduleId: activity.lessonScheduleId,
          versionId: activity.versionId,
          orderNumber: { gt: activity.orderNumber },
        },
        data: {
          orderNumber: { decrement: 1 },
        },
      })
    })

    // Recalculate lesson schedule time estimate
    await recalculateScheduledLessonEstimate(activity.lessonScheduleId)

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to delete activity' })
  }
})

// ============================================================================
// Scheduled Activity: Reset
// ============================================================================

/**
 * @openapi
 * /api/scheduled-activities/{id}/reset:
 *   post:
 *     tags: [Enrollments]
 *     summary: Reset a scheduled activity (clear content, video, source references, read blocks)
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Activity reset
 *       404:
 *         description: Not found
 */
router.post('/scheduled-activities/:id/reset', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        lessonSchedule: { include: { enrollment: true } },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    await prisma.$transaction(async (tx) => {
      await tx.activityReadBlock.deleteMany({
        where: { scheduledActivityId: id },
      })
      await tx.activitySourceReference.deleteMany({
        where: { scheduledActivityId: id },
      })
      await tx.scheduledLessonActivity.update({
        where: { id },
        data: {
          readContent: null,
          videoId: null,
          videoUrl: null,
        },
      })
    })

    const updatedActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    // Recalculate lesson schedule time estimate
    await recalculateScheduledLessonEstimate(activity.lessonScheduleId)

    res.json({ success: true, scheduledActivity: updatedActivity })
  } catch (error) {
    console.error('Error resetting scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to reset activity' })
  }
})

// ============================================================================
// Scheduled Activity: Source References
// ============================================================================

const scheduledSourceReferenceSchema = z.object({
  sourceType: z.string().default('SCRIPTURE'),
  passageReference: z.string().nullable().optional(),
  bookNumber: z.number().int().min(1).max(66).nullable().optional(),
  bookName: z.string().nullable().optional(),
  chapterStart: z.number().int().min(1).nullable().optional(),
  chapterEnd: z.number().int().min(1).nullable().optional(),
  verseStart: z.number().int().min(1).nullable().optional(),
  verseEnd: z.number().int().min(1).nullable().optional(),
  content: z.string().nullable().optional(),
})

/**
 * @openapi
 * /api/scheduled-activities/{id}/source-references:
 *   post:
 *     tags: [Enrollments]
 *     summary: Add a source reference to a scheduled activity
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       201:
 *         description: Source reference created
 */
router.post('/scheduled-activities/:id/source-references', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const body = scheduledSourceReferenceSchema.parse(req.body)

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        lessonSchedule: { include: { enrollment: true } },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    // Shift existing blocks up to make room at position 1
    await prisma.activityReadBlock.updateMany({
      where: { scheduledActivityId: id },
      data: { orderNumber: { increment: 1 } },
    })

    const ref = await prisma.activitySourceReference.create({
      data: {
        scheduledActivityId: id,
        sourceType: body.sourceType,
        passageReference: body.passageReference ?? null,
        bookNumber: body.bookNumber ?? null,
        bookName: body.bookName ?? null,
        chapterStart: body.chapterStart ?? null,
        chapterEnd: body.chapterEnd ?? null,
        verseStart: body.verseStart ?? null,
        verseEnd: body.verseEnd ?? null,
      },
    })

    // Store canonical numbered markdown for scripture content. Use client-provided
    // content if available, otherwise fetch from Bible database.
    let verseContent: string | null = normalizeScriptureMarkdown(body.content)
    if (!verseContent && body.bookNumber && body.chapterStart && body.verseStart) {
      const translation = await prisma.translation.findUnique({
        where: { code: 'WEB' },
      })
      if (translation) {
        const verseEnd = body.verseEnd ?? body.verseStart
        const verses = await prisma.verse.findMany({
          where: {
            translationId: translation.id,
            bookNumber: body.bookNumber,
            chapter: body.chapterStart,
            verse: { gte: body.verseStart, lte: verseEnd },
          },
          orderBy: { verse: 'asc' },
        })
        if (verses.length > 0) {
          verseContent = normalizeScriptureVerses(verses)
        }
      }
    }

    // Create locked read block at position 1
    await prisma.activityReadBlock.create({
      data: {
        scheduledActivityId: id,
        orderNumber: 1,
        title: body.passageReference ?? null,
        content: verseContent ?? body.passageReference ?? null,
        contentFormat: 'markdown',
        isLocked: true,
        sourceReferenceId: ref.id,
      },
    })

    const updatedActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    res.status(201).json({ success: true, sourceReference: ref, scheduledActivity: updatedActivity })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error adding source reference to scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to add source reference' })
  }
})

/**
 * @openapi
 * /api/scheduled-activities/{id}/source-references/{refId}:
 *   delete:
 *     tags: [Enrollments]
 *     summary: Remove a source reference from a scheduled activity
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Source reference deleted
 */
router.delete('/scheduled-activities/:id/source-references/:refId', requireAuth, async (req, res) => {
  try {
    const { id, refId } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        lessonSchedule: { include: { enrollment: true } },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    const ref = await prisma.activitySourceReference.findFirst({
      where: { id: refId, scheduledActivityId: id },
    })

    if (!ref) {
      return res.status(404).json({ success: false, error: 'Source reference not found' })
    }

    // Delete linked read block first, then source reference
    await prisma.activityReadBlock.deleteMany({
      where: { sourceReferenceId: refId },
    })
    await prisma.activitySourceReference.delete({ where: { id: refId } })

    // Renumber remaining read blocks
    const remainingBlocks = await prisma.activityReadBlock.findMany({
      where: { scheduledActivityId: id },
      orderBy: { orderNumber: 'asc' },
    })
    for (let i = 0; i < remainingBlocks.length; i++) {
      if (remainingBlocks[i].orderNumber !== i + 1) {
        await prisma.activityReadBlock.update({
          where: { id: remainingBlocks[i].id },
          data: { orderNumber: i + 1 },
        })
      }
    }

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting source reference from scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to delete source reference' })
  }
})

// ============================================================================
// Scheduled Activity: Read Blocks
// ============================================================================

/**
 * @openapi
 * /api/scheduled-activities/{id}/read-blocks:
 *   post:
 *     tags: [Enrollments]
 *     summary: Add a read block to a scheduled activity
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       201:
 *         description: Read block created
 */
router.post('/scheduled-activities/:id/read-blocks', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      title: z.string().nullable().optional(),
      content: z.string().nullable().optional(),
      isLocked: z.boolean().optional().default(false),
      sourceReferenceId: z.string().uuid().nullable().optional(),
      orderNumber: z.number().int().min(1).optional(),
    })

    const body = schema.parse(req.body)

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        lessonSchedule: { include: { enrollment: true } },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    let orderNumber = body.orderNumber
    if (!orderNumber) {
      const maxBlock = await prisma.activityReadBlock.findFirst({
        where: { scheduledActivityId: id },
        orderBy: { orderNumber: 'desc' },
        select: { orderNumber: true },
      })
      orderNumber = (maxBlock?.orderNumber ?? 0) + 1
    }

    const isScriptureLinkedBlock = body.sourceReferenceId != null
    const content = isScriptureLinkedBlock
      ? normalizeScriptureMarkdown(body.content)
      : (body.content ?? null)

    const block = await prisma.activityReadBlock.create({
      data: {
        scheduledActivityId: id,
        orderNumber,
        title: body.title ?? null,
        content,
        contentFormat: 'markdown',
        isLocked: body.isLocked,
        sourceReferenceId: body.sourceReferenceId ?? null,
      },
    })

    const updatedActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    // Recalculate lesson schedule time estimate
    await recalculateScheduledLessonEstimate(activity.lessonScheduleId)

    res.status(201).json({ success: true, block, scheduledActivity: updatedActivity })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error adding read block to scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to add read block' })
  }
})

/**
 * @openapi
 * /api/scheduled-activities/{activityId}/read-blocks/{blockId}:
 *   patch:
 *     tags: [Enrollments]
 *     summary: Update a read block on a scheduled activity
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: blockId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Read block updated
 *       400:
 *         description: Cannot edit locked block content
 */
router.patch('/scheduled-activities/:activityId/read-blocks/:blockId', requireAuth, async (req, res) => {
  try {
    const { activityId, blockId } = req.params
    const userId = (req.user as any).id

    const selectionSchema = z.object({
      start: z.number().int().min(0),
      end: z.number().int().min(1),
      style: z.string().min(1),
    }).refine((s) => s.end > s.start, { message: 'end must be greater than start' })

    const schema = z.object({
      title: z.string().nullable().optional(),
      content: z.string().nullable().optional(),
      orderNumber: z.number().int().min(1).optional(),
      themeId: z.string().uuid().nullable().optional(),
      contentFormat: z.enum(['html', 'markdown']).optional(),
      selections: z.array(selectionSchema).nullable().optional(),
    })

    const body = schema.parse(req.body)

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id: activityId },
      include: {
        lessonSchedule: { include: { enrollment: true } },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    const block = await prisma.activityReadBlock.findFirst({
      where: { id: blockId, scheduledActivityId: activityId },
    })

    if (!block) {
      return res.status(404).json({ success: false, error: 'Read block not found' })
    }

    if (block.isLocked && body.content !== undefined) {
      return res.status(400).json({ success: false, error: 'Cannot edit content of a locked block' })
    }

    const content = block.sourceReferenceId
      ? normalizeScriptureMarkdown(body.content)
      : (body.content ?? null)

    const updated = await prisma.activityReadBlock.update({
      where: { id: blockId },
      data: {
        ...(body.title !== undefined && { title: body.title }),
        ...(body.content !== undefined && { content }),
        ...(body.orderNumber !== undefined && { orderNumber: body.orderNumber }),
        ...(body.themeId !== undefined && { themeId: body.themeId }),
        ...(body.contentFormat !== undefined && { contentFormat: body.contentFormat }),
        ...(body.selections !== undefined && { selections: body.selections === null ? Prisma.DbNull : (body.selections as Prisma.InputJsonValue) }),
      },
    })

    // Recalculate lesson schedule time estimate if content changed
    if (body.content !== undefined) {
      await recalculateScheduledLessonEstimate(activity.lessonScheduleId)
    }

    res.json({ success: true, block: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating read block on scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to update read block' })
  }
})

/**
 * @openapi
 * /api/scheduled-activities/{activityId}/read-blocks/{blockId}:
 *   delete:
 *     tags: [Enrollments]
 *     summary: Delete a read block from a scheduled activity
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: blockId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Read block deleted
 *       400:
 *         description: Cannot delete the last block
 */
router.delete('/scheduled-activities/:activityId/read-blocks/:blockId', requireAuth, async (req, res) => {
  try {
    const { activityId, blockId } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id: activityId },
      include: {
        lessonSchedule: { include: { enrollment: true } },
        readBlocks: { include: { theme: { select: { id: true, slug: true, name: true } } } },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    const block = activity.readBlocks.find(b => b.id === blockId)
    if (!block) {
      return res.status(404).json({ success: false, error: 'Read block not found' })
    }

    // Enrolled lessons must stay deliverable, so a read activity here must keep
    // at least one read block (unlike program templates, which may be left
    // incomplete). Guide the leader to remove the whole activity instead.
    if (activity.readBlocks.length <= 1) {
      return res.status(400).json({
        success: false,
        error: 'A read activity must keep at least one read block. To remove it from this lesson, delete the entire activity instead.',
      })
    }

    await prisma.activityReadBlock.delete({ where: { id: blockId } })

    // Renumber remaining blocks
    const remainingBlocks = await prisma.activityReadBlock.findMany({
      where: { scheduledActivityId: activityId },
      orderBy: { orderNumber: 'asc' },
    })
    for (let i = 0; i < remainingBlocks.length; i++) {
      if (remainingBlocks[i].orderNumber !== i + 1) {
        await prisma.activityReadBlock.update({
          where: { id: remainingBlocks[i].id },
          data: { orderNumber: i + 1 },
        })
      }
    }

    const updatedActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id: activityId },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    // Recalculate lesson schedule time estimate
    await recalculateScheduledLessonEstimate(activity.lessonScheduleId)

    res.json({ success: true, scheduledActivity: updatedActivity })
  } catch (error) {
    console.error('Error deleting read block from scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to delete read block' })
  }
})

/**
 * @openapi
 * /api/scheduled-activities/{id}/read-blocks/reorder:
 *   patch:
 *     tags: [Enrollments]
 *     summary: Reorder read blocks for a scheduled activity
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [blockIds]
 *             properties:
 *               blockIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Blocks reordered
 */
router.patch('/scheduled-activities/:id/read-blocks/reorder', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      blockIds: z.array(z.string().uuid()).min(1),
    })

    const { blockIds } = schema.parse(req.body)

    const activity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: {
        lessonSchedule: { include: { enrollment: true } },
        readBlocks: { include: { theme: { select: { id: true, slug: true, name: true } } } },
      },
    })

    if (
      !activity ||
      (activity.lessonSchedule.enrollment.createdById !== userId &&
        !(await canManageGroupId(userId, activity.lessonSchedule.enrollment.groupId)))
    ) {
      return res.status(404).json({ success: false, error: 'Scheduled activity not found' })
    }

    const activityBlockIds = new Set(activity.readBlocks.map(b => b.id))
    for (const blockId of blockIds) {
      if (!activityBlockIds.has(blockId)) {
        return res.status(400).json({
          success: false,
          error: `Block ${blockId} does not belong to this activity`,
        })
      }
    }

    if (blockIds.length !== activity.readBlocks.length) {
      return res.status(400).json({
        success: false,
        error: `Expected ${activity.readBlocks.length} blocks, got ${blockIds.length}`,
      })
    }

    await prisma.$transaction(
      blockIds.map((blockId, index) =>
        prisma.activityReadBlock.update({
          where: { id: blockId },
          data: { orderNumber: index + 1 },
        })
      )
    )

    const updatedActivity = await prisma.scheduledLessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    res.json({ success: true, scheduledActivity: updatedActivity })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error reordering read blocks on scheduled activity:', error)
    res.status(500).json({ success: false, error: 'Failed to reorder read blocks' })
  }
})

// ============================================================================
// Scheduled Activity: Reorder Activities
// ============================================================================

/**
 * @openapi
 * /api/enrollments/{enrollmentId}/schedules/{scheduleId}/reorder-activities:
 *   post:
 *     tags: [Enrollments]
 *     summary: Reorder scheduled activities via drag-and-drop
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: scheduleId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [activityOrder]
 *             properties:
 *               activityOrder:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Activities reordered
 */
router.post(
  '/enrollments/:enrollmentId/schedules/:scheduleId/reorder-activities',
  requireAuth,
  async (req, res) => {
    try {
      const { enrollmentId, scheduleId } = req.params
      const userId = (req.user as any).id

      const schema = z.object({
        activityOrder: z.array(z.string().uuid()).min(1),
      })

      const { activityOrder } = schema.parse(req.body)

      const enrollment = await prisma.enrollment.findFirst({
        where: { id: enrollmentId, ...(await enrollmentManageFilter(userId)) },
      })

      if (!enrollment) {
        return res.status(404).json({ success: false, error: 'Enrollment not found' })
      }

      const schedule = await prisma.lessonSchedule.findFirst({
        where: { id: scheduleId, enrollmentId },
        include: { scheduledActivities: true },
      })

      if (!schedule) {
        return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
      }

      // Reordering applies to the current version's activity set only —
      // pinned historical versions must stay untouched.
      const currentActivities = schedule.scheduledActivities.filter(
        (a) => a.versionId === schedule.currentVersionId
      )
      const scheduleActivityIds = new Set(currentActivities.map(a => a.id))
      for (const activityId of activityOrder) {
        if (!scheduleActivityIds.has(activityId)) {
          return res.status(400).json({
            success: false,
            error: `Activity ${activityId} does not belong to this schedule`,
          })
        }
      }

      if (activityOrder.length !== currentActivities.length) {
        return res.status(400).json({
          success: false,
          error: `Expected ${currentActivities.length} activities, got ${activityOrder.length}`,
        })
      }

      // Use transaction with temporary high values to avoid unique constraint conflicts
      await prisma.$transaction(async (tx) => {
        // First, set all to high numbers to avoid unique constraint on [versionId, orderNumber]
        for (let i = 0; i < activityOrder.length; i++) {
          await tx.scheduledLessonActivity.update({
            where: { id: activityOrder[i] },
            data: { orderNumber: 1000 + i },
          })
        }
        // Then set the correct order
        for (let i = 0; i < activityOrder.length; i++) {
          await tx.scheduledLessonActivity.update({
            where: { id: activityOrder[i] },
            data: { orderNumber: i + 1 },
          })
        }
      })

      const updatedActivities = await prisma.scheduledLessonActivity.findMany({
        where: { lessonScheduleId: scheduleId, versionId: schedule.currentVersionId },
        orderBy: { orderNumber: 'asc' },
        include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
      })

      res.json({ success: true, activities: updatedActivities })
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: error.errors })
      }
      console.error('Error reordering scheduled activities:', error)
      res.status(500).json({ success: false, error: 'Failed to reorder activities' })
    }
  }
)

// ============================================================================
// Schedule Lesson for Enrollment
// ============================================================================

/**
 * @openapi
 * /api/enrollments/{id}/schedules:
 *   post:
 *     tags: [Enrollments]
 *     summary: Schedule a lesson for an enrollment
 *     description: |
 *       Schedules an existing lesson for a group enrollment, copying activities.
 *       The scheduled date is calculated by walking forward from the latest existing
 *       schedule date, matching the enrollment's enabledDays pattern.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - lessonId
 *             properties:
 *               lessonId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       200:
 *         description: Lesson schedule created with activities
 *       400:
 *         description: Lesson does not belong to this enrollment's program
 *       404:
 *         description: Enrollment or lesson not found
 *       409:
 *         description: Lesson already scheduled for this enrollment
 */
router.post('/enrollments/:id/schedules', requireAuth, async (req, res) => {
  try {
    const { id: enrollmentId } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      lessonId: z.string().uuid(),
    })
    const body = schema.parse(req.body)

    // Verify enrollment exists and caller has access (creator or org owner)
    const enrollment = await prisma.enrollment.findFirst({
      where: {
        id: enrollmentId,
        ...(await enrollmentManageFilter(userId)),
      },
      include: {
        studyProgram: {
          select: {
            id: true,
            name: true,
            description: true,
            currentVersionNumber: true,
            template: { select: { id: true, name: true } },
          },
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // Verify lesson belongs to this enrollment's study program
    const lesson = await prisma.lesson.findFirst({
      where: {
        id: body.lessonId,
        studyProgramId: enrollment.studyProgramId,
      },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
          include: {
            sourceReferences: true,
            readBlocks: {
              orderBy: { orderNumber: 'asc' },
              include: {
                theme: { select: { id: true, slug: true, name: true } },
                exegesisHighlights: { orderBy: { orderNumber: 'asc' } },
              },
            },
          },
        },
      },
    })

    if (!lesson) {
      return res.status(400).json({
        success: false,
        error: 'Lesson not found or does not belong to this enrollment\'s program',
      })
    }

    // Check for duplicate (unique constraint: enrollmentId + lessonId)
    const existing = await prisma.lessonSchedule.findUnique({
      where: {
        enrollmentId_lessonId: {
          enrollmentId,
          lessonId: body.lessonId,
        },
      },
    })

    if (existing) {
      return res.status(409).json({
        success: false,
        error: 'This lesson is already scheduled for this enrollment',
      })
    }

    // Calculate scheduledDate: find latest existing schedule and walk forward
    const enabledDays: string[] = JSON.parse(enrollment.enabledDays as string)
    const dayMap: { [key: string]: number } = {
      'Sun': 0, 'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6,
    }
    const enabledDayNumbers = enabledDays.map(d => dayMap[d])

    const latestSchedule = await prisma.lessonSchedule.findFirst({
      where: { enrollmentId },
      orderBy: { scheduledDate: 'desc' },
      select: { scheduledDate: true },
    })

    let scheduledDate: Date
    if (latestSchedule) {
      // Walk forward from the day after the latest schedule
      const cursor = new Date(latestSchedule.scheduledDate)
      cursor.setDate(cursor.getDate() + 1)
      while (!enabledDayNumbers.includes(cursor.getDay())) {
        cursor.setDate(cursor.getDate() + 1)
      }
      scheduledDate = cursor
    } else {
      // No existing schedules — use enrollment start date
      scheduledDate = new Date(enrollment.startDate)
      while (!enabledDayNumbers.includes(scheduledDate.getDay())) {
        scheduledDate.setDate(scheduledDate.getDate() + 1)
      }
    }

    // Create schedule, activities, event — sequential with cleanup on failure
    const scheduleId = randomUUID()
    const code = generateStudyCode()

    try {
      // Step 1: Create the lesson schedule
      await prisma.lessonSchedule.create({
        data: {
          id: scheduleId,
          code,
          enrollmentId,
          lessonId: body.lessonId,
          scheduledDate,
          templateId: enrollment.studyProgram.template?.id ?? null,
          templateName: enrollment.studyProgram.template?.name ?? null,
          title: lesson.title ?? null,
        },
      })

      // Step 2: Create the v1 version for this schedule, then copy lesson
      // activities → scheduled lesson activities (stamped for study-sync)
      const versionId = randomUUID()
      await prisma.lessonScheduleVersion.create({
        data: {
          id: versionId,
          lessonScheduleId: scheduleId,
          versionNumber: 1,
          programVersionNumber: enrollment.studyProgram.currentVersionNumber ?? null,
          sourceContentHash: hashLessonContent(lesson as any),
        },
      })
      await prisma.lessonSchedule.update({
        where: { id: scheduleId },
        data: { currentVersionId: versionId },
      })

      const { scheduledActivityData, sourceRefData, readBlockData, exegesisHighlightData } = buildLessonCopyRows({
        lessonScheduleId: scheduleId,
        versionId,
        activities: lesson.activities as any,
      })

      if (scheduledActivityData.length > 0) {
        await prisma.scheduledLessonActivity.createMany({ data: scheduledActivityData })
      }
      if (sourceRefData.length > 0) {
        await prisma.activitySourceReference.createMany({ data: sourceRefData })
      }
      if (readBlockData.length > 0) {
        await prisma.activityReadBlock.createMany({ data: readBlockData })
      }
      if (exegesisHighlightData.length > 0) {
        await prisma.exegesisHighlight.createMany({ data: exegesisHighlightData })
      }

      // Step 3: Create calendar event
      await prisma.event.create({
        data: {
          groupId: enrollment.groupId,
          type: 'LESSON' as const,
          title: `Day ${lesson.dayNumber}: ${enrollment.studyProgram.name}`,
          description: enrollment.studyProgram.description,
          date: scheduledDate,
          startTime: enrollment.smsTime,
          lessonScheduleId: scheduleId,
          enrollmentId,
          dayNumber: lesson.dayNumber,
        },
      })

      // Step 4: Update enrollment endDate if new date extends past it
      if (scheduledDate > enrollment.endDate) {
        await prisma.enrollment.update({
          where: { id: enrollmentId },
          data: { endDate: scheduledDate },
        })
      }
    } catch (stepError) {
      // Clean up partial schedule on failure
      console.error('Error during schedule creation, cleaning up...', stepError)
      try {
        await prisma.lessonSchedule.delete({ where: { id: scheduleId } })
      } catch {
        // Schedule might not have been created yet
      }
      throw stepError
    }

    // Fetch the created schedule with activities
    const schedule = await prisma.lessonSchedule.findUnique({
      where: { id: scheduleId },
      include: {
        lesson: true,
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
          include: {
            sourceReferences: true,
            readBlocks: {
              orderBy: { orderNumber: 'asc' },
              include: {
                theme: { select: { id: true, slug: true, name: true } },
                exegesisHighlights: { orderBy: { orderNumber: 'asc' } },
              },
            },
          },
        },
        event: true,
      },
    })

    res.json({ success: true, schedule })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error scheduling lesson:', error)
    res.status(500).json({ success: false, error: 'Failed to schedule lesson' })
  }
})

// ============================================================================
// Update Lesson Schedule Title
// ============================================================================

/**
 * @openapi
 * /api/enrollments/{enrollmentId}/schedules/{scheduleId}:
 *   patch:
 *     tags: [Enrollments]
 *     summary: Update a lesson schedule's title
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: path
 *         name: scheduleId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [title]
 *             properties:
 *               title:
 *                 type: string
 *                 maxLength: 200
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Lesson schedule updated
 *       404:
 *         description: Enrollment or schedule not found
 */
router.patch('/enrollments/:enrollmentId/schedules/:scheduleId', requireAuth, async (req, res) => {
  try {
    const { enrollmentId, scheduleId } = req.params
    const userId = (req.user as any).id

    const updateSchema = z.object({
      title: z.string().max(200).nullable(),
    })
    const data = updateSchema.parse(req.body)

    const enrollment = await prisma.enrollment.findFirst({
      where: {
        id: enrollmentId,
        ...(await enrollmentManageFilter(userId)),
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const schedule = await prisma.lessonSchedule.findFirst({
      where: {
        id: scheduleId,
        enrollmentId,
      },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
    }

    const updated = await prisma.lessonSchedule.update({
      where: { id: scheduleId },
      data: { title: data.title },
    })

    res.json({ success: true, schedule: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating lesson schedule:', error)
    res.status(500).json({ success: false, error: 'Failed to update lesson schedule' })
  }
})

// ============================================================================
// Delete Lesson Schedule from Enrollment
// ============================================================================

/**
 * @openapi
 * /api/enrollments/{enrollmentId}/schedules/{scheduleId}:
 *   delete:
 *     tags: [Enrollments]
 *     summary: Delete a lesson schedule from an enrollment
 *     description: |
 *       Removes a scheduled lesson from an enrollment. Also deletes the associated
 *       calendar event, the lesson from the program, and recalculates the enrollment end date.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: path
 *         name: scheduleId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Lesson schedule deleted
 *       404:
 *         description: Enrollment or schedule not found
 */
router.delete('/enrollments/:enrollmentId/schedules/:scheduleId', requireAuth, async (req, res) => {
  try {
    const { enrollmentId, scheduleId } = req.params
    const userId = (req.user as any).id

    // Verify enrollment exists and caller has access
    const enrollment = await prisma.enrollment.findFirst({
      where: {
        id: enrollmentId,
        ...(await enrollmentManageFilter(userId)),
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // Verify schedule belongs to this enrollment
    const schedule = await prisma.lessonSchedule.findFirst({
      where: {
        id: scheduleId,
        enrollmentId,
      },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
    }

    // Delete the associated event
    await prisma.event.deleteMany({
      where: { lessonScheduleId: scheduleId },
    })

    // Delete the schedule (cascades to scheduledActivities, sourceReferences, readBlocks)
    await prisma.lessonSchedule.delete({
      where: { id: scheduleId },
    })

    // Delete the lesson from the program and sync days count (skip when the
    // curriculum lesson is already gone — orphaned schedule)
    await prisma.$transaction(async (tx) => {
      const lesson = schedule.lessonId
        ? await tx.lesson.findUnique({ where: { id: schedule.lessonId } })
        : null

      if (lesson) {
        const programId = lesson.studyProgramId

        await tx.lesson.delete({ where: { id: lesson.id } })

        // Reorder remaining lessons
        await tx.lesson.updateMany({
          where: {
            studyProgramId: programId,
            dayNumber: { gt: lesson.dayNumber },
          },
          data: { dayNumber: { decrement: 1 } },
        })

        // Sync days count
        const lessonCount = await tx.lesson.count({ where: { studyProgramId: programId } })
        await tx.studyProgram.update({
          where: { id: programId },
          data: { days: lessonCount },
        })
      }
    })

    // Recalculate enrollment endDate from remaining schedules
    const latestSchedule = await prisma.lessonSchedule.findFirst({
      where: { enrollmentId },
      orderBy: { scheduledDate: 'desc' },
      select: { scheduledDate: true },
    })

    if (latestSchedule) {
      await prisma.enrollment.update({
        where: { id: enrollmentId },
        data: { endDate: latestSchedule.scheduledDate },
      })
    }

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting lesson schedule:', error)
    res.status(500).json({ success: false, error: 'Failed to delete lesson schedule' })
  }
})

// ============================================================================
// Unenrollment Flow
// ============================================================================

/**
 * @openapi
 * /api/enrollments/{id}/unenroll-info:
 *   get:
 *     tags: [Enrollments]
 *     summary: Get unenroll info for an enrollment
 *     description: |
 *       Returns information about which lesson schedules have member response data,
 *       so the client can present context-aware unenrollment options.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Unenroll info
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     enrollmentId:
 *                       type: string
 *                     programName:
 *                       type: string
 *                     totalLessons:
 *                       type: integer
 *                     lessonsWithData:
 *                       type: integer
 *                     cleanLessons:
 *                       type: integer
 *                     canFullyUnenroll:
 *                       type: boolean
 *       404:
 *         description: Enrollment not found
 */
router.get('/enrollments/:id/unenroll-info', requireAuth, async (req, res) => {
  try {
    const { id } = req.params

    const enrollment = await prisma.enrollment.findUnique({
      where: { id },
      include: {
        studyProgram: { select: { name: true } },
        lessonSchedules: {
          select: {
            id: true,
            _count: {
              select: { memberProgress: true },
            },
          },
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const totalLessons = enrollment.lessonSchedules.length
    const lessonsWithData = enrollment.lessonSchedules.filter(
      (ls) => ls._count.memberProgress > 0
    ).length
    const cleanLessons = totalLessons - lessonsWithData

    res.json({
      success: true,
      data: {
        enrollmentId: enrollment.id,
        programName: enrollment.studyProgram.name,
        totalLessons,
        lessonsWithData,
        cleanLessons,
        canFullyUnenroll: lessonsWithData === 0,
      },
    })
  } catch (error) {
    console.error('Error fetching unenroll info:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch unenroll info' })
  }
})

/**
 * @openapi
 * /api/enrollments/{id}/cancel-future:
 *   post:
 *     tags: [Enrollments]
 *     summary: Cancel future lessons without data
 *     description: |
 *       Removes only the lesson schedules that have zero member responses.
 *       The enrollment itself stays active and completes when its original end date passes.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Clean lessons removed
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *       404:
 *         description: Enrollment not found
 */
router.post('/enrollments/:id/cancel-future', requireAuth, async (req, res) => {
  try {
    const { id } = req.params

    const enrollment = await prisma.enrollment.findUnique({
      where: { id },
      include: {
        lessonSchedules: {
          select: {
            id: true,
            _count: {
              select: { memberProgress: true },
            },
          },
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const cleanScheduleIds = enrollment.lessonSchedules
      .filter((ls) => ls._count.memberProgress === 0)
      .map((ls) => ls.id)

    if (cleanScheduleIds.length > 0) {
      await prisma.lessonSchedule.deleteMany({
        where: { id: { in: cleanScheduleIds } },
      })
    }

    res.json({ success: true })
  } catch (error) {
    console.error('Error cancelling future lessons:', error)
    res.status(500).json({ success: false, error: 'Failed to cancel future lessons' })
  }
})

export default router
