import { Router } from 'express'
import { z } from 'zod'
import { randomUUID } from 'crypto'
import QRCode from 'qrcode'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { logSuccess, logFailure } from '../lib/activity-log.js'
import { ActivityTypes } from '../lib/activity-types.js'
import { trackActivity } from '../services/activity.js'
import { getUserOrgId } from '../services/media-library.js'
import { getEnrollmentCompletionStats } from '../services/enrollment-analytics.service.js'
import { createScheduledLessons, syncEnrollmentToCurrent, SyncNotPossibleError } from '../services/enrollment-sync.js'
import { computePendingChanges, getEnrollmentSyncStatus } from '../services/enrollment-sync-changes.js'
import { resolveNotificationsByDedupeKey } from '../services/notification.js'
import {
  mediaForScheduledLessons,
  scheduledLessonInclude,
  serializeScheduledLesson,
  setScheduledLessonTitle,
} from '../services/enrollment-lessons.js'
import { getStudyEnrollment, listStudyEnrollments } from '../services/study-enrollment-view.js'
import { thumbnailFromDocument } from '../services/next-study-thumbnail.js'
import { deleteLessonIn } from '../services/program-lessons.service.js'
import { ContentError } from '../services/content-errors.js'
import { buildMediaMap } from '../services/content-media.service.js'
import { generateScheduleDates, validateScheduleDates } from '../services/enrollment-schedule.js'
import { isValidTimezone } from '../utils/timezone.js'
import { programReadFilter } from '../services/study-program.service.js'
import { deleteDraftsForPair } from '../services/enrollment-draft.service.js'
import { applyEnrollmentEdit, applyStudySwap, previewEnrollmentEdit, EnrollmentEditError } from '../services/enrollment-edit.js'
import {
  canManageOrgContent,
  enrollmentManageFilter,
  groupManageFilter,
  buildEnrollmentManageChecker,
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
 *       Lesson dates are calculated based on enabled days (e.g., Mon, Wed, Fri), unless
 *       `scheduleDates` gives them exactly (stored as 00:00 in `timezone`, UTC when absent).
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
 *                 description: IANA time zone (e.g. America/Chicago); an invalid zone is a 400
 *               requireResponse:
 *                 type: boolean
 *               syncMode:
 *                 type: string
 *                 enum: [OFF, AUTO, APPROVAL]
 *               scheduleDates:
 *                 type: array
 *                 description: |
 *                   Exact lesson dates (yyyy-MM-dd), one per program lesson, strictly ascending, the
 *                   first not before today in `timezone`. Absent → derived from startDate + enabledDays.
 *                 items:
 *                   type: string
 *                   format: date
 *                 minItems: 1
 *               lessonAccess:
 *                 type: string
 *                 enum: [ONE_AT_A_TIME, ALL_AT_ONCE]
 *                 description: When lessons open to members (default ALL_AT_ONCE)
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
 *         description: |
 *           Validation error (incl. an invalid timezone); "Schedule doesn't match the program: …"
 *           when scheduleDates has the wrong count, is not ascending or starts before today;
 *           `group_has_no_members` when the group has no active members; draft program or no lessons
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Group not manageable by the caller, or program outside the caller's read scope
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       409:
 *         description: "`already_enrolled` — the group already has an enrollment of this program whose endDate has not passed; the body carries its `enrollmentId`"
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
      // D16: an invalid zone is a 400, never a silent UTC fallback.
      timezone: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).optional(),
      requireResponse: z.boolean().optional(), // Override program default (inherits from program if not specified)
      syncMode: z.enum(['OFF', 'AUTO', 'APPROVAL']).optional(), // "Sync to study": how this enrollment tracks published curriculum updates
      // ui2-enrollment-create D3: the app's exact lesson dates (overrides included); absent → derived.
      scheduleDates: z.array(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).min(1).optional(),
      // D4: when lessons open to members; absent → the column default ALL_AT_ONCE.
      lessonAccess: z.enum(['ONE_AT_A_TIME', 'ALL_AT_ONCE']).optional(),
      // ui2-enrollments-browse D11: the checklist's server draft; an unknown id is ignored (D24 deletes by pair).
      draftId: z.string().uuid().optional(),
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
      include: { _count: { select: { members: { where: { isActive: true } } } } },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // D5: an enrollment needs someone to enroll — the pickers hide empty groups, this guards every caller.
    if (group._count.members === 0) {
      return res.status(400).json({ success: false, error: 'group_has_no_members', message: 'Group has no members' })
    }

    // Verify study program exists and is active
    // T12: only a program the caller can read (programReadFilter, the GET /api/programs/:id scope).
    const program = await prisma.studyProgram.findFirst({
      where: {
        id: body.studyProgramId,
        isActive: true,
        ...(await programReadFilter(userId)),
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Study program not found' })
    }

    // D2: an enrollment schedules the lessons of the program's current published version.
    const programVersionId = program.currentVersionId
    if (!programVersionId) {
      return res.status(400).json({ success: false, error: 'Publish this program before enrolling a group', code: 'VALIDATION' })
    }
    const versionLessons = await prisma.programVersionLesson.findMany({
      where: { programVersionId },
      orderBy: { position: 'asc' },
      select: { lessonId: true },
    })
    if (versionLessons.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Cannot enroll in a study program with no lessons. Please add lessons to the program first.'
      })
    }

    // enroll-picker-hide-enrolled D6: one current (active or upcoming) enrollment per group + program.
    const current = await prisma.enrollment.findFirst({
      where: { groupId: body.groupId, studyProgramId: body.studyProgramId, endDate: { gt: new Date() } },
      select: { id: true },
    })
    if (current) {
      return res.status(409).json({ success: false, error: 'already_enrolled', enrollmentId: current.id })
    }

    // D3: the app's exact dates when sent (00:00 in `timezone`, D16); else the weekday walk —
    // one per lesson on the enabled weekdays from the start date (shared with edit/reschedule).
    let scheduleDates: Date[]
    if (body.scheduleDates) {
      const checked = validateScheduleDates(body.scheduleDates, versionLessons.length, body.timezone ?? 'UTC', new Date())
      if (!checked.ok) {
        return res.status(400).json({ success: false, error: checked.error })
      }
      scheduleDates = checked.dates
    } else {
      scheduleDates = generateScheduleDates(new Date(body.startDate), body.enabledDays, versionLessons.length)
    }
    const startDate = body.scheduleDates ? scheduleDates[0] : new Date(body.startDate)
    const endDate = scheduleDates[scheduleDates.length - 1]

    // One transaction: the enrollment, a ScheduledLesson (and its calendar event) per lesson of the program
    // version, and the welcome post land together or not at all.
    const enrollmentId = randomUUID()
    const scheduleDatesByLesson = new Map(versionLessons.map((l, i) => [l.lessonId, scheduleDates[i]]))
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

    await prisma.$transaction(
      async (tx) => {
        await tx.enrollment.create({
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
            lessonAccess: body.lessonAccess ?? 'ALL_AT_ONCE',
            programVersionId,
            createdById: userId,
          },
        })
        await createScheduledLessons(tx, enrollmentId, programVersionId, scheduleDatesByLesson)
        await tx.post.create({
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
      },
      { timeout: 60_000 },
    )

    // ui2-enrollments-browse D11 + D24: the enrollment and its welcome post exist, so the pair's drafts are
    // promoted — deleted whether or not draftId was sent. A failure here is logged and the 200 stands.
    try {
      await deleteDraftsForPair(body.groupId, body.studyProgramId)
    } catch (draftError) {
      console.error('   ⚠️ Could not delete the enrollment drafts for this group + program:', draftError)
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
        lessonAccess: true,
        syncMode: true,
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
            scheduledLessons: true,
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

    // The wire keeps `_count.lessonSchedules`: its value is now the scheduled lessons.
    res.json({
      success: true,
      enrollment: enrollment && {
        ...enrollment,
        _count: { lessonSchedules: enrollment._count.scheduledLessons, events: enrollment._count.events },
      },
    })
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
        scheduledLessons: {
          orderBy: { scheduledDate: 'asc' },
          include: scheduledLessonInclude,
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // `lessonSchedules[]` keeps today's keys, built from the ScheduledLessons; `media` resolves their documents' media ids.
    const { scheduledLessons, ...rest } = enrollment
    res.json({
      success: true,
      enrollment: { ...rest, lessonSchedules: scheduledLessons.map(serializeScheduledLesson) },
      media: await mediaForScheduledLessons(scheduledLessons),
    })
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

    // The active enrollment for this group (most recent). Exclude enrollments whose study program was
    // soft-deleted (isActive:false) so a deleted study stops rendering (monday#12415690223).
    const enrollment = await getStudyEnrollment({ groupId, studyProgram: { isActive: true } }, memberId, true)

    res.json({ success: true, enrollment })
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

    const formatted = await listStudyEnrollments(groupId, memberId)

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

    const enrollment = await getStudyEnrollment({ id: enrollmentId, groupId }, memberId)

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    res.json({ success: true, enrollment })
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
            // Program creator's name — so the client can tell a leader who
            // can't edit this study "created by <name>, contact them for
            // changes" (monday#12270302158 follow-up).
            creator: { select: { name: true } },
          },
        },
        _count: {
          select: { scheduledLessons: true },
        },
      },
    })

    // Stamp canManage so the client can disable "Edit enrollment" for
    // enrollments this user can't edit (monday#12270302158). All enrollments
    // here share the one group fetched above.
    const canManage = await buildEnrollmentManageChecker(userId)
    const enrollmentsWithPerm = enrollments.map(({ _count, ...e }) => ({
      ...e,
      // The wire keeps `_count.lessonSchedules`: its value is now the scheduled lessons.
      _count: { lessonSchedules: _count.scheduledLessons },
      canManage: canManage({ createdById: e.createdById, group }),
      studyProgramCreatorName: e.studyProgram?.creator?.name ?? null,
    }))

    res.json({ success: true, enrollments: enrollmentsWithPerm })
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

    // Find the next scheduled lesson across all enrollments for this group (a removed lesson is never next)
    const nextLesson = await prisma.scheduledLesson.findFirst({
      where: {
        enrollment: {
          groupId,
        },
        removedAt: null,
        scheduledDate: {
          gte: today, // Today or future
        },
      },
      orderBy: {
        scheduledDate: 'asc', // Get the soonest one
      },
      include: {
        lesson: { select: { position: true } },
        currentVersion: {
          select: {
            title: true,
            activities: {
              orderBy: { position: 'asc' },
              select: { id: true, kind: true, position: true, title: true, document: true },
            },
          },
        },
        enrollment: {
          select: {
            id: true,
            requireResponse: true,
            startDate: true,
            endDate: true,
            studyProgram: {
              select: { id: true, name: true, description: true, days: true, coverImageUrl: true, requireResponse: true },
            },
          },
        },
      },
    })

    if (!nextLesson) {
      // No upcoming lessons - return 204 No Content
      return res.status(204).send()
    }

    // Thumbnails come from each activity's document, through the media its background or poster names.
    const media = await buildMediaMap(prisma, nextLesson.currentVersion.activities.map((a) => a.document))
    const { studyProgram, ...enrollment } = nextLesson.enrollment

    // Format response
    const study = {
      id: nextLesson.id,
      code: nextLesson.code,
      title: nextLesson.currentVersion.title ?? null,
      dayNumber: nextLesson.lesson?.position ?? 0,
      scheduledDate: nextLesson.scheduledDate,
      enrollment,
      studyProgram,
      activities: nextLesson.currentVersion.activities.map(({ id, kind, position, title, document }) => ({
        id,
        type: kind,
        orderNumber: position,
        title,
        videoUrl: null,
        sourceReferences: [],
        thumbnailUrl: thumbnailFromDocument(document, media),
      })),
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
            // For the canManage check (monday#12270302158):
            creatorId: true,
            organizationId: true,
            _count: {
              select: { members: true },
            },
            creator: {
              select: { name: true },
            },
          },
        },
        // Program creator's name — so a leader who can't edit this study sees
        // "created by <name>, contact them for changes" (monday#12270302158).
        studyProgram: {
          select: {
            creator: { select: { name: true } },
          },
        },
      },
    })

    // Stamp canManage so the client can disable "Edit enrollment" for
    // enrollments this user can't edit (monday#12270302158). These span
    // multiple groups, so the check reads each enrollment's own group.
    const canManage = await buildEnrollmentManageChecker(userId)
    const enrollmentsWithPerm = enrollments.map((e) => ({
      ...e,
      canManage: canManage({ createdById: e.createdById, group: e.group }),
      studyProgramCreatorName: e.studyProgram?.creator?.name ?? null,
    }))

    res.json({ success: true, enrollments: enrollmentsWithPerm })
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
 * /api/enrollments/{id}/edit/preview:
 *   post:
 *     tags: [Enrollments]
 *     summary: Preview the impact of an enrollment edit
 *     description: >
 *       Dry-run for the edit-enrollment flow (monday#12270302158). Reports which
 *       lessons a group change / reschedule / study-swap would remove, archive,
 *       add, or shift — without mutating anything — so the client can warn the
 *       leader before Save.
 *     security:
 *       - userSession: []
 */
router.post('/enrollments/:id/edit/preview', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      groupId: z.string().uuid().optional(),
      studyProgramId: z.string().uuid().optional(),
      startDate: z.string().datetime().optional(),
      enabledDays: z.array(z.enum(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])).min(1).optional(),
    })
    const body = schema.parse(req.body)

    // Ownership gate (same as PATCH).
    const enrollment = await prisma.enrollment.findFirst({
      where: { id, ...(await enrollmentManageFilter(userId)) },
      select: { id: true },
    })
    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const preview = await previewEnrollmentEdit(id, body)
    res.json({ success: true, preview })
  } catch (error) {
    if (error instanceof EnrollmentEditError) {
      return res.status(error.status).json({ success: false, error: error.message })
    }
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: 'Invalid request', details: error.errors })
    }
    console.error('Error previewing enrollment edit:', error)
    res.status(500).json({ success: false, error: 'Failed to preview enrollment edit' })
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
      // Structural edits (monday#12270302158) — routed through enrollment-edit service.
      groupId: z.string().uuid().optional(),
      studyProgramId: z.string().uuid().optional(),
      startDate: z.string().datetime().optional(),
      enabledDays: z.array(z.enum(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])).min(1).optional(),
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

    // Structural edit (group change / reschedule) — commit atomically first,
    // then fall through to patch any scalar fields sent alongside.
    const hasStructural =
      body.groupId !== undefined ||
      body.studyProgramId !== undefined ||
      body.startDate !== undefined ||
      body.enabledDays !== undefined
    if (hasStructural) {
      const editChanges = {
        groupId: body.groupId,
        studyProgramId: body.studyProgramId,
        startDate: body.startDate,
        enabledDays: body.enabledDays,
      }
      const swappingStudy = body.studyProgramId !== undefined && body.studyProgramId !== enrollment.studyProgramId
      try {
        if (swappingStudy) {
          await applyStudySwap(id, editChanges, userId)
        } else {
          await applyEnrollmentEdit(id, editChanges, userId)
        }
      } catch (err) {
        if (err instanceof EnrollmentEditError) {
          return res.status(err.status).json({ success: false, error: err.message })
        }
        throw err
      }
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
 *       and the pending versions' change summaries so a leader can decide
 *       whether to apply them. Version numbers are ProgramVersion.number.
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
      where: { id, studyProgram: { isActive: true }, ...(await enrollmentManageFilter(userId)) },
      select: { id: true },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const sync = await getEnrollmentSyncStatus(id)
    // `sync` is the nested object the iPhone decodes; the same fields are also at the top level.
    res.json({ success: true, ...sync, sync })
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
      where: { id, studyProgram: { isActive: true }, ...(await enrollmentManageFilter(userId)) },
      select: { id: true },
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
 *       version, in one transaction, by moving pointers. Used by APPROVAL-mode
 *       acceptance and manual catch-up for OFF-mode enrollments with drift.
 *       Lessons the group customized are skipped and listed in
 *       skippedCustomizedLessonIds. Idempotent — reapplying is a no-op.
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
      where: { id, studyProgram: { isActive: true }, ...(await enrollmentManageFilter(userId)) },
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

    const outcome = await syncEnrollmentToCurrent({
      enrollmentId: id,
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

    // Fetch the scheduled lesson with related data
    const schedule = await prisma.scheduledLesson.findUnique({
      where: { id },
      include: {
        lesson: { select: { position: true } },
        template: { select: { name: true } },
        enrollment: {
          include: {
            studyProgram: { select: { id: true, name: true, description: true, days: true, coverImageUrl: true } },
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

    res.json({
      success: true,
      invite: {
        id: schedule.id,
        lessonScheduleId: schedule.id, // Deprecated: use 'id' instead
        code: schedule.code,
        dayNumber: schedule.lesson?.position ?? 0,
        scheduledDate: schedule.scheduledDate,
        templateName: schedule.template?.name ?? null,
        // Documents carry passages as book/chapter/verse numbers, not a printable reference.
        passageReference: null,
        studyProgram: {
          id: schedule.enrollment.studyProgram.id,
          name: schedule.enrollment.studyProgram.name,
          days: schedule.enrollment.studyProgram.days,
          coverImageUrl: schedule.enrollment.studyProgram.coverImageUrl,
        },
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
        scheduledLessonId: true,
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

    // The wire keeps `lessonScheduleId`: the calendar event's ScheduledLesson.
    res.json({ success: true, events: events.map(({ scheduledLessonId, ...event }) => ({ ...event, lessonScheduleId: scheduledLessonId })) })
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
      include: { studyProgram: { select: { currentVersionId: true } } },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    // The lesson must be in the program version the enrollment is on (else the program's current one).
    const programVersionId = enrollment.programVersionId ?? enrollment.studyProgram.currentVersionId
    const versionLesson = programVersionId
      ? await prisma.programVersionLesson.findFirst({ where: { programVersionId, lessonId: body.lessonId, lesson: { programId: enrollment.studyProgramId, deletedAt: null } } })
      : null

    if (!programVersionId || !versionLesson) {
      return res.status(400).json({
        success: false,
        error: 'Lesson not found or does not belong to this enrollment\'s program',
      })
    }

    // Check for duplicate (unique constraint: enrollmentId + lessonId)
    const existing = await prisma.scheduledLesson.findUnique({
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

    const latestSchedule = await prisma.scheduledLesson.findFirst({
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

    // The scheduled lesson, its calendar event and the endDate move together.
    await prisma.$transaction(async (tx) => {
      await createScheduledLessons(tx, enrollmentId, programVersionId, new Map([[body.lessonId, scheduledDate]]))
      if (scheduledDate > enrollment.endDate) {
        await tx.enrollment.update({ where: { id: enrollmentId }, data: { endDate: scheduledDate } })
      }
    })

    // Fetch the created schedule with its lesson's activities
    const row = await prisma.scheduledLesson.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId: body.lessonId } },
      include: { ...scheduledLessonInclude, event: true },
    })
    const { event, ...scheduled } = row
    const schedule = { ...serializeScheduledLesson(scheduled), event }
    const media = await mediaForScheduledLessons([row])

    res.json({ success: true, schedule, media })
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

    const schedule = await prisma.scheduledLesson.findFirst({
      where: {
        id: scheduleId,
        enrollmentId,
      },
      select: { id: true },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
    }

    await setScheduledLessonTitle(scheduleId, data.title)
    const updated = await prisma.scheduledLesson.findUniqueOrThrow({
      where: { id: scheduleId },
      include: scheduledLessonInclude,
    })

    res.json({ success: true, schedule: serializeScheduledLesson(updated) })
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
    const schedule = await prisma.scheduledLesson.findFirst({
      where: {
        id: scheduleId,
        enrollmentId,
      },
    })

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Lesson schedule not found' })
    }

    // One transaction: the event and schedule go, the curriculum lesson goes with them (D36 closes the program
    // up), and the end date follows. A user who manages this enrollment but not the program's content gets the
    // lesson's 404 and nothing changes. A lesson already gone (or an orphaned schedule) is skipped.
    await prisma.$transaction(async (tx) => {
      await tx.event.deleteMany({ where: { scheduledLessonId: scheduleId } })
      await tx.scheduledLesson.delete({ where: { id: scheduleId } })
      if (schedule.lessonId) {
        const lesson = await tx.lesson.findUnique({ where: { id: schedule.lessonId }, select: { deletedAt: true } })
        if (lesson && !lesson.deletedAt) await deleteLessonIn(tx, userId, schedule.lessonId)
      }
      const latestSchedule = await tx.scheduledLesson.findFirst({
        where: { enrollmentId },
        orderBy: { scheduledDate: 'desc' },
        select: { scheduledDate: true },
      })
      if (latestSchedule) {
        await tx.enrollment.update({ where: { id: enrollmentId }, data: { endDate: latestSchedule.scheduledDate } })
      }
    })

    res.json({ success: true })
  } catch (error) {
    if (error instanceof ContentError) return res.status(error.status).json({ success: false, error: error.message, code: error.code })
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
        scheduledLessons: {
          select: {
            id: true,
            _count: {
              select: { activityProgress: true, lessonProgress: true },
            },
          },
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const totalLessons = enrollment.scheduledLessons.length
    const lessonsWithData = enrollment.scheduledLessons.filter(
      (ls) => ls._count.activityProgress + ls._count.lessonProgress > 0
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
        scheduledLessons: {
          select: {
            id: true,
            _count: {
              select: { activityProgress: true, lessonProgress: true },
            },
          },
        },
      },
    })

    if (!enrollment) {
      return res.status(404).json({ success: false, error: 'Enrollment not found' })
    }

    const cleanScheduleIds = enrollment.scheduledLessons
      .filter((ls) => ls._count.activityProgress + ls._count.lessonProgress === 0)
      .map((ls) => ls.id)

    if (cleanScheduleIds.length > 0) {
      await prisma.scheduledLesson.deleteMany({
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
