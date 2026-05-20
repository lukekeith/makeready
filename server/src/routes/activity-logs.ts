import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { getParam } from '../lib/params.js'
import { LogCategory, LogStatus, Prisma } from '../generated/prisma/index.js'

const router = Router()

// ============================================================================
// Ingest endpoint — accepts logs from the Laravel client (server-to-server)
// ============================================================================

const ingestSchema = z.object({
  category: z.enum(['AUTH', 'JOIN', 'ACCESS']),
  activityType: z.string().min(1).max(100),
  status: z.enum(['SUCCESS', 'FAILURE', 'WARNING']),
  message: z.string().max(2000).optional().default(''),
  userId: z.string().uuid().optional().nullable(),
  memberId: z.string().uuid().optional().nullable(),
  actorIp: z.string().max(100).optional().nullable(),
  userAgent: z.string().max(500).optional().nullable(),
  route: z.string().max(500).optional().default(''),
  method: z.string().max(10).optional().default('GET'),
  groupId: z.string().uuid().optional().nullable(),
  eventId: z.string().uuid().optional().nullable(),
  enrollmentId: z.string().uuid().optional().nullable(),
  lessonId: z.string().uuid().optional().nullable(),
  organizationId: z.string().uuid().optional().nullable(),
  inviteId: z.string().uuid().optional().nullable(),
  errorCode: z.string().max(100).optional().nullable(),
  errorMessage: z.string().max(2000).optional().nullable(),
  warningMessage: z.string().max(2000).optional().nullable(),
  metadata: z.any().optional().nullable(),
})

