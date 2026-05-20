import { Router, Request, Response } from 'express'
import { z } from 'zod'
import { requireMemberAuth } from '../middleware/auth.js'
import {
  getMemberLessons,
  getMemberLessonDetail,
  getMemberEnrollments,
  getEnrollmentProgress,
  getGroupStudies,
} from '../services/member-progress.service.js'
import { prisma } from '../lib/prisma.js'

const router = Router()

/**
 * Check if the current request is from a group leader (org owner via Google OAuth).
 * Returns true if req.user exists and owns an org that contains the given groupId.
 */
async function isRequestFromGroupLeader(req: Request, groupId?: string): Promise<boolean> {
  const user = req.user as any
  if (!user?.id) return false

  if (groupId) {
    // Check if this user owns the org that contains this specific group
    const group = await prisma.group.findUnique({
      where: { id: groupId },
      select: { organizationId: true },
    })
    if (!group || !group.organizationId) return false

    const org = await prisma.organization.findUnique({
      where: { id: group.organizationId },
      select: { ownerId: true },
    })
    return org?.ownerId === user.id
  }

  // No specific group — check if user owns any org
  const ownedOrg = await prisma.organization.findFirst({
    where: { ownerId: user.id, isActive: true },
  })
  return ownedOrg !== null
}

// ============================================================================
// Member Lesson History Routes
// ============================================================================

/**
 * @openapi
 * components:
 *   schemas:
 *     MemberLesson:
 *       type: object
 *       properties:
 *         lessonScheduleId:
 *           type: string
 *           format: uuid
 *           description: Unique identifier for the lesson schedule
 *         lessonId:
 *           type: string
 *           format: uuid
 *           description: Unique identifier for the lesson
 *         title:
 *           type: string
 *           description: Title of the lesson
 *         description:
 *           type: string
 *           nullable: true
 *           description: Description of the lesson
 *         scheduledDate:
 *           type: string
 *           format: date-time
 *           description: Scheduled date and time for the lesson
 *         status:
 *           type: string
 *           enum: [completed, in_progress, upcoming]
 *           description: Current status of the lesson for this member
 *         completedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *           description: When the lesson was completed
 *         enrollmentId:
 *           type: string
 *           format: uuid
 *           description: ID of the enrollment this lesson belongs to
 *         programName:
 *           type: string
 *           description: Name of the program
 *         totalActivities:
 *           type: integer
 *           description: Total number of activities in the lesson
 *         completedActivities:
 *           type: integer
 *           description: Number of activities completed by the member
 *       example:
 *         lessonScheduleId: "550e8400-e29b-41d4-a716-446655440000"
 *         lessonId: "550e8400-e29b-41d4-a716-446655440001"
 *         title: "Introduction to Sales"
 *         description: "Learn the basics of sales techniques"
 *         scheduledDate: "2024-01-15T09:00:00Z"
 *         status: "completed"
 *         completedAt: "2024-01-15T10:30:00Z"
 *         enrollmentId: "550e8400-e29b-41d4-a716-446655440002"
 *         programName: "Sales Training 101"
 *         totalActivities: 5
 *         completedActivities: 5
 *     MemberLessonDetail:
 *       type: object
 *       properties:
 *         lessonScheduleId:
 *           type: string
 *           format: uuid
 *         lessonId:
 *           type: string
 *           format: uuid
 *         title:
 *           type: string
 *         description:
 *           type: string
 *           nullable: true
 *         scheduledDate:
 *           type: string
 *           format: date-time
 *         status:
 *           type: string
 *           enum: [completed, in_progress, upcoming]
 *         completedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *         enrollmentId:
 *           type: string
 *           format: uuid
 *         programName:
 *           type: string
 *         activities:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/ActivityProgress'
 *       example:
 *         lessonScheduleId: "550e8400-e29b-41d4-a716-446655440000"
 *         lessonId: "550e8400-e29b-41d4-a716-446655440001"
 *         title: "Introduction to Sales"
 *         description: "Learn the basics of sales techniques"
 *         scheduledDate: "2024-01-15T09:00:00Z"
 *         status: "completed"
 *         completedAt: "2024-01-15T10:30:00Z"
 *         enrollmentId: "550e8400-e29b-41d4-a716-446655440002"
 *         programName: "Sales Training 101"
 *         activities: []
 *     ActivityProgress:
 *       type: object
 *       properties:
 *         activityId:
 *           type: string
 *           format: uuid
 *         title:
 *           type: string
 *         type:
 *           type: string
 *           description: Type of activity (e.g., video, quiz, reading)
 *         order:
 *           type: integer
 *           description: Order of the activity within the lesson
 *         completed:
 *           type: boolean
 *         completedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *         notes:
 *           type: string
 *           nullable: true
 *           description: Member's notes for this activity
 *       example:
 *         activityId: "550e8400-e29b-41d4-a716-446655440003"
 *         title: "Watch Introduction Video"
 *         type: "video"
 *         order: 1
 *         completed: true
 *         completedAt: "2024-01-15T09:15:00Z"
 *         notes: "Great overview of key concepts"
 *     MemberEnrollment:
 *       type: object
 *       properties:
 *         enrollmentId:
 *           type: string
 *           format: uuid
 *         programId:
 *           type: string
 *           format: uuid
 *         programName:
 *           type: string
 *         startDate:
 *           type: string
 *           format: date-time
 *         endDate:
 *           type: string
 *           format: date-time
 *           nullable: true
 *         status:
 *           type: string
 *           enum: [active, completed, cancelled]
 *         totalLessons:
 *           type: integer
 *         completedLessons:
 *           type: integer
 *         progressPercentage:
 *           type: number
 *           format: float
 *           description: Progress as a percentage (0-100)
 *       example:
 *         enrollmentId: "550e8400-e29b-41d4-a716-446655440002"
 *         programId: "550e8400-e29b-41d4-a716-446655440004"
 *         programName: "Sales Training 101"
 *         startDate: "2024-01-01T00:00:00Z"
 *         endDate: "2024-03-01T00:00:00Z"
 *         status: "active"
 *         totalLessons: 20
 *         completedLessons: 8
 *         progressPercentage: 40.0
 *     EnrollmentProgress:
 *       type: object
 *       properties:
 *         enrollment:
 *           $ref: '#/components/schemas/MemberEnrollment'
 *         days:
 *           type: array
 *           items:
 *             type: object
 *             properties:
 *               dayNumber:
 *                 type: integer
 *               date:
 *                 type: string
 *                 format: date
 *               lessons:
 *                 type: array
 *                 items:
 *                   $ref: '#/components/schemas/MemberLesson'
 *               completedCount:
 *                 type: integer
 *               totalCount:
 *                 type: integer
 *       example:
 *         enrollment:
 *           enrollmentId: "550e8400-e29b-41d4-a716-446655440002"
 *           programName: "Sales Training 101"
 *           status: "active"
 *         days:
 *           - dayNumber: 1
 *             date: "2024-01-15"
 *             lessons: []
 *             completedCount: 2
 *             totalCount: 2
 *     PaginationInfo:
 *       type: object
 *       properties:
 *         total:
 *           type: integer
 *           description: Total number of items
 *         limit:
 *           type: integer
 *           description: Maximum items per page
 *         offset:
 *           type: integer
 *           description: Current offset
 *         hasMore:
 *           type: boolean
 *           description: Whether there are more items available
 *       example:
 *         total: 50
 *         limit: 10
 *         offset: 0
 *         hasMore: true
 */

