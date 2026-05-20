import { Router, Request, Response } from 'express'
import { z } from 'zod'
import { requireMemberAuth, requireAuth } from '../middleware/auth.js'
import {
  createNote,
  getNotes,
  getNote,
  updateNote,
  deleteNote,
  getNotesForLLM,
  getNotesForEntity,
  getNotesWithContext,
  NOTE_TYPES,
  LINK_TYPES,
  type NoteType,
  type LinkType,
} from '../services/notes.service.js'

/**
 * @openapi
 * components:
 *   schemas:
 *     Note:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *           description: Unique identifier for the note
 *         type:
 *           type: string
 *           description: Type of note (OBSERVATION, APPLICATION, PRAYER, etc.)
 *         content:
 *           type: string
 *           description: The note content text
 *         memberId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the member who owns this note (for member-authenticated notes)
 *         userId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the user who owns this note (for Google-authenticated notes)
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: When the note was created
 *         updatedAt:
 *           type: string
 *           format: date-time
 *           description: When the note was last updated
 *         deletedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *           description: When the note was soft-deleted (null if not deleted)
 *         links:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/NoteLink'
 *           description: Links connecting this note to other entities
 *     NoteLink:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *           description: Unique identifier for the link
 *         noteId:
 *           type: string
 *           format: uuid
 *           description: ID of the note this link belongs to
 *         refType:
 *           type: string
 *           description: Type of entity being linked (LESSON, ENROLLMENT, GROUP, etc.)
 *         refId:
 *           type: string
 *           format: uuid
 *           description: ID of the linked entity
 *         metadata:
 *           type: object
 *           nullable: true
 *           description: Additional metadata for the link
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: When the link was created
 *     NoteLinkInput:
 *       type: object
 *       required:
 *         - refType
 *         - refId
 *       properties:
 *         refType:
 *           type: string
 *           description: Type of entity being linked (LESSON, ENROLLMENT, GROUP, etc.)
 *         refId:
 *           type: string
 *           format: uuid
 *           description: ID of the linked entity
 *         metadata:
 *           type: object
 *           description: Additional metadata for the link
 *     CreateNoteInput:
 *       type: object
 *       required:
 *         - type
 *         - content
 *       properties:
 *         type:
 *           type: string
 *           description: Type of note (OBSERVATION, APPLICATION, PRAYER, etc.)
 *         content:
 *           type: string
 *           minLength: 1
 *           description: The note content text
 *         links:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/NoteLinkInput'
 *           description: Optional links to associate with the note
 *     UpdateNoteInput:
 *       type: object
 *       required:
 *         - content
 *       properties:
 *         content:
 *           type: string
 *           minLength: 1
 *           description: The updated note content text
 *     NoteTypes:
 *       type: object
 *       properties:
 *         noteTypes:
 *           type: array
 *           items:
 *             type: string
 *           description: Available note types
 *         linkTypes:
 *           type: array
 *           items:
 *             type: string
 *           description: Available link types
 *     LLMNote:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         type:
 *           type: string
 *         content:
 *           type: string
 *         createdAt:
 *           type: string
 *           format: date-time
 *         scriptureContext:
 *           type: object
 *           nullable: true
 *           description: Scripture reference and context if linked to a lesson
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
 *           description: Number of items skipped
 *         hasMore:
 *           type: boolean
 *           description: Whether there are more items available
 *     SuccessResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
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
 *           description: Validation error details (optional)
 *   securitySchemes:
 *     memberSession:
 *       type: apiKey
 *       in: cookie
 *       name: member.sid
 *       description: Member session cookie (phone-authenticated)
 *     userSession:
 *       type: apiKey
 *       in: cookie
 *       name: connect.sid
 *       description: User session cookie (Google-authenticated)
 */

const router = Router()

// ============================================================================
// Validation Schemas
// ============================================================================

const noteLinkSchema = z.object({
  refType: z.string(),
  refId: z.string().uuid(),
  metadata: z.record(z.unknown()).optional(),
})

const createNoteSchema = z.object({
  type: z.string().min(1), // Now a string for extensibility
  content: z.string().min(1),
  links: z.array(noteLinkSchema).optional(),
})

