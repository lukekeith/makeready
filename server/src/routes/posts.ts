import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { trackActivity } from '../services/activity.js'

/**
 * @openapi
 * components:
 *   schemas:
 *     Post:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the post
 *           example: "clx9876543210"
 *         groupId:
 *           type: string
 *           description: ID of the group this post belongs to
 *           example: "clx1234567890"
 *         authorId:
 *           type: string
 *           description: ID of the user who created the post
 *           example: "usr123"
 *         authorName:
 *           type: string
 *           description: Display name of the post author
 *           example: "John Doe"
 *         authorAvatarUrl:
 *           type: string
 *           nullable: true
 *           description: URL to the author's avatar image
 *           example: "https://example.com/avatar.jpg"
 *         type:
 *           type: string
 *           enum: [WELCOME, POLL, VIDEO, EVENT, ANNOUNCEMENT]
 *           description: The type of post
 *           example: "ANNOUNCEMENT"
 *         title:
 *           type: string
 *           nullable: true
 *           description: Optional title for the post
 *           example: "Important Update"
 *         content:
 *           type: string
 *           description: The main content/body of the post
 *           example: "We have some exciting news!"
 *         imageUrl:
 *           type: string
 *           nullable: true
 *           description: URL to an image attachment
 *         pollOptions:
 *           type: array
 *           nullable: true
 *           items:
 *             $ref: '#/components/schemas/PollOption'
 *           description: Poll options (for POLL type posts)
 *         videoUrl:
 *           type: string
 *           nullable: true
 *           description: URL to a video (for VIDEO type posts)
 *         eventDate:
 *           type: string
 *           format: date-time
 *           nullable: true
 *           description: Event date and time (for EVENT type posts)
 *         eventLocation:
 *           type: string
 *           nullable: true
 *           description: Event location (for EVENT type posts)
 *         enrollmentId:
 *           type: string
 *           nullable: true
 *           description: Associated enrollment ID (for study program posts)
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: When the post was created
 *           example: "2024-01-15T10:30:00.000Z"
 *         updatedAt:
 *           type: string
 *           format: date-time
 *           description: When the post was last updated
 *           example: "2024-01-15T10:30:00.000Z"
 *     PostPublic:
 *       type: object
 *       description: Post object for public (unauthenticated) access - excludes enrollmentId
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the post
 *           example: "clx9876543210"
 *         groupId:
 *           type: string
 *           description: ID of the group this post belongs to
 *           example: "clx1234567890"
 *         authorId:
 *           type: string
 *           description: ID of the user who created the post
 *           example: "usr123"
 *         authorName:
 *           type: string
 *           description: Display name of the post author
 *           example: "John Doe"
 *         authorAvatarUrl:
 *           type: string
 *           nullable: true
 *           description: URL to the author's avatar image
 *           example: "https://example.com/avatar.jpg"
 *         type:
 *           type: string
 *           enum: [WELCOME, POLL, VIDEO, EVENT, ANNOUNCEMENT]
 *           description: The type of post
 *           example: "ANNOUNCEMENT"
 *         title:
 *           type: string
 *           nullable: true
 *           description: Optional title for the post
 *           example: "Important Update"
 *         content:
 *           type: string
 *           description: The main content/body of the post
 *           example: "We have some exciting news!"
 *         imageUrl:
 *           type: string
 *           nullable: true
 *           description: URL to an image attachment
 *         pollOptions:
 *           type: array
 *           nullable: true
 *           items:
 *             $ref: '#/components/schemas/PollOption'
 *           description: Poll options (for POLL type posts)
 *         videoUrl:
 *           type: string
 *           nullable: true
 *           description: URL to a video (for VIDEO type posts)
 *         eventDate:
 *           type: string
 *           format: date-time
 *           nullable: true
 *           description: Event date and time (for EVENT type posts)
 *         eventLocation:
 *           type: string
 *           nullable: true
 *           description: Event location (for EVENT type posts)
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: When the post was created
 *           example: "2024-01-15T10:30:00.000Z"
 *         updatedAt:
 *           type: string
 *           format: date-time
 *           description: When the post was last updated
 *           example: "2024-01-15T10:30:00.000Z"
 *     PollOption:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the poll option
 *           example: "opt1"
 *         text:
 *           type: string
 *           description: The text of the poll option
 *           example: "Monday"
 *         voteCount:
 *           type: integer
 *           description: Number of votes for this option
 *           example: 5
 *     ErrorResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: false
 *         error:
 *           type: string
 *           description: Error message describing what went wrong
 *           example: "Resource not found"
 */