/**
 * @openapi
 * /api/member/lessons:
 *   get:
 *     tags:
 *       - Member Lessons
 *     summary: Get all lessons for the authenticated member
 *     description: |
 *       Retrieves all lessons for the authenticated member with their completion status.
 *       Results can be filtered by status and enrollment, and support pagination.
 *
 *       **Group Leader Access:** When the authenticated session also has a Google OAuth
 *       user who owns the group's organization, future-scheduled lessons are returned
 *       as `not_started` instead of `upcoming`, making them accessible.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [all, completed, in_progress, upcoming]
 *           default: all
 *         description: Filter lessons by completion status
 *       - in: query
 *         name: enrollmentId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by specific enrollment
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 50
 *         description: Maximum number of results to return
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           minimum: 0
 *           default: 0
 *         description: Number of results to skip for pagination
 *     responses:
 *       200:
 *         description: Successfully retrieved lessons
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 lessons:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/MemberLesson'
 *                 pagination:
 *                   $ref: '#/components/schemas/PaginationInfo'
 *       400:
 *         description: Invalid query parameters
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Invalid query parameters"
 *                 details:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Member not authenticated"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Failed to fetch lessons"
 */
router.get(
  '/member/lessons',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate query params
      const querySchema = z.object({
        status: z.enum(['all', 'completed', 'in_progress', 'upcoming']).optional(),
        enrollmentId: z.string().uuid().optional(),
        limit: z.coerce.number().int().min(1).max(100).optional(),
        offset: z.coerce.number().int().min(0).optional(),
      })

      const parsed = querySchema.safeParse(req.query)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid query parameters',
          details: parsed.error.errors,
        })
      }

      const { status, enrollmentId, limit, offset } = parsed.data

      const isGroupLeader = await isRequestFromGroupLeader(req)

      const result = await getMemberLessons(memberId, {
        status,
        enrollmentId,
        limit,
        offset,
        isGroupLeader,
      })

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        lessons: result.data?.data || [],
        pagination: result.data?.pagination,
      })
    } catch (error) {
      console.error('Error fetching member lessons:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch lessons',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/lessons/{lessonScheduleId}:
 *   get:
 *     tags:
 *       - Member Lessons
 *     summary: Get detailed lesson information
 *     description: |
 *       Retrieves detailed information about a specific lesson including all activities
 *       with their progress status and any notes the member has made.
 *
 *       **Group Leader Access:** When the authenticated session also has a Google OAuth
 *       user who owns the group's organization, future-scheduled lessons return full
 *       detail with status `not_started` instead of `upcoming`.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: lessonScheduleId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The unique identifier of the lesson schedule
 *     responses:
 *       200:
 *         description: Successfully retrieved lesson details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 lesson:
 *                   $ref: '#/components/schemas/MemberLessonDetail'
 *       400:
 *         description: Invalid lesson schedule ID format
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Invalid lesson schedule ID"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Member not authenticated"
 *       403:
 *         description: Member does not have access to this lesson
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Access denied"
 *       404:
 *         description: Lesson not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Lesson not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Failed to fetch lesson detail"
 */
router.get(
  '/member/lessons/:lessonScheduleId',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      // Support memberId as query param for backward compatibility (like study-enrollment endpoint)
      const queryMemberId = req.query.memberId as string | undefined
      const sessionMemberId = req.member?.id
      const memberId = queryMemberId || sessionMemberId
      const { lessonScheduleId } = req.params

      // Debug logging
      console.log('[member-lessons] Request:', {
        lessonScheduleId,
        sessionMemberId,
        queryMemberId,
        memberId,
        memberName: req.member ? `${req.member.firstName} ${req.member.lastName}` : 'N/A',
      })

      // Log for debugging
      if (queryMemberId && sessionMemberId && queryMemberId !== sessionMemberId) {
        console.warn('Member ID mismatch:', { queryMemberId, sessionMemberId })
      }

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate UUID
      const uuidSchema = z.string().uuid()
      const uuidResult = uuidSchema.safeParse(lessonScheduleId)
      if (!uuidResult.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid lesson schedule ID',
        })
      }

      const isGroupLeader = await isRequestFromGroupLeader(req)
      const result = await getMemberLessonDetail(memberId, lessonScheduleId, isGroupLeader)

      if (!result.success) {
        console.log('[member-lessons] Error:', { memberId, lessonScheduleId, error: result.error })
        const statusCode = result.error === 'Lesson not found' ? 404 : 403
        return res.status(statusCode).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        lesson: result.data,
      })
    } catch (error) {
      console.error('Error fetching lesson detail:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch lesson detail',
      })
    }
  }
)

