import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { ActivityAction, Prisma } from '../generated/prisma/index.js'

const router = Router()

/**
 * @openapi
 * /api/activities:
 *   get:
 *     tags: [Activities]
 *     summary: List activities with multi-level filtering
 *     description: >
 *       Unified activity feed supporting org, group, member, program, and lesson-level queries.
 *       Session auth: returns activities where the user is actor, target, or belongs to the group.
 *       API key auth: returns all activities with optional filters.
 *       Cursor-based pagination, newest first.
 *     security:
 *       - userSession: []
 *       - apiKey: []
 *     parameters:
 *       - in: query
 *         name: actorId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by actor
 *       - in: query
 *         name: organizationId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by organization
 *       - in: query
 *         name: groupId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by group
 *       - in: query
 *         name: targetUserId
 *         schema:
 *           type: string
 *         description: Filter by target user. Use "me" for current user's notifications.
 *       - in: query
 *         name: scope
 *         schema:
 *           type: string
 *           enum: [primary, all]
 *           default: all
 *         description: >
 *           "primary" filters to content and membership activities only
 *           (GROUP, PROGRAM, LESSON, ENROLLMENT, MEMBER, EVENT, POST, TEMPLATE, NOTIFICATION).
 *           "all" returns everything including low-level system events.
 *       - in: query
 *         name: resourceType
 *         schema:
 *           type: string
 *         description: Filter by resource type (GROUP, PROGRAM, LESSON, etc.)
 *       - in: query
 *         name: resourceId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by specific resource
 *       - in: query
 *         name: action
 *         schema:
 *           type: string
 *         description: Filter by action(s). Single value or comma-separated.
 *       - in: query
 *         name: isRead
 *         schema:
 *           type: boolean
 *         description: Filter by read status (for targeted activities)
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date-time
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date-time
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 50
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Pagination cursor (activity ID)
 *     responses:
 *       200:
 *         description: Activities retrieved
 */
const querySchema = z.object({
  actorId: z.string().uuid().optional(),
  organizationId: z.string().uuid().optional(),
  groupId: z.string().uuid().optional(),
  targetUserId: z.string().optional(), // "me" or UUID
  scope: z.enum(['primary', 'all']).default('all').optional(),
  resourceType: z.string().optional(),
  resourceId: z.string().uuid().optional(),
  action: z.string().optional(),
  isRead: z
    .enum(['true', 'false'])
    .transform((v) => v === 'true')
    .optional(),
  startDate: z.coerce.date().optional(),
  endDate: z.coerce.date().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().uuid().optional(),
})

router.get('/', requireAuth, async (req, res) => {
  try {
    const parseResult = querySchema.safeParse(req.query)
    if (!parseResult.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parseResult.error.errors,
      })
    }
    const query = parseResult.data
    const isApiKey = !!req.apiKeyId
    const userId = (req.user as any)?.id

    // Resolve "me" shorthand for targetUserId
    const targetUserId = query.targetUserId === 'me' ? userId : query.targetUserId

    const where: Prisma.ActivityWhereInput = {}

    if (isApiKey) {
      // API key: apply all filters directly
      if (query.actorId) where.actorId = query.actorId
      if (targetUserId) where.targetUserId = targetUserId
    } else {
      // Session auth: scope to activities the user can see
      if (targetUserId) {
        // Notification feed: only show activities targeted at the current user
        where.targetUserId = userId
      } else if (query.actorId) {
        where.actorId = query.actorId
      } else if (!query.groupId && !query.organizationId && !query.resourceId) {
        // Default: show activities where user is actor or target
        where.OR = [{ actorId: userId }, { targetUserId: userId }]
      }
    }

    if (query.organizationId) where.organizationId = query.organizationId
    if (query.groupId) where.groupId = query.groupId
    if (query.resourceType) where.resourceType = query.resourceType
    if (query.resourceId) where.resourceId = query.resourceId
    if (query.isRead !== undefined) where.isRead = query.isRead

    // scope=primary: only content and membership activities (no low-level system events)
    if (query.scope === 'primary') {
      where.resourceType = {
        in: [
          'GROUP',
          'PROGRAM',
          'LESSON',
          'ENROLLMENT',
          'MEMBER',
          'EVENT',
          'POST',
          'TEMPLATE',
          'NOTIFICATION',
        ],
      }
    }

    // Support single action or comma-separated list
    if (query.action) {
      const actions = query.action.split(',').map((a) => a.trim()) as ActivityAction[]
      if (actions.length === 1) {
        where.action = actions[0]
      } else {
        where.action = { in: actions }
      }
    }

    // Date range filtering
    if (query.startDate || query.endDate) {
      where.createdAt = {}
      if (query.startDate) where.createdAt.gte = query.startDate
      if (query.endDate) where.createdAt.lte = query.endDate
    }

    const activities = await prisma.activity.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: query.limit + 1,
      cursor: query.cursor ? { id: query.cursor } : undefined,
      skip: query.cursor ? 1 : 0,
      include: {
        actor: {
          select: { id: true, name: true, picture: true },
        },
      },
    })

    const hasMore = activities.length > query.limit
    const items = hasMore ? activities.slice(0, query.limit) : activities
    const nextCursor = hasMore ? items[items.length - 1].id : null

    res.json({
      success: true,
      activities: items,
      pagination: { hasMore, nextCursor, count: items.length },
    })
  } catch (error) {
    console.error('Error fetching activities:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch activities' })
  }
})

/**
 * @openapi
 * /api/activities/unread-count:
 *   get:
 *     tags: [Activities]
 *     summary: Get count of unread notifications for current user
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Unread count
 */
router.get('/unread-count', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id

    const count = await prisma.activity.count({
      where: {
        targetUserId: userId,
        isRead: false,
      },
    })

    res.json({ success: true, count })
  } catch (error) {
    console.error('Error fetching unread count:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch unread count' })
  }
})

/**
 * @openapi
 * /api/activities/mark-read:
 *   post:
 *     tags: [Activities]
 *     summary: Mark activities as read
 *     description: Mark specific activities by ID, or all unread activities for the current user.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               ids:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uuid
 *               all:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Activities marked as read
 */
const markReadSchema = z
  .object({
    ids: z.array(z.string().uuid()).optional(),
    all: z.boolean().optional(),
  })
  .refine((data) => data.ids || data.all, {
    message: 'Provide either ids or all: true',
  })

router.post('/mark-read', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const body = markReadSchema.parse(req.body)

    const where: Prisma.ActivityWhereInput = {
      targetUserId: userId,
      isRead: false,
    }

    if (body.ids) {
      where.id = { in: body.ids }
    }

    const result = await prisma.activity.updateMany({
      where,
      data: { isRead: true },
    })

    res.json({ success: true, updated: result.count })
  } catch (error) {
    console.error('Error marking activities as read:', error)
    res.status(500).json({ success: false, error: 'Failed to mark activities as read' })
  }
})

export default router
