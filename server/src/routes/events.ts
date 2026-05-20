import { Router } from 'express'
import { z } from 'zod'
import sharp from 'sharp'
import { prisma } from '../lib/prisma.js'
import { requireAuth, requireMemberAuth } from '../middleware/auth.js'
import { generateUniqueEventCode, normalizeEventCode } from '../lib/event-code.js'
import {
  generateRecurringEvents,
  updateRecurrenceSeries,
  deleteRecurrenceSeries,
} from '../services/recurrence.js'
import { EventType, EventVisibility, RecurrenceFrequency, RsvpStatus } from '../generated/prisma/index.js'
import { logSuccess } from '../lib/activity-log.js'
import { ActivityTypes } from '../lib/activity-types.js'
import { uploadImageVariants, uploadFile } from '../services/storage.js'
import { trackActivity } from '../services/activity.js'

const router = Router()

// ============================================================================
// Validation Schemas
// ============================================================================

const createEventSchema = z.object({
  type: z.enum(['LESSON', 'MEETING', 'ONLINE', 'DEADLINE', 'SOCIAL', 'OTHER']).default('MEETING'),
  title: z.string().min(1).max(200),
  description: z.string().max(5000).optional(),
  date: z.string().datetime(),
  startTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  endTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  isAllDay: z.boolean().default(false),
  timezone: z.string().optional(),
  externalUrl: z.string().url().optional().nullable(),
  visibility: z.enum(['PRIVATE', 'PUBLIC']).default('PRIVATE'),
  // Location
  locationName: z.string().max(200).optional().nullable(),
  locationAddress: z.string().max(500).optional().nullable(),
  locationLat: z.number().min(-90).max(90).optional().nullable(),
  locationLng: z.number().min(-180).max(180).optional().nullable(),
  googlePlaceId: z.string().optional().nullable(),
  // Recurrence
  recurrenceFrequency: z.enum(['NONE', 'DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'YEARLY']).default('NONE'),
  recurrenceEndDate: z.string().datetime().optional().nullable(),
  recurrenceCount: z.number().int().min(1).max(365).optional().nullable(),
  // Alert
  alertMinutesBefore: z.number().int().optional().nullable(),
})

const updateEventSchema = createEventSchema.partial()

const publicRsvpSchema = z.object({
  phoneNumber: z.string().regex(/^\+[1-9]\d{1,14}$/, 'Phone must be E.164 format'),
  firstName: z.string().min(1).max(100),
  lastName: z.string().max(100).optional(),
  gender: z.string().optional(),
  birthdate: z.string().datetime().optional(),
  rsvpStatus: z.enum(['GOING', 'MAYBE', 'NOT_GOING']),
})

const memberRsvpSchema = z.object({
  rsvpStatus: z.enum(['GOING', 'MAYBE', 'NOT_GOING']),
})

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Check if user owns the group
 */
async function verifyGroupOwnership(groupId: string, userId: string) {
  const group = await prisma.group.findFirst({
    where: { id: groupId, creatorId: userId, isActive: true },
  })
  return group
}

/**
 * Check if user owns the event (via group ownership)
 */
async function verifyEventOwnership(eventId: string, userId: string) {
  const event = await prisma.event.findFirst({
    where: {
      id: eventId,
      isActive: true,
      group: { creatorId: userId, isActive: true },
    },
    include: { group: true },
  })
  return event
}

// ============================================================================
// Event CRUD Endpoints
// ============================================================================

/**
 * @openapi
 * /api/groups/{groupId}/events:
 *   post:
 *     tags: [Events]
 *     summary: Create a new event in a group
 *     description: Creates a new event within a specified group. Supports recurring events, location data, and various event types. Only the group owner can create events.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The ID of the group to create the event in
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - date
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [LESSON, MEETING, ONLINE, DEADLINE, SOCIAL, OTHER]
 *                 default: MEETING
 *                 description: The type of event
 *               title:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 200
 *                 description: The event title
 *               description:
 *                 type: string
 *                 maxLength: 5000
 *                 description: Detailed event description
 *               date:
 *                 type: string
 *                 format: date-time
 *                 description: The event date in ISO 8601 format
 *               startTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *                 description: Start time in HH:MM format
 *               endTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *                 description: End time in HH:MM format
 *               isAllDay:
 *                 type: boolean
 *                 default: false
 *                 description: Whether this is an all-day event
 *               timezone:
 *                 type: string
 *                 description: IANA timezone identifier
 *               externalUrl:
 *                 type: string
 *                 format: uri
 *                 nullable: true
 *                 description: External URL for the event (e.g., video call link)
 *               visibility:
 *                 type: string
 *                 enum: [PRIVATE, PUBLIC]
 *                 default: PRIVATE
 *                 description: Event visibility setting
 *               locationName:
 *                 type: string
 *                 maxLength: 200
 *                 nullable: true
 *                 description: Name of the location
 *               locationAddress:
 *                 type: string
 *                 maxLength: 500
 *                 nullable: true
 *                 description: Full address of the location
 *               locationLat:
 *                 type: number
 *                 minimum: -90
 *                 maximum: 90
 *                 nullable: true
 *                 description: Latitude coordinate
 *               locationLng:
 *                 type: number
 *                 minimum: -180
 *                 maximum: 180
 *                 nullable: true
 *                 description: Longitude coordinate
 *               googlePlaceId:
 *                 type: string
 *                 nullable: true
 *                 description: Google Places ID for the location
 *               recurrenceFrequency:
 *                 type: string
 *                 enum: [NONE, DAILY, WEEKLY, BIWEEKLY, MONTHLY, YEARLY]
 *                 default: NONE
 *                 description: How often the event repeats
 *               recurrenceEndDate:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *                 description: When the recurrence ends
 *               recurrenceCount:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 365
 *                 nullable: true
 *                 description: Number of occurrences
 *               alertMinutesBefore:
 *                 type: integer
 *                 nullable: true
 *                 description: Minutes before event to send alert
 *     responses:
 *       201:
 *         description: Event created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 event:
 *                   $ref: '#/components/schemas/Event'
 *                 recurrence:
 *                   type: object
 *                   nullable: true
 *                   description: Information about created recurring instances
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       path:
 *                         type: array
 *                         items:
 *                           type: string
 *                       message:
 *                         type: string
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Group not found or user is not the owner
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
 *                   example: Group not found
 *       500:
 *         description: Internal server error
 */
router.post('/groups/:groupId/events', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id

    // Verify group ownership
    const group = await verifyGroupOwnership(groupId, userId)
    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    const body = createEventSchema.parse(req.body)

    // Generate unique event code
    const code = await generateUniqueEventCode()

    // Create event
    const event = await prisma.event.create({
      data: {
        code,
        groupId,
        type: body.type as EventType,
        title: body.title,
        description: body.description,
        date: new Date(body.date),
        startTime: body.startTime,
        endTime: body.endTime,
        isAllDay: body.isAllDay,
        timezone: body.timezone,
        externalUrl: body.externalUrl,
        visibility: body.visibility as EventVisibility,
        locationName: body.locationName,
        locationAddress: body.locationAddress,
        locationLat: body.locationLat,
        locationLng: body.locationLng,
        googlePlaceId: body.googlePlaceId,
        recurrenceFrequency: body.recurrenceFrequency as RecurrenceFrequency,
        alertMinutesBefore: body.alertMinutesBefore,
        createdById: userId,
      },
      include: {
        group: { select: { id: true, name: true, code: true, organizationId: true } },
        attendees: true,
        attachments: true,
      },
    })

    // Generate recurring instances if needed
    let recurrenceInfo = null
    if (body.recurrenceFrequency && body.recurrenceFrequency !== 'NONE') {
      recurrenceInfo = await generateRecurringEvents(event.id, {
        frequency: body.recurrenceFrequency as RecurrenceFrequency,
        endDate: body.recurrenceEndDate ? new Date(body.recurrenceEndDate) : undefined,
        count: body.recurrenceCount || undefined,
      })
    }

    trackActivity({
      actorId: userId,
      action: 'CREATED',
      resourceType: 'EVENT',
      resourceId: event.id,
      resourceName: event.title,
      organizationId: event.group?.organizationId,
      groupId: groupId,
    })

    res.status(201).json({
      success: true,
      event,
      recurrence: recurrenceInfo,
    })
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
 * /api/groups/{groupId}/events:
 *   get:
 *     tags: [Events]
 *     summary: List events for a group
 *     description: Retrieves a paginated list of events for a specific group. Supports filtering by date range and event type. Only the group owner can access this endpoint.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The ID of the group
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter events on or after this date
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter events on or before this date
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [LESSON, MEETING, ONLINE, DEADLINE, SOCIAL, OTHER]
 *         description: Filter by event type
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Maximum number of events to return
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Cursor for pagination (event ID to start after)
 *     responses:
 *       200:
 *         description: List of events retrieved successfully
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
 *                     allOf:
 *                       - $ref: '#/components/schemas/Event'
 *                       - type: object
 *                         properties:
 *                           _count:
 *                             type: object
 *                             properties:
 *                               attendees:
 *                                 type: integer
 *                           attachments:
 *                             type: array
 *                             items:
 *                               $ref: '#/components/schemas/EventAttachment'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     hasMore:
 *                       type: boolean
 *                       description: Whether more events exist
 *                     nextCursor:
 *                       type: string
 *                       nullable: true
 *                       description: Cursor to use for the next page
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Group not found or user is not the owner
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
 *                   example: Group not found
 *       500:
 *         description: Internal server error
 */
router.get('/groups/:groupId/events', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id

    // Verify group ownership
    const group = await verifyGroupOwnership(groupId, userId)
    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Parse query params
    const startDate = req.query.startDate
      ? new Date(req.query.startDate as string)
      : undefined
    const endDate = req.query.endDate
      ? new Date(req.query.endDate as string)
      : undefined
    const type = req.query.type as string | undefined
    const limit = parseInt(req.query.limit as string) || 50
    const cursor = req.query.cursor as string | undefined

    // Build where clause
    const where: any = {
      groupId,
      isActive: true,
    }

    if (startDate) {
      where.date = { ...where.date, gte: startDate }
    }
    if (endDate) {
      where.date = { ...where.date, lte: endDate }
    }
    if (type) {
      where.type = type
    }

    const events = await prisma.event.findMany({
      where,
      orderBy: { date: 'asc' },
      take: limit + 1,
      cursor: cursor ? { id: cursor } : undefined,
      include: {
        _count: { select: { attendees: true } },
        attachments: true,
      },
    })

    // Handle pagination
    const hasMore = events.length > limit
    const items = hasMore ? events.slice(0, limit) : events
    const nextCursor = hasMore ? items[items.length - 1].id : null

    res.json({
      success: true,
      events: items,
      pagination: {
        hasMore,
        nextCursor,
      },
    })
  } catch (error) {
    console.error('Error listing events:', error)
    res.status(500).json({ success: false, error: 'Failed to list events' })
  }
})

/**
 * @openapi
 * /api/events/{id}:
 *   get:
 *     tags: [Events]
 *     summary: Get a single event by ID
 *     description: Retrieves detailed information about a specific event, including group info, attendees with member details, attachments, and creator information. Only the group owner can access this endpoint.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     responses:
 *       200:
 *         description: Event retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 event:
 *                   allOf:
 *                     - $ref: '#/components/schemas/Event'
 *                     - type: object
 *                       properties:
 *                         group:
 *                           type: object
 *                           properties:
 *                             id:
 *                               type: string
 *                             name:
 *                               type: string
 *                             code:
 *                               type: string
 *                         attendees:
 *                           type: array
 *                           items:
 *                             $ref: '#/components/schemas/EventAttendee'
 *                         attachments:
 *                           type: array
 *                           items:
 *                             $ref: '#/components/schemas/EventAttachment'
 *                         createdBy:
 *                           type: object
 *                           properties:
 *                             id:
 *                               type: string
 *                             name:
 *                               type: string
 *                             picture:
 *                               type: string
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.get('/events/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    // Fetch full event with relations
    const fullEvent = await prisma.event.findUnique({
      where: { id },
      include: {
        group: { select: { id: true, name: true, code: true } },
        attendees: {
          include: {
            groupMember: {
              include: {
                member: { select: { id: true, firstName: true, lastName: true, profilePicture: true } },
              },
            },
          },
        },
        attachments: true,
        createdBy: { select: { id: true, name: true, picture: true } },
      },
    })

    res.json({ success: true, event: fullEvent })
  } catch (error) {
    console.error('Error fetching event:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch event' })
  }
})

/**
 * @openapi
 * /api/events/code/{code}:
 *   get:
 *     tags: [Events]
 *     summary: Get a public event by its 6-digit code
 *     description: Retrieves a public event using its unique 6-digit code. No authentication required. Only returns events with PUBLIC visibility.
 *     parameters:
 *       - in: path
 *         name: code
 *         required: true
 *         schema:
 *           type: string
 *           pattern: '^\d{6}$'
 *         description: The 6-digit event code
 *         example: "123456"
 *     responses:
 *       200:
 *         description: Public event retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 event:
 *                   allOf:
 *                     - $ref: '#/components/schemas/Event'
 *                     - type: object
 *                       properties:
 *                         group:
 *                           type: object
 *                           properties:
 *                             id:
 *                               type: string
 *                             name:
 *                               type: string
 *                             coverImageUrl:
 *                               type: string
 *                               nullable: true
 *                         _count:
 *                           type: object
 *                           properties:
 *                             attendees:
 *                               type: integer
 *       404:
 *         description: Event not found (invalid code, inactive, or not public)
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.get('/events/code/:code', async (req, res) => {
  try {
    const code = normalizeEventCode(req.params.code)

    const event = await prisma.event.findFirst({
      where: {
        code,
        isActive: true,
        visibility: 'PUBLIC',
      },
      include: {
        group: { select: { id: true, name: true, coverImageUrl: true } },
        _count: { select: { attendees: true } },
      },
    })

    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    res.json({ success: true, event })
  } catch (error) {
    console.error('Error fetching event by code:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch event' })
  }
})

/**
 * @openapi
 * /api/events/{id}:
 *   patch:
 *     tags: [Events]
 *     summary: Update an event
 *     description: Updates an existing event. All fields are optional - only provided fields will be updated. Only the group owner can update events.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [LESSON, MEETING, ONLINE, DEADLINE, SOCIAL, OTHER]
 *               title:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 200
 *               description:
 *                 type: string
 *                 maxLength: 5000
 *               date:
 *                 type: string
 *                 format: date-time
 *               startTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *               endTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *               isAllDay:
 *                 type: boolean
 *               timezone:
 *                 type: string
 *               externalUrl:
 *                 type: string
 *                 format: uri
 *                 nullable: true
 *               visibility:
 *                 type: string
 *                 enum: [PRIVATE, PUBLIC]
 *               locationName:
 *                 type: string
 *                 maxLength: 200
 *                 nullable: true
 *               locationAddress:
 *                 type: string
 *                 maxLength: 500
 *                 nullable: true
 *               locationLat:
 *                 type: number
 *                 minimum: -90
 *                 maximum: 90
 *                 nullable: true
 *               locationLng:
 *                 type: number
 *                 minimum: -180
 *                 maximum: 180
 *                 nullable: true
 *               googlePlaceId:
 *                 type: string
 *                 nullable: true
 *               alertMinutesBefore:
 *                 type: integer
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Event updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 event:
 *                   $ref: '#/components/schemas/Event'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.patch('/events/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const body = updateEventSchema.parse(req.body)

    const updateData: any = {}

    if (body.type !== undefined) updateData.type = body.type
    if (body.title !== undefined) updateData.title = body.title
    if (body.description !== undefined) updateData.description = body.description
    if (body.date !== undefined) updateData.date = new Date(body.date)
    if (body.startTime !== undefined) updateData.startTime = body.startTime
    if (body.endTime !== undefined) updateData.endTime = body.endTime
    if (body.isAllDay !== undefined) updateData.isAllDay = body.isAllDay
    if (body.timezone !== undefined) updateData.timezone = body.timezone
    if (body.externalUrl !== undefined) updateData.externalUrl = body.externalUrl
    if (body.visibility !== undefined) updateData.visibility = body.visibility
    if (body.locationName !== undefined) updateData.locationName = body.locationName
    if (body.locationAddress !== undefined) updateData.locationAddress = body.locationAddress
    if (body.locationLat !== undefined) updateData.locationLat = body.locationLat
    if (body.locationLng !== undefined) updateData.locationLng = body.locationLng
    if (body.googlePlaceId !== undefined) updateData.googlePlaceId = body.googlePlaceId
    if (body.alertMinutesBefore !== undefined) updateData.alertMinutesBefore = body.alertMinutesBefore
    updateData.updatedById = userId

    const updatedEvent = await prisma.event.update({
      where: { id },
      data: updateData,
      include: {
        group: { select: { id: true, name: true, code: true, organizationId: true } },
        attendees: true,
        attachments: true,
      },
    })

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'EVENT',
      resourceId: id,
      resourceName: updatedEvent.title,
      organizationId: updatedEvent.group?.organizationId,
      groupId: event.groupId,
    })

    res.json({ success: true, event: updatedEvent })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating event:', error)
    res.status(500).json({ success: false, error: 'Failed to update event' })
  }
})

/**
 * @openapi
 * /api/events/{id}:
 *   delete:
 *     tags: [Events]
 *     summary: Soft delete an event
 *     description: Marks an event as inactive (soft delete). The event data is preserved but will no longer appear in queries. Only the group owner can delete events.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     responses:
 *       200:
 *         description: Event deleted successfully
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
 *                   example: Event deleted
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.delete('/events/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    await prisma.event.update({
      where: { id },
      data: { isActive: false },
    })

    trackActivity({
      actorId: userId,
      action: 'DELETED',
      resourceType: 'EVENT',
      resourceId: id,
      resourceName: event.title,
      organizationId: event.group?.organizationId,
      groupId: event.groupId,
    })

    res.json({ success: true, message: 'Event deleted' })
  } catch (error) {
    console.error('Error deleting event:', error)
    res.status(500).json({ success: false, error: 'Failed to delete event' })
  }
})

// ============================================================================
// Recurrence Endpoints
// ============================================================================

/**
 * @openapi
 * /api/events/{id}/update-series:
 *   patch:
 *     tags: [Events]
 *     summary: Update multiple events in a recurrence series
 *     description: Updates events in a recurring series. Supports updating just this instance, this and future instances, or all instances in the series. Only the group owner can update events.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID (any event in the series)
 *       - in: query
 *         name: scope
 *         required: true
 *         schema:
 *           type: string
 *           enum: [this, future, all]
 *         description: |
 *           Which events to update:
 *           - `this`: Only this event instance
 *           - `future`: This event and all future occurrences
 *           - `all`: All events in the series
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 200
 *               description:
 *                 type: string
 *                 maxLength: 5000
 *               startTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *               endTime:
 *                 type: string
 *                 pattern: '^\d{2}:\d{2}$'
 *               locationName:
 *                 type: string
 *                 maxLength: 200
 *                 nullable: true
 *               locationAddress:
 *                 type: string
 *                 maxLength: 500
 *                 nullable: true
 *               alertMinutesBefore:
 *                 type: integer
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Series updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 updatedCount:
 *                   type: integer
 *                   description: Number of events updated
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.patch('/events/:id/update-series', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const scopeSchema = z.object({
      scope: z.enum(['this', 'future', 'all']),
    })
    const { scope } = scopeSchema.parse(req.query)
    const body = updateEventSchema.parse(req.body)

    const updateData: any = {}
    if (body.title !== undefined) updateData.title = body.title
    if (body.description !== undefined) updateData.description = body.description
    if (body.startTime !== undefined) updateData.startTime = body.startTime
    if (body.endTime !== undefined) updateData.endTime = body.endTime
    if (body.locationName !== undefined) updateData.locationName = body.locationName
    if (body.locationAddress !== undefined) updateData.locationAddress = body.locationAddress
    if (body.alertMinutesBefore !== undefined) updateData.alertMinutesBefore = body.alertMinutesBefore

    const result = await updateRecurrenceSeries(id, updateData, scope)

    res.json({ success: true, ...result })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating series:', error)
    res.status(500).json({ success: false, error: 'Failed to update series' })
  }
})

/**
 * @openapi
 * /api/events/{id}/delete-series:
 *   delete:
 *     tags: [Events]
 *     summary: Delete multiple events in a recurrence series
 *     description: Soft deletes events in a recurring series. Supports deleting just this instance, this and future instances, or all instances in the series. Only the group owner can delete events.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID (any event in the series)
 *       - in: query
 *         name: scope
 *         required: true
 *         schema:
 *           type: string
 *           enum: [this, future, all]
 *         description: |
 *           Which events to delete:
 *           - `this`: Only this event instance
 *           - `future`: This event and all future occurrences
 *           - `all`: All events in the series
 *     responses:
 *       200:
 *         description: Series deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 deletedCount:
 *                   type: integer
 *                   description: Number of events deleted
 *       400:
 *         description: Validation error (invalid scope)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.delete('/events/:id/delete-series', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const scopeSchema = z.object({
      scope: z.enum(['this', 'future', 'all']),
    })
    const { scope } = scopeSchema.parse(req.query)

    const result = await deleteRecurrenceSeries(id, scope)

    res.json({ success: true, ...result })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error deleting series:', error)
    res.status(500).json({ success: false, error: 'Failed to delete series' })
  }
})

// ============================================================================
// Cover Image Upload
// ============================================================================

/**
 * @openapi
 * /api/events/{id}/cover-image:
 *   post:
 *     tags: [Events]
 *     summary: Upload a cover image for an event
 *     description: Uploads a cover image for an event. The image is processed into multiple sizes (original, medium, thumbnail) and stored in cloud storage. Only the group owner can upload cover images.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - imageData
 *             properties:
 *               imageData:
 *                 type: string
 *                 description: Base64-encoded image data (can include data URI prefix)
 *                 example: "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
 *               contentType:
 *                 type: string
 *                 default: image/jpeg
 *                 description: MIME type of the image
 *     responses:
 *       200:
 *         description: Cover image uploaded successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 coverImageUrl:
 *                   type: string
 *                   format: uri
 *                   description: Public URL of the uploaded cover image
 *                 event:
 *                   $ref: '#/components/schemas/Event'
 *       400:
 *         description: Validation error (missing or invalid image data)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error or upload failure
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
 *                   example: "Upload failed: Storage error"
 */
router.post('/events/:id/cover-image', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const schema = z.object({
      imageData: z.string().min(1, 'Image data is required'),
      contentType: z.string().default('image/jpeg'),
    })

    const body = schema.parse(req.body)

    // Decode base64 image
    const base64Data = body.imageData.replace(/^data:image\/\w+;base64,/, '')
    const imageBuffer = Buffer.from(base64Data, 'base64')

    // Determine file naming
    const timestamp = Date.now()
    const baseName = `event-${id}-${timestamp}`
    const extension = 'jpeg'

    // Generate image variants using sharp
    const [originalBuffer, mediumBuffer, thumbBuffer] = await Promise.all([
      sharp(imageBuffer)
        .resize(1200, null, { withoutEnlargement: true })
        .jpeg({ quality: 85 })
        .toBuffer(),
      sharp(imageBuffer)
        .resize(400, null, { withoutEnlargement: true })
        .jpeg({ quality: 80 })
        .toBuffer(),
      sharp(imageBuffer)
        .resize(150, null, { withoutEnlargement: true })
        .jpeg({ quality: 75 })
        .toBuffer(),
    ])

    // Upload to R2
    const { url: coverImageUrl } = await uploadImageVariants(
      'events/covers',
      baseName,
      extension,
      originalBuffer,
      mediumBuffer,
      thumbBuffer,
    )

    // Update event
    const updatedEvent = await prisma.event.update({
      where: { id },
      data: { coverImageUrl },
    })

    res.json({ success: true, coverImageUrl, event: updatedEvent })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error uploading cover image:', error)
    res.status(500).json({ success: false, error: 'Failed to upload cover image' })
  }
})

