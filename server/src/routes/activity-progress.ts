import { Router, Request, Response } from 'express'
import { z } from 'zod'
import { requireMemberAuth, requireAuth } from '../middleware/auth.js'
import {
  saveActivityProgress,
  getActivityProgress,
  submitActivityResponse,
  type NoteType,
} from '../services/notes.service.js'
import {
  saveVideoProgress,
  getVideoProgress,
  checkAndUpdateLessonCompletion,
} from '../services/member-progress.service.js'
import { prisma } from '../lib/prisma.js'

/**
 * @openapi
 * components:
 *   schemas:
 *     NoteType:
 *       type: string
 *       enum:
 *         - OBSERVATION
 *         - APPLICATION
 *         - PRAYER
 *         - JOURNAL
 *         - REFLECTION
 *         - SCRIPTURE_NOTE
 *         - QUESTION
 *       description: Type of note created during SOAP activity
 *
 *     ActivityStep:
 *       type: string
 *       enum:
 *         - READ_SCRIPTURE
 *         - OBSERVE
 *         - APPLICATION
 *         - PRAYER
 *         - COMPLETE
 *       description: Current step in the SOAP activity workflow
 *
 *     Note:
 *       type: object
 *       required:
 *         - type
 *         - content
 *       properties:
 *         type:
 *           $ref: '#/components/schemas/NoteType'
 *         content:
 *           type: string
 *           minLength: 1
 *           description: The note content
 *       example:
 *         type: OBSERVATION
 *         content: "The passage emphasizes God's faithfulness throughout generations."
 *
 *     SaveActivityProgressRequest:
 *       type: object
 *       required:
 *         - lessonScheduleId
 *         - currentStep
 *       properties:
 *         lessonScheduleId:
 *           type: string
 *           format: uuid
 *           description: The scheduled lesson ID
 *         currentStep:
 *           $ref: '#/components/schemas/ActivityStep'
 *         notes:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/Note'
 *           description: Optional array of notes to save with this progress update
 *       example:
 *         lessonScheduleId: "123e4567-e89b-12d3-a456-426614174000"
 *         currentStep: OBSERVE
 *         notes:
 *           - type: OBSERVATION
 *             content: "Key observation from the scripture reading"
 *
 *     ActivityProgress:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         memberId:
 *           type: string
 *           format: uuid
 *         lessonScheduleId:
 *           type: string
 *           format: uuid
 *         lessonActivityId:
 *           type: string
 *           format: uuid
 *         currentStep:
 *           $ref: '#/components/schemas/ActivityStep'
 *         completedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *         createdAt:
 *           type: string
 *           format: date-time
 *         updatedAt:
 *           type: string
 *           format: date-time
 *
 *     SaveActivityProgressResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         data:
 *           type: object
 *           properties:
 *             progress:
 *               $ref: '#/components/schemas/ActivityProgress'
 *             notes:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: string
 *                     format: uuid
 *                   type:
 *                     $ref: '#/components/schemas/NoteType'
 *                   content:
 *                     type: string
 *                   createdAt:
 *                     type: string
 *                     format: date-time
 *
 *     GetActivityProgressResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         data:
 *           oneOf:
 *             - $ref: '#/components/schemas/ActivityProgress'
 *             - type: 'null'
 *           description: Activity progress or null if not started
 *
 *     SaveVideoProgressRequest:
 *       type: object
 *       required:
 *         - lessonScheduleId
 *         - watchedSeconds
 *       properties:
 *         lessonScheduleId:
 *           type: string
 *           format: uuid
 *           description: The scheduled lesson ID
 *         watchedSeconds:
 *           type: integer
 *           minimum: 0
 *           description: Number of seconds watched
 *         totalDuration:
 *           type: integer
 *           minimum: 0
 *           description: Total video duration in seconds (optional)
 *       example:
 *         lessonScheduleId: "123e4567-e89b-12d3-a456-426614174000"
 *         watchedSeconds: 180
 *         totalDuration: 600
 *
 *     VideoProgress:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         memberId:
 *           type: string
 *           format: uuid
 *         lessonScheduleId:
 *           type: string
 *           format: uuid
 *         lessonActivityId:
 *           type: string
 *           format: uuid
 *         watchedSeconds:
 *           type: integer
 *           description: Number of seconds watched
 *         totalDuration:
 *           type: integer
 *           nullable: true
 *           description: Total video duration in seconds
 *         completed:
 *           type: boolean
 *           description: Whether video is considered complete (>=90% watched)
 *         completedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *         createdAt:
 *           type: string
 *           format: date-time
 *         updatedAt:
 *           type: string
 *           format: date-time
 *
 *     VideoProgressResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         data:
 *           oneOf:
 *             - $ref: '#/components/schemas/VideoProgress'
 *             - type: 'null'
 *           description: Video progress or null if not started
 *
 *     ErrorResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: false
 *         error:
 *           type: string
 *           description: Error message
 *         details:
 *           type: array
 *           items:
 *             type: object
 *           description: Validation error details (when applicable)
 */

