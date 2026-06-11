import { Router } from 'express'
import { z } from 'zod'
import sharp from 'sharp'
import { extractImageMetadata } from '../services/media-metadata.js'
import {
  createMedia,
  getMedia,
  listMedia,
  updateMedia,
  deleteMedia,
} from '../services/content.js'
import {
  requireAuth,
  requirePermission,
  requireModifyPermission,
} from '../middleware/auth.js'
import {
  listLibrary,
  getLibraryItem,
  addTags,
  removeTags,
  listUsages,
  enrichMediaWithAI,
  getUserOrgId,
} from '../services/media-library.js'
import { prisma } from '../lib/prisma.js'
import { uploadImageVariants } from '../services/storage.js'
import { createDirectUploadUrl } from '../services/cloudflare.js'

const router = Router()

// ============================================================================
// Media CRUD Endpoints
// ============================================================================

/**
 * @openapi
 * /api/organizations/{organizationId}/media:
 *   get:
 *     summary: List all media for an organization
 *     description: Retrieves a list of all media items belonging to the specified organization. Supports filtering by group, visibility, and active status.
 *     tags:
 *       - Media
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the organization
 *         example: "org_abc123"
 *       - in: query
 *         name: groupId
 *         schema:
 *           type: string
 *         description: Filter media by group ID
 *         example: "grp_xyz789"
 *       - in: query
 *         name: visibility
 *         schema:
 *           type: string
 *           enum: [public, members, group]
 *         description: Filter media by visibility level
 *         example: "public"
 *       - in: query
 *         name: isActive
 *         schema:
 *           type: string
 *           enum: ["true", "false"]
 *         description: Filter by active status
 *         example: "true"
 *     responses:
 *       200:
 *         description: Successfully retrieved media list
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
 *                         example: "media_abc123"
 *                       title:
 *                         type: string
 *                         example: "Training Video"
 *                       description:
 *                         type: string
 *                         example: "Introduction to safety procedures"
 *                       url:
 *                         type: string
 *                         example: "https://storage.example.com/media/video.mp4"
 *                       type:
 *                         type: string
 *                         enum: [photo, video, document]
 *                         example: "video"
 *                       mimeType:
 *                         type: string
 *                         example: "video/mp4"
 *                       fileSize:
 *                         type: integer
 *                         example: 15728640
 *                       visibility:
 *                         type: string
 *                         enum: [public, members, group]
 *                         example: "members"
 *                       isActive:
 *                         type: boolean
 *                         example: true
 *                       organizationId:
 *                         type: string
 *                         example: "org_abc123"
 *                       groupId:
 *                         type: string
 *                         nullable: true
 *                         example: "grp_xyz789"
 *                       uploadedBy:
 *                         type: string
 *                         example: "usr_def456"
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       updatedAt:
 *                         type: string
 *                         format: date-time
 *                 count:
 *                   type: integer
 *                   example: 5
 *       401:
 *         description: Authentication required
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
 *                   example: "Authentication required"
 *       403:
 *         description: Insufficient permissions
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
 *                   example: "Permission denied: media.read required"
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
router.get(
  '/organizations/:organizationId/media',
  requireAuth,
  requirePermission('media.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const { groupId, visibility, isActive } = req.query

      const result = await listMedia({
        organizationId,
        ...(groupId && { groupId: groupId as string }),
        ...(visibility && { visibility: visibility as any }),
        ...(isActive !== undefined && { isActive: isActive === 'true' }),
      })

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        count: result.data?.length || 0,
      })
    } catch (error) {
      console.error('Error listing media:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/media/tags:
 *   get:
 *     tags: [Media Library]
 *     summary: List distinct media tags in the user's org with usage counts.
 *     description: Parallel to /api/programs/tags. Drives the Library Media tab tags dropdown.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of tags with usage counts
 */