// ============================================================================
// Attachments
// ============================================================================

/**
 * @openapi
 * /api/events/{id}/attachments:
 *   post:
 *     tags: [Events]
 *     summary: Upload an attachment to an event
 *     description: Uploads a file attachment to an event. Supported file types are JPEG, PNG, GIF, WebP, and PDF. Maximum file size is 5MB. Only the group owner can upload attachments.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - fileData
 *               - fileName
 *               - fileType
 *             properties:
 *               fileData:
 *                 type: string
 *                 description: Base64-encoded file data (can include data URI prefix)
 *                 example: "data:application/pdf;base64,JVBERi0xLjQK..."
 *               fileName:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 255
 *                 description: Original file name
 *                 example: "event-schedule.pdf"
 *               fileType:
 *                 type: string
 *                 enum: [image/jpeg, image/png, image/gif, image/webp, application/pdf]
 *                 description: MIME type of the file
 *     responses:
 *       201:
 *         description: Attachment uploaded successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 attachment:
 *                   $ref: '#/components/schemas/EventAttachment'
 *       400:
 *         description: Validation error or invalid file
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   oneOf:
 *                     - type: string
 *                       example: "Invalid file type. Allowed: JPEG, PNG, GIF, WebP, PDF"
 *                     - type: string
 *                       example: "File too large. Max 5MB."
 *                     - type: array
 *                       items:
 *                         type: object
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error or upload failure
 */