router.post('/ingest', async (req, res) => {
  try {
    const ingestKey = process.env.ACTIVITY_LOG_INGEST_KEY
    const providedKey = req.headers['x-ingest-key'] as string | undefined

    if (!ingestKey || !providedKey || providedKey !== ingestKey) {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }

    const validation = ingestSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: validation.error.errors,
      })
    }

    const data = validation.data

    await prisma.activityLog.create({
      data: {
        category: data.category as LogCategory,
        activityType: data.activityType,
        status: data.status as LogStatus,
        message: data.message || '',
        userId: data.userId || null,
        memberId: data.memberId || null,
        actorIp: data.actorIp || null,
        userAgent: data.userAgent || null,
        route: data.route || '',
        method: data.method || 'GET',
        groupId: data.groupId || null,
        eventId: data.eventId || null,
        enrollmentId: data.enrollmentId || null,
        lessonId: data.lessonId || null,
        organizationId: data.organizationId || null,
        inviteId: data.inviteId || null,
        errorCode: data.errorCode || null,
        errorMessage: data.errorMessage || null,
        warningMessage: data.warningMessage || null,
        metadata: data.metadata ?? undefined,
      },
    })

    res.status(201).json({ success: true })
  } catch (error) {
    console.error('Error ingesting activity log:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

// ============================================================================
// Authenticated endpoints (admin/leader access)
// ============================================================================

/**
 * @openapi
 * components:
 *   schemas:
 *     ActivityLog:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *           description: Unique identifier for the activity log entry
 *           example: "550e8400-e29b-41d4-a716-446655440000"
 *         category:
 *           type: string
 *           enum: [AUTH, JOIN, ACCESS]
 *           description: Category of the activity
 *           example: "AUTH"
 *         activityType:
 *           type: string
 *           description: Specific type of activity within the category
 *           example: "AUTH_GOOGLE_LOGIN_SUCCESS"
 *         status:
 *           type: string
 *           enum: [SUCCESS, FAILURE, WARNING]
 *           description: Status/outcome of the activity
 *           example: "SUCCESS"
 *         message:
 *           type: string
 *           description: Human-readable description of the activity
 *           example: "User logged in via Google OAuth"
 *         userId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the user who performed the activity
 *         memberId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the member associated with the activity
 *         groupId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the group associated with the activity
 *         eventId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the event associated with the activity
 *         enrollmentId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the enrollment associated with the activity
 *         organizationId:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: ID of the organization associated with the activity
 *         metadata:
 *           type: object
 *           nullable: true
 *           description: Additional metadata about the activity
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: Timestamp when the activity was logged
 *           example: "2024-01-15T10:30:00.000Z"
 *     ActivityLogPagination:
 *       type: object
 *       properties:
 *         hasMore:
 *           type: boolean
 *           description: Whether there are more results available
 *           example: true
 *         nextCursor:
 *           type: string
 *           format: uuid
 *           nullable: true
 *           description: Cursor for fetching the next page of results
 *           example: "550e8400-e29b-41d4-a716-446655440001"
 *         count:
 *           type: integer
 *           description: Number of items returned in this page
 *           example: 50
 *     ActivityLogStats:
 *       type: object
 *       properties:
 *         key:
 *           type: string
 *           description: The grouping key (category, activityType, status, or date)
 *           example: "AUTH"
 *         status:
 *           type: string
 *           description: Status breakdown (when grouping by category, activityType, or day)
 *           example: "SUCCESS"
 *         count:
 *           type: integer
 *           description: Number of logs matching this grouping
 *           example: 150
 */

/**
 * @openapi
 * /api/activity-logs:
 *   get:
 *     tags: [Activity Logs]
 *     summary: Query activity logs with filters
 *     description: >
 *       Retrieves activity logs with support for filtering by category, status, activity type,
 *       associated entities (user, member, group, event, enrollment, organization),
 *       date range, and text search. Results are paginated using cursor-based pagination.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           enum: [AUTH, JOIN, ACCESS]
 *         description: Filter by activity category
 *       - in: query
 *         name: activityType
 *         schema:
 *           type: string
 *         description: Filter by specific activity type (e.g., AUTH_GOOGLE_LOGIN_SUCCESS)
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [SUCCESS, FAILURE, WARNING]
 *         description: Filter by activity status
 *       - in: query
 *         name: userId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by user ID
 *       - in: query
 *         name: memberId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by member ID
 *       - in: query
 *         name: groupId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by group ID
 *       - in: query
 *         name: eventId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by event ID
 *       - in: query
 *         name: enrollmentId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by enrollment ID
 *       - in: query
 *         name: organizationId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by organization ID
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter logs created on or after this date (ISO 8601 format)
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter logs created on or before this date (ISO 8601 format)
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 200
 *           default: 50
 *         description: Maximum number of results to return (default 50, max 200)
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Pagination cursor (activity log ID) for fetching next page
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *           maxLength: 100
 *         description: Search term to filter by message content (case-insensitive)
 *     responses:
 *       200:
 *         description: Successfully retrieved activity logs
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 logs:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/ActivityLog'
 *                 pagination:
 *                   $ref: '#/components/schemas/ActivityLogPagination'
 *             example:
 *               success: true
 *               logs:
 *                 - id: "550e8400-e29b-41d4-a716-446655440000"
 *                   category: "AUTH"
 *                   activityType: "AUTH_GOOGLE_LOGIN_SUCCESS"
 *                   status: "SUCCESS"
 *                   message: "User logged in via Google OAuth"
 *                   userId: "123e4567-e89b-12d3-a456-426614174000"
 *                   createdAt: "2024-01-15T10:30:00.000Z"
 *               pagination:
 *                 hasMore: true
 *                 nextCursor: "550e8400-e29b-41d4-a716-446655440001"
 *                 count: 50
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
 *                     properties:
 *                       path:
 *                         type: array
 *                         items:
 *                           type: string
 *                       message:
 *                         type: string
 *       401:
 *         description: Not authenticated
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
 *                   example: "Not authenticated"
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
 *                   example: "Failed to fetch activity logs"
 */
const querySchema = z.object({
  category: z.nativeEnum(LogCategory).optional(),
  activityType: z.string().optional(),
  status: z.nativeEnum(LogStatus).optional(),
  userId: z.string().uuid().optional(),
  memberId: z.string().uuid().optional(),
  groupId: z.string().uuid().optional(),
  eventId: z.string().uuid().optional(),
  enrollmentId: z.string().uuid().optional(),
  organizationId: z.string().uuid().optional(),
  actorIp: z.string().optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
  cursor: z.string().uuid().optional(),
  search: z.string().max(100).optional(),
})

router.get('/', requireAuth, async (req, res) => {
  try {
    // Validate query params
    const parseResult = querySchema.safeParse(req.query)
    if (!parseResult.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parseResult.error.errors,
      })
    }
    const query = parseResult.data

    // Build where clause
    const where: Prisma.ActivityLogWhereInput = {}

    if (query.category) where.category = query.category
    if (query.activityType) where.activityType = query.activityType
    if (query.status) where.status = query.status
    if (query.userId) where.userId = query.userId
    if (query.memberId) where.memberId = query.memberId
    if (query.groupId) where.groupId = query.groupId
    if (query.eventId) where.eventId = query.eventId
    if (query.enrollmentId) where.enrollmentId = query.enrollmentId
    if (query.organizationId) where.organizationId = query.organizationId
    if (query.actorIp) where.actorIp = query.actorIp

    // Date range filter
    if (query.startDate || query.endDate) {
      where.createdAt = {}
      if (query.startDate) where.createdAt.gte = new Date(query.startDate)
      if (query.endDate) where.createdAt.lte = new Date(query.endDate)
    }

    // Search in message
    if (query.search) {
      where.message = { contains: query.search, mode: 'insensitive' }
    }

    // Fetch logs with cursor pagination
    const logs = await prisma.activityLog.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: query.limit + 1, // Fetch one extra to determine hasMore
      cursor: query.cursor ? { id: query.cursor } : undefined,
      skip: query.cursor ? 1 : 0, // Skip the cursor itself
    })

    // Handle pagination
    const hasMore = logs.length > query.limit
    const items = hasMore ? logs.slice(0, query.limit) : logs
    const nextCursor = hasMore ? items[items.length - 1].id : null

    res.json({
      success: true,
      logs: items,
      pagination: {
        hasMore,
        nextCursor,
        count: items.length,
      },
    })
  } catch (error) {
    console.error('Error fetching activity logs:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to fetch activity logs',
    })
  }
})