// NOTE: Must be registered BEFORE `/media/:mediaId` so Express doesn't match
// "tags" as a mediaId param.
router.get('/media/tags', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    // No org context → empty list. The library list endpoint is org-scoped via
    // requirePermission, so a user without an org also has no media to tag.
    if (!userOrgId) {
      return res.json({ success: true, tags: [] })
    }

    const tags = await prisma.mediaTag.groupBy({
      by: ['tag'],
      where: {
        media: {
          isActive: true,
          organizationId: userOrgId,
        },
      },
      _count: { tag: true },
      orderBy: { _count: { tag: 'desc' } },
    })

    res.json({
      success: true,
      tags: tags.map((t) => ({ tag: t.tag, count: t._count.tag })),
    })
  } catch (error) {
    console.error('Error fetching all media tags:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /api/media/{mediaId}:
 *   get:
 *     summary: Get media details
 *     description: Retrieves detailed information about a specific media item by its ID.
 *     tags:
 *       - Media
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the media item
 *         example: "media_abc123"
 *     responses:
 *       200:
 *         description: Successfully retrieved media details
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
 *                     id:
 *                       type: string
 *                       example: "media_abc123"
 *                     title:
 *                       type: string
 *                       example: "Training Video"
 *                     description:
 *                       type: string
 *                       example: "Introduction to safety procedures"
 *                     url:
 *                       type: string
 *                       example: "https://storage.example.com/media/video.mp4"
 *                     type:
 *                       type: string
 *                       enum: [photo, video, document]
 *                       example: "video"
 *                     mimeType:
 *                       type: string
 *                       example: "video/mp4"
 *                     fileSize:
 *                       type: integer
 *                       example: 15728640
 *                     visibility:
 *                       type: string
 *                       enum: [public, members, group]
 *                       example: "members"
 *                     isActive:
 *                       type: boolean
 *                       example: true
 *                     organizationId:
 *                       type: string
 *                       example: "org_abc123"
 *                     groupId:
 *                       type: string
 *                       nullable: true
 *                       example: "grp_xyz789"
 *                     uploadedBy:
 *                       type: string
 *                       example: "usr_def456"
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
 *       401:
 *         description: Authentication required
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
 *                   example: "Authentication required"
 *       403:
 *         description: Insufficient permissions
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
 *                   example: "Permission denied: media.read required"
 *       404:
 *         description: Media not found
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
 *                   example: "Media not found"
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
router.get(
  '/media/:mediaId',
  requireAuth,
  requirePermission('media.read', 'media', (req) => req.params.mediaId),
  async (req, res) => {
    try {
      const { mediaId } = req.params

      const result = await getMedia(mediaId)

      if (!result.success) {
        return res.status(404).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error fetching media:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/media:
 *   post:
 *     summary: Create a new media record
 *     description: Creates a new media record in the specified organization. The media file should be uploaded separately, and the URL provided in the request body.
 *     tags:
 *       - Media
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the organization
 *         example: "org_abc123"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - url
 *               - type
 *             properties:
 *               title:
 *                 type: string
 *                 minLength: 1
 *                 description: The title of the media item
 *                 example: "Safety Training Video"
 *               description:
 *                 type: string
 *                 description: A description of the media item
 *                 example: "Comprehensive safety training for new employees"
 *               url:
 *                 type: string
 *                 format: uri
 *                 description: The URL where the media file is hosted
 *                 example: "https://storage.example.com/media/safety-training.mp4"
 *               type:
 *                 type: string
 *                 enum: [photo, video, document]
 *                 description: The type of media
 *                 example: "video"
 *               mimeType:
 *                 type: string
 *                 description: The MIME type of the file
 *                 example: "video/mp4"
 *               fileSize:
 *                 type: integer
 *                 minimum: 1
 *                 description: The size of the file in bytes
 *                 example: 15728640
 *               groupId:
 *                 type: string
 *                 description: Optional group ID to associate the media with
 *                 example: "grp_xyz789"
 *               visibility:
 *                 type: string
 *                 enum: [public, members, group]
 *                 description: The visibility level of the media
 *                 example: "members"
 *     responses:
 *       201:
 *         description: Media created successfully
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
 *                     id:
 *                       type: string
 *                       example: "media_abc123"
 *                     title:
 *                       type: string
 *                       example: "Safety Training Video"
 *                     description:
 *                       type: string
 *                       example: "Comprehensive safety training for new employees"
 *                     url:
 *                       type: string
 *                       example: "https://storage.example.com/media/safety-training.mp4"
 *                     type:
 *                       type: string
 *                       example: "video"
 *                     mimeType:
 *                       type: string
 *                       example: "video/mp4"
 *                     fileSize:
 *                       type: integer
 *                       example: 15728640
 *                     visibility:
 *                       type: string
 *                       example: "members"
 *                     isActive:
 *                       type: boolean
 *                       example: true
 *                     organizationId:
 *                       type: string
 *                       example: "org_abc123"
 *                     groupId:
 *                       type: string
 *                       nullable: true
 *                       example: "grp_xyz789"
 *                     uploadedBy:
 *                       type: string
 *                       example: "usr_def456"
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
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
 *                   example: "Media title is required"
 *       401:
 *         description: Authentication required
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
 *                   example: "Authentication required"
 *       403:
 *         description: Insufficient permissions
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
 *                   example: "Permission denied: media.create required"
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
const createMediaSchema = z.object({
  title: z.string().min(1, 'Media title is required'),
  description: z.string().optional(),
  url: z.string().url('Invalid URL format'),
  type: z.enum(['photo', 'video', 'document'], {
    errorMap: () => ({ message: 'Type must be photo, video, or document' }),
  }),
  mimeType: z.string().optional(),
  fileSize: z.number().int().positive().optional(),
  groupId: z.string().optional(),
  visibility: z.enum(['public', 'members', 'group']).optional(),
})

router.post(
  '/organizations/:organizationId/media',
  requireAuth,
  requirePermission('media.create', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const userId = (req.user as any)?.id

      // Validate request body
      const validation = createMediaSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { title, description, url, type, mimeType, fileSize, groupId, visibility } =
        validation.data

      const result = await createMedia({
        title,
        description,
        url,
        type,
        mimeType,
        fileSize,
        organizationId,
        groupId,
        uploadedBy: userId,
        visibility,
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
      console.error('Error creating media:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/media/{mediaId}:
 *   patch:
 *     summary: Update media metadata
 *     description: Updates the metadata of an existing media item. Only the uploader or users with 'media.update' permission can modify media.
 *     tags:
 *       - Media
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the media item
 *         example: "media_abc123"
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
 *                 description: Updated title for the media item
 *                 example: "Updated Safety Training Video"
 *               description:
 *                 type: string
 *                 description: Updated description for the media item
 *                 example: "Revised safety training content for 2024"
 *               visibility:
 *                 type: string
 *                 enum: [public, members, group]
 *                 description: Updated visibility level
 *                 example: "public"
 *               isActive:
 *                 type: boolean
 *                 description: Whether the media item is active
 *                 example: true
 *     responses:
 *       200:
 *         description: Media updated successfully
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
 *                     id:
 *                       type: string
 *                       example: "media_abc123"
 *                     title:
 *                       type: string
 *                       example: "Updated Safety Training Video"
 *                     description:
 *                       type: string
 *                       example: "Revised safety training content for 2024"
 *                     url:
 *                       type: string
 *                       example: "https://storage.example.com/media/safety-training.mp4"
 *                     type:
 *                       type: string
 *                       example: "video"
 *                     mimeType:
 *                       type: string
 *                       example: "video/mp4"
 *                     fileSize:
 *                       type: integer
 *                       example: 15728640
 *                     visibility:
 *                       type: string
 *                       example: "public"
 *                     isActive:
 *                       type: boolean
 *                       example: true
 *                     organizationId:
 *                       type: string
 *                       example: "org_abc123"
 *                     groupId:
 *                       type: string
 *                       nullable: true
 *                       example: "grp_xyz789"
 *                     uploadedBy:
 *                       type: string
 *                       example: "usr_def456"
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
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
 *         description: Authentication required
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
 *                   example: "Authentication required"
 *       403:
 *         description: Insufficient permissions
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
 *                   example: "Permission denied: media.update required or must be uploader"
 *       404:
 *         description: Media not found
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
 *                   example: "Media not found"
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
const updateMediaSchema = z.object({
  title: z.string().min(1).optional(),
  description: z.string().optional(),
  visibility: z.enum(['public', 'members', 'group']).optional(),
  isActive: z.boolean().optional(),
})

router.patch(
  '/media/:mediaId',
  requireAuth,
  requireModifyPermission('media', (req) => req.params.mediaId),
  async (req, res) => {
    try {
      const { mediaId } = req.params

      // Validate request body
      const validation = updateMediaSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { title, description, visibility, isActive } = validation.data

      const result = await updateMedia(mediaId, {
        title,
        description,
        visibility,
        isActive,
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
      console.error('Error updating media:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/media/{mediaId}:
 *   delete:
 *     summary: Delete media
 *     description: Permanently deletes a media item. This action cannot be undone. Requires 'media.delete' permission.
 *     tags:
 *       - Media
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the media item to delete
 *         example: "media_abc123"
 *     responses:
 *       200:
 *         description: Media deleted successfully
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
 *                     id:
 *                       type: string
 *                       example: "media_abc123"
 *                     title:
 *                       type: string
 *                       example: "Safety Training Video"
 *                     deleted:
 *                       type: boolean
 *                       example: true
 *       400:
 *         description: Failed to delete media
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
 *                   example: "Failed to delete media"
 *       401:
 *         description: Authentication required
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
 *                   example: "Authentication required"
 *       403:
 *         description: Insufficient permissions
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
 *                   example: "Permission denied: media.delete required"
 *       404:
 *         description: Media not found
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
 *                   example: "Media not found"
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
router.delete(
  '/media/:mediaId',
  requireAuth,
  requirePermission('media.delete', 'media', (req) => req.params.mediaId),
  async (req, res) => {
    try {
      const { mediaId } = req.params

      const result = await deleteMedia(mediaId)

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
      console.error('Error deleting media:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

// ============================================================================
// Media Library Endpoints
// ============================================================================

/**
 * @openapi
 * /api/organizations/{organizationId}/media/library:
 *   get:
 *     summary: Browse the media library
 *     description: Full library view with tags, usages, pagination, search, and creator filtering.
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: uploadedBy
 *         schema:
 *           type: string
 *         description: '"me" for current user, or a specific userId'
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [photo, video, document]
 *       - in: query
 *         name: tags
 *         schema:
 *           type: string
 *         description: Comma-separated tags to filter by
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Text search on title/description
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Offset paging (deprecated for deep paging — prefer cursor)
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *         description: |
 *           Opaque keyset cursor from a previous response's `nextCursor`.
 *           When set, `page` is ignored; the response carries exact `hasMore`
 *           and `nextCursor` and omits `total` (use the total from your
 *           initial page-mode request). Stays flat at any depth.
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *     responses:
 *       200:
 *         description: Paginated library results (page mode includes total/totalPages; both modes include hasMore/nextCursor)
 */
router.get(
  '/organizations/:organizationId/media/library',
  requireAuth,
  requirePermission('media.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const userId = (req.user as any)?.id
      const { uploadedBy, leaders, type, tags, search, q, page, limit, cursor } = req.query

      const resolvedUploadedBy = uploadedBy === 'me' ? userId : (uploadedBy as string | undefined)
      const tagList = tags ? (tags as string).split(',').map((t) => t.trim()).filter(Boolean) : undefined
      const leaderList = leaders ? (leaders as string).split(',').map((id) => id.trim()).filter(Boolean) : undefined

      const result = await listLibrary({
        organizationId,
        uploadedBy: resolvedUploadedBy,
        uploadedByIn: leaderList,
        type: type as string | undefined,
        tags: tagList,
        search: search as string | undefined,
        q: q as string | undefined,
        page: page ? parseInt(page as string, 10) : undefined,
        limit: limit ? parseInt(limit as string, 10) : undefined,
        cursor: cursor as string | undefined,
      })

      res.json({ success: true, ...result })
    } catch (error) {
      console.error('Error listing media library:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/media/upload:
 *   post:
 *     summary: Upload media directly to the library
 *     description: |
 *       For images: accepts base64 data, processes with sharp, uploads to R2, creates library entry.
 *       For videos: returns a Cloudflare TUS upload URL and creates a pending library entry.
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [title, type]
 *             properties:
 *               title:
 *                 type: string
 *               description:
 *                 type: string
 *               type:
 *                 type: string
 *                 enum: [photo, video]
 *               imageData:
 *                 type: string
 *                 description: Base64 image data (required for photos)
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *               maxDurationSeconds:
 *                 type: integer
 *                 description: Max video duration in seconds (for videos only)
 *     responses:
 *       201:
 *         description: Media created/upload initiated
 */
const uploadMediaSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  description: z.string().optional(),
  type: z.enum(['photo', 'video']),
  imageData: z.string().optional(),
  tags: z.array(z.string()).optional(),
  maxDurationSeconds: z.number().int().min(1).max(600).optional(),
})

router.post(
  '/organizations/:organizationId/media/upload',
  requireAuth,
  requirePermission('media.create', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const userId = (req.user as any)?.id

      const validation = uploadMediaSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({ success: false, error: validation.error.errors[0].message })
      }

      const { title, description, type, imageData, tags: tagList, maxDurationSeconds } = validation.data

      if (type === 'photo') {
        if (!imageData) {
          return res.status(400).json({ success: false, error: 'imageData is required for photo uploads' })
        }

        const base64Data = imageData.replace(/^data:image\/\w+;base64,/, '')
        const imageBuffer = Buffer.from(base64Data, 'base64')

        const timestamp = Date.now()
        const baseName = `library-${userId}-${timestamp}`
        const extension = 'jpeg'

        const [originalBuffer, mediumBuffer, thumbBuffer] = await Promise.all([
          sharp(imageBuffer).resize(1200, null, { withoutEnlargement: true }).jpeg({ quality: 85 }).toBuffer(),
          sharp(imageBuffer).resize(400, null, { withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer(),
          sharp(imageBuffer).resize(150, null, { withoutEnlargement: true }).jpeg({ quality: 75 }).toBuffer(),
        ])

        const [{ url }, imageMeta] = await Promise.all([
          uploadImageVariants('library', baseName, extension, originalBuffer, mediumBuffer, thumbBuffer),
          extractImageMetadata(imageBuffer),
        ])
        const thumbnailUrl = url.replace('.jpeg', '-thumb.jpeg')

        const media = await prisma.media.create({
          data: {
            title,
            description: description ?? undefined,
            url,
            type: 'photo',
            mimeType: 'image/jpeg',
            fileSize: originalBuffer.length,
            thumbnailUrl,
            organizationId,
            uploadedBy: userId,
            source: 'direct',
            uploadStatus: 'ready',
            visibility: 'members',
            width: imageMeta.width,
            height: imageMeta.height,
            aspectRatio: imageMeta.aspectRatio,
            dominantColor: imageMeta.dominantColor,
            fileHash: imageMeta.fileHash,
            exifData: (imageMeta.exifData as any) ?? undefined,
          },
          include: {
            uploader: { select: { id: true, name: true, email: true } },
          },
        })

        if (tagList && tagList.length > 0) {
          await addTags(media.id, tagList)
        }

        // Fire-and-forget AI enrichment
        enrichMediaWithAI(media.id, url, { title })

        return res.status(201).json({ success: true, data: media })
      }

      if (type === 'video') {
        const uploadResult = await createDirectUploadUrl(maxDurationSeconds || 300, {
          userId,
          title,
        })

        if (!uploadResult.success) {
          return res.status(500).json({ success: false, error: 'Failed to create video upload URL' })
        }

        // Create video record
        const video = await prisma.video.create({
          data: {
            cloudflareUid: uploadResult.uid!,
            title,
            description: description ?? undefined,
            playbackUrl: '',
            status: 'pending',
            userId,
          },
        })

        // Create pending media library entry
        const media = await prisma.media.create({
          data: {
            title,
            description: description ?? undefined,
            url: '',
            type: 'video',
            mimeType: 'video/mp4',
            organizationId,
            uploadedBy: userId,
            videoId: video.id,
            source: 'direct',
            uploadStatus: 'pending',
            visibility: 'members',
          },
          include: {
            uploader: { select: { id: true, name: true, email: true } },
          },
        })

        if (tagList && tagList.length > 0) {
          await addTags(media.id, tagList)
        }

        return res.status(201).json({
          success: true,
          data: {
            media,
            uploadUrl: uploadResult.uploadUrl,
            videoId: video.id,
            cloudflareUid: uploadResult.uid,
          },
        })
      }
    } catch (error) {
      console.error('Error uploading media:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/media/upload/batch:
 *   post:
 *     summary: Batch create media library entries
 *     description: Creates multiple media records at once. Returns IDs for status polling.
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [items]
 *             properties:
 *               items:
 *                 type: array
 *                 items:
 *                   type: object
 *                   required: [title, url, type]
 *                   properties:
 *                     title:
 *                       type: string
 *                     url:
 *                       type: string
 *                     type:
 *                       type: string
 *                       enum: [photo, video, document]
 *                     mimeType:
 *                       type: string
 *                     fileSize:
 *                       type: integer
 *                     tags:
 *                       type: array
 *                       items:
 *                         type: string
 *     responses:
 *       201:
 *         description: Batch created
 */
const batchItemSchema = z.object({
  title: z.string().min(1),
  url: z.string().url(),
  type: z.enum(['photo', 'video', 'document']),
  mimeType: z.string().optional(),
  fileSize: z.number().int().positive().optional(),
  description: z.string().optional(),
  tags: z.array(z.string()).optional(),
  thumbnailUrl: z.string().optional(),
  videoId: z.string().optional(),
})

const batchUploadSchema = z.object({
  items: z.array(batchItemSchema).min(1).max(50),
})

router.post(
  '/organizations/:organizationId/media/upload/batch',
  requireAuth,
  requirePermission('media.create', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const userId = (req.user as any)?.id

      const validation = batchUploadSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({ success: false, error: validation.error.errors[0].message })
      }

      const results = await prisma.$transaction(
        validation.data.items.map((item) =>
          prisma.media.create({
            data: {
              title: item.title,
              description: item.description ?? undefined,
              url: item.url,
              type: item.type,
              mimeType: item.mimeType ?? undefined,
              fileSize: item.fileSize ?? undefined,
              thumbnailUrl: item.thumbnailUrl ?? undefined,
              videoId: item.videoId ?? undefined,
              organizationId,
              uploadedBy: userId,
              source: 'direct',
              uploadStatus: 'ready',
              visibility: 'members',
            },
          })
        )
      )

      // Add tags and AI enrichment in background (fire-and-forget)
      for (let i = 0; i < validation.data.items.length; i++) {
        const item = validation.data.items[i]
        const media = results[i]
        if (item.tags && item.tags.length > 0) {
          addTags(media.id, item.tags).catch((err) =>
            console.error('Failed to add batch tags:', err)
          )
        }
        if (item.type === 'photo' && item.url) {
          enrichMediaWithAI(media.id, item.url, { title: item.title })
        }
      }

      res.status(201).json({
        success: true,
        data: results.map((m) => ({ id: m.id, title: m.title, uploadStatus: m.uploadStatus })),
        count: results.length,
      })
    } catch (error) {
      console.error('Error batch creating media:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

// ============================================================================
// Tag Management Endpoints
// ============================================================================

/**
 * @openapi
 * /api/media/{mediaId}/tags:
 *   post:
 *     summary: Add tags to media
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [tags]
 *             properties:
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Tags added
 */
router.post(
  '/media/:mediaId/tags',
  requireAuth,
  requireModifyPermission('media', (req) => req.params.mediaId),
  async (req, res) => {
    try {
      const { mediaId } = req.params
      const { tags } = z.object({ tags: z.array(z.string()).min(1) }).parse(req.body)

      await addTags(mediaId, tags)

      const item = await getLibraryItem(mediaId)
      res.json({ success: true, data: item })
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: error.errors[0].message })
      }
      console.error('Error adding tags:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/media/{mediaId}/tags:
 *   delete:
 *     summary: Remove tags from media
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [tags]
 *             properties:
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Tags removed
 */
router.delete(
  '/media/:mediaId/tags',
  requireAuth,
  requireModifyPermission('media', (req) => req.params.mediaId),
  async (req, res) => {
    try {
      const { mediaId } = req.params
      const { tags } = z.object({ tags: z.array(z.string()).min(1) }).parse(req.body)

      await removeTags(mediaId, tags)

      const item = await getLibraryItem(mediaId)
      res.json({ success: true, data: item })
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: error.errors[0].message })
      }
      console.error('Error removing tags:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

// ============================================================================
// Usage Tracking Endpoints
// ============================================================================

/**
 * @openapi
 * /api/media/{mediaId}/usages:
 *   get:
 *     summary: List where media is used
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of usages
 */
router.get(
  '/media/:mediaId/usages',
  requireAuth,
  requirePermission('media.read', 'media', (req) => req.params.mediaId),
  async (req, res) => {
    try {
      const { mediaId } = req.params
      const usages = await listUsages(mediaId)
      res.json({ success: true, data: usages })
    } catch (error) {
      console.error('Error listing media usages:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/media/{mediaId}/detail:
 *   get:
 *     summary: Get full library item detail
 *     description: Returns media with tags, usages, and video details
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Full media detail
 *       404:
 *         description: Media not found
 */
router.get(
  '/media/:mediaId/detail',
  requireAuth,
  requirePermission('media.read', 'media', (req) => req.params.mediaId),
  async (req, res) => {
    try {
      const { mediaId } = req.params
      const item = await getLibraryItem(mediaId)

      if (!item) {
        return res.status(404).json({ success: false, error: 'Media not found' })
      }

      res.json({ success: true, data: item })
    } catch (error) {
      console.error('Error fetching media detail:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

export default router