router.post('/events/:id/attachments', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const schema = z.object({
      fileData: z.string().min(1, 'File data is required'),
      fileName: z.string().min(1).max(255),
      fileType: z.string().min(1), // MIME type
    })

    const body = schema.parse(req.body)

    // Validate file type
    const allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
    ]
    if (!allowedTypes.includes(body.fileType)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid file type. Allowed: JPEG, PNG, GIF, WebP, PDF',
      })
    }

    // Decode base64
    const base64Data = body.fileData.replace(/^data:[^;]+;base64,/, '')
    const fileBuffer = Buffer.from(base64Data, 'base64')

    // Check file size (5MB max)
    if (fileBuffer.length > 5 * 1024 * 1024) {
      return res.status(400).json({ success: false, error: 'File too large. Max 5MB.' })
    }

    // Generate unique filename
    const timestamp = Date.now()
    const safeFileName = body.fileName.replace(/[^a-zA-Z0-9.-]/g, '_')
    const storagePath = `event-${id}/${timestamp}-${safeFileName}`

    // Upload to R2
    const { url: fileUrl } = await uploadFile(
      'events/attachments',
      storagePath,
      fileBuffer,
      body.fileType,
    )

    // Create attachment record
    const attachment = await prisma.eventAttachment.create({
      data: {
        eventId: id,
        url: fileUrl,
        fileName: body.fileName,
        fileType: body.fileType,
        fileSize: fileBuffer.length,
        uploadedById: userId,
      },
    })

    res.status(201).json({ success: true, attachment })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error uploading attachment:', error)
    res.status(500).json({ success: false, error: 'Failed to upload attachment' })
  }
})