// ============================================================================
// Member Enrollment Progress Routes
// ============================================================================

/**
 * @openapi
 * /api/member/enrollments:
 *   get:
 *     tags:
 *       - Member Lessons
 *     summary: Get all enrollments for the authenticated member
 *     description: |
 *       Retrieves all program enrollments for the authenticated member with a
 *       summary of progress for each enrollment including completed lessons count
 *       and overall progress percentage.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: Successfully retrieved enrollments
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
 *                     $ref: '#/components/schemas/MemberEnrollment'
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Member not authenticated"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Failed to fetch enrollments"
 */
router.get(
  '/member/enrollments',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      const result = await getMemberEnrollments(memberId)

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        enrollments: result.data || [],
      })
    } catch (error) {
      console.error('Error fetching member enrollments:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch enrollments',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/enrollments/{enrollmentId}:
 *   get:
 *     tags:
 *       - Member Lessons
 *     summary: Get detailed enrollment progress
 *     description: |
 *       Retrieves detailed progress information for a specific enrollment including
 *       a day-by-day breakdown of lessons, their completion status, and overall
 *       program progress metrics.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: enrollmentId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The unique identifier of the enrollment
 *     responses:
 *       200:
 *         description: Successfully retrieved enrollment progress
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 enrollment:
 *                   $ref: '#/components/schemas/MemberEnrollment'
 *                 days:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       dayNumber:
 *                         type: integer
 *                         description: The day number in the program sequence
 *                       date:
 *                         type: string
 *                         format: date
 *                         description: The calendar date for this day
 *                       lessons:
 *                         type: array
 *                         items:
 *                           $ref: '#/components/schemas/MemberLesson'
 *                       completedCount:
 *                         type: integer
 *                         description: Number of lessons completed on this day
 *                       totalCount:
 *                         type: integer
 *                         description: Total number of lessons scheduled for this day
 *       400:
 *         description: Invalid enrollment ID format
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Invalid enrollment ID"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Member not authenticated"
 *       403:
 *         description: Member does not have access to this enrollment
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Access denied"
 *       404:
 *         description: Enrollment not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Enrollment not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Failed to fetch enrollment progress"
 */
router.get(
  '/member/enrollments/:enrollmentId',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id
      const { enrollmentId } = req.params

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate UUID
      const uuidSchema = z.string().uuid()
      const uuidResult = uuidSchema.safeParse(enrollmentId)
      if (!uuidResult.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid enrollment ID',
        })
      }

      const result = await getEnrollmentProgress(memberId, enrollmentId)

      if (!result.success) {
        const statusCode = result.error === 'Enrollment not found' ? 404 : 403
        return res.status(statusCode).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        ...result.data,
      })
    } catch (error) {
      console.error('Error fetching enrollment progress:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch enrollment progress',
      })
    }
  }
)