const router = Router()

// ============================================================================
// Validation Schemas
// ============================================================================

const noteSchema = z.object({
  type: z.enum([
    'OBSERVATION',
    'APPLICATION',
    'PRAYER',
    'JOURNAL',
    'REFLECTION',
    'SCRIPTURE_NOTE',
    'QUESTION',
  ]),
  content: z.string().min(1),
})

const saveProgressSchema = z.object({
  lessonScheduleId: z.string().uuid(),
  currentStep: z.enum([
    'READ_SCRIPTURE',
    'OBSERVE',
    'APPLICATION',
    'PRAYER',
    'COMPLETE',
  ]),
  notes: z.array(noteSchema).optional(),
})

const submitActivitySchema = z.object({
  lessonScheduleId: z.string().uuid(),
  note: z
    .object({
      // StudyNote.type is a free-form string (OBSERVATION/APPLICATION/PRAYER/
      // JOURNAL/etc.). Activities can define an arbitrary note type, or none —
      // the client derives one — so accept any non-empty string here rather than
      // rejecting otherwise-valid submissions with a 400.
      type: z.string().min(1),
      content: z.string().min(1),
    })
    .optional(),
  action: z.enum(['start', 'skip_to_complete', 'complete']).optional(),
})

// ============================================================================
// Member Activity Progress Routes
// ============================================================================

/**
 * @openapi
 * /api/member/activities/{lessonActivityId}/progress:
 *   post:
 *     tags:
 *       - Activity Progress
 *     summary: Save member activity progress and notes
 *     description: |
 *       Save activity progress and notes in a single atomic request.
 *       This is the main endpoint for Members completing SOAP activities.
 *       It handles progress tracking and note creation together.
 *
 *       The activity follows a step-by-step workflow:
 *       1. READ_SCRIPTURE - Reading the assigned scripture
 *       2. OBSERVE - Making observations about the text
 *       3. APPLICATION - Applying the scripture to life
 *       4. PRAYER - Recording prayer responses
 *       5. COMPLETE - Activity finished
 *
 *       Notes can be added at any step and are associated with the progress record.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: lessonActivityId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The lesson activity ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/SaveActivityProgressRequest'
 *     responses:
 *       200:
 *         description: Progress saved successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SaveActivityProgressResponse'
 *             example:
 *               success: true
 *               data:
 *                 progress:
 *                   id: "abc123"
 *                   memberId: "member456"
 *                   lessonScheduleId: "schedule789"
 *                   lessonActivityId: "activity012"
 *                   currentStep: "OBSERVE"
 *                   completedAt: null
 *                   createdAt: "2024-01-15T10:30:00Z"
 *                   updatedAt: "2024-01-15T10:35:00Z"
 *                 notes:
 *                   - id: "note123"
 *                     type: "OBSERVATION"
 *                     content: "Key observation from scripture"
 *                     createdAt: "2024-01-15T10:35:00Z"
 *       400:
 *         description: Invalid request body or validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Invalid request body"
 *               details:
 *                 - path: ["lessonScheduleId"]
 *                   message: "Invalid uuid"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Member not authenticated"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to save progress"
 */