/**
 * @openapi
 * /api/events/{id}/attachments/{attachmentId}:
 *   delete:
 *     tags: [Events]
 *     summary: Remove an attachment from an event
 *     description: Deletes an attachment record from the database. The file remains in storage. Only the group owner can delete attachments.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *       - in: path
 *         name: attachmentId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The attachment ID to delete
 *     responses:
 *       200:
 *         description: Attachment deleted successfully
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
 *                   example: Attachment deleted
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event or attachment not found
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
 *                   example: Attachment not found
 *       500:
 *         description: Internal server error
 */
router.delete('/events/:id/attachments/:attachmentId', requireAuth, async (req, res) => {
  try {
    const { id, attachmentId } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const attachment = await prisma.eventAttachment.findFirst({
      where: { id: attachmentId, eventId: id },
    })

    if (!attachment) {
      return res.status(404).json({ success: false, error: 'Attachment not found' })
    }

    // Delete from database (file remains in storage for now)
    await prisma.eventAttachment.delete({
      where: { id: attachmentId },
    })

    res.json({ success: true, message: 'Attachment deleted' })
  } catch (error) {
    console.error('Error deleting attachment:', error)
    res.status(500).json({ success: false, error: 'Failed to delete attachment' })
  }
})

// ============================================================================
// Attendees & RSVP
// ============================================================================