/**
 * @openapi
 * /api/activity-logs/stats:
 *   get:
 *     tags: [Activity Logs]
 *     summary: Get aggregated statistics for activity logs
 *     description: >
 *       Retrieves aggregated statistics for activity logs, grouped by category, activity type,
 *       status, or day. Useful for dashboards and analytics. Also returns total counts by status.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           enum: [AUTH, JOIN, ACCESS]
 *         description: Filter statistics to a specific category
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter logs created on or after this date (ISO 8601 format)
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter logs created on or before this date (ISO 8601 format)
 *       - in: query
 *         name: groupBy
 *         schema:
 *           type: string
 *           enum: [category, activityType, status, day]
 *           default: category
 *         description: Field to group statistics by
 *     responses:
 *       200:
 *         description: Successfully retrieved activity log statistics
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 stats:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/ActivityLogStats'
 *                 totals:
 *                   type: object
 *                   description: Total counts grouped by status
 *                   properties:
 *                     success:
 *                       type: integer
 *                       example: 1500
 *                     failure:
 *                       type: integer
 *                       example: 50
 *                     warning:
 *                       type: integer
 *                       example: 25
 *             example:
 *               success: true
 *               stats:
 *                 - key: "AUTH"
 *                   status: "SUCCESS"
 *                   count: 1200
 *                 - key: "AUTH"
 *                   status: "FAILURE"
 *                   count: 30
 *                 - key: "JOIN"
 *                   status: "SUCCESS"
 *                   count: 300
 *               totals:
 *                 success: 1500
 *                 failure: 50
 *                 warning: 25
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
 *                     properties:
 *                       path:
 *                         type: array
 *                         items:
 *                           type: string
 *                       message:
 *                         type: string
 *       401:
 *         description: Not authenticated
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
 *                   example: "Not authenticated"
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
 *                   example: "Failed to fetch stats"
 */
const statsSchema = z.object({
  category: z.nativeEnum(LogCategory).optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  groupBy: z
    .enum(['category', 'activityType', 'status', 'day'])
    .default('category'),
})

