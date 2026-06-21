import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import {
  createDirectUploadUrl,
  getVideo as getCloudflareVideo,
  deleteVideo as deleteCloudflareVideo,
} from '../services/cloudflare.js'
import { trackActivity } from '../services/activity.js'
import { captureToLibrary, getUserOrgId, syncVideoStatus } from '../services/media-library.js'
import { deriveVideoMetadata } from '../services/media-metadata.js'
import { canManageOrgContent } from '../services/permission.js'

/**
 * The organization that owns a video, derived from its media-library entry.
 * Videos have no `organizationId` of their own — they're scoped to an org only
 * via the `Media` row created when the video is captured to the library. Returns
 * null if the video was never captured (e.g. uploaded before the user had an org).
 */
async function getVideoOrgId(videoId: string): Promise<string | null> {
  const entry = await prisma.media.findFirst({
    where: { videoId },
    select: { organizationId: true },
  })
  return entry?.organizationId ?? null
}

/**
 * @openapi
 * components:
 *   schemas:
 *     Video:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the video
 *           example: "clx9876543210"
 *         cloudflareUid:
 *           type: string
 *           description: Cloudflare Stream video UID
 *           example: "ea95132c15732412d22c1476fa83f27a"
 *         title:
 *           type: string
 *           nullable: true
 *           description: Video title
 *           example: "My Training Video"
 *         description:
 *           type: string
 *           nullable: true
 *           description: Video description
 *           example: "A detailed walkthrough of the training process"
 *         playbackUrl:
 *           type: string
 *           description: HLS playback URL for the video
 *           example: "https://customer-abc123.cloudflarestream.com/ea95132c15732412d22c1476fa83f27a/manifest/video.m3u8"
 *         thumbnailUrl:
 *           type: string
 *           nullable: true
 *           description: URL to the video thumbnail
 *           example: "https://customer-abc123.cloudflarestream.com/ea95132c15732412d22c1476fa83f27a/thumbnails/thumbnail.jpg"
 *         duration:
 *           type: integer
 *           nullable: true
 *           description: Video duration in seconds
 *           example: 120
 *         status:
 *           type: string
 *           enum: [pending, ready, error]
 *           description: Video processing status
 *           example: "ready"
 *         userId:
 *           type: string
 *           description: ID of the user who uploaded the video
 *           example: "usr123"
 *         isActive:
 *           type: boolean
 *           description: Whether the video is active
 *           example: true
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: When the video was created
 *           example: "2024-01-15T10:30:00.000Z"
 *         updatedAt:
 *           type: string
 *           format: date-time
 *           description: When the video was last updated
 *           example: "2024-01-15T10:30:00.000Z"
 *     VideoUploadUrl:
 *       type: object
 *       properties:
 *         uploadUrl:
 *           type: string
 *           description: Cloudflare direct upload URL (use with TUS protocol or form upload)
 *           example: "https://upload.cloudflarestream.com/tus/ea95132c15732412d22c1476fa83f27a"
 *         uid:
 *           type: string
 *           description: Cloudflare video UID to use when creating video record
 *           example: "ea95132c15732412d22c1476fa83f27a"
 */

const router = Router()

// ============================================================================
// Video Endpoints
// ============================================================================

/**
 * @openapi
 * /api/videos/upload-url:
 *   post:
 *     tags: [Videos]
 *     summary: Generate a direct upload URL for video uploads
 *     description: |
 *       Creates a direct upload URL for client-side video uploads to Cloudflare Stream.
 *       The client can upload directly to Cloudflare without going through the server.
 *
 *       **Upload Flow:**
 *       1. Call this endpoint to get an upload URL and UID
 *       2. Upload video file directly to the `uploadUrl` (supports TUS protocol)
 *       3. After upload completes, call `POST /api/videos` with the `cloudflareUid`
 *       4. Poll `POST /api/videos/:videoId/refresh` to check processing status
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               maxDurationSeconds:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 600
 *                 default: 300
 *                 description: Maximum allowed video duration in seconds (max 10 minutes)
 *                 example: 300
 *               title:
 *                 type: string
 *                 description: Optional title metadata stored with Cloudflare
 *                 example: "My Training Video"
 *     responses:
 *       200:
 *         description: Upload URL created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/VideoUploadUrl'
 *             example:
 *               success: true
 *               data:
 *                 uploadUrl: "https://upload.cloudflarestream.com/tus/ea95132c15732412d22c1476fa83f27a"
 *                 uid: "ea95132c15732412d22c1476fa83f27a"
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
 *                   type: string
 *                   example: "Number must be less than or equal to 600"
 *       401:
 *         description: User not authenticated
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
 *                   example: "User not authenticated"
 *       500:
 *         description: Failed to create upload URL
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
 *                   example: "Failed to create upload URL"
 */