const router = Router()

// ============================================================================
// Posts API (Group Feed)
// ============================================================================

/**
 * @openapi
 * /api/groups/{groupId}/posts:
 *   get:
 *     tags: [Posts]
 *     summary: Get posts for a group
 *     description: |
 *       Retrieves posts for a specific group with cursor-based pagination.
 *       User must be the group creator or an active member to access posts.
 *       Posts are ordered by creation date (newest first).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *         example: "clx1234567890"
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *           default: 20
 *         description: Maximum number of posts to return (capped at 50)
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *           format: date-time
 *         description: ISO 8601 timestamp cursor for pagination (returns posts created before this time)
 *         example: "2024-01-15T10:30:00.000Z"
 *     responses:
 *       200:
 *         description: Posts retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 posts:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Post'
 *                 nextCursor:
 *                   type: string
 *                   nullable: true
 *                   format: date-time
 *                   description: Cursor for fetching the next page of results, null if no more pages
 *                   example: "2024-01-14T08:00:00.000Z"
 *             example:
 *               success: true
 *               posts:
 *                 - id: "clx9876543210"
 *                   groupId: "clx1234567890"
 *                   authorId: "usr123"
 *                   authorName: "John Doe"
 *                   authorAvatarUrl: "https://example.com/avatar.jpg"
 *                   type: "ANNOUNCEMENT"
 *                   title: "Welcome to the group!"
 *                   content: "We're excited to have you here."
 *                   imageUrl: null
 *                   pollOptions: null
 *                   videoUrl: null
 *                   eventDate: null
 *                   eventLocation: null
 *                   enrollmentId: null
 *                   createdAt: "2024-01-15T10:30:00.000Z"
 *                   updatedAt: "2024-01-15T10:30:00.000Z"
 *               nextCursor: "2024-01-14T08:00:00.000Z"
 *       404:
 *         description: Group not found or user does not have access
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Group not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to fetch posts"
 */