router.post(
  '/member/activities/:lessonActivityId/progress',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const { lessonActivityId } = req.params
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate request body
      console.log('Save progress request:', {
        lessonActivityId,
        memberId,
        body: req.body,
      })
      const parsed = saveProgressSchema.safeParse(req.body)
      if (!parsed.success) {
        console.error('Validation failed:', JSON.stringify(parsed.error.errors, null, 2))
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      const { lessonScheduleId, currentStep, notes } = parsed.data

      // Save progress and notes
      const result = await saveActivityProgress({
        memberId,
        lessonScheduleId,
        lessonActivityId,
        currentStep,
        notes: notes?.map(n => ({ type: n.type as NoteType, content: n.content })),
      })

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: {
          progress: result.progress,
          notes: result.notes,
        },
      })
    } catch (error) {
      console.error('Error saving activity progress:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to save progress',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/activities/{lessonActivityId}/submit:
 *   post:
 *     tags:
 *       - Activity Progress
 *     summary: Submit activity response with server-side step completion
 *     description: |
 *       Submit an activity response where the server determines step completion.
 *       This is the new approach for SOAP activities:
 *
 *       **Actions:**
 *       - `start` - Opens the activity, marks READ_SCRIPTURE as complete
 *       - `skip_to_complete` - Marks all steps complete (only if enrollment.requireResponse = false,
 *         or if the user is a group leader/org owner via Google OAuth)
 *
 *       **Note Submission:**
 *       - Submit a note with type OBSERVATION, APPLICATION, or PRAYER
 *       - The server marks the corresponding step as complete
 *
 *       **Step-to-Note Mapping:**
 *       | Note Type | Step Completed |
 *       |-----------|----------------|
 *       | OBSERVATION | OBSERVE |
 *       | APPLICATION | APPLICATION |
 *       | PRAYER | PRAYER |
 *
 *       When all 4 steps (READ_SCRIPTURE, OBSERVE, APPLICATION, PRAYER) are complete,
 *       the activity is marked as COMPLETE.
 *
 *       Returns the full lesson state after processing.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: lessonActivityId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The lesson activity ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - lessonScheduleId
 *             properties:
 *               lessonScheduleId:
 *                 type: string
 *                 format: uuid
 *                 description: The scheduled lesson ID
 *               note:
 *                 type: object
 *                 properties:
 *                   type:
 *                     type: string
 *                     enum: [OBSERVATION, APPLICATION, PRAYER]
 *                     description: Type of note (maps to step)
 *                   content:
 *                     type: string
 *                     minLength: 1
 *                     description: The note content
 *               action:
 *                 type: string
 *                 enum: [start, skip_to_complete]
 *                 description: Action to perform (start opens activity, skip_to_complete marks all done)
 *           examples:
 *             startActivity:
 *               summary: Start activity (mark READ_SCRIPTURE complete)
 *               value:
 *                 lessonScheduleId: "123e4567-e89b-12d3-a456-426614174000"
 *                 action: "start"
 *             submitObservation:
 *               summary: Submit observation note
 *               value:
 *                 lessonScheduleId: "123e4567-e89b-12d3-a456-426614174000"
 *                 note:
 *                   type: "OBSERVATION"
 *                   content: "The passage emphasizes God's faithfulness."
 *             skipToComplete:
 *               summary: Skip to complete (when responses not required)
 *               value:
 *                 lessonScheduleId: "123e4567-e89b-12d3-a456-426614174000"
 *                 action: "skip_to_complete"
 *     responses:
 *       200:
 *         description: Activity response submitted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 lesson:
 *                   type: object
 *                   description: Full lesson detail with updated progress
 *                   properties:
 *                     lessonScheduleId:
 *                       type: string
 *                       format: uuid
 *                     dayNumber:
 *                       type: integer
 *                     scheduledDate:
 *                       type: string
 *                       format: date-time
 *                     status:
 *                       type: string
 *                       enum: [completed, in_progress, not_started, upcoming]
 *                     completionPercentage:
 *                       type: integer
 *                     completedAt:
 *                       type: string
 *                       format: date-time
 *                       nullable: true
 *                     requireResponse:
 *                       type: boolean
 *                       description: Whether user input is required before step completion
 *                     studyProgram:
 *                       type: object
 *                       properties:
 *                         id:
 *                           type: string
 *                         name:
 *                           type: string
 *                     group:
 *                       type: object
 *                       properties:
 *                         id:
 *                           type: string
 *                         name:
 *                           type: string
 *                     activities:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                           type:
 *                             type: string
 *                           orderNumber:
 *                             type: integer
 *                           progress:
 *                             type: object
 *                             nullable: true
 *                             properties:
 *                               currentStep:
 *                                 type: string
 *                               completedSteps:
 *                                 type: array
 *                                 items:
 *                                   type: string
 *                               completedAt:
 *                                 type: string
 *                                 format: date-time
 *                                 nullable: true
 *                           notes:
 *                             type: array
 *                             items:
 *                               type: object
 *                               properties:
 *                                 id:
 *                                   type: string
 *                                 type:
 *                                   type: string
 *                                 content:
 *                                   type: string
 *       400:
 *         description: Invalid request or cannot skip to complete
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post(
  '/member/activities/:lessonActivityId/submit',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const { lessonActivityId } = req.params
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate request body
      const parsed = submitActivitySchema.safeParse(req.body)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      const { lessonScheduleId, note, action } = parsed.data

      // Check if requesting user is a group leader (org owner via Google OAuth)
      let isGroupLeader = false
      const user = req.user as any
      if (user?.id) {
        const schedule = await prisma.lessonSchedule.findUnique({
          where: { id: lessonScheduleId },
          select: { enrollment: { select: { group: { select: { organizationId: true } } } } },
        })
        if (schedule && schedule.enrollment.group.organizationId) {
          const org = await prisma.organization.findUnique({
            where: { id: schedule.enrollment.group.organizationId },
            select: { ownerId: true },
          })
          isGroupLeader = org?.ownerId === user.id
        }
      }

      // Submit activity response
      const result = await submitActivityResponse({
        memberId,
        lessonScheduleId,
        lessonActivityId,
        note,
        action,
        isGroupLeader,
      })

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        lesson: result.lesson,
      })
    } catch (error) {
      console.error('Error submitting activity response:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to submit activity response',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/activities/{lessonActivityId}/progress:
 *   get:
 *     tags:
 *       - Activity Progress
 *     summary: Get member activity progress
 *     description: |
 *       Retrieve the current progress for a specific activity.
 *       Returns the member's progress including current step and completion status.
 *       Returns null data if the member has not started this activity yet.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: lessonActivityId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The lesson activity ID
 *       - in: query
 *         name: lessonScheduleId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The scheduled lesson ID
 *     responses:
 *       200:
 *         description: Progress retrieved successfully (null if not started)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/GetActivityProgressResponse'
 *             examples:
 *               inProgress:
 *                 summary: Activity in progress
 *                 value:
 *                   success: true
 *                   data:
 *                     id: "abc123"
 *                     memberId: "member456"
 *                     lessonScheduleId: "schedule789"
 *                     lessonActivityId: "activity012"
 *                     currentStep: "OBSERVE"
 *                     completedAt: null
 *                     createdAt: "2024-01-15T10:30:00Z"
 *                     updatedAt: "2024-01-15T10:35:00Z"
 *               notStarted:
 *                 summary: Activity not started
 *                 value:
 *                   success: true
 *                   data: null
 *       400:
 *         description: Missing or invalid lessonScheduleId parameter
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "lessonScheduleId query parameter is required"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Member not authenticated"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to fetch progress"
 */
router.get(
  '/member/activities/:lessonActivityId/progress',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const { lessonActivityId } = req.params
      const { lessonScheduleId } = req.query
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      if (!lessonScheduleId || typeof lessonScheduleId !== 'string') {
        return res.status(400).json({
          success: false,
          error: 'lessonScheduleId query parameter is required',
        })
      }

      const result = await getActivityProgress(
        memberId,
        lessonActivityId,
        lessonScheduleId
      )

      if (!result.success) {
        // Return empty progress if not started yet
        if (result.error === 'Progress not found') {
          return res.json({
            success: true,
            data: null,
          })
        }
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error fetching activity progress:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch progress',
      })
    }
  }
)