/**
 * @openapi
 * /api/events/{id}/attendees:
 *   get:
 *     tags: [Events]
 *     summary: List attendees for an event
 *     description: Retrieves all attendees for an event with their RSVP status and member details. Includes aggregated statistics by RSVP status. Only the group owner can access this endpoint.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     responses:
 *       200:
 *         description: Attendees retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 attendees:
 *                   type: array
 *                   items:
 *                     allOf:
 *                       - $ref: '#/components/schemas/EventAttendee'
 *                       - type: object
 *                         properties:
 *                           groupMember:
 *                             type: object
 *                             properties:
 *                               member:
 *                                 type: object
 *                                 properties:
 *                                   id:
 *                                     type: string
 *                                   firstName:
 *                                     type: string
 *                                   lastName:
 *                                     type: string
 *                                   profilePicture:
 *                                     type: string
 *                                     nullable: true
 *                 stats:
 *                   type: object
 *                   properties:
 *                     going:
 *                       type: integer
 *                       description: Number of attendees with GOING status
 *                     maybe:
 *                       type: integer
 *                       description: Number of attendees with MAYBE status
 *                     notGoing:
 *                       type: integer
 *                       description: Number of attendees with NOT_GOING status
 *                     pending:
 *                       type: integer
 *                       description: Number of attendees with PENDING status
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.get('/events/:id/attendees', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const attendees = await prisma.eventAttendee.findMany({
      where: { eventId: id },
      include: {
        groupMember: {
          include: {
            member: {
              select: { id: true, firstName: true, lastName: true, profilePicture: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    })

    // Group by RSVP status
    const stats = {
      going: attendees.filter((a) => a.rsvpStatus === 'GOING').length,
      maybe: attendees.filter((a) => a.rsvpStatus === 'MAYBE').length,
      notGoing: attendees.filter((a) => a.rsvpStatus === 'NOT_GOING').length,
      pending: attendees.filter((a) => a.rsvpStatus === 'PENDING').length,
    }

    res.json({ success: true, attendees, stats })
  } catch (error) {
    console.error('Error listing attendees:', error)
    res.status(500).json({ success: false, error: 'Failed to list attendees' })
  }
})

/**
 * @openapi
 * /api/events/{id}/invite:
 *   post:
 *     tags: [Events]
 *     summary: Invite group members to an event
 *     description: Bulk invite group members to an event. Can invite specific members by ID or all active members in the group. Duplicate invitations are automatically skipped. Only the group owner can invite members.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               memberIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uuid
 *                 description: Array of group member IDs to invite (use this OR inviteAll)
 *               inviteAll:
 *                 type: boolean
 *                 description: If true, invite all active members in the group
 *           examples:
 *             inviteSpecific:
 *               summary: Invite specific members
 *               value:
 *                 memberIds: ["550e8400-e29b-41d4-a716-446655440001", "550e8400-e29b-41d4-a716-446655440002"]
 *             inviteAll:
 *               summary: Invite all group members
 *               value:
 *                 inviteAll: true
 *     responses:
 *       200:
 *         description: Members invited successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 invitedCount:
 *                   type: integer
 *                   description: Number of members invited
 *                   example: 15
 *       400:
 *         description: Validation error or no valid members to invite
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
 *                   example: No valid members to invite
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event not found or user is not the group owner
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.post('/events/:id/invite', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const schema = z.object({
      memberIds: z.array(z.string().uuid()).optional(),
      inviteAll: z.boolean().optional(),
    })

    const body = schema.parse(req.body)

    let groupMemberIds: string[] = []

    if (body.inviteAll) {
      // Get all active group members
      const members = await prisma.groupMember.findMany({
        where: { groupId: event.groupId, isActive: true },
        select: { id: true },
      })
      groupMemberIds = members.map((m) => m.id)
    } else if (body.memberIds) {
      // Verify members belong to group
      const members = await prisma.groupMember.findMany({
        where: {
          id: { in: body.memberIds },
          groupId: event.groupId,
          isActive: true,
        },
        select: { id: true },
      })
      groupMemberIds = members.map((m) => m.id)
    }

    if (groupMemberIds.length === 0) {
      return res.status(400).json({ success: false, error: 'No valid members to invite' })
    }

    // Create attendee records (ignore duplicates)
    const attendeeData = groupMemberIds.map((groupMemberId) => ({
      eventId: id,
      groupMemberId,
      rsvpStatus: 'PENDING' as RsvpStatus,
    }))

    await prisma.eventAttendee.createMany({
      data: attendeeData,
      skipDuplicates: true,
    })

    res.json({ success: true, invitedCount: groupMemberIds.length })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error inviting members:', error)
    res.status(500).json({ success: false, error: 'Failed to invite members' })
  }
})

/**
 * @openapi
 * /api/events/{id}/rsvp:
 *   post:
 *     tags: [Events]
 *     summary: RSVP to a private event
 *     description: Allows a member to RSVP to a private event. Requires member authentication via session. The member must belong to the event's group. For public events, use /events/code/{code}/rsvp instead.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - rsvpStatus
 *             properties:
 *               rsvpStatus:
 *                 type: string
 *                 enum: [GOING, MAYBE, NOT_GOING]
 *                 description: The member's RSVP response
 *     responses:
 *       200:
 *         description: RSVP recorded successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 attendee:
 *                   $ref: '#/components/schemas/EventAttendee'
 *       400:
 *         description: Validation error or wrong endpoint for public events
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   oneOf:
 *                     - type: string
 *                       example: "Use /events/code/:code/rsvp for public events"
 *                     - type: array
 *                       items:
 *                         type: object
 *       401:
 *         description: Not authenticated as a member
 *       403:
 *         description: Member does not belong to the event's group
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
 *                   example: You are not a member of this group
 *       404:
 *         description: Event not found
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.post('/events/:id/rsvp', requireMemberAuth, async (req, res) => {
  try {
    const { id } = req.params
    const memberId = req.session.memberId

    // Verify event exists and is private
    const event = await prisma.event.findFirst({
      where: { id, isActive: true },
    })

    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    if (event.visibility !== 'PRIVATE') {
      return res.status(400).json({
        success: false,
        error: 'Use /events/code/:code/rsvp for public events',
      })
    }

    // Verify member belongs to group
    const groupMember = await prisma.groupMember.findFirst({
      where: { groupId: event.groupId, memberId, isActive: true },
    })

    if (!groupMember) {
      return res.status(403).json({ success: false, error: 'You are not a member of this group' })
    }

    const body = memberRsvpSchema.parse(req.body)

    // Upsert attendee record
    const attendee = await prisma.eventAttendee.upsert({
      where: {
        eventId_groupMemberId: { eventId: id, groupMemberId: groupMember.id },
      },
      update: {
        rsvpStatus: body.rsvpStatus,
        rsvpAt: new Date(),
      },
      create: {
        eventId: id,
        groupMemberId: groupMember.id,
        rsvpStatus: body.rsvpStatus,
        rsvpAt: new Date(),
      },
    })

    // Log RSVP
    logSuccess(ActivityTypes.JOIN.EVENT_RSVP_SUBMITTED, req, {
      memberId,
      eventId: id,
      groupId: event.groupId,
      rsvpStatus: body.rsvpStatus,
    })

    res.json({ success: true, attendee })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error RSVPing:', error)
    res.status(500).json({ success: false, error: 'Failed to RSVP' })
  }
})

/**
 * @openapi
 * /api/events/code/{code}/rsvp:
 *   post:
 *     tags: [Events]
 *     summary: RSVP to a public event
 *     description: Allows anyone to RSVP to a public event using the event code. No authentication required. Collects contact information. If the phone number has already RSVP'd, the existing record is updated.
 *     parameters:
 *       - in: path
 *         name: code
 *         required: true
 *         schema:
 *           type: string
 *           pattern: '^\d{6}$'
 *         description: The 6-digit event code
 *         example: "123456"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - phoneNumber
 *               - firstName
 *               - rsvpStatus
 *             properties:
 *               phoneNumber:
 *                 type: string
 *                 pattern: '^\+[1-9]\d{1,14}$'
 *                 description: Phone number in E.164 format
 *                 example: "+15551234567"
 *               firstName:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 100
 *                 description: First name
 *                 example: "John"
 *               lastName:
 *                 type: string
 *                 maxLength: 100
 *                 description: Last name (optional)
 *                 example: "Doe"
 *               gender:
 *                 type: string
 *                 description: Gender (optional)
 *               birthdate:
 *                 type: string
 *                 format: date-time
 *                 description: Date of birth (optional)
 *               rsvpStatus:
 *                 type: string
 *                 enum: [GOING, MAYBE, NOT_GOING]
 *                 description: The RSVP response
 *     responses:
 *       200:
 *         description: Existing RSVP updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 attendee:
 *                   $ref: '#/components/schemas/EventAttendee'
 *                 isUpdate:
 *                   type: boolean
 *                   example: true
 *                   description: Indicates the existing RSVP was updated
 *       201:
 *         description: New RSVP created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 attendee:
 *                   $ref: '#/components/schemas/EventAttendee'
 *                 isUpdate:
 *                   type: boolean
 *                   example: false
 *                   description: Indicates a new RSVP was created
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       path:
 *                         type: array
 *                         items:
 *                           type: string
 *                       message:
 *                         type: string
 *       404:
 *         description: Event not found (invalid code, inactive, or not public)
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.post('/events/code/:code/rsvp', async (req, res) => {
  try {
    const code = normalizeEventCode(req.params.code)

    // Find public event
    const event = await prisma.event.findFirst({
      where: { code, isActive: true, visibility: 'PUBLIC' },
    })

    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const body = publicRsvpSchema.parse(req.body)

    // Check if already RSVP'd with this phone
    const existing = await prisma.eventAttendee.findFirst({
      where: { eventId: event.id, phoneNumber: body.phoneNumber },
    })

    if (existing) {
      // Update existing RSVP
      const updated = await prisma.eventAttendee.update({
        where: { id: existing.id },
        data: {
          rsvpStatus: body.rsvpStatus,
          firstName: body.firstName,
          lastName: body.lastName,
          gender: body.gender,
          birthdate: body.birthdate ? new Date(body.birthdate) : undefined,
          rsvpAt: new Date(),
        },
      })

      // Log public RSVP update
      logSuccess(ActivityTypes.JOIN.EVENT_PUBLIC_RSVP, req, {
        eventId: event.id,
        eventCode: code,
        phoneNumber: body.phoneNumber,
        rsvpStatus: body.rsvpStatus,
        metadata: { isUpdate: true },
      })

      return res.json({ success: true, attendee: updated, isUpdate: true })
    }

    // Create new attendee
    const attendee = await prisma.eventAttendee.create({
      data: {
        eventId: event.id,
        phoneNumber: body.phoneNumber,
        firstName: body.firstName,
        lastName: body.lastName,
        gender: body.gender,
        birthdate: body.birthdate ? new Date(body.birthdate) : undefined,
        rsvpStatus: body.rsvpStatus,
        rsvpAt: new Date(),
      },
    })

    // Log public RSVP
    logSuccess(ActivityTypes.JOIN.EVENT_PUBLIC_RSVP, req, {
      eventId: event.id,
      eventCode: code,
      phoneNumber: body.phoneNumber,
      rsvpStatus: body.rsvpStatus,
      metadata: { isUpdate: false },
    })

    res.status(201).json({ success: true, attendee, isUpdate: false })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error RSVPing to public event:', error)
    res.status(500).json({ success: false, error: 'Failed to RSVP' })
  }
})

/**
 * @openapi
 * /api/events/{id}/attendees/{attendeeId}:
 *   patch:
 *     tags: [Events]
 *     summary: Update an attendee
 *     description: Updates an attendee's RSVP status or check-in status. Only the group owner can update attendees.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *       - in: path
 *         name: attendeeId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The attendee ID to update
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               rsvpStatus:
 *                 type: string
 *                 enum: [GOING, MAYBE, NOT_GOING, PENDING]
 *                 description: Update the attendee's RSVP status
 *               checkedIn:
 *                 type: boolean
 *                 description: Mark the attendee as checked in (true) or not checked in (false)
 *           examples:
 *             checkIn:
 *               summary: Check in an attendee
 *               value:
 *                 checkedIn: true
 *             updateStatus:
 *               summary: Update RSVP status
 *               value:
 *                 rsvpStatus: GOING
 *     responses:
 *       200:
 *         description: Attendee updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 attendee:
 *                   $ref: '#/components/schemas/EventAttendee'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event or attendee not found
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.patch('/events/:id/attendees/:attendeeId', requireAuth, async (req, res) => {
  try {
    const { id, attendeeId } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    const schema = z.object({
      rsvpStatus: z.enum(['GOING', 'MAYBE', 'NOT_GOING', 'PENDING']).optional(),
      checkedIn: z.boolean().optional(),
    })

    const body = schema.parse(req.body)

    const updateData: any = {}
    if (body.rsvpStatus) updateData.rsvpStatus = body.rsvpStatus
    if (body.checkedIn !== undefined) {
      updateData.checkedIn = body.checkedIn
      updateData.checkedInAt = body.checkedIn ? new Date() : null
    }

    const attendee = await prisma.eventAttendee.update({
      where: { id: attendeeId, eventId: id },
      data: updateData,
    })

    res.json({ success: true, attendee })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating attendee:', error)
    res.status(500).json({ success: false, error: 'Failed to update attendee' })
  }
})

/**
 * @openapi
 * /api/events/{id}/attendees/{attendeeId}:
 *   delete:
 *     tags: [Events]
 *     summary: Remove an attendee from an event
 *     description: Permanently removes an attendee record from an event. Only the group owner can remove attendees.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The event ID
 *       - in: path
 *         name: attendeeId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The attendee ID to remove
 *     responses:
 *       200:
 *         description: Attendee removed successfully
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
 *                   example: Attendee removed
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Event or attendee not found
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
 *                   example: Event not found
 *       500:
 *         description: Internal server error
 */
router.delete('/events/:id/attendees/:attendeeId', requireAuth, async (req, res) => {
  try {
    const { id, attendeeId } = req.params
    const userId = (req.user as any).id

    const event = await verifyEventOwnership(id, userId)
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' })
    }

    await prisma.eventAttendee.delete({
      where: { id: attendeeId, eventId: id },
    })

    res.json({ success: true, message: 'Attendee removed' })
  } catch (error) {
    console.error('Error removing attendee:', error)
    res.status(500).json({ success: false, error: 'Failed to remove attendee' })
  }
})

export default router