router.get('/groups/:groupId/posts', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50)
    const cursor = req.query.cursor as string | undefined

    // Verify group access (user is creator or member)
    const group = await prisma.group.findFirst({
      where: {
        id: groupId,
        isActive: true,
        OR: [
          { creatorId: userId },
          { members: { some: { member: { id: userId }, isActive: true } } },
        ],
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Build query
    const whereClause = {
      groupId,
      isActive: true,
      ...(cursor ? { createdAt: { lt: new Date(cursor) } } : {}),
    }

    const posts = await prisma.post.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' },
      take: limit + 1, // Fetch one extra to determine if there are more
      include: {
        author: {
          select: {
            id: true,
            name: true,
            picture: true,
          },
        },
        enrollment: {
          select: {
            id: true,
            studyProgram: {
              select: {
                id: true,
                name: true,
                days: true,
              },
            },
          },
        },
      },
    })

    // Check if there are more results
    const hasMore = posts.length > limit
    const results = hasMore ? posts.slice(0, limit) : posts
    const nextCursor = hasMore ? results[results.length - 1].createdAt.toISOString() : null

    // Transform posts to match client expectations
    const transformedPosts = results.map((post) => ({
      id: post.id,
      groupId: post.groupId,
      authorId: post.authorId,
      authorName: post.author?.name || 'MakeReady',
      authorAvatarUrl: post.author?.picture || null,
      type: post.type,
      title: post.title,
      content: post.content,
      imageUrl: post.imageUrl,
      pollOptions: post.pollOptions,
      videoUrl: post.videoUrl,
      eventDate: post.eventDate,
      eventLocation: post.eventLocation,
      enrollmentId: post.enrollmentId,
      createdAt: post.createdAt.toISOString(),
      updatedAt: post.updatedAt.toISOString(),
    }))

    res.json({
      success: true,
      posts: transformedPosts,
      nextCursor,
      hasMore,
    })
  } catch (error) {
    console.error('Error fetching posts:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch posts' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/posts/public:
 *   get:
 *     tags: [Posts]
 *     summary: Get posts for a group (public)
 *     description: |
 *       Retrieves posts for a specific group without requiring authentication.
 *       Used for member preview after clicking an invite link.
 *       Posts are ordered by creation date (newest first) with cursor-based pagination.
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *         example: "clx1234567890"
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *           default: 20
 *         description: Maximum number of posts to return (capped at 50)
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *           format: date-time
 *         description: ISO 8601 timestamp cursor for pagination (returns posts created before this time)
 *         example: "2024-01-15T10:30:00.000Z"
 *     responses:
 *       200:
 *         description: Posts retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 posts:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/PostPublic'
 *                 nextCursor:
 *                   type: string
 *                   nullable: true
 *                   format: date-time
 *                   description: Cursor for fetching the next page of results, null if no more pages
 *                   example: "2024-01-14T08:00:00.000Z"
 *             example:
 *               success: true
 *               posts:
 *                 - id: "clx9876543210"
 *                   groupId: "clx1234567890"
 *                   authorId: "usr123"
 *                   authorName: "John Doe"
 *                   authorAvatarUrl: "https://example.com/avatar.jpg"
 *                   type: "ANNOUNCEMENT"
 *                   title: "Welcome to the group!"
 *                   content: "We're excited to have you here."
 *                   imageUrl: null
 *                   pollOptions: null
 *                   videoUrl: null
 *                   eventDate: null
 *                   eventLocation: null
 *                   createdAt: "2024-01-15T10:30:00.000Z"
 *                   updatedAt: "2024-01-15T10:30:00.000Z"
 *               nextCursor: "2024-01-14T08:00:00.000Z"
 *       404:
 *         description: Group not found or inactive
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Group not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to fetch posts"
 */
router.get('/groups/:groupId/posts/public', async (req, res) => {
  try {
    const { groupId } = req.params
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50)
    const cursor = req.query.cursor as string | undefined

    // Verify group exists and is active
    const group = await prisma.group.findFirst({
      where: {
        id: groupId,
        isActive: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Build query
    const whereClause = {
      groupId,
      isActive: true,
      ...(cursor ? { createdAt: { lt: new Date(cursor) } } : {}),
    }

    const posts = await prisma.post.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      include: {
        author: {
          select: {
            id: true,
            name: true,
            picture: true,
          },
        },
      },
    })

    // Check if there are more results
    const hasMore = posts.length > limit
    const results = hasMore ? posts.slice(0, limit) : posts
    const nextCursor = hasMore ? results[results.length - 1].createdAt.toISOString() : null

    // Transform posts
    const transformedPosts = results.map((post) => ({
      id: post.id,
      groupId: post.groupId,
      authorId: post.authorId,
      authorName: post.author?.name || 'MakeReady',
      authorAvatarUrl: post.author?.picture || null,
      type: post.type,
      title: post.title,
      content: post.content,
      imageUrl: post.imageUrl,
      pollOptions: post.pollOptions,
      videoUrl: post.videoUrl,
      eventDate: post.eventDate,
      eventLocation: post.eventLocation,
      createdAt: post.createdAt.toISOString(),
      updatedAt: post.updatedAt.toISOString(),
    }))

    res.json({
      success: true,
      posts: transformedPosts,
      nextCursor,
      hasMore,
    })
  } catch (error) {
    console.error('Error fetching public posts:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch posts' })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/posts:
 *   post:
 *     tags: [Posts]
 *     summary: Create a new post in a group
 *     description: |
 *       Creates a new post in the specified group.
 *       Only the group creator can create posts.
 *       Supports different post types: POLL, VIDEO, EVENT, and ANNOUNCEMENT.
 *       WELCOME posts are system-generated only and cannot be created via this endpoint.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *         example: "clx1234567890"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - type
 *               - content
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [POLL, VIDEO, EVENT, ANNOUNCEMENT]
 *                 description: The type of post to create
 *               title:
 *                 type: string
 *                 maxLength: 200
 *                 description: Optional title for the post
 *               content:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 5000
 *                 description: The main content/body of the post
 *               imageUrl:
 *                 type: string
 *                 format: uri
 *                 description: URL to an image attachment
 *               pollOptions:
 *                 type: array
 *                 items:
 *                   type: object
 *                   required:
 *                     - id
 *                     - text
 *                   properties:
 *                     id:
 *                       type: string
 *                       description: Unique identifier for the poll option
 *                     text:
 *                       type: string
 *                       description: The text of the poll option
 *                     voteCount:
 *                       type: integer
 *                       default: 0
 *                       description: Number of votes for this option
 *                 description: Poll options (required for POLL type)
 *               videoUrl:
 *                 type: string
 *                 format: uri
 *                 description: URL to a video (required for VIDEO type)
 *               eventDate:
 *                 type: string
 *                 format: date-time
 *                 description: Event date and time (for EVENT type)
 *               eventLocation:
 *                 type: string
 *                 maxLength: 500
 *                 description: Event location (for EVENT type)
 *           examples:
 *             announcement:
 *               summary: Create an announcement
 *               value:
 *                 type: "ANNOUNCEMENT"
 *                 title: "Important Update"
 *                 content: "We have some exciting news to share with the group!"
 *             poll:
 *               summary: Create a poll
 *               value:
 *                 type: "POLL"
 *                 title: "What day works best?"
 *                 content: "Vote for your preferred meeting day"
 *                 pollOptions:
 *                   - id: "opt1"
 *                     text: "Monday"
 *                     voteCount: 0
 *                   - id: "opt2"
 *                     text: "Wednesday"
 *                     voteCount: 0
 *                   - id: "opt3"
 *                     text: "Friday"
 *                     voteCount: 0
 *             event:
 *               summary: Create an event
 *               value:
 *                 type: "EVENT"
 *                 title: "Group Meetup"
 *                 content: "Join us for our monthly meetup!"
 *                 eventDate: "2024-02-15T18:00:00.000Z"
 *                 eventLocation: "Community Center, 123 Main St"
 *             video:
 *               summary: Create a video post
 *               value:
 *                 type: "VIDEO"
 *                 title: "Tutorial Video"
 *                 content: "Check out this helpful tutorial"
 *                 videoUrl: "https://example.com/video.mp4"
 *     responses:
 *       200:
 *         description: Post created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 post:
 *                   $ref: '#/components/schemas/Post'
 *             example:
 *               success: true
 *               post:
 *                 id: "clx9876543210"
 *                 groupId: "clx1234567890"
 *                 authorId: "usr123"
 *                 authorName: "John Doe"
 *                 authorAvatarUrl: "https://example.com/avatar.jpg"
 *                 type: "ANNOUNCEMENT"
 *                 title: "Important Update"
 *                 content: "We have some exciting news to share with the group!"
 *                 imageUrl: null
 *                 pollOptions: null
 *                 videoUrl: null
 *                 eventDate: null
 *                 eventLocation: null
 *                 createdAt: "2024-01-15T10:30:00.000Z"
 *                 updatedAt: "2024-01-15T10:30:00.000Z"
 *       400:
 *         description: Invalid request body
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
 *                       code:
 *                         type: string
 *                       message:
 *                         type: string
 *                       path:
 *                         type: array
 *                         items:
 *                           type: string
 *             example:
 *               success: false
 *               error:
 *                 - code: "too_small"
 *                   message: "String must contain at least 1 character(s)"
 *                   path: ["content"]
 *       404:
 *         description: Group not found or access denied
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Group not found or access denied"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to create post"
 */
router.post('/groups/:groupId/posts', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      type: z.enum(['POLL', 'VIDEO', 'EVENT', 'ANNOUNCEMENT']), // WELCOME is system-generated only
      title: z.string().max(200).optional(),
      content: z.string().min(1).max(5000),
      imageUrl: z.string().url().optional(),
      pollOptions: z
        .array(
          z.object({
            id: z.string(),
            text: z.string(),
            voteCount: z.number().default(0),
          })
        )
        .optional(),
      videoUrl: z.string().url().optional(),
      eventDate: z.string().datetime().optional(),
      eventLocation: z.string().max(500).optional(),
    })

    const body = schema.parse(req.body)

    // Verify group access (user is creator or admin)
    const group = await prisma.group.findFirst({
      where: {
        id: groupId,
        creatorId: userId,
        isActive: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found or access denied' })
    }

    const post = await prisma.post.create({
      data: {
        groupId,
        authorId: userId,
        type: body.type,
        title: body.title,
        content: body.content,
        imageUrl: body.imageUrl,
        pollOptions: body.pollOptions,
        videoUrl: body.videoUrl,
        eventDate: body.eventDate ? new Date(body.eventDate) : null,
        eventLocation: body.eventLocation,
      },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            picture: true,
          },
        },
      },
    })

    console.log(`📝 Created post ${post.id} (${post.type}) in group ${groupId}`)

    trackActivity({
      actorId: userId,
      action: 'CREATED',
      resourceType: 'POST',
      resourceId: post.id,
      resourceName: post.title || post.type,
      organizationId: group.organizationId,
      groupId: groupId,
    })

    res.json({
      success: true,
      post: {
        id: post.id,
        groupId: post.groupId,
        authorId: post.authorId,
        authorName: post.author?.name || 'Unknown',
        authorAvatarUrl: post.author?.picture || null,
        type: post.type,
        title: post.title,
        content: post.content,
        imageUrl: post.imageUrl,
        pollOptions: post.pollOptions,
        videoUrl: post.videoUrl,
        eventDate: post.eventDate?.toISOString() || null,
        eventLocation: post.eventLocation,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      },
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error creating post:', error)
    res.status(500).json({ success: false, error: 'Failed to create post' })
  }
})

/**
 * @openapi
 * /api/posts/{id}:
 *   patch:
 *     tags: [Posts]
 *     summary: Update a post
 *     description: |
 *       Updates an existing post. Only the post author or group creator can update.
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
 *             properties:
 *               title:
 *                 type: string
 *                 maxLength: 200
 *               content:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 5000
 *               imageUrl:
 *                 type: string
 *                 format: uri
 *                 nullable: true
 *               pollOptions:
 *                 type: array
 *                 nullable: true
 *               videoUrl:
 *                 type: string
 *                 format: uri
 *                 nullable: true
 *               eventDate:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *               eventLocation:
 *                 type: string
 *                 maxLength: 500
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Post updated successfully
 *       403:
 *         description: Not authorized
 *       404:
 *         description: Post not found
 */
router.patch('/posts/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const post = await prisma.post.findFirst({
      where: { id, isActive: true },
      include: { group: { select: { creatorId: true } } },
    })

    if (!post) {
      return res.status(404).json({ success: false, error: 'Post not found' })
    }

    if (post.authorId !== userId && post.group.creatorId !== userId) {
      return res.status(403).json({ success: false, error: 'Not authorized to update this post' })
    }

    const schema = z.object({
      title: z.string().max(200).optional(),
      content: z.string().min(1).max(5000).optional(),
      imageUrl: z.string().url().nullable().optional(),
      pollOptions: z
        .array(z.object({ id: z.string(), text: z.string(), voteCount: z.number().default(0) }))
        .nullable()
        .optional(),
      videoUrl: z.string().url().nullable().optional(),
      eventDate: z.string().datetime().nullable().optional(),
      eventLocation: z.string().max(500).nullable().optional(),
    })

    const body = schema.parse(req.body)

    const data: any = {}
    if (body.title !== undefined) data.title = body.title
    if (body.content !== undefined) data.content = body.content
    if (body.imageUrl !== undefined) data.imageUrl = body.imageUrl
    if (body.videoUrl !== undefined) data.videoUrl = body.videoUrl
    if (body.eventLocation !== undefined) data.eventLocation = body.eventLocation
    if (body.pollOptions !== undefined) data.pollOptions = body.pollOptions ?? undefined
    if (body.eventDate !== undefined) data.eventDate = body.eventDate ? new Date(body.eventDate) : null

    const updated = await prisma.post.update({
      where: { id },
      data,
      include: {
        author: { select: { id: true, name: true, picture: true } },
      },
    })

    res.json({
      success: true,
      post: {
        id: updated.id,
        groupId: updated.groupId,
        authorId: updated.authorId,
        authorName: (updated as any).author?.name || 'Unknown',
        authorAvatarUrl: (updated as any).author?.picture || null,
        type: updated.type,
        title: updated.title,
        content: updated.content,
        imageUrl: updated.imageUrl,
        pollOptions: updated.pollOptions,
        videoUrl: updated.videoUrl,
        eventDate: updated.eventDate?.toISOString() || null,
        eventLocation: updated.eventLocation,
        createdAt: updated.createdAt.toISOString(),
        updatedAt: updated.updatedAt.toISOString(),
      },
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating post:', error)
    res.status(500).json({ success: false, error: 'Failed to update post' })
  }
})