// ============================================================================
// User Activity Progress Routes (for Google-authenticated users)
// ============================================================================

/**
 * @openapi
 * /api/activities/{lessonActivityId}/progress:
 *   post:
 *     tags:
 *       - Activity Progress
 *     summary: Save user activity progress (Google auth)
 *     description: |
 *       Save activity progress and notes for Google-authenticated users.
 *
 *       **Note:** This endpoint is not yet implemented. Use the member authentication
 *       endpoints (/api/member/activities/{lessonActivityId}/progress) instead.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: lessonActivityId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The lesson activity ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/SaveActivityProgressRequest'
 *     responses:
 *       501:
 *         description: Not implemented
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "User activity progress not yet implemented. Use member auth."
 *       400:
 *         description: Invalid request body
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: User not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "User not authenticated"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to save progress"
 */
router.post(
  '/activities/:lessonActivityId/progress',
  requireAuth,
  async (req: Request, res: Response) => {
    try {
      const userId = (req.user as any)?.id

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'User not authenticated',
        })
      }

      // Validate request body
      const parsed = saveProgressSchema.safeParse(req.body)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      // For now, User progress uses the same service but with userId
      // This could be extended to have separate UserActivityProgress model
      // For simplicity, we'll create notes with userId instead of memberId

      return res.status(501).json({
        success: false,
        error: 'User activity progress not yet implemented. Use member auth.',
      })
    } catch (error) {
      console.error('Error saving user activity progress:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to save progress',
      })
    }
  }
)