router.get('/stats', requireAuth, async (req, res) => {
  try {
    const parseResult = statsSchema.safeParse(req.query)
    if (!parseResult.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parseResult.error.errors,
      })
    }
    const query = parseResult.data

    // Build where clause for date range
    const whereClause: string[] = []
    const params: (string | Date)[] = []
    let paramIndex = 1

    if (query.category) {
      whereClause.push(`category = $${paramIndex++}`)
      params.push(query.category)
    }
    if (query.startDate) {
      whereClause.push(`"createdAt" >= $${paramIndex++}`)
      params.push(new Date(query.startDate))
    }
    if (query.endDate) {
      whereClause.push(`"createdAt" <= $${paramIndex++}`)
      params.push(new Date(query.endDate))
    }

    const whereSQL =
      whereClause.length > 0 ? `WHERE ${whereClause.join(' AND ')}` : ''

    // Build group by query based on parameter
    let groupBySQL: string
    let selectSQL: string

    switch (query.groupBy) {
      case 'activityType':
        selectSQL = `"activityType" as key, status, COUNT(*)::int as count`
        groupBySQL = `"activityType", status`
        break
      case 'status':
        selectSQL = `status as key, COUNT(*)::int as count`
        groupBySQL = `status`
        break
      case 'day':
        selectSQL = `DATE("createdAt") as key, status, COUNT(*)::int as count`
        groupBySQL = `DATE("createdAt"), status`
        break
      case 'category':
      default:
        selectSQL = `category as key, status, COUNT(*)::int as count`
        groupBySQL = `category, status`
    }

    const result = await prisma.$queryRawUnsafe<
      { key: string; status?: string; count: number }[]
    >(
      `SELECT ${selectSQL} FROM activity_logs ${whereSQL} GROUP BY ${groupBySQL} ORDER BY count DESC`,
      ...params
    )

    // Get totals
    const totals = await prisma.$queryRawUnsafe<
      { status: string; count: number }[]
    >(
      `SELECT status, COUNT(*)::int as count FROM activity_logs ${whereSQL} GROUP BY status`,
      ...params
    )

    res.json({
      success: true,
      stats: result,
      totals: totals.reduce(
        (acc, row) => {
          acc[row.status.toLowerCase()] = row.count
          return acc
        },
        {} as Record<string, number>
      ),
    })
  } catch (error) {
    console.error('Error fetching activity log stats:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to fetch stats',
    })
  }
})

/**
 * @openapi
 * /api/activity-logs/stats/heatmap:
 *   get:
 *     tags: [Activity Logs]
 *     summary: Get activity heatmap data (day-of-week × hour-of-day)
 *     description: >
 *       Returns aggregated activity counts grouped by day of week and hour of day,
 *       useful for rendering a heatmap showing when members are most active.
 *       Day of week uses 0=Sunday through 6=Saturday. Hours are 0-23.
 *       Pass a timezone parameter to localize the hour bucketing (defaults to UTC).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: groupId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter to activity within a specific group
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           enum: [AUTH, JOIN, ACCESS]
 *         description: Filter by activity category
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter logs created on or after this date (ISO 8601)
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Filter logs created on or before this date (ISO 8601)
 *       - in: query
 *         name: timezone
 *         schema:
 *           type: string
 *           default: UTC
 *         description: IANA timezone name for hour bucketing (e.g. "America/Chicago")
 *     responses:
 *       200:
 *         description: Successfully retrieved heatmap data
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 heatmap:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       dayOfWeek:
 *                         type: integer
 *                         minimum: 0
 *                         maximum: 6
 *                         description: "Day of week (0=Sunday, 6=Saturday)"
 *                       hour:
 *                         type: integer
 *                         minimum: 0
 *                         maximum: 23
 *                         description: Hour of day (0-23)
 *                       count:
 *                         type: integer
 *                         description: Number of activities in this slot
 *             example:
 *               success: true
 *               heatmap:
 *                 - dayOfWeek: 1
 *                   hour: 9
 *                   count: 12
 *                 - dayOfWeek: 1
 *                   hour: 10
 *                   count: 18
 *                 - dayOfWeek: 2
 *                   hour: 8
 *                   count: 5
 *       400:
 *         description: Invalid query parameters
 *       401:
 *         description: Not authenticated
 *       500:
 *         description: Server error
 */