/**
 * @openapi
 * /api/posts/{id}:
 *   delete:
 *     tags: [Posts]
 *     summary: Delete a post
 *     description: |
 *       Soft deletes a post by setting isActive to false.
 *       Only the post author or the group creator can delete a post.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the post to delete
 *         example: "clx9876543210"
 *     responses:
 *       200:
 *         description: Post deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *             example:
 *               success: true
 *       403:
 *         description: Not authorized to delete this post
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Not authorized to delete this post"
 *       404:
 *         description: Post not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Post not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to delete post"
 */
router.delete('/posts/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    // Find post and verify ownership
    const post = await prisma.post.findFirst({
      where: { id },
      include: {
        group: {
          select: { creatorId: true },
        },
      },
    })

    if (!post) {
      return res.status(404).json({ success: false, error: 'Post not found' })
    }

    // Only author or group creator can delete
    if (post.authorId !== userId && post.group.creatorId !== userId) {
      return res.status(403).json({ success: false, error: 'Not authorized to delete this post' })
    }

    // Soft delete
    await prisma.post.update({
      where: { id },
      data: { isActive: false },
    })

    console.log(`🗑️ Deleted post ${id}`)

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting post:', error)
    res.status(500).json({ success: false, error: 'Failed to delete post' })
  }
})

export default router