// ============================================================================
// Group Studies Route
// ============================================================================

/**
 * @openapi
 * /api/member/groups/{groupId}/studies:
 *   get:
 *     tags:
 *       - Member Lessons
 *     summary: Get available studies for a group
 *     description: |
 *       Returns all enrollments for a specific group with lessons available today or earlier.
 *       Used for the group home page to show available study content.
 *
 *       **Group Leader Access:** When the authenticated session also has a Google OAuth
 *       user who owns the group's organization, ALL lessons are returned regardless
 *       of scheduled date (including future lessons).
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The unique identifier of the group
 *     responses:
 *       200:
 *         description: Successfully retrieved group studies
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     group:
 *                       type: object
 *                       properties:
 *                         id:
 *                           type: string
 *                           format: uuid
 *                         name:
 *                           type: string
 *                         coverImageUrl:
 *                           type: string
 *                           nullable: true
 *                     enrollments:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                             format: uuid
 *                           studyProgram:
 *                             type: object
 *                             properties:
 *                               id:
 *                                 type: string
 *                                 format: uuid
 *                               name:
 *                                 type: string
 *                               description:
 *                                 type: string
 *                                 nullable: true
 *                               coverImageUrl:
 *                                 type: string
 *                                 nullable: true
 *                               totalDays:
 *                                 type: integer
 *                           startDate:
 *                             type: string
 *                             format: date-time
 *                           endDate:
 *                             type: string
 *                             format: date-time
 *                             nullable: true
 *                           availableLessons:
 *                             type: array
 *                             items:
 *                               type: object
 *                               properties:
 *                                 lessonScheduleId:
 *                                   type: string
 *                                   format: uuid
 *                                 lessonId:
 *                                   type: string
 *                                   format: uuid
 *                                 dayNumber:
 *                                   type: integer
 *                                 scheduledDate:
 *                                   type: string
 *                                   format: date-time
 *                                 status:
 *                                   type: string
 *                                   enum: [completed, in_progress, available]
 *                                 activityCount:
 *                                   type: integer
 *                                 completedActivityCount:
 *                                   type: integer
 *                           totalLessons:
 *                             type: integer
 *                           availableLessonCount:
 *                             type: integer
 *                           completedLessonCount:
 *                             type: integer
 *       400:
 *         description: Invalid group ID format
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Invalid group ID"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Member not authenticated"
 *       403:
 *         description: Not a member of this group
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Not a member of this group"
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Group not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Failed to fetch group studies"
 */
router.get(
  '/member/groups/:groupId/studies',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id
      const { groupId } = req.params

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate UUID
      const uuidSchema = z.string().uuid()
      const uuidResult = uuidSchema.safeParse(groupId)
      if (!uuidResult.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid group ID',
        })
      }

      const isGroupLeader = await isRequestFromGroupLeader(req, groupId)
      const result = await getGroupStudies(memberId, groupId, isGroupLeader)

      if (!result.success) {
        let statusCode = 500
        if (result.error === 'Not a member of this group') {
          statusCode = 403
        } else if (result.error === 'Group not found') {
          statusCode = 404
        }
        return res.status(statusCode).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error fetching group studies:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch group studies',
      })
    }
  }
)

export default router