const heatmapSchema = z.object({
  groupId: z.string().uuid().optional(),
  category: z.nativeEnum(LogCategory).optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  timezone: z.string().default('UTC'),
})

router.get('/stats/heatmap', requireAuth, async (req, res) => {
  try {
    const parseResult = heatmapSchema.safeParse(req.query)
    if (!parseResult.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parseResult.error.errors,
      })
    }
    const query = parseResult.data

    // Build WHERE clause
    const whereClause: string[] = []
    const params: (string | Date)[] = []
    let paramIndex = 1

    // Timezone is used in SELECT, not WHERE — reserve $1 for it
    params.push(query.timezone)
    paramIndex++

    if (query.groupId) {
      whereClause.push(`"groupId" = $${paramIndex++}`)
      params.push(query.groupId)
    }
    if (query.category) {
      whereClause.push(`category = $${paramIndex++}`)
      params.push(query.category)
    }
    if (query.startDate) {
      whereClause.push(`"createdAt" >= $${paramIndex++}`)
      params.push(new Date(query.startDate))
    }
    if (query.endDate) {
      whereClause.push(`"createdAt" <= $${paramIndex++}`)
      params.push(new Date(query.endDate))
    }

    const whereSQL =
      whereClause.length > 0 ? `WHERE ${whereClause.join(' AND ')}` : ''

    const result = await prisma.$queryRawUnsafe<
      { dayOfWeek: number; hour: number; count: number }[]
    >(
      `SELECT
        EXTRACT(DOW FROM "createdAt" AT TIME ZONE $1)::int AS "dayOfWeek",
        EXTRACT(HOUR FROM "createdAt" AT TIME ZONE $1)::int AS hour,
        COUNT(*)::int AS count
      FROM activity_logs
      ${whereSQL}
      GROUP BY "dayOfWeek", hour
      ORDER BY "dayOfWeek", hour`,
      ...params
    )

    res.json({
      success: true,
      heatmap: result,
    })
  } catch (error) {
    console.error('Error fetching activity heatmap:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to fetch heatmap data',
    })
  }
})

/**
 * @openapi
 * /api/activity-logs/{id}:
 *   get:
 *     tags: [Activity Logs]
 *     summary: Get a single activity log entry
 *     description: Retrieves detailed information about a specific activity log entry by its ID.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: The unique identifier of the activity log entry
 *         example: "550e8400-e29b-41d4-a716-446655440000"
 *     responses:
 *       200:
 *         description: Successfully retrieved activity log entry
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 log:
 *                   $ref: '#/components/schemas/ActivityLog'
 *             example:
 *               success: true
 *               log:
 *                 id: "550e8400-e29b-41d4-a716-446655440000"
 *                 category: "AUTH"
 *                 activityType: "AUTH_GOOGLE_LOGIN_SUCCESS"
 *                 status: "SUCCESS"
 *                 message: "User logged in via Google OAuth"
 *                 userId: "123e4567-e89b-12d3-a456-426614174000"
 *                 memberId: null
 *                 groupId: null
 *                 eventId: null
 *                 enrollmentId: null
 *                 organizationId: null
 *                 metadata:
 *                   ipAddress: "192.168.1.1"
 *                   userAgent: "Mozilla/5.0..."
 *                 createdAt: "2024-01-15T10:30:00.000Z"
 *       400:
 *         description: Invalid or missing activity log ID
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
 *                   example: "Activity log ID is required"
 *       401:
 *         description: Not authenticated
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
 *                   example: "Not authenticated"
 *       404:
 *         description: Activity log not found
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
 *                   example: "Activity log not found"
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
 *                   example: "Failed to fetch activity log"
 */
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const id = getParam(req.params.id)

    if (!id) {
      return res.status(400).json({
        success: false,
        error: 'Activity log ID is required',
      })
    }

    const log = await prisma.activityLog.findUnique({
      where: { id },
    })

    if (!log) {
      return res.status(404).json({
        success: false,
        error: 'Activity log not found',
      })
    }

    res.json({ success: true, log })
  } catch (error) {
    console.error('Error fetching activity log:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to fetch activity log',
    })
  }
})

export default router