const updateNoteSchema = z.object({
  content: z.string().min(1),
})

// ============================================================================
// Member Notes Routes (phone-authenticated)
// ============================================================================

/**
 * @openapi
 * /api/member/notes:
 *   post:
 *     tags: [Notes]
 *     summary: Create a new note (member)
 *     description: |
 *       Create a standalone note (journal, reflection, etc.) for the authenticated member.
 *       For SOAP activity notes, use POST /api/member/activities/:id/progress instead.
 *     security:
 *       - memberSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreateNoteInput'
 *           example:
 *             type: "OBSERVATION"
 *             content: "Today I noticed that the passage emphasizes humility..."
 *             links:
 *               - refType: "LESSON"
 *                 refId: "123e4567-e89b-12d3-a456-426614174000"
 *     responses:
 *       201:
 *         description: Note created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Note'
 *       400:
 *         description: Invalid request body
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
  '/member/notes',
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

      // Validate request body
      const parsed = createNoteSchema.safeParse(req.body)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      const result = await createNote({
        memberId,
        type: parsed.data.type,
        content: parsed.data.content,
        links: parsed.data.links,
      })

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.status(201).json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error creating note:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to create note',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/notes:
 *   get:
 *     tags: [Notes]
 *     summary: Get notes for authenticated member
 *     description: |
 *       Retrieve notes for the authenticated member with optional filtering by type,
 *       link type, date range, and pagination support.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - name: type
 *         in: query
 *         schema:
 *           type: string
 *         description: Filter by note type (OBSERVATION, APPLICATION, PRAYER, etc.)
 *       - name: linkType
 *         in: query
 *         schema:
 *           type: string
 *         description: Filter by link type (LESSON, ENROLLMENT, GROUP, etc.)
 *       - name: linkRefId
 *         in: query
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by linked entity ID (requires linkType)
 *       - name: startDate
 *         in: query
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter notes created on or after this date (ISO string)
 *       - name: endDate
 *         in: query
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter notes created on or before this date (ISO string)
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Maximum number of results to return
 *       - name: offset
 *         in: query
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Number of results to skip for pagination
 *     responses:
 *       200:
 *         description: Notes retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Note'
 *                 pagination:
 *                   $ref: '#/components/schemas/PaginationInfo'
 *       400:
 *         description: Invalid query parameters
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
router.get(
  '/member/notes',
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

      // Parse query params
      const {
        type,
        linkType,
        linkRefId,
        startDate,
        endDate,
        limit,
        offset,
      } = req.query

      const result = await getNotes({
        memberId,
        type: type as NoteType | undefined,
        linkType: linkType as LinkType | undefined,
        linkRefId: linkRefId as string | undefined,
        startDate: startDate ? new Date(startDate as string) : undefined,
        endDate: endDate ? new Date(endDate as string) : undefined,
        limit: limit ? parseInt(limit as string) : 50,
        offset: offset ? parseInt(offset as string) : 0,
      })

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        pagination: {
          total: result.total,
          limit: limit ? parseInt(limit as string) : 50,
          offset: offset ? parseInt(offset as string) : 0,
          hasMore:
            (result.total ?? 0) >
            (offset ? parseInt(offset as string) : 0) +
              (limit ? parseInt(limit as string) : 50),
        },
      })
    } catch (error) {
      console.error('Error fetching notes:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch notes',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/notes/entity/{refType}/{refId}:
 *   get:
 *     tags: [Notes]
 *     summary: Get notes linked to a specific entity
 *     description: |
 *       Retrieve all notes owned by the authenticated member that are linked to a specific entity.
 *       The entity is identified by its reference type and ID.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - name: refType
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *         description: Type of entity (LESSON, ENROLLMENT, GROUP, etc.)
 *       - name: refId
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID of the entity
 *       - name: type
 *         in: query
 *         schema:
 *           type: string
 *         description: Filter by note type (OBSERVATION, APPLICATION, PRAYER, etc.)
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           default: 100
 *         description: Maximum number of results to return
 *     responses:
 *       200:
 *         description: Notes retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Note'
 *                 total:
 *                   type: integer
 *                   description: Total number of notes returned
 *       400:
 *         description: Invalid parameters
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
router.get(
  '/member/notes/entity/:refType/:refId',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id
      const { refType, refId } = req.params
      const { type, limit } = req.query

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      const result = await getNotesForEntity({
        refType,
        refId,
        type: type as NoteType | undefined,
        limit: limit ? parseInt(limit as string) : 100,
      })

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      // Filter to only return notes owned by this member
      const memberNotes = result.data?.filter(note => note.memberId === memberId)

      res.json({
        success: true,
        data: memberNotes,
        total: memberNotes?.length ?? 0,
      })
    } catch (error) {
      console.error('Error fetching notes for entity:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch notes',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/notes/with-context:
 *   get:
 *     tags: [Notes]
 *     summary: Get notes with resolved context
 *     description: |
 *       Retrieve notes for the authenticated member with resolved contextual data
 *       (study program, lesson, activity, verse, group, etc.) using cursor-based pagination.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - name: cursor
 *         in: query
 *         schema:
 *           type: string
 *           format: date-time
 *         description: ISO datetime cursor for pagination (createdAt of last item from previous page)
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           default: 20
 *           maximum: 100
 *         description: Maximum number of results to return (max 100)
 *       - name: type
 *         in: query
 *         schema:
 *           type: string
 *         description: Filter by note type (OBSERVATION, APPLICATION, PRAYER, etc.)
 *     responses:
 *       200:
 *         description: Notes with context retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         format: uuid
 *                       type:
 *                         type: string
 *                       content:
 *                         type: string
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       updatedAt:
 *                         type: string
 *                         format: date-time
 *                       context:
 *                         type: object
 *                         properties:
 *                           program:
 *                             type: object
 *                           lesson:
 *                             type: object
 *                           activity:
 *                             type: object
 *                           verse:
 *                             type: object
 *                           group:
 *                             type: object
 *                           lessonSchedule:
 *                             type: object
 *                           enrollment:
 *                             type: object
 *                 nextCursor:
 *                   type: string
 *                   nullable: true
 *                   description: Cursor for next page (null if no more results)
 *                 hasMore:
 *                   type: boolean
 *                   description: Whether there are more results available
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
router.get(
  '/member/notes/with-context',
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

      const { cursor, limit, type } = req.query

      // Validate cursor if provided
      let cursorDate: Date | undefined
      if (cursor) {
        cursorDate = new Date(cursor as string)
        if (isNaN(cursorDate.getTime())) {
          return res.status(400).json({
            success: false,
            error: 'Invalid cursor format. Must be an ISO datetime string.',
          })
        }
      }

      const parsedLimit = limit ? parseInt(limit as string) : 20
      if (isNaN(parsedLimit) || parsedLimit < 1 || parsedLimit > 100) {
        return res.status(400).json({
          success: false,
          error: 'Invalid limit. Must be between 1 and 100.',
        })
      }

      const result = await getNotesWithContext({
        memberId,
        type: type as NoteType | undefined,
        cursor: cursorDate,
        limit: parsedLimit,
      })

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
      })
    } catch (error) {
      console.error('Error fetching notes with context:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch notes with context',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/notes/{noteId}:
 *   get:
 *     tags: [Notes]
 *     summary: Get a specific note (member)
 *     description: Retrieve a specific note by ID. The note must belong to the authenticated member.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - name: noteId
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID of the note to retrieve
 *     responses:
 *       200:
 *         description: Note retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Note'
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Access denied - note belongs to another member
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "You do not have access to this note"
 *       404:
 *         description: Note not found
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
router.get(
  '/member/notes/:noteId',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id
      const { noteId } = req.params

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      const result = await getNote(noteId)

      if (!result.success) {
        return res.status(404).json({
          success: false,
          error: result.error,
        })
      }

      // Verify ownership
      if (result.data?.memberId !== memberId) {
        return res.status(403).json({
          success: false,
          error: 'You do not have access to this note',
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error fetching note:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch note',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/notes/{noteId}:
 *   patch:
 *     tags: [Notes]
 *     summary: Update a note (member)
 *     description: Update the content of a specific note. The note must belong to the authenticated member.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - name: noteId
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID of the note to update
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UpdateNoteInput'
 *           example:
 *             content: "Updated note content with new observations..."
 *     responses:
 *       200:
 *         description: Note updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Note'
 *       400:
 *         description: Invalid request body
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
 *       403:
 *         description: Permission denied - note belongs to another member
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "You do not have permission to update this note"
 *       404:
 *         description: Note not found
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
router.patch(
  '/member/notes/:noteId',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id
      const { noteId } = req.params

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Validate request body
      const parsed = updateNoteSchema.safeParse(req.body)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      // Verify ownership first
      const existingNote = await getNote(noteId)
      if (!existingNote.success || !existingNote.data) {
        return res.status(404).json({
          success: false,
          error: 'Note not found',
        })
      }

      if (existingNote.data.memberId !== memberId) {
        return res.status(403).json({
          success: false,
          error: 'You do not have permission to update this note',
        })
      }

      const result = await updateNote(noteId, parsed.data.content)

      if (!result.success) {
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
      console.error('Error updating note:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to update note',
      })
    }
  }
)

/**
 * @openapi
 * /api/member/notes/{noteId}:
 *   delete:
 *     tags: [Notes]
 *     summary: Delete a note (member)
 *     description: |
 *       Soft delete a specific note. The note must belong to the authenticated member.
 *       Soft-deleted notes are not permanently removed and can potentially be restored.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - name: noteId
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID of the note to delete
 *     responses:
 *       200:
 *         description: Note deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Note deleted"
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Permission denied - note belongs to another member
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "You do not have permission to delete this note"
 *       404:
 *         description: Note not found
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
router.delete(
  '/member/notes/:noteId',
  requireMemberAuth,
  async (req: Request, res: Response) => {
    try {
      const memberId = req.member?.id
      const { noteId } = req.params

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member not authenticated',
        })
      }

      // Verify ownership first
      const existingNote = await getNote(noteId)
      if (!existingNote.success || !existingNote.data) {
        return res.status(404).json({
          success: false,
          error: 'Note not found',
        })
      }

      if (existingNote.data.memberId !== memberId) {
        return res.status(403).json({
          success: false,
          error: 'You do not have permission to delete this note',
        })
      }

      const result = await deleteNote(noteId)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        message: 'Note deleted',
      })
    } catch (error) {
      console.error('Error deleting note:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to delete note',
      })
    }
  }
)

// ============================================================================
// User Notes Routes (Google-authenticated)
// ============================================================================

/**
 * @openapi
 * /api/notes:
 *   post:
 *     tags: [Notes]
 *     summary: Create a new note (user)
 *     description: Create a standalone note for the Google-authenticated user.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreateNoteInput'
 *           example:
 *             type: "OBSERVATION"
 *             content: "Today I noticed that the passage emphasizes humility..."
 *             links:
 *               - refType: "LESSON"
 *                 refId: "123e4567-e89b-12d3-a456-426614174000"
 *     responses:
 *       201:
 *         description: Note created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Note'
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
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/notes', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not authenticated',
      })
    }

    // Validate request body
    const parsed = createNoteSchema.safeParse(req.body)
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: parsed.error.errors,
      })
    }

    const result = await createNote({
      userId,
      type: parsed.data.type,
      content: parsed.data.content,
      links: parsed.data.links,
    })

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error,
      })
    }

    res.status(201).json({
      success: true,
      data: result.data,
    })
  } catch (error) {
    console.error('Error creating note:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to create note',
    })
  }
})

/**
 * @openapi
 * /api/notes:
 *   get:
 *     tags: [Notes]
 *     summary: Get notes for authenticated user
 *     description: |
 *       Retrieve notes for the Google-authenticated user with optional filtering by type,
 *       link type, date range, and pagination support.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: type
 *         in: query
 *         schema:
 *           type: string
 *         description: Filter by note type (OBSERVATION, APPLICATION, PRAYER, etc.)
 *       - name: linkType
 *         in: query
 *         schema:
 *           type: string
 *         description: Filter by link type (LESSON, ENROLLMENT, GROUP, etc.)
 *       - name: linkRefId
 *         in: query
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by linked entity ID (requires linkType)
 *       - name: startDate
 *         in: query
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter notes created on or after this date (ISO string)
 *       - name: endDate
 *         in: query
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter notes created on or before this date (ISO string)
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Maximum number of results to return
 *       - name: offset
 *         in: query
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Number of results to skip for pagination
 *     responses:
 *       200:
 *         description: Notes retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Note'
 *                 pagination:
 *                   $ref: '#/components/schemas/PaginationInfo'
 *       400:
 *         description: Invalid query parameters
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
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/notes', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not authenticated',
      })
    }

    // Parse query params
    const {
      type,
      linkType,
      linkRefId,
      startDate,
      endDate,
      limit,
      offset,
    } = req.query

    const result = await getNotes({
      userId,
      type: type as NoteType | undefined,
      linkType: linkType as LinkType | undefined,
      linkRefId: linkRefId as string | undefined,
      startDate: startDate ? new Date(startDate as string) : undefined,
      endDate: endDate ? new Date(endDate as string) : undefined,
      limit: limit ? parseInt(limit as string) : 50,
      offset: offset ? parseInt(offset as string) : 0,
    })

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error,
      })
    }

    res.json({
      success: true,
      data: result.data,
      pagination: {
        total: result.total,
        limit: limit ? parseInt(limit as string) : 50,
        offset: offset ? parseInt(offset as string) : 0,
        hasMore:
          (result.total ?? 0) >
          (offset ? parseInt(offset as string) : 0) +
            (limit ? parseInt(limit as string) : 50),
      },
    })
  } catch (error) {
    console.error('Error fetching notes:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to fetch notes',
    })
  }
})

/**
 * @openapi
 * /api/notes/{noteId}:
 *   get:
 *     tags: [Notes]
 *     summary: Get a specific note (user)
 *     description: Retrieve a specific note by ID. The note must belong to the authenticated user.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: noteId
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID of the note to retrieve
 *     responses:
 *       200:
 *         description: Note retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Note'
 *       401:
 *         description: User not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Access denied - note belongs to another user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "You do not have access to this note"
 *       404:
 *         description: Note not found
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
router.get('/notes/:noteId', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id
    const { noteId } = req.params

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not authenticated',
      })
    }

    const result = await getNote(noteId)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        error: result.error,
      })
    }

    // Verify ownership
    if (result.data?.userId !== userId) {
      return res.status(403).json({
        success: false,
        error: 'You do not have access to this note',
      })
    }

    res.json({
      success: true,
      data: result.data,
    })
  } catch (error) {
    console.error('Error fetching note:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to fetch note',
    })
  }
})

/**
 * @openapi
 * /api/notes/{noteId}:
 *   patch:
 *     tags: [Notes]
 *     summary: Update a note (user)
 *     description: Update the content of a specific note. The note must belong to the authenticated user.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: noteId
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID of the note to update
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UpdateNoteInput'
 *           example:
 *             content: "Updated note content with new observations..."
 *     responses:
 *       200:
 *         description: Note updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Note'
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
 *       403:
 *         description: Permission denied - note belongs to another user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "You do not have permission to update this note"
 *       404:
 *         description: Note not found
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
router.patch(
  '/notes/:noteId',
  requireAuth,
  async (req: Request, res: Response) => {
    try {
      const userId = (req.user as any)?.id
      const { noteId } = req.params

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'User not authenticated',
        })
      }

      // Validate request body
      const parsed = updateNoteSchema.safeParse(req.body)
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.errors,
        })
      }

      // Verify ownership first
      const existingNote = await getNote(noteId)
      if (!existingNote.success || !existingNote.data) {
        return res.status(404).json({
          success: false,
          error: 'Note not found',
        })
      }

      if (existingNote.data.userId !== userId) {
        return res.status(403).json({
          success: false,
          error: 'You do not have permission to update this note',
        })
      }

      const result = await updateNote(noteId, parsed.data.content)

      if (!result.success) {
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
      console.error('Error updating note:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to update note',
      })
    }
  }
)

/**
 * @openapi
 * /api/notes/{noteId}:
 *   delete:
 *     tags: [Notes]
 *     summary: Delete a note (user)
 *     description: |
 *       Soft delete a specific note. The note must belong to the authenticated user.
 *       Soft-deleted notes are not permanently removed and can potentially be restored.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: noteId
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: ID of the note to delete
 *     responses:
 *       200:
 *         description: Note deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Note deleted"
 *       401:
 *         description: User not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Permission denied - note belongs to another user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "You do not have permission to delete this note"
 *       404:
 *         description: Note not found
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
router.delete(
  '/notes/:noteId',
  requireAuth,
  async (req: Request, res: Response) => {
    try {
      const userId = (req.user as any)?.id
      const { noteId } = req.params

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'User not authenticated',
        })
      }

      // Verify ownership first
      const existingNote = await getNote(noteId)
      if (!existingNote.success || !existingNote.data) {
        return res.status(404).json({
          success: false,
          error: 'Note not found',
        })
      }

      if (existingNote.data.userId !== userId) {
        return res.status(403).json({
          success: false,
          error: 'You do not have permission to delete this note',
        })
      }

      const result = await deleteNote(noteId)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        message: 'Note deleted',
      })
    } catch (error) {
      console.error('Error deleting note:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to delete note',
      })
    }
  }
)

// ============================================================================
// LLM-Ready Notes Endpoint
// ============================================================================

/**
 * @openapi
 * /api/member/notes/llm:
 *   get:
 *     tags: [Notes]
 *     summary: Get notes formatted for LLM consumption
 *     description: |
 *       Retrieve notes formatted for LLM (Large Language Model) consumption.
 *       Returns notes with scripture context ready for AI summarization and analysis.
 *       This endpoint is useful for generating AI-powered insights from member notes.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - name: enrollmentId
 *         in: query
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter notes by enrollment ID
 *       - name: type
 *         in: query
 *         schema:
 *           type: string
 *         description: Filter by note type (OBSERVATION, APPLICATION, PRAYER, etc.)
 *       - name: startDate
 *         in: query
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter notes created on or after this date (ISO string)
 *       - name: endDate
 *         in: query
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter notes created on or before this date (ISO string)
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           default: 100
 *         description: Maximum number of results to return
 *     responses:
 *       200:
 *         description: LLM-formatted notes retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/LLMNote'
 *       400:
 *         description: Invalid query parameters
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
router.get(
  '/member/notes/llm',
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

      const { enrollmentId, type, startDate, endDate, limit } = req.query

      const result = await getNotesForLLM(memberId, undefined, {
        enrollmentId: enrollmentId as string | undefined,
        type: type as NoteType | undefined,
        startDate: startDate ? new Date(startDate as string) : undefined,
        endDate: endDate ? new Date(endDate as string) : undefined,
        limit: limit ? parseInt(limit as string) : 100,
      })

      if (!result.success) {
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
      console.error('Error fetching notes for LLM:', error)
      res.status(500).json({
        success: false,
        error: 'Failed to fetch notes',
      })
    }
  }
)

// ============================================================================
// Constants Export (for API documentation)
// ============================================================================

/**
 * @openapi
 * /api/notes/types:
 *   get:
 *     tags: [Notes]
 *     summary: Get available note and link types
 *     description: |
 *       Retrieve the list of available note types and link types.
 *       This endpoint is useful for API documentation and for populating
 *       UI dropdowns with valid options.
 *     responses:
 *       200:
 *         description: Note types and link types retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/NoteTypes'
 *             example:
 *               success: true
 *               data:
 *                 noteTypes:
 *                   - OBSERVATION
 *                   - APPLICATION
 *                   - PRAYER
 *                   - JOURNAL
 *                 linkTypes:
 *                   - LESSON
 *                   - ENROLLMENT
 *                   - GROUP
 *                   - ACTIVITY
 */
router.get('/notes/types', (_req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      noteTypes: NOTE_TYPES,
      linkTypes: LINK_TYPES,
    },
  })
})

export default router