const uploadUrlSchema = z.object({
  maxDurationSeconds: z.number().int().min(1).max(600).optional(), // Max 10 minutes
  title: z.string().optional(),
})

router.post('/upload-url', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not authenticated',
      })
    }

    // Validate request body
    const validation = uploadUrlSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const { maxDurationSeconds = 300, title } = validation.data

    // Create upload URL with optional metadata
    const result = await createDirectUploadUrl(maxDurationSeconds, {
      userId,
      ...(title && { title }),
    })

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error || 'Failed to create upload URL',
      })
    }

    res.json({
      success: true,
      data: {
        uploadUrl: result.uploadUrl,
        uid: result.uid,
      },
    })
  } catch (error) {
    console.error('Error creating upload URL:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/videos:
 *   post:
 *     tags: [Videos]
 *     summary: Create a video record after upload
 *     description: |
 *       Creates a video record in the database after the client has uploaded to Cloudflare.
 *       This should be called after the direct upload completes.
 *
 *       The endpoint will verify the video exists in Cloudflare and populate status,
 *       playback URL, thumbnail URL, and duration from Cloudflare's response.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - cloudflareUid
 *             properties:
 *               cloudflareUid:
 *                 type: string
 *                 description: Cloudflare video UID from the upload URL response
 *                 example: "ea95132c15732412d22c1476fa83f27a"
 *               title:
 *                 type: string
 *                 description: Video title
 *                 example: "My Training Video"
 *               description:
 *                 type: string
 *                 description: Video description
 *                 example: "A detailed walkthrough of the training process"
 *     responses:
 *       201:
 *         description: Video record created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Video'
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
 *                   type: string
 *                   example: "Cloudflare UID is required"
 *       401:
 *         description: User not authenticated
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
 *                   example: "User not authenticated"
 *       409:
 *         description: Video already exists
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
 *                   example: "Video already exists"
 *       500:
 *         description: Internal server error
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
 *                   example: "Internal server error"
 */
const createVideoSchema = z.object({
  cloudflareUid: z.string().min(1, 'Cloudflare UID is required'),
  title: z.string().optional(),
  description: z.string().optional(),
})

router.post('/', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not authenticated',
      })
    }

    // Validate request body
    const validation = createVideoSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const { cloudflareUid, title, description } = validation.data

    // Check if video already exists
    const existingVideo = await prisma.video.findUnique({
      where: { cloudflareUid },
    })

    if (existingVideo) {
      return res.status(409).json({
        success: false,
        error: 'Video already exists',
      })
    }

    // Get video details from Cloudflare to verify it exists and get status
    const cloudflareResult = await getCloudflareVideo(cloudflareUid)

    // Determine status and URLs
    let status = 'pending'
    let playbackUrl = '' // Will be populated when video is ready
    let thumbnailUrl: string | null = null
    let duration: number | null = null

    if (cloudflareResult.success && cloudflareResult.video) {
      const cfVideo = cloudflareResult.video

      // Map Cloudflare status to our status
      if (cfVideo.status.state === 'ready') {
        status = 'ready'
        duration = cfVideo.duration ? Math.round(cfVideo.duration) : null
        // Use Cloudflare's actual URLs (includes correct customer subdomain)
        thumbnailUrl = cfVideo.thumbnail || null
        playbackUrl = cfVideo.playback?.hls || ''
      } else if (cfVideo.status.state === 'error') {
        status = 'error'
      } else {
        status = 'pending'
      }
    }

    // Create video record
    const video = await prisma.video.create({
      data: {
        cloudflareUid,
        title,
        description,
        playbackUrl,
        thumbnailUrl,
        duration,
        status,
        userId,
      },
    })

    trackActivity({
      actorId: userId,
      action: 'CREATED',
      resourceType: 'VIDEO',
      resourceId: video.id,
      resourceName: video.title || 'Untitled video',
    })

    // Auto-capture to media library with video metadata
    const orgId = await getUserOrgId(userId)
    if (orgId) {
      const cfInput = cloudflareResult.video?.input
      const videoMeta = deriveVideoMetadata({ width: cfInput?.width, height: cfInput?.height })
      captureToLibrary({
        title: video.title || 'Untitled video',
        url: video.playbackUrl || '',
        type: 'video',
        mimeType: 'video/mp4',
        thumbnailUrl: video.thumbnailUrl ?? undefined,
        organizationId: orgId,
        uploadedBy: userId,
        videoId: video.id,
        source: 'auto_capture',
        uploadStatus: video.status === 'ready' ? 'ready' : 'pending',
        duration: video.duration ?? undefined,
        ...videoMeta,
      })
    }

    res.status(201).json({
      success: true,
      data: video,
    })
  } catch (error) {
    console.error('Error creating video:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/videos/me:
 *   get:
 *     tags: [Videos]
 *     summary: Get all videos for the authenticated user
 *     description: |
 *       Returns all active videos uploaded by the authenticated user.
 *       Results are ordered by creation date (newest first).
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of user's videos
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
 *                     $ref: '#/components/schemas/Video'
 *                 count:
 *                   type: integer
 *                   description: Total number of videos
 *                   example: 5
 *             example:
 *               success: true
 *               data:
 *                 - id: "clx9876543210"
 *                   cloudflareUid: "ea95132c15732412d22c1476fa83f27a"
 *                   title: "My Training Video"
 *                   status: "ready"
 *                   duration: 120
 *                   createdAt: "2024-01-15T10:30:00.000Z"
 *               count: 1
 *       401:
 *         description: User not authenticated
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
 *                   example: "User not authenticated"
 *       500:
 *         description: Internal server error
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
 *                   example: "Internal server error"
 */
router.get('/me', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not authenticated',
      })
    }

    const videos = await prisma.video.findMany({
      where: {
        userId,
        isActive: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    })

    res.json({
      success: true,
      data: videos,
      count: videos.length,
    })
  } catch (error) {
    console.error('Error fetching videos:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/videos/{videoId}:
 *   get:
 *     tags: [Videos]
 *     summary: Get a specific video by ID
 *     description: |
 *       Returns details for a specific video.
 *       Only the video owner can view their videos.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: videoId
 *         required: true
 *         schema:
 *           type: string
 *         description: The video ID
 *         example: "clx9876543210"
 *     responses:
 *       200:
 *         description: Video details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Video'
 *       401:
 *         description: User not authenticated
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
 *                   example: "User not authenticated"
 *       403:
 *         description: Not authorized to view this video
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
 *                   example: "Not authorized to view this video"
 *       404:
 *         description: Video not found
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
 *                   example: "Video not found"
 *       500:
 *         description: Internal server error
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
 *                   example: "Internal server error"
 */
router.get('/:videoId', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const { videoId } = req.params

    const video = await prisma.video.findUnique({
      where: { id: videoId },
    })

    if (!video) {
      return res.status(404).json({
        success: false,
        error: 'Video not found',
      })
    }

    // The uploader, or anyone who can manage the owning org's content (org
    // owner / role-holder / super admin), may view the video. Without this,
    // a group leader couldn't preview a video used in their org's program.
    if (video.userId !== userId) {
      const orgId = await getVideoOrgId(video.id)
      if (!(await canManageOrgContent(userId, orgId, video.userId))) {
        return res.status(403).json({
          success: false,
          error: 'Not authorized to view this video',
        })
      }
    }

    res.json({
      success: true,
      data: video,
    })
  } catch (error) {
    console.error('Error fetching video:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/videos/{videoId}:
 *   patch:
 *     tags: [Videos]
 *     summary: Update video metadata
 *     description: |
 *       Updates the title and/or description of a video.
 *       Only the video owner can update their videos.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: videoId
 *         required: true
 *         schema:
 *           type: string
 *         description: The video ID
 *         example: "clx9876543210"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 description: New video title
 *                 example: "Updated Training Video"
 *               description:
 *                 type: string
 *                 description: New video description
 *                 example: "Updated description with more details"
 *     responses:
 *       200:
 *         description: Video updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Video'
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
 *                   type: string
 *                   example: "Invalid request body"
 *       401:
 *         description: User not authenticated
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
 *                   example: "User not authenticated"
 *       403:
 *         description: Not authorized to update this video
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
 *                   example: "Not authorized to update this video"
 *       404:
 *         description: Video not found
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
 *                   example: "Video not found"
 *       500:
 *         description: Internal server error
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
 *                   example: "Internal server error"
 */
const updateVideoSchema = z.object({
  title: z.string().optional(),
  description: z.string().optional(),
})

router.patch('/:videoId', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const { videoId } = req.params

    // Validate request body
    const validation = updateVideoSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const video = await prisma.video.findUnique({
      where: { id: videoId },
    })

    if (!video) {
      return res.status(404).json({
        success: false,
        error: 'Video not found',
      })
    }

    // The uploader, or anyone who can manage the owning org's content, may edit.
    if (video.userId !== userId) {
      const orgId = await getVideoOrgId(video.id)
      if (!(await canManageOrgContent(userId, orgId, video.userId))) {
        return res.status(403).json({
          success: false,
          error: 'Not authorized to update this video',
        })
      }
    }

    const { title, description } = validation.data

    const updatedVideo = await prisma.video.update({
      where: { id: videoId },
      data: {
        ...(title !== undefined && { title }),
        ...(description !== undefined && { description }),
      },
    })

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'VIDEO',
      resourceId: videoId,
      resourceName: updatedVideo.title || 'Untitled video',
    })

    res.json({
      success: true,
      data: updatedVideo,
    })
  } catch (error) {
    console.error('Error updating video:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/videos/{videoId}/refresh:
 *   post:
 *     tags: [Videos]
 *     summary: Refresh video status from Cloudflare
 *     description: |
 *       Fetches the latest video status from Cloudflare and updates the database record.
 *       Use this to check if video processing is complete after upload.
 *
 *       **Polling Strategy:**
 *       - Call this endpoint every 5-10 seconds after creating a video
 *       - Stop polling when status changes from "pending" to "ready" or "error"
 *       - When status is "ready", playbackUrl, thumbnailUrl, and duration will be populated
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: videoId
 *         required: true
 *         schema:
 *           type: string
 *         description: The video ID
 *         example: "clx9876543210"
 *     responses:
 *       200:
 *         description: Video status refreshed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Video'
 *             example:
 *               success: true
 *               data:
 *                 id: "clx9876543210"
 *                 cloudflareUid: "ea95132c15732412d22c1476fa83f27a"
 *                 title: "My Training Video"
 *                 status: "ready"
 *                 playbackUrl: "https://customer-abc123.cloudflarestream.com/ea95132c15732412d22c1476fa83f27a/manifest/video.m3u8"
 *                 thumbnailUrl: "https://customer-abc123.cloudflarestream.com/ea95132c15732412d22c1476fa83f27a/thumbnails/thumbnail.jpg"
 *                 duration: 120
 *       401:
 *         description: User not authenticated
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
 *                   example: "User not authenticated"
 *       403:
 *         description: Not authorized to access this video
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
 *                   example: "Not authorized to access this video"
 *       404:
 *         description: Video not found
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
 *                   example: "Video not found"
 *       500:
 *         description: Failed to get video status from Cloudflare
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
 *                   example: "Failed to get video status"
 */
router.post('/:videoId/refresh', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const { videoId } = req.params

    const video = await prisma.video.findUnique({
      where: { id: videoId },
    })

    if (!video) {
      return res.status(404).json({
        success: false,
        error: 'Video not found',
      })
    }

    if (video.userId !== userId) {
      const orgId = await getVideoOrgId(video.id)
      if (!(await canManageOrgContent(userId, orgId, video.userId))) {
        return res.status(403).json({
          success: false,
          error: 'Not authorized to access this video',
        })
      }
    }

    // Get latest status from Cloudflare
    const cloudflareResult = await getCloudflareVideo(video.cloudflareUid)

    if (!cloudflareResult.success) {
      return res.status(500).json({
        success: false,
        error: cloudflareResult.error || 'Failed to get video status',
      })
    }

    const cfVideo = cloudflareResult.video!

    // Update status and URLs based on Cloudflare response
    let status = video.status
    let playbackUrl = video.playbackUrl
    let thumbnailUrl = video.thumbnailUrl
    let duration = video.duration

    if (cfVideo.status.state === 'ready') {
      status = 'ready'
      duration = cfVideo.duration ? Math.round(cfVideo.duration) : null
      // Use Cloudflare's actual URLs (includes correct customer subdomain)
      thumbnailUrl = cfVideo.thumbnail || null
      playbackUrl = cfVideo.playback?.hls || video.playbackUrl
    } else if (cfVideo.status.state === 'error') {
      status = 'error'
    }

    const updatedVideo = await prisma.video.update({
      where: { id: videoId },
      data: {
        status,
        playbackUrl,
        thumbnailUrl,
        duration,
      },
    })

    // Sync status change to media library
    if (status !== video.status) {
      const videoMeta = deriveVideoMetadata({ width: cfVideo.input?.width, height: cfVideo.input?.height })
      syncVideoStatus(videoId, status, playbackUrl, thumbnailUrl ?? undefined, duration ?? undefined, videoMeta)
    }

    res.json({
      success: true,
      data: updatedVideo,
    })
  } catch (error) {
    console.error('Error refreshing video status:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/videos/{videoId}:
 *   delete:
 *     tags: [Videos]
 *     summary: Delete a video
 *     description: |
 *       Deletes a video from both the database and Cloudflare Stream.
 *       Only the video owner can delete their videos.
 *
 *       **Note:** If deletion from Cloudflare fails (e.g., video already deleted),
 *       the database record will still be deleted to maintain consistency.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: videoId
 *         required: true
 *         schema:
 *           type: string
 *         description: The video ID
 *         example: "clx9876543210"
 *     responses:
 *       200:
 *         description: Video deleted successfully
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
 *                   example: "Video deleted successfully"
 *       401:
 *         description: User not authenticated
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
 *                   example: "User not authenticated"
 *       403:
 *         description: Not authorized to delete this video
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
 *                   example: "Not authorized to delete this video"
 *       404:
 *         description: Video not found
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
 *                   example: "Video not found"
 *       500:
 *         description: Internal server error
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
 *                   example: "Internal server error"
 */
router.delete('/:videoId', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const { videoId } = req.params

    const video = await prisma.video.findUnique({
      where: { id: videoId },
    })

    if (!video) {
      return res.status(404).json({
        success: false,
        error: 'Video not found',
      })
    }

    // The uploader, or anyone who can manage the owning org's content, may delete.
    if (video.userId !== userId) {
      const orgId = await getVideoOrgId(video.id)
      if (!(await canManageOrgContent(userId, orgId, video.userId))) {
        return res.status(403).json({
          success: false,
          error: 'Not authorized to delete this video',
        })
      }
    }

    // Delete from Cloudflare first
    const deleteResult = await deleteCloudflareVideo(video.cloudflareUid)

    if (!deleteResult.success) {
      console.warn(
        `[Videos] Failed to delete video from Cloudflare: ${deleteResult.error}. Proceeding with database deletion.`
      )
      // Continue with database deletion even if Cloudflare delete fails
      // The video might already be deleted from Cloudflare
    }

    // Delete from database
    await prisma.video.delete({
      where: { id: videoId },
    })

    trackActivity({
      actorId: userId,
      action: 'DELETED',
      resourceType: 'VIDEO',
      resourceId: videoId,
      resourceName: video.title || 'Untitled video',
    })

    res.json({
      success: true,
      message: 'Video deleted successfully',
    })
  } catch (error) {
    console.error('Error deleting video:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

export default router