// ============================================================================
// Video Progress Routes
// ============================================================================

const videoProgressSchema = z.object({
  lessonScheduleId: z.string().uuid(),
  watchedSeconds: z.number().int().min(0),
  totalDuration: z.number().int().min(0).optional(),
})

/**
 * @openapi
 * /api/member/activities/{lessonActivityId}/video-progress:
 *   post:
 *     tags:
 *       - Activity Progress
 *     summary: Save member video watch progress
 *     description: |
 *       Save video watch progress for a member's activity.
 *       Tracks how many seconds of a video the member has watched.
 *
 *       **Auto-completion:** The video is automatically marked as complete
 *       when the member has watched >= 90% of the total duration.
 *
 *       This endpoint should be called periodically while the video is playing
 *       to track progress (e.g., every 10-30 seconds).
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: lessonActivityId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The lesson activity ID for the video activity
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/SaveVideoProgressRequest'
 *     responses:
 *       200:
 *         description: Video progress saved successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/VideoProgressResponse'
 *             example:
 *               success: true
 *               data:
 *                 id: "video123"
 *                 memberId: "member456"
 *                 lessonScheduleId: "schedule789"
 *                 lessonActivityId: "activity012"
 *                 watchedSeconds: 180
 *                 totalDuration: 600
 *                 completed: false
 *                 completedAt: null
 *                 createdAt: "2024-01-15T10:30:00Z"
 *                 updatedAt: "2024-01-15T10:35:00Z"
 *       400:
 *         description: Invalid request body or validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Invalid request body"
 *               details:
 *                 - path: ["watchedSeconds"]
 *                   message: "Expected number, received string"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Member not authenticated"
 *       404:
 *         description: Activity or lesson schedule not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Lesson activity not found"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to save video progress"
 */
router.post(
  '/member/activities/:lessonActivityId/video-progress',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const { lessonActivityId } = req.params
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate request body
      const parsed = videoProgressSchema.safeParse(req.body)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      const { lessonScheduleId, watchedSeconds, totalDuration } = parsed.data

      const result = await saveVideoProgress(
        memberId,
        lessonScheduleId,
        lessonActivityId,
        watchedSeconds,
        totalDuration ?? null
      )

      if (!result.success) {
        const statusCode = result.error?.includes('not found') ? 404 : 400
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
      console.error('Error saving video progress:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to save video progress',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/activities/{lessonActivityId}/video-progress:
 *   get:
 *     tags:
 *       - Activity Progress
 *     summary: Get member video watch progress
 *     description: |
 *       Retrieve the current video watch progress for a member's activity.
 *       Returns the number of seconds watched, total duration (if known),
 *       and whether the video has been marked as complete.
 *
 *       Returns null data if the member has not started watching this video yet.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: lessonActivityId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The lesson activity ID for the video activity
 *       - in: query
 *         name: lessonScheduleId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The scheduled lesson ID
 *     responses:
 *       200:
 *         description: Video progress retrieved successfully (null if not started)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/VideoProgressResponse'
 *             examples:
 *               inProgress:
 *                 summary: Video partially watched
 *                 value:
 *                   success: true
 *                   data:
 *                     id: "video123"
 *                     memberId: "member456"
 *                     lessonScheduleId: "schedule789"
 *                     lessonActivityId: "activity012"
 *                     watchedSeconds: 180
 *                     totalDuration: 600
 *                     completed: false
 *                     completedAt: null
 *                     createdAt: "2024-01-15T10:30:00Z"
 *                     updatedAt: "2024-01-15T10:35:00Z"
 *               completed:
 *                 summary: Video completed
 *                 value:
 *                   success: true
 *                   data:
 *                     id: "video123"
 *                     memberId: "member456"
 *                     lessonScheduleId: "schedule789"
 *                     lessonActivityId: "activity012"
 *                     watchedSeconds: 580
 *                     totalDuration: 600
 *                     completed: true
 *                     completedAt: "2024-01-15T10:45:00Z"
 *                     createdAt: "2024-01-15T10:30:00Z"
 *                     updatedAt: "2024-01-15T10:45:00Z"
 *               notStarted:
 *                 summary: Video not started
 *                 value:
 *                   success: true
 *                   data: null
 *       400:
 *         description: Missing or invalid lessonScheduleId parameter
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "lessonScheduleId query parameter is required"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Member not authenticated"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to fetch video progress"
 */
router.get(
  '/member/activities/:lessonActivityId/video-progress',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const { lessonActivityId } = req.params
      const { lessonScheduleId } = req.query
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      if (!lessonScheduleId || typeof lessonScheduleId !== 'string') {
        return res.status(400).json({
          success: false,
          error: 'lessonScheduleId query parameter is required',
        })
      }

      const result = await getVideoProgress(
        memberId,
        lessonActivityId,
        lessonScheduleId
      )

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error fetching video progress:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch video progress',
      })
    }
  }
)

// ============================================================================
// Exegesis Progress
// ============================================================================

const exegesisVisitSchema = z.object({
  lessonScheduleId: z.string().uuid(),
  highlightId: z.string().uuid(),
})

/**
 * Mark an EXEGESIS highlight as visited (active at least once).
 * Activity completes when all highlights for the scheduled activity have been visited.
 */
router.post(
  '/member/activities/:lessonActivityId/exegesis-visit',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const { lessonActivityId } = req.params
      const memberId = req.member?.id

      if (!memberId) {
        return res.status(401).json({ success: false, error: 'Member not authenticated' })
      }

      const parsed = exegesisVisitSchema.safeParse(req.body)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      const { lessonScheduleId, highlightId } = parsed.data

      const scheduledActivity = await prisma.scheduledLessonActivity.findUnique({
        where: { id: lessonActivityId },
        select: { id: true, type: true },
      })

      if (!scheduledActivity) {
        return res.status(404).json({ success: false, error: 'Lesson activity not found' })
      }

      if (scheduledActivity.type !== 'EXEGESIS') {
        return res.status(400).json({ success: false, error: 'Activity is not an EXEGESIS activity' })
      }

      const lockedBlock = await prisma.activityReadBlock.findFirst({
        where: { scheduledActivityId: lessonActivityId, isLocked: true },
        select: { id: true },
      })

      if (!lockedBlock) {
        return res.status(404).json({ success: false, error: 'Read block not found' })
      }

      const allHighlights = await prisma.exegesisHighlight.findMany({
        where: { readBlockId: lockedBlock.id },
        select: { id: true },
      })

      if (allHighlights.length === 0) {
        return res.status(400).json({ success: false, error: 'No highlights configured for this activity' })
      }

      if (!allHighlights.some((h) => h.id === highlightId)) {
        return res.status(404).json({ success: false, error: 'Highlight not found' })
      }

      const existingProgress = await prisma.memberActivityProgress.findFirst({
        where: {
          memberId,
          lessonScheduleId,
          scheduledActivityId: lessonActivityId,
        },
      })

      const prevVisited = (existingProgress as any)?.exegesisVisitedHighlightIds
      const prevIds: string[] = Array.isArray(prevVisited) ? prevVisited : []

      const visitedSet = new Set(prevIds)
      visitedSet.add(highlightId)

      const visitedIds = Array.from(visitedSet)
      const isComplete = visitedIds.length >= allHighlights.length

      const now = new Date()

      if (existingProgress) {
        await prisma.memberActivityProgress.update({
          where: { id: existingProgress.id },
          data: {
            exegesisVisitedHighlightIds: visitedIds as any,
            completedAt: isComplete ? (existingProgress.completedAt ?? now) : null,
            lastUpdatedAt: now,
          },
        })
      } else {
        await prisma.memberActivityProgress.create({
          data: {
            memberId,
            lessonScheduleId,
            scheduledActivityId: lessonActivityId,
            exegesisVisitedHighlightIds: visitedIds as any,
            completedAt: isComplete ? now : null,
          },
        })
      }

      await checkAndUpdateLessonCompletion(memberId, lessonScheduleId)

      return res.json({
        success: true,
        data: {
          exegesisVisitedHighlightIds: visitedIds,
          completed: isComplete,
        },
      })
    } catch (error) {
      console.error('Error saving exegesis highlight visit:', error)
      return res.status(500).json({ success: false, error: 'Failed to save exegesis progress' })
    }
  }
)

export default router
