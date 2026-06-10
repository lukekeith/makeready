import crypto from 'crypto'
import { Router } from 'express'
import { z } from 'zod'
import multer from 'multer'
import sharp from 'sharp'
import { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { uploadImageVariants, deleteFromR2, extractKeyFromUrl } from '../services/storage.js'
import { trackActivity } from '../services/activity.js'
import { exportProgram, importProgram } from '../services/program-export.js'
import { captureToLibrary, getUserOrgId } from '../services/media-library.js'
import { extractImageMetadata } from '../services/media-metadata.js'
import { suggestProgramTags } from '../services/claude.js'
import { recalculateLessonEstimate } from '../services/lesson-estimate.service.js'
import { extractYouTubeVideoId, extractStartTime, fetchYouTubeMetadata } from '../services/youtube.js'
import { normalizeScriptureMarkdown, normalizeScriptureVerses } from '../utils/scripture-content-normalizer.js'

// Configure multer for ZIP upload (memory storage)
const uploadZip = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/zip' || file.originalname.endsWith('.zip')) {
      cb(null, true)
    } else {
      cb(new Error('Only ZIP files are allowed'))
    }
  },
})

const router = Router()

/**
 * Build an access filter for READ access: org-scoped if user has an org,
 * creator-scoped otherwise. Lets org members view each other's programs.
 */
function accessFilter(userOrgId: string | undefined, userId: string) {
  // Always include creator-scoped access so users can see their own programs
  // even if org association is missing (e.g. programs created before org
  // stamping covered non-owner roles).
  return userOrgId
    ? { OR: [{ organizationId: userOrgId }, { creatorId: userId }] }
    : { creatorId: userId }
}

/**
 * Build an access filter for MUTATIONS (PATCH/POST/DELETE that change a
 * program or its nested resources). Creator-only — group leaders can VIEW
 * any program in their org but only edit ones they created themselves.
 */
function mutationFilter(userId: string) {
  return { creatorId: userId }
}

// ─── Preview Tokens ─────────────────────────────────────────────────────────
// Database-backed tokens that let WKWebView authenticate preview routes
// without cookie planting. One token per user (upsert replaces the old one).
// Tokens never expire — they persist until a new one is generated.
// Org-scoped: any group leader in the org can preview any org content.

/**
 * POST /api/preview-token — generate a preview token for the current user.
 * Replaces any existing token for this user (one token per user).
 * The token is org-scoped and never expires.
 */
router.post('/preview-token', requireAuth, async (_req, res) => {
  try {
    const userId = (_req.user as any).id
    const orgId = await getUserOrgId(userId)
    if (!orgId) {
      return res.status(400).json({ success: false, error: 'User has no organization' })
    }

    const token = crypto.randomBytes(24).toString('base64url')

    // Upsert: one token per user — delete old, insert new
    await prisma.previewToken.upsert({
      where: { userId },
      update: { token, organizationId: orgId },
      create: { token, userId, organizationId: orgId },
    })

    res.json({ success: true, token })
  } catch (error) {
    console.error('Error generating preview token:', error)
    res.status(500).json({ success: false, error: 'Failed to generate preview token' })
  }
})

/**
 * Resolve a userId from either the session or a preview_token query param.
 * Preview tokens are org-scoped — the returned userId is the token owner's.
 * Returns null if neither is valid.
 */
async function resolvePreviewUser(req: any): Promise<string | null> {
  // Session-based auth
  if (req.isAuthenticated?.()) return (req.user as any).id

  // Token-based auth via query param (DB lookup)
  const token = req.query.preview_token as string | undefined
  if (token) {
    const record = await prisma.previewToken.findUnique({
      where: { token },
      select: { userId: true, organizationId: true },
    })
    if (record) return record.userId
  }

  return null
}

/**
 * Resolve the organizationId from a preview token (if present).
 * Used by canPreview to allow org-scoped access.
 */
async function resolvePreviewOrgId(req: any): Promise<string | null> {
  const token = req.query.preview_token as string | undefined
  if (!token) return null
  const record = await prisma.previewToken.findUnique({
    where: { token },
    select: { organizationId: true },
  })
  return record?.organizationId ?? null
}

/**
 * Check if a user can preview content.
 * Access is granted if:
 *   1. The user is the program creator, OR
 *   2. The preview token's org matches the program's org (org-scoped access)
 *   3. Fallback: the user belongs to the same org as the program
 */
async function canPreview(userId: string, creatorId: string, programOrgId: string | null, req?: any): Promise<boolean> {
  if (userId === creatorId) return true
  if (!programOrgId) return false

  // Check org-scoped preview token
  if (req) {
    const tokenOrgId = await resolvePreviewOrgId(req)
    if (tokenOrgId === programOrgId) return true
  }

  // Fallback: check user's own org
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { organizationId: true },
  })
  return user?.organizationId === programOrgId
}

// ============================================================================
// Study Program CRUD
// ============================================================================

/**
 * @openapi
 * /api/programs:
 *   post:
 *     tags: [Programs]
 *     summary: Create a new study program
 *     description: Creates a study program with lessons. Template activities are copied into each lesson.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - templateId
 *             properties:
 *               name:
 *                 type: string
 *                 maxLength: 200
 *               description:
 *                 type: string
 *                 maxLength: 2000
 *               templateId:
 *                 type: string
 *                 format: uuid
 *               days:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 360
 *                 default: 30
 *               coverImageUrl:
 *                 type: string
 *                 format: uri
 *     responses:
 *       200:
 *         description: Program created with lessons
 *       400:
 *         description: Validation error
 */
router.post('/programs', requireAuth, async (req, res) => {
  try {
    const schema = z.object({
      name: z.string().min(1).max(200),
      description: z.string().max(2000).optional(),
      templateId: z.string().uuid(),
      days: z.number().int().min(1).max(360).default(30),
      coverImageUrl: z.string().url().optional(),
      isPublished: z.boolean().default(false),
    })

    const body = schema.parse(req.body)
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    // Verify template exists and is accessible
    const template = await prisma.lessonTemplate.findFirst({
      where: {
        id: body.templateId,
        isActive: true,
        OR: [
          { isSystem: true },
          { creatorId: userId },
          ...(userOrgId ? [{ organizationId: userOrgId }] : []),
        ],
      },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
      },
    })

    if (!template) {
      return res.status(404).json({ success: false, error: 'Template not found' })
    }

    // Create program with lessons in a transaction
    const program = await prisma.$transaction(async (tx) => {
      // Create the program
      const newProgram = await tx.studyProgram.create({
        data: {
          name: body.name,
          description: body.description,
          templateId: body.templateId,
          days: body.days,
          coverImageUrl: body.coverImageUrl,
          isPublished: body.isPublished,
          publishedAt: body.isPublished ? new Date() : null,
          creatorId: userId,
          // userOrgId resolves owners, members, and role-holders (group
          // leaders) — not just org owners — so leader-created programs are
          // visible org-wide.
          organizationId: userOrgId ?? null,
        },
      })

      // Create lessons for each day
      const lessonsData = Array.from({ length: body.days }, (_, i) => ({
        studyProgramId: newProgram.id,
        dayNumber: i + 1,
        title: template.name,
      }))

      await tx.lesson.createMany({ data: lessonsData })

      // Get created lessons to create activities
      const lessons = await tx.lesson.findMany({
        where: { studyProgramId: newProgram.id },
        orderBy: { dayNumber: 'asc' },
      })

      // Copy template activities into each lesson
      const activityData = lessons.flatMap((lesson) =>
        template.activities.map((ta) => ({
          lessonId: lesson.id,
          activityType: ta.type,
          orderNumber: ta.orderNumber,
          title: ta.title,
          referenceTitle: ta.referenceTitle,
          helpTitle: ta.helpTitle,
          helpDescription: ta.helpDescription,
          helpAlwaysVisible: ta.helpAlwaysVisible,
          helpIcon: ta.helpIcon,
        }))
      )

      await tx.lessonActivity.createMany({ data: activityData })

      // Create default unlocked read block for every READ activity
      const readActivities = await tx.lessonActivity.findMany({
        where: {
          lessonId: { in: lessons.map((l) => l.id) },
          activityType: 'READ',
        },
        select: { id: true },
      })
      if (readActivities.length > 0) {
        await tx.activityReadBlock.createMany({
          data: readActivities.map((a) => ({
            lessonActivityId: a.id,
            orderNumber: 1,
            isLocked: false,
          })),
        })
      }

      // Return full program with lessons and activities
      return tx.studyProgram.findUnique({
        where: { id: newProgram.id },
        include: {
          template: {
            select: { id: true, name: true },
          },
          lessons: {
            orderBy: { dayNumber: 'asc' },
            include: {
              activities: {
                orderBy: { orderNumber: 'asc' },
                include: {
                  video: true,
                  sourceReferences: true,
                  readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
                },
              },
            },
          },
        },
      })
    })

    if (program) {
      trackActivity({
        actorId: userId,
        action: 'CREATED',
        resourceType: 'PROGRAM',
        resourceId: program.id,
        resourceName: program.name,
        organizationId: userOrgId,
      })
    }

    res.json({ success: true, program })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error creating program:', error)
    res.status(500).json({ success: false, error: 'Failed to create program' })
  }
})

/**
 * @openapi
 * /api/programs:
 *   get:
 *     tags: [Programs]
 *     summary: List study programs
 *     description: >
 *       Returns study programs within the user's organization. Supports filtering
 *       by creator (group leader), group (via enrollment), and published status.
 *     security:
 *       - userSession: []
 *       - apiKey: []
 *     parameters:
 *       - in: query
 *         name: creatorId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by program creator (group leader)
 *       - in: query
 *         name: groupId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter to programs enrolled in a specific group
 *       - in: query
 *         name: isPublished
 *         schema:
 *           type: boolean
 *         description: Filter by published status
 *       - in: query
 *         name: includeInactive
 *         schema:
 *           type: boolean
 *         description: Include soft-deleted programs (API key only)
 *     responses:
 *       200:
 *         description: List of programs
 */
router.get('/programs', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    const isApiKey = !!(req as any).apiKeyId
    const userOrgId = await getUserOrgId(userId)

    const includeInactive = isApiKey && req.query.includeInactive === 'true'

    const where: any = {
      ...(isApiKey ? {} : accessFilter(userOrgId, userId)),
      ...(includeInactive ? {} : { isActive: true }),
    }

    // Filter by creator (group leader)
    if (req.query.creatorId) {
      where.creatorId = req.query.creatorId as string
    }

    // Filter by multiple group leaders — comma-separated user IDs.
    // Coexists with single ?creatorId=; if both set, ?leaders= wins.
    if (req.query.leaders) {
      const leaderIds = (req.query.leaders as string).split(',').map((id) => id.trim()).filter(Boolean)
      if (leaderIds.length > 0) {
        where.creatorId = { in: leaderIds }
      }
    }

    // Filter by published status
    if (req.query.isPublished === 'true') {
      where.isPublished = true
    } else if (req.query.isPublished === 'false') {
      where.isPublished = false
    }

    // Filter by group (programs enrolled in a specific group)
    if (req.query.groupId) {
      where.enrollments = {
        some: { groupId: req.query.groupId as string },
      }
    }

    // Filter by tag(s) — comma-separated, matches programs with any of the tags
    if (req.query.tag) {
      const tagList = (req.query.tag as string).split(',').map((t) => t.toLowerCase().trim()).filter(Boolean)
      if (tagList.length > 0) {
        where.tags = { some: { tag: { in: tagList } } }
      }
    }

    const programs = await prisma.studyProgram.findMany({
      where,
      orderBy: { updatedAt: 'desc' },
      select: {
        id: true,
        name: true,
        description: true,
        templateId: true,
        days: true,
        coverImageUrl: true,
        creatorId: true,
        isActive: true,
        isPublished: true,
        createdAt: true,
        updatedAt: true,
        template: {
          select: { id: true, name: true },
        },
        tags: {
          select: { tag: true },
          orderBy: { createdAt: 'asc' as const },
        },
        _count: {
          select: {
            enrollments: true,
          },
        },
      },
    })

    res.json({
      success: true,
      programs: programs.map((p) => ({
        ...p,
        tags: p.tags.map((t) => t.tag),
      })),
    })
  } catch (error) {
    console.error('Error fetching programs:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch programs' })
  }
})

/**
 * @openapi
 * /api/programs/{id}:
 *   get:
 *     tags: [Programs]
 *     summary: Get program by ID
 *     description: Returns program details with paginated lessons.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: lessonPage
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: lessonLimit
 *         schema:
 *           type: integer
 *           default: 30
 *           maximum: 60
 *     responses:
 *       200:
 *         description: Program with lessons
 *       404:
 *         description: Program not found
 */

/**
 * @openapi
 * /api/programs/tags:
 *   get:
 *     tags: [Programs]
 *     summary: Get all study program tags ordered by usage count
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of tags with usage counts
 */
router.get('/programs/tags', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    const tags = await prisma.studyProgramTag.groupBy({
      by: ['tag'],
      where: {
        studyProgram: {
          isActive: true,
          ...(userOrgId
            ? { OR: [{ organizationId: userOrgId }, { creatorId: userId }] }
            : { creatorId: userId }),
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
    console.error('Error fetching all program tags:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /api/group-leaders:
 *   get:
 *     tags: [Programs]
 *     summary: List group leaders in the caller's organization with content counts.
 *     description: |
 *       Drives the Library "Group leaders" filter dropdown on both the Programs
 *       and Media tabs. Returns one row per user with a leadership role
 *       (Owner, Admin, or Group Leader) in the caller's org, plus the org
 *       owner, including the count of programs and media items they've
 *       created. Sorted by lastName.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of leaders with program and media counts
 */
router.get('/group-leaders', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)
    if (!userOrgId) {
      return res.json({ success: true, leaders: [] })
    }

    // Collect leaders from two sources:
    // 1. Users who have created groups in this org
    // 2. Users with leadership roles (Owner, Admin, Group Leader) in this org
    const [groupCreators, roleAssignments] = await Promise.all([
      prisma.group.findMany({
        where: { organizationId: userOrgId, isActive: true },
        select: { creatorId: true, creator: { select: { id: true, name: true, picture: true } } },
        distinct: ['creatorId'],
      }),
      prisma.userRole.findMany({
        where: {
          organizationId: userOrgId,
          role: { name: { in: ['Owner', 'Admin', 'Group Leader'] } },
        },
        select: { user: { select: { id: true, name: true, picture: true } } },
      }),
    ])

    const usersById = new Map<string, { id: string; name: string; picture: string | null }>()
    for (const gc of groupCreators) {
      if (gc.creator) usersById.set(gc.creator.id, gc.creator)
    }
    for (const ra of roleAssignments) {
      if (ra.user && !usersById.has(ra.user.id)) usersById.set(ra.user.id, ra.user)
    }

    const userIds = Array.from(usersById.keys())
    if (userIds.length === 0) {
      return res.json({ success: true, leaders: [] })
    }

    // Aggregate counts in two grouped queries to avoid N+1.
    const [programCounts, mediaCounts] = await Promise.all([
      prisma.studyProgram.groupBy({
        by: ['creatorId'],
        where: {
          organizationId: userOrgId,
          isActive: true,
          creatorId: { in: userIds },
        },
        _count: { _all: true },
      }),
      prisma.media.groupBy({
        by: ['uploadedBy'],
        where: {
          organizationId: userOrgId,
          isActive: true,
          uploadedBy: { in: userIds },
        },
        _count: { _all: true },
      }),
    ])

    const programCountByUser = new Map(programCounts.map((r) => [r.creatorId, r._count._all]))
    const mediaCountByUser = new Map(mediaCounts.map((r) => [r.uploadedBy, r._count._all]))

    const leaders = userIds.map((id) => {
      const u = usersById.get(id)!
      const nameParts = (u.name || '').split(' ')
      const firstName = nameParts[0] || null
      const lastName = nameParts.slice(1).join(' ') || null
      return {
        id,
        firstName,
        lastName,
        avatarUrl: u.picture ?? null,
        programCount: programCountByUser.get(id) ?? 0,
        mediaCount: mediaCountByUser.get(id) ?? 0,
      }
    }).sort((a, b) => {
      const aKey = (a.lastName ?? '').toLowerCase()
      const bKey = (b.lastName ?? '').toLowerCase()
      if (aKey !== bKey) return aKey < bKey ? -1 : 1
      return (a.firstName ?? '').toLowerCase() < (b.firstName ?? '').toLowerCase() ? -1 : 1
    })

    res.json({ success: true, leaders })
  } catch (error) {
    console.error('Error fetching group leaders:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

router.get('/programs/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    const lessonPage = Math.max(1, parseInt(req.query.lessonPage as string) || 1)
    const lessonLimit = Math.min(60, Math.max(1, parseInt(req.query.lessonLimit as string) || 30))
    const lessonSkip = (lessonPage - 1) * lessonLimit

    const program = await prisma.studyProgram.findFirst({
      where: {
        id,
        ...accessFilter(userOrgId, userId),
        isActive: true,
      },
      select: {
        id: true,
        name: true,
        description: true,
        templateId: true,
        days: true,
        coverImageUrl: true,
        creatorId: true,
        isActive: true,
        isPublished: true,
        createdAt: true,
        updatedAt: true,
        template: {
          select: { id: true, name: true, description: true },
        },
        lessons: {
          orderBy: { dayNumber: 'asc' },
          skip: lessonSkip,
          take: lessonLimit,
          select: {
            id: true,
            dayNumber: true,
            title: true,
            estimatedMinutes: true,
            createdAt: true,
            updatedAt: true,
            activities: {
              orderBy: { orderNumber: 'asc' },
              select: {
                id: true,
                activityType: true,
                orderNumber: true,
                title: true,
                isHelpEnabled: true,
                helpTitle: true,
                helpDescription: true,
                helpAlwaysVisible: true,
                helpIcon: true,
                readContent: true,
                themeId: true,
                videoId: true,
                videoUrl: true,
                youtubeUrl: true,
                youtubeVideoId: true,
                youtubeStartSeconds: true,
                youtubeEndSeconds: true,
                youtubeThumbnailUrl: true,
                estimatedSeconds: true,
                video: {
                  select: {
                    id: true,
                    title: true,
                    playbackUrl: true,
                    thumbnailUrl: true,
                    duration: true,
                    status: true,
                  },
                },
                sourceReferences: true,
                readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
              },
            },
          },
        },
        tags: {
          select: { tag: true },
          orderBy: { createdAt: 'asc' as const },
        },
        _count: {
          select: {
            lessons: true,
            enrollments: true,
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const totalLessons = program._count.lessons
    const totalPages = Math.ceil(totalLessons / lessonLimit)

    res.json({
      success: true,
      program: {
        ...program,
        tags: program.tags.map((t) => t.tag),
      },
      pagination: {
        page: lessonPage,
        limit: lessonLimit,
        totalLessons,
        totalPages,
        hasMore: lessonPage < totalPages,
      },
    })
  } catch (error) {
    console.error('Error fetching program:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch program' })
  }
})

/**
 * @openapi
 * /api/programs/{id}:
 *   patch:
 *     tags: [Programs]
 *     summary: Update program
 *     description: Updates program metadata. If days changes, creates or removes lessons accordingly.
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
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               days:
 *                 type: integer
 *               templateId:
 *                 type: string
 *                 format: uuid
 *               coverImageUrl:
 *                 type: string
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Program updated
 *       404:
 *         description: Program not found
 */
router.patch('/programs/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const isApiKey = !!(req as any).apiKeyId
    const userOrgId = await getUserOrgId(userId)

    const schema = z.object({
      name: z.string().min(1).max(200).optional(),
      description: z.string().max(2000).optional(),
      days: z.number().int().min(1).max(360).optional(),
      templateId: z.string().uuid().optional(),
      coverImageUrl: z.string().url().optional().nullable(),
      isPublished: z.boolean().optional(),
      organizationId: z.string().uuid().optional(),
    })

    const body = schema.parse(req.body)

    // API key callers can update any program; regular users must be the creator.
    // Org-wide editing was previously allowed via accessFilter — tightened to
    // mutationFilter so only the program's creator can mutate it.
    const existingProgram = await prisma.studyProgram.findFirst({
      where: { id, ...(isApiKey ? {} : mutationFilter(userId)), isActive: true },
    })

    if (!existingProgram) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    // If template is changing, get the new template
    let newTemplate = null
    if (body.templateId && body.templateId !== existingProgram.templateId) {
      newTemplate = await prisma.lessonTemplate.findFirst({
        where: {
          id: body.templateId,
          isActive: true,
          OR: [{ isSystem: true }, { creatorId: userId }, ...(userOrgId ? [{ organizationId: userOrgId }] : [])],
        },
        include: {
          activities: { orderBy: { orderNumber: 'asc' } },
        },
      })
      if (!newTemplate) {
        return res.status(404).json({ success: false, error: 'Template not found' })
      }
    }

    // Compute publishedAt when transitioning to published
    const publishedAt = (body.isPublished === true && !existingProgram.isPublished)
      ? new Date()
      : (body.isPublished === false ? null : undefined)

    // If days changed, handle lesson creation/deletion
    if (body.days !== undefined && body.days !== existingProgram.days) {
      await prisma.$transaction(async (tx) => {
        const currentDays = existingProgram.days
        const newDays = body.days!

        if (newDays > currentDays) {
          // Resolve template (new or existing) before creating lessons
          const templateToUse = newTemplate || (existingProgram.templateId ? await tx.lessonTemplate.findUnique({
            where: { id: existingProgram.templateId },
            include: { activities: { orderBy: { orderNumber: 'asc' } } },
          }) : null)

          // Add new lessons with template name as title
          const newLessonsData = Array.from(
            { length: newDays - currentDays },
            (_, i) => ({
              studyProgramId: id,
              dayNumber: currentDays + i + 1,
              title: templateToUse?.name ?? null,
            })
          )

          await tx.lesson.createMany({ data: newLessonsData })

          // Copy template activities into new lessons
          if (templateToUse) {
            const newLessons = await tx.lesson.findMany({
              where: {
                studyProgramId: id,
                dayNumber: { gt: currentDays },
              },
            })

            const activityData = newLessons.flatMap((lesson) =>
              templateToUse.activities.map((ta) => ({
                lessonId: lesson.id,
                activityType: ta.type,
                orderNumber: ta.orderNumber,
                title: ta.title,
                referenceTitle: ta.referenceTitle,
                helpTitle: ta.helpTitle,
                helpDescription: ta.helpDescription,
                helpAlwaysVisible: ta.helpAlwaysVisible,
                helpIcon: ta.helpIcon,
              }))
            )

            await tx.lessonActivity.createMany({ data: activityData })
          }
        } else if (newDays < currentDays) {
          await tx.lesson.deleteMany({
            where: {
              studyProgramId: id,
              dayNumber: { gt: newDays },
            },
          })
        }

        // Update program
        await tx.studyProgram.update({
          where: { id },
          data: {
            ...body,
            ...(newTemplate ? { templateId: newTemplate.id } : {}),
            ...(publishedAt !== undefined ? { publishedAt } : {}),
            updatedById: userId,
          },
        })
      })
    } else {
      // Simple update without day changes
      await prisma.studyProgram.update({
        where: { id },
        data: {
          ...body,
          ...(newTemplate ? { templateId: newTemplate.id } : {}),
          ...(publishedAt !== undefined ? { publishedAt } : {}),
          updatedById: userId,
        },
      })
    }

    // Fetch updated program
    const program = await prisma.studyProgram.findUnique({
      where: { id },
      include: {
        template: { select: { id: true, name: true } },
        lessons: {
          orderBy: { dayNumber: 'asc' },
          include: {
            activities: {
              orderBy: { orderNumber: 'asc' },
              include: {
                video: true,
                sourceReferences: true,
                readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
              },
            },
          },
        },
        _count: {
          select: { enrollments: true },
        },
      },
    })

    // Track activity: PUBLISHED if toggling to published, otherwise UPDATED
    const action = body.isPublished && !existingProgram.isPublished ? 'PUBLISHED' : 'UPDATED'
    trackActivity({
      actorId: userId,
      action,
      resourceType: 'PROGRAM',
      resourceId: id,
      resourceName: program?.name ?? existingProgram.name,
      organizationId: existingProgram.organizationId,
    })

    res.json({ success: true, program })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating program:', error)
    res.status(500).json({ success: false, error: 'Failed to update program' })
  }
})

/**
 * @openapi
 * /api/programs/{id}/reorder-lessons:
 *   post:
 *     tags: [Programs]
 *     summary: Reorder lessons via drag-and-drop
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
 *             required: [lessonOrder]
 *             properties:
 *               lessonOrder:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Lessons reordered
 */
router.post('/programs/:id/reorder-lessons', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      lessonOrder: z.array(z.string().uuid()).min(1),
    })

    const { lessonOrder } = schema.parse(req.body)

    // Verify ownership
    const program = await prisma.studyProgram.findFirst({
      where: { id, ...mutationFilter(userId), isActive: true },
      include: { lessons: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    // Verify all lesson IDs belong to this program
    const programLessonIds = new Set(program.lessons.map(l => l.id))
    for (const lessonId of lessonOrder) {
      if (!programLessonIds.has(lessonId)) {
        return res.status(400).json({
          success: false,
          error: `Lesson ${lessonId} does not belong to this program`,
        })
      }
    }

    if (lessonOrder.length !== program.lessons.length) {
      return res.status(400).json({
        success: false,
        error: `Expected ${program.lessons.length} lessons, got ${lessonOrder.length}`,
      })
    }

    // Use transaction with temporary high values to avoid unique constraint conflicts
    await prisma.$transaction(async (tx) => {
      // First, set all to high numbers to avoid unique constraint on [studyProgramId, dayNumber]
      for (let i = 0; i < lessonOrder.length; i++) {
        await tx.lesson.update({
          where: { id: lessonOrder[i] },
          data: { dayNumber: 1000 + i },
        })
      }
      // Then set the correct order
      for (let i = 0; i < lessonOrder.length; i++) {
        await tx.lesson.update({
          where: { id: lessonOrder[i] },
          data: { dayNumber: i + 1 },
        })
      }
    })

    const updatedProgram = await prisma.studyProgram.findUnique({
      where: { id },
      include: {
        template: { select: { id: true, name: true } },
        lessons: {
          orderBy: { dayNumber: 'asc' },
          include: {
            activities: {
              orderBy: { orderNumber: 'asc' },
              include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
            },
          },
        },
        _count: { select: { enrollments: true } },
      },
    })

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'PROGRAM',
      resourceId: id,
      resourceName: program.name,
      organizationId: program.organizationId,
      metadata: { reordered: 'lessons' },
    })

    res.json({ success: true, program: updatedProgram })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error reordering lessons:', error)
    res.status(500).json({ success: false, error: 'Failed to reorder lessons' })
  }
})

/**
 * @openapi
 * /api/programs/{id}:
 *   delete:
 *     tags: [Programs]
 *     summary: Delete program (soft delete)
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
 *         description: Program deleted
 *       404:
 *         description: Program not found
 */
router.delete('/programs/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...mutationFilter(userId), isActive: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    await prisma.studyProgram.update({
      where: { id },
      data: { isActive: false },
    })

    trackActivity({
      actorId: userId,
      action: 'DELETED',
      resourceType: 'PROGRAM',
      resourceId: program.id,
      resourceName: program.name,
      organizationId: program.organizationId,
    })

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting program:', error)
    res.status(500).json({ success: false, error: 'Failed to delete program' })
  }
})

/**
 * @openapi
 * /api/programs/{id}/permanent:
 *   delete:
 *     tags: [Programs]
 *     summary: Permanently delete a program and all related data (API key only)
 *     security:
 *       - apiKey: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Program permanently deleted
 *       403:
 *         description: API key required
 *       404:
 *         description: Program not found
 */
router.delete('/programs/:id/permanent', requireAuth, async (req, res) => {
  try {
    const isApiKey = !!(req as any).apiKeyId
    if (!isApiKey) {
      return res.status(403).json({ success: false, error: 'API key required' })
    }

    const { id } = req.params

    const program = await prisma.studyProgram.findUnique({ where: { id } })
    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    // Clean up cover image and variants from R2
    if (program.coverImageUrl) {
      const key = extractKeyFromUrl(program.coverImageUrl)
      if (key) {
        const baseName = key.replace(/\.[^.]+$/, '')
        const ext = key.match(/\.[^.]+$/)?.[0] || ''
        await Promise.allSettled([
          deleteFromR2(key),
          deleteFromR2(`${baseName}-md${ext}`),
          deleteFromR2(`${baseName}-thumb${ext}`),
        ])
      }
    }

    await prisma.studyProgram.delete({ where: { id } })

    res.json({ success: true })
  } catch (error) {
    console.error('Error permanently deleting program:', error)
    res.status(500).json({ success: false, error: 'Failed to permanently delete program' })
  }
})

// ============================================================================
// Lesson Operations
// ============================================================================

/**
 * @openapi
 * /api/programs/{programId}/lessons/{lessonId}:
 *   delete:
 *     tags: [Programs]
 *     summary: Delete a lesson and reorder remaining lessons
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: programId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: lessonId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Lesson deleted
 *       400:
 *         description: Cannot delete the last lesson
 *       404:
 *         description: Not found
 */
router.delete(
  '/programs/:programId/lessons/:lessonId',
  requireAuth,
  async (req, res) => {
    try {
      const { programId, lessonId } = req.params
      const userId = (req.user as any).id

      const program = await prisma.studyProgram.findFirst({
        where: { id: programId, ...mutationFilter(userId), isActive: true },
      })

      if (!program) {
        return res.status(404).json({ success: false, error: 'Program not found' })
      }

      if (program.days <= 1) {
        return res.status(400).json({
          success: false,
          error: 'Cannot delete the last lesson',
        })
      }

      await prisma.$transaction(async (tx) => {
        const lessonToDelete = await tx.lesson.findUnique({
          where: { id: lessonId },
        })

        if (!lessonToDelete || lessonToDelete.studyProgramId !== programId) {
          throw new Error('Lesson not found')
        }

        await tx.lesson.delete({ where: { id: lessonId } })

        await tx.lesson.updateMany({
          where: {
            studyProgramId: programId,
            dayNumber: { gt: lessonToDelete.dayNumber },
          },
          data: {
            dayNumber: { decrement: 1 },
          },
        })

        await tx.studyProgram.update({
          where: { id: programId },
          data: { days: { decrement: 1 } },
        })
      })

      res.json({ success: true })
    } catch (error) {
      if ((error as Error).message === 'Lesson not found') {
        return res.status(404).json({ success: false, error: 'Lesson not found' })
      }
      console.error('Error deleting lesson:', error)
      res.status(500).json({ success: false, error: 'Failed to delete lesson' })
    }
  }
)

// ============================================================================
// Activity Operations
// ============================================================================

/**
 * @openapi
 * /api/activities/{id}:
 *   patch:
 *     tags: [Activities]
 *     summary: Update a lesson activity
 *     description: Updates activity fields like readContent, videoId, title, help text, etc.
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
 *               activityType:
 *                 type: string
 *                 enum: [USER_INPUT, READ, VIDEO]
 *               title:
 *                 type: string
 *               helpTitle:
 *                 type: string
 *                 nullable: true
 *               helpDescription:
 *                 type: string
 *                 nullable: true
 *               helpAlwaysVisible:
 *                 type: boolean
 *               readContent:
 *                 type: string
 *                 nullable: true
 *               videoId:
 *                 type: string
 *                 format: uuid
 *                 nullable: true
 *               videoUrl:
 *                 type: string
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Activity updated
 *       404:
 *         description: Activity not found
 */
/**
 * @openapi
 * /api/activities/{id}/preview-data:
 *   get:
 *     tags: [Programs]
 *     summary: Fetch activity + readBlocks (with theme definitions) for the preview page
 *     description: Authenticated endpoint used by the web client's /preview/activity/:id route to hydrate the canonical preview player.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Activity + blocks + theme definitions }
 *       404: { description: Activity not found or not owned by the user }
 */
router.get('/activities/:id/preview-data', async (req, res) => {
  try {
    const userId = await resolvePreviewUser(req)
    if (!userId) return res.status(401).json({ error: 'Not authenticated' })
    const { id } = req.params

    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      select: {
        id: true,
        activityType: true,
        orderNumber: true,
        title: true,
        readContent: true,
        themeId: true,
        sourceReferences: true,
        // Help context (USER_INPUT activities)
        isHelpEnabled: true,
        helpTitle: true,
        helpDescription: true,
        helpAlwaysVisible: true,
        helpIcon: true,
        // YouTube fields
        youtubeUrl: true,
        youtubeVideoId: true,
        youtubeStartSeconds: true,
        youtubeEndSeconds: true,
        readBlocks: {
          orderBy: { orderNumber: 'asc' as const },
          select: {
            id: true,
            orderNumber: true,
            title: true,
            content: true,
            isLocked: true,
            // Marks blocks whose verses were copied in by the Bible
            // book/chapter/verse process — the preview player uses it to
            // apply print-Bible (serif) styling to scripture blocks only.
            sourceReferenceId: true,
            themeId: true,
            backgroundImageUrl: true,
            backgroundColor: true,
            backgroundOverlayOpacity: true,
            fontSize: true,
            theme: { select: { id: true, slug: true, name: true, definition: true } },
            exegesisHighlights: {
              orderBy: { orderNumber: 'asc' as const },
              select: {
                id: true,
                orderNumber: true,
                start: true,
                end: true,
                noteMarkdown: true,
              },
            },
          },
        },
        lesson: {
          select: { studyProgram: { select: { creatorId: true, organizationId: true } } },
        },
      },
    })

    if (!activity) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    const canAccess = await canPreview(userId, activity.lesson.studyProgram.creatorId, activity.lesson.studyProgram.organizationId ?? null, req)
    if (!canAccess) {
      console.warn(`[preview-data] Access denied for activity ${req.params.id}: userId=${userId}, creatorId=${activity.lesson.studyProgram.creatorId}, programOrgId=${activity.lesson.studyProgram.organizationId}`)
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    const { lesson: _lesson, ...activityWithoutLesson } = activity
    res.json({
      success: true,
      activity: { ...activityWithoutLesson, type: activity.activityType },
    })
  } catch (error) {
    console.error('Error fetching activity preview data:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch activity' })
  }
})

/**
 * @openapi
 * /api/programs/{id}/preview-data:
 *   get:
 *     tags: [Programs]
 *     summary: Fetch a program overview for the authenticated study preview page
 *     description: |
 *       Authenticated counterpart to /public/preview/{token} — returns program
 *       metadata plus lesson list for the creator to step through without
 *       minting a public token. Non-owners get 404.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Program with ordered lesson list }
 *       404: { description: Program not found or not owned by the user }
 */
router.get('/programs/:id/preview-data', async (req, res) => {
  try {
    const userId = await resolvePreviewUser(req)
    if (!userId) return res.status(401).json({ error: 'Not authenticated' })
    const { id } = req.params

    const program = await prisma.studyProgram.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        description: true,
        coverImageUrl: true,
        days: true,
        creatorId: true,
        organizationId: true,
        lessons: {
          orderBy: { dayNumber: 'asc' },
          select: {
            id: true,
            dayNumber: true,
            title: true,
            activities: {
              orderBy: { orderNumber: 'asc' },
              select: {
                id: true,
                activityType: true,
                title: true,
                estimatedSeconds: true,
                sourceReferences: {
                  take: 1,
                  select: { passageReference: true },
                },
              },
            },
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const canAccess = await canPreview(userId, program.creatorId, program.organizationId ?? null, req)
    if (!canAccess) {
      console.warn(`[preview-data] Access denied for program ${req.params.id}: userId=${userId}, creatorId=${program.creatorId}, programOrgId=${program.organizationId}`)
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    // Reflect saved preview progress so the overview's cards/cells show completion.
    // Lesson-level markers (entityType 'lesson_complete') cover whole-lesson
    // completion (including READ steps that persist nothing); per-activity notes
    // and finished videos drive partial completion.
    const completedLessonIds = new Set<string>()
    const completedActivityIds = new Set<string>()
    const previewTokenStr = req.query.preview_token as string | undefined
    if (previewTokenStr) {
      const tokenRecord = await prisma.previewToken.findUnique({
        where: { token: previewTokenStr },
        select: { id: true },
      })
      if (tokenRecord) {
        const states = await prisma.previewState.findMany({
          where: { previewTokenId: tokenRecord.id },
          select: { entityType: true, activityId: true, data: true },
        })
        for (const s of states) {
          if (s.entityType === 'lesson_complete') {
            completedLessonIds.add(s.activityId)
          } else if (s.entityType === 'activity_complete') {
            completedActivityIds.add(s.activityId)
          } else if (s.entityType === 'note' && ((s.data as any)?.content ?? '').trim()) {
            completedActivityIds.add(s.activityId)
          } else if (s.entityType === 'video_progress' && ((s.data as any)?.progress ?? 0) >= 0.9) {
            completedActivityIds.add(s.activityId)
          }
        }
      }
    }

    const clientUrl = process.env.CLIENT_URL || 'http://localhost:8000'
    const lessons = program.lessons.map((lesson) => {
      const firstActivity = lesson.activities[0]
      const passageRef = firstActivity?.sourceReferences?.[0]?.passageReference
      const displayTitle =
        lesson.title || passageRef || firstActivity?.title || `Day ${lesson.dayNumber}`
      const totalSeconds = lesson.activities.reduce((sum, a) => sum + (a.estimatedSeconds || 0), 0)
      const lessonComplete = completedLessonIds.has(lesson.id)
      return {
        id: lesson.id,
        dayNumber: lesson.dayNumber,
        title: displayTitle,
        activities: lesson.activities.map((a) => ({
          type: a.activityType,
          completed: lessonComplete || completedActivityIds.has(a.id),
        })),
        estimatedMinutes: totalSeconds > 0 ? Math.max(1, Math.round(totalSeconds / 60)) : null,
        routes: {
          // Authenticated lesson preview — no token in the path.
          lesson: `${clientUrl}/preview/lesson/${lesson.id}`,
        },
      }
    })

    res.json({
      success: true,
      program: {
        id: program.id,
        name: program.name,
        description: program.description,
        coverImageUrl: program.coverImageUrl,
        days: program.days,
      },
      lessons,
    })
  } catch (error) {
    console.error('Error fetching program preview data:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch program' })
  }
})

/**
 * @openapi
 * /api/lessons/{id}/preview-data:
 *   get:
 *     tags: [Programs]
 *     summary: Fetch a full lesson (activities + readBlocks + themes) for the authenticated lesson preview page
 *     description: |
 *       Authenticated counterpart to the token-based /public/preview/:token/lesson/:lessonId endpoint.
 *       Used by the web client's /preview/lesson/:id route to hydrate a full-lesson preview (LessonIsland)
 *       without minting a public token — the caller must be the program creator.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Lesson with activities, readBlocks, and theme definitions }
 *       404: { description: Lesson not found or not owned by the user }
 */
router.get('/lessons/:id/preview-data', async (req, res) => {
  try {
    const userId = await resolvePreviewUser(req)
    if (!userId) return res.status(401).json({ error: 'Not authenticated' })
    const { id } = req.params

    const lesson = await prisma.lesson.findUnique({
      where: { id },
      select: {
        id: true,
        dayNumber: true,
        title: true,
        studyProgramId: true,
        studyProgram: {
          select: {
            id: true,
            name: true,
            description: true,
            coverImageUrl: true,
            days: true,
            creatorId: true,
            organizationId: true,
          },
        },
        activities: {
          orderBy: { orderNumber: 'asc' },
          select: {
            id: true,
            activityType: true,
            orderNumber: true,
            title: true,
            isHelpEnabled: true,
            helpTitle: true,
            helpDescription: true,
            helpAlwaysVisible: true,
            helpIcon: true,
            referenceTitle: true,
            readContent: true,
            themeId: true,
            videoId: true,
            videoUrl: true,
            youtubeUrl: true,
            youtubeVideoId: true,
            youtubeStartSeconds: true,
            youtubeEndSeconds: true,
            youtubeThumbnailUrl: true,
            video: {
              select: {
                id: true,
                title: true,
                playbackUrl: true,
                thumbnailUrl: true,
                duration: true,
                status: true,
              },
            },
            sourceReferences: true,
            readBlocks: {
              orderBy: { orderNumber: 'asc' as const },
              include: {
                theme: { select: { id: true, slug: true, name: true, definition: true } },
                exegesisHighlights: {
                  orderBy: { orderNumber: 'asc' as const },
                  select: {
                    id: true,
                    orderNumber: true,
                    start: true,
                    end: true,
                    noteMarkdown: true,
                  },
                },
              },
            },
          },
        },
      },
    })

    if (!lesson || !(await canPreview(userId, lesson.studyProgram.creatorId, lesson.studyProgram.organizationId ?? null, req))) {
      return res.status(404).json({ success: false, error: 'Lesson not found' })
    }

    // Match the shape LessonIsland expects — it keys on `type`, not activityType.
    let activities: any[] = lesson.activities.map(a => ({ ...a, type: a.activityType }))

    // Merge saved preview state if this is a token-based preview request
    const previewTokenStr = req.query.preview_token as string | undefined
    if (previewTokenStr) {
      const tokenRecord = await prisma.previewToken.findUnique({
        where: { token: previewTokenStr },
        select: { id: true },
      })
      if (tokenRecord) {
        const states = await prisma.previewState.findMany({
          where: { previewTokenId: tokenRecord.id },
          select: { entityType: true, activityId: true, data: true },
        })
        if (states.length > 0) {
          const stateMap = new Map<string, Map<string, any>>()
          for (const s of states) {
            if (!stateMap.has(s.activityId)) stateMap.set(s.activityId, new Map())
            stateMap.get(s.activityId)!.set(s.entityType, s.data)
          }
          activities = activities.map(a => {
            const aStates = stateMap.get(a.id)
            if (!aStates) return a
            const merged = { ...a }
            const noteState = aStates.get('note')
            if (noteState) merged.note = { content: (noteState as any).content }
            const videoState = aStates.get('video_progress')
            if (videoState) {
              merged.progress = { ...(merged.progress ?? {}), completedAt: (videoState as any).progress >= 0.9 ? new Date().toISOString() : null }
            }
            const exState = aStates.get('exegesis_visit')
            if (exState) {
              merged.progress = { ...(merged.progress ?? {}), exegesisVisitedHighlightIds: (exState as any).visitedIds ?? [] }
            }
            return merged
          })
        }
      }
    }

    res.json({ success: true, lesson: { ...lesson, activities } })
  } catch (error) {
    console.error('Error fetching lesson preview data:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch lesson' })
  }
})

router.patch('/activities/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      activityType: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']).optional(),
      title: z.string().min(1).max(200).optional(),
      referenceTitle: z.string().max(200).nullable().optional(),
      isHelpEnabled: z.boolean().optional(),
      helpTitle: z.string().max(200).nullable().optional(),
      helpDescription: z.string().max(2000).nullable().optional(),
      helpAlwaysVisible: z.boolean().optional(),
      placeholder: z.string().max(200).nullable().optional(),
      readContent: z.string().nullable().optional(),
      videoId: z.string().uuid().nullable().optional(),
      videoUrl: z.string().url().nullable().optional(),
      youtubeUrl: z.string().url().nullable().optional(),
      youtubeStartSeconds: z.number().int().min(0).nullable().optional(),
      youtubeEndSeconds: z.number().int().min(0).nullable().optional(),
    })

    const body = schema.parse(req.body)

    // Verify ownership through lesson -> program -> creator
    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        lesson: {
          include: { studyProgram: true },
        },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    // If setting videoId, validate the video exists
    if (body.videoId) {
      const video = await prisma.video.findFirst({
        where: { id: body.videoId, userId, isActive: true },
      })
      if (!video) {
        return res.status(404).json({ success: false, error: 'Video not found' })
      }
    }

    // If setting youtubeUrl, extract video ID and fetch metadata
    const updateData: any = { ...body }
    if (body.youtubeUrl) {
      const videoId = extractYouTubeVideoId(body.youtubeUrl)
      if (!videoId) {
        return res.status(400).json({ success: false, error: 'Invalid YouTube URL' })
      }
      updateData.youtubeVideoId = videoId

      // Extract start time from URL if not explicitly provided
      if (body.youtubeStartSeconds === undefined) {
        const urlStart = extractStartTime(body.youtubeUrl)
        if (urlStart) updateData.youtubeStartSeconds = urlStart
      }

      // Fetch thumbnail via oEmbed
      const metadata = await fetchYouTubeMetadata(body.youtubeUrl)
      if (metadata) {
        updateData.youtubeThumbnailUrl = metadata.thumbnailUrl
        // Auto-set title if activity has no title or default title
        if (!activity.title || activity.title === 'YouTube' || activity.title === 'Untitled') {
          updateData.title = metadata.title
        }
      }
    }

    const updated = await prisma.lessonActivity.update({
      where: { id },
      data: updateData,
      include: {
        video: true,
        sourceReferences: true,
        readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
      },
    })

    // Backward compat: sync readContent to read blocks
    if (body.readContent !== undefined) {
      const existingBlocks = updated.readBlocks
      if (existingBlocks.length === 0) {
        // No blocks yet - create one
        await prisma.activityReadBlock.create({
          data: {
            lessonActivityId: id,
            orderNumber: 1,
            content: body.readContent,
            isLocked: false,
          },
        })
      } else if (existingBlocks.length === 1 && !existingBlocks[0].isLocked) {
        // Exactly one unlocked block - update it
        await prisma.activityReadBlock.update({
          where: { id: existingBlocks[0].id },
          data: { content: body.readContent },
        })
      }
      // Otherwise: multiple or locked blocks exist, new block-based UI takes precedence
    }

    // Re-fetch with updated blocks
    const result = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        video: true,
        sourceReferences: true,
        readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
      },
    })

    // Recalculate lesson time estimate
    await recalculateLessonEstimate(activity.lessonId)

    res.json({ success: true, activity: result })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating activity:', error)
    res.status(500).json({ success: false, error: 'Failed to update activity' })
  }
})

/**
 * @openapi
 * /api/programs/{programId}/lessons/{lessonId}/activities:
 *   post:
 *     tags: [Programs]
 *     summary: Add an activity to a lesson
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: programId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: lessonId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [activityType, title]
 *             properties:
 *               activityType:
 *                 type: string
 *                 enum: [USER_INPUT, READ, VIDEO]
 *               title:
 *                 type: string
 *               helpTitle:
 *                 type: string
 *               helpDescription:
 *                 type: string
 *               videoId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       200:
 *         description: Activity created
 *       404:
 *         description: Not found
 */
router.post(
  '/programs/:programId/lessons/:lessonId/activities',
  requireAuth,
  async (req, res) => {
    try {
      const { programId, lessonId } = req.params
      const userId = (req.user as any).id

      const schema = z.object({
        activityType: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']),
        title: z.string().max(200).optional(),
        referenceTitle: z.string().max(200).nullable().optional(),
        isHelpEnabled: z.boolean().optional(),
        helpTitle: z.string().max(200).nullable().optional(),
        helpDescription: z.string().max(2000).nullable().optional(),
        helpAlwaysVisible: z.boolean().optional().default(false),
        readContent: z.string().nullable().optional(),
        videoId: z.string().uuid().optional(),
        youtubeUrl: z.string().url().optional(),
        youtubeStartSeconds: z.number().int().min(0).nullable().optional(),
        youtubeEndSeconds: z.number().int().min(0).nullable().optional(),
      })

      const body = schema.parse(req.body)

      // Title is required for READ and VIDEO activities, optional for USER_INPUT and YOUTUBE
      if (!body.title && body.activityType !== 'USER_INPUT' && body.activityType !== 'YOUTUBE') {
        return res.status(400).json({ success: false, error: 'Title is required for READ and VIDEO activities' })
      }

      // Verify ownership
      const program = await prisma.studyProgram.findFirst({
        where: { id: programId, ...mutationFilter(userId), isActive: true },
      })

      if (!program) {
        return res.status(404).json({ success: false, error: 'Program not found' })
      }

      // Get lesson with max order number
      const lesson = await prisma.lesson.findFirst({
        where: { id: lessonId, studyProgramId: programId },
        include: {
          activities: {
            orderBy: { orderNumber: 'desc' },
            take: 1,
          },
        },
      })

      if (!lesson) {
        return res.status(404).json({ success: false, error: 'Lesson not found' })
      }

      // Validate video reference
      if (body.activityType === 'VIDEO' && body.videoId) {
        const video = await prisma.video.findFirst({
          where: { id: body.videoId, userId, isActive: true },
        })
        if (!video) {
          return res.status(404).json({ success: false, error: 'Video not found' })
        }
      }

      // Handle YouTube URL metadata
      let youtubeData: any = {}
      if (body.activityType === 'YOUTUBE' && body.youtubeUrl) {
          const videoId = extractYouTubeVideoId(body.youtubeUrl)
        if (!videoId) {
          return res.status(400).json({ success: false, error: 'Invalid YouTube URL' })
        }
        youtubeData.youtubeUrl = body.youtubeUrl
        youtubeData.youtubeVideoId = videoId
        youtubeData.youtubeStartSeconds = body.youtubeStartSeconds ?? extractStartTime(body.youtubeUrl) ?? null
        youtubeData.youtubeEndSeconds = body.youtubeEndSeconds ?? null

        const metadata = await fetchYouTubeMetadata(body.youtubeUrl)
        if (metadata) {
          youtubeData.youtubeThumbnailUrl = metadata.thumbnailUrl
          if (!body.title) youtubeData.title = metadata.title
        }
      }

      const nextOrder = lesson.activities[0]?.orderNumber
        ? lesson.activities[0].orderNumber + 1
        : 1

      const activity = await prisma.lessonActivity.create({
        data: {
          lessonId,
          activityType: body.activityType,
          orderNumber: nextOrder,
          title: body.title || youtubeData.title || '',
          referenceTitle: body.referenceTitle ?? null,
          ...(body.isHelpEnabled !== undefined && { isHelpEnabled: body.isHelpEnabled }),
          helpTitle: body.helpTitle ?? null,
          helpDescription: body.helpDescription ?? null,
          helpAlwaysVisible: body.helpAlwaysVisible ?? false,
          readContent: body.readContent ?? null,
          videoId: body.activityType === 'VIDEO' ? body.videoId : null,
          ...youtubeData,
        },
        include: {
          video: true,
          sourceReferences: true,
          readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
        },
      })

      // Auto-create a default empty read block for READ activities
      if (body.activityType === 'READ') {
        await prisma.activityReadBlock.create({
          data: {
            lessonActivityId: activity.id,
            orderNumber: 1,
            content: body.readContent ?? null,
            isLocked: false,
          },
        })
      }

      // Re-fetch to include the newly created block
      const result = body.activityType === 'READ'
        ? await prisma.lessonActivity.findUnique({
            where: { id: activity.id },
            include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
          })
        : activity

      // Recalculate lesson time estimate
      await recalculateLessonEstimate(lessonId)

      res.json({ success: true, activity: result })
    } catch (error) {
      if (error instanceof z.ZodError) {
        const first = error.errors?.[0]
        const path = first?.path?.length ? first.path.join('.') : undefined
        const message = first?.message ?? 'Validation error'
        const friendly = path ? `${path}: ${message}` : message

        return res.status(400).json({
          success: false,
          // Keep `errors` for structured clients, but also provide a string `error`
          // so older clients can surface something useful.
          error: friendly,
          errors: error.errors,
        })
      }
      const errMsg = error instanceof Error ? error.message : String(error)
      const errCode = (error as any)?.code
      console.error('Error creating activity:', errMsg, errCode ? `[${errCode}]` : '', error)
      res.status(500).json({ success: false, error: 'Failed to create activity', details: errMsg })
    }
  }
)

/**
 * @openapi
 * /api/programs/{programId}/lessons/{lessonId}/reorder-activities:
 *   post:
 *     tags: [Programs]
 *     summary: Reorder activities via drag-and-drop
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Activities reordered
 */
router.post(
  '/programs/:programId/lessons/:lessonId/reorder-activities',
  requireAuth,
  async (req, res) => {
    try {
      const { programId, lessonId } = req.params
      const userId = (req.user as any).id

      const schema = z.object({
        activityOrder: z.array(z.string().uuid()).min(1),
      })

      const { activityOrder } = schema.parse(req.body)

      const program = await prisma.studyProgram.findFirst({
        where: { id: programId, ...mutationFilter(userId), isActive: true },
      })

      if (!program) {
        return res.status(404).json({ success: false, error: 'Program not found' })
      }

      const lesson = await prisma.lesson.findFirst({
        where: { id: lessonId, studyProgramId: programId },
        include: { activities: true },
      })

      if (!lesson) {
        return res.status(404).json({ success: false, error: 'Lesson not found' })
      }

      const lessonActivityIds = new Set(lesson.activities.map(a => a.id))
      for (const activityId of activityOrder) {
        if (!lessonActivityIds.has(activityId)) {
          return res.status(400).json({
            success: false,
            error: `Activity ${activityId} does not belong to this lesson`,
          })
        }
      }

      if (activityOrder.length !== lesson.activities.length) {
        return res.status(400).json({
          success: false,
          error: `Expected ${lesson.activities.length} activities, got ${activityOrder.length}`,
        })
      }

      // Use transaction with temporary high values to avoid unique constraint conflicts
      await prisma.$transaction(async (tx) => {
        // First, set all to high numbers to avoid unique constraint on [lessonId, orderNumber]
        for (let i = 0; i < activityOrder.length; i++) {
          await tx.lessonActivity.update({
            where: { id: activityOrder[i] },
            data: { orderNumber: 1000 + i },
          })
        }
        // Then set the correct order
        for (let i = 0; i < activityOrder.length; i++) {
          await tx.lessonActivity.update({
            where: { id: activityOrder[i] },
            data: { orderNumber: i + 1 },
          })
        }
      })

      const updatedActivities = await prisma.lessonActivity.findMany({
        where: { lessonId },
        orderBy: { orderNumber: 'asc' },
        include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
      })

      trackActivity({
        actorId: userId,
        action: 'UPDATED',
        resourceType: 'LESSON',
        resourceId: lessonId,
        resourceName: lesson.title || `Lesson`,
        organizationId: program.organizationId,
        metadata: { programId, programName: program.name, reordered: 'activities' },
      })

      res.json({ success: true, activities: updatedActivities })
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: error.errors })
      }
      console.error('Error reordering activities:', error)
      res.status(500).json({ success: false, error: 'Failed to reorder activities' })
    }
  }
)

/**
 * @openapi
 * /api/activities/{id}:
 *   delete:
 *     tags: [Programs]
 *     summary: Delete an activity from a lesson
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
 *         description: Activity deleted
 *       400:
 *         description: Cannot delete last activity
 *       404:
 *         description: Not found
 */
router.delete('/activities/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        lesson: {
          include: {
            studyProgram: true,
            activities: true,
          },
        },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    await prisma.$transaction(async (tx) => {
      await tx.lessonActivity.delete({ where: { id } })

      await tx.lessonActivity.updateMany({
        where: {
          lessonId: activity.lessonId,
          orderNumber: { gt: activity.orderNumber },
        },
        data: {
          orderNumber: { decrement: 1 },
        },
      })
    })

    // Recalculate lesson time estimate
    await recalculateLessonEstimate(activity.lessonId)

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting activity:', error)
    res.status(500).json({ success: false, error: 'Failed to delete activity' })
  }
})

/**
 * @openapi
 * /api/activities/{id}/reset:
 *   post:
 *     tags: [Programs]
 *     summary: Reset an activity (clear readContent, video, source references)
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
 *         description: Activity reset
 *       404:
 *         description: Not found
 */
router.post('/activities/:id/reset', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        lesson: { include: { studyProgram: true } },
      },
    })

    if (!activity) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    if (activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(403).json({ success: false, error: 'Not authorized' })
    }

    // Reset: clear content, source references, and read blocks
    await prisma.$transaction(async (tx) => {
      // Delete read blocks (must be before source references due to FK)
      await tx.activityReadBlock.deleteMany({
        where: { lessonActivityId: id },
      })

      // Delete source references
      await tx.activitySourceReference.deleteMany({
        where: { lessonActivityId: id },
      })

      // Clear content fields
      await tx.lessonActivity.update({
        where: { id },
        data: {
          readContent: null,
          videoId: null,
          videoUrl: null,
        },
      })
    })

    const updatedActivity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    // Recalculate lesson time estimate
    await recalculateLessonEstimate(activity.lessonId)

    res.json({ success: true, activity: updatedActivity })
  } catch (error) {
    console.error('Error resetting activity:', error)
    res.status(500).json({ success: false, error: 'Failed to reset activity' })
  }
})

// ============================================================================
// YouTube Metadata
// ============================================================================

/**
 * @openapi
 * /api/youtube/metadata:
 *   post:
 *     tags: [YouTube]
 *     summary: Get YouTube video metadata (title, thumbnail, duration)
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [url]
 *             properties:
 *               url:
 *                 type: string
 *     responses:
 *       200:
 *         description: Video metadata
 *       400:
 *         description: Invalid URL
 */
router.post('/youtube/metadata', requireAuth, async (req, res) => {
  try {
    const { url } = z.object({ url: z.string().url() }).parse(req.body)

    const videoId = extractYouTubeVideoId(url)
    if (!videoId) {
      return res.status(400).json({ success: false, error: 'Invalid YouTube URL' })
    }

    const metadata = await fetchYouTubeMetadata(url)
    if (!metadata) {
      return res.status(400).json({ success: false, error: 'Could not fetch video metadata' })
    }

    res.json({
      success: true,
      metadata: {
        videoId: metadata.videoId,
        title: metadata.title,
        thumbnailUrl: metadata.thumbnailUrl,
        authorName: metadata.authorName,
        durationSeconds: metadata.durationSeconds,
      },
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error fetching YouTube metadata:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch metadata' })
  }
})

// ============================================================================
// Activity Source References
// ============================================================================

const sourceReferenceSchema = z.object({
  sourceType: z.string().default('SCRIPTURE'),
  passageReference: z.string().nullable().optional(),
  bookNumber: z.number().int().min(1).max(66).nullable().optional(),
  bookName: z.string().nullable().optional(),
  chapterStart: z.number().int().min(1).nullable().optional(),
  chapterEnd: z.number().int().min(1).nullable().optional(),
  verseStart: z.number().int().min(1).nullable().optional(),
  verseEnd: z.number().int().min(1).nullable().optional(),
  content: z.string().nullable().optional(),
})

/**
 * @openapi
 * /api/activities/{id}/source-references:
 *   post:
 *     tags: [Activities]
 *     summary: Add a source reference to an activity
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       201:
 *         description: Source reference created
 */
router.post('/activities/:id/source-references', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const body = sourceReferenceSchema.parse(req.body)

    // Verify ownership
    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        lesson: { include: { studyProgram: true } },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    if (activity.activityType === 'EXEGESIS') {
      // EXEGESIS supports exactly one scripture passage block. Adding a new
      // passage replaces the prior passage + any highlights.
      const existingBlocks = await prisma.activityReadBlock.findMany({
        where: { lessonActivityId: id },
        select: { id: true },
      })
      const blockIds = existingBlocks.map((b) => b.id)
      if (blockIds.length > 0) {
        await prisma.exegesisHighlight.deleteMany({ where: { readBlockId: { in: blockIds } } })
      }
      await prisma.activityReadBlock.deleteMany({ where: { lessonActivityId: id } })
      await prisma.activitySourceReference.deleteMany({ where: { lessonActivityId: id } })
    } else {
      // Shift all existing blocks' orderNumber up by 1 to make room at position 1
      await prisma.activityReadBlock.updateMany({
        where: { lessonActivityId: id },
        data: { orderNumber: { increment: 1 } },
      })
    }

    // Create source reference and locked read block together
    const ref = await prisma.activitySourceReference.create({
      data: {
        lessonActivityId: id,
        sourceType: body.sourceType,
        passageReference: body.passageReference ?? null,
        bookNumber: body.bookNumber ?? null,
        bookName: body.bookName ?? null,
        chapterStart: body.chapterStart ?? null,
        chapterEnd: body.chapterEnd ?? null,
        verseStart: body.verseStart ?? null,
        verseEnd: body.verseEnd ?? null,
      },
    })

    // Store canonical numbered markdown for scripture content. Use client-provided
    // content if available, otherwise fetch from Bible database.
    let verseContent: string | null = normalizeScriptureMarkdown(body.content)
    if (!verseContent && body.bookNumber && body.chapterStart && body.verseStart) {
      const translation = await prisma.translation.findUnique({
        where: { code: 'KJV' },
      })
      if (translation) {
        const verseEnd = body.verseEnd ?? body.verseStart
        const verses = await prisma.verse.findMany({
          where: {
            translationId: translation.id,
            bookNumber: body.bookNumber,
            chapter: body.chapterStart,
            verse: { gte: body.verseStart, lte: verseEnd },
          },
          orderBy: { verse: 'asc' },
        })
        if (verses.length > 0) {
          verseContent = normalizeScriptureVerses(verses)
        }
      }
    }

    // Create a locked read block at position 1, linked to this source reference
    await prisma.activityReadBlock.create({
      data: {
        lessonActivityId: id,
        orderNumber: 1,
        title: body.passageReference ?? null,
        content: verseContent ?? body.passageReference ?? null,
        contentFormat: 'markdown',
        isLocked: true,
        sourceReferenceId: ref.id,
      },
    })

    // Return the full updated activity with all blocks
    const updatedActivity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    res.status(201).json({ success: true, sourceReference: ref, activity: updatedActivity })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error adding source reference:', error)
    res.status(500).json({ success: false, error: 'Failed to add source reference' })
  }
})

/**
 * @openapi
 * /api/activities/{id}/source-references/{refId}:
 *   delete:
 *     tags: [Activities]
 *     summary: Remove a source reference from an activity
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Source reference deleted
 */
router.delete('/activities/:id/source-references/:refId', requireAuth, async (req, res) => {
  try {
    const { id, refId } = req.params
    const userId = (req.user as any).id

    // Verify ownership
    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        lesson: { include: { studyProgram: true } },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    const ref = await prisma.activitySourceReference.findFirst({
      where: { id: refId, lessonActivityId: id },
    })

    if (!ref) {
      return res.status(404).json({ success: false, error: 'Source reference not found' })
    }

    // Delete linked read block first (FK constraint), then the source reference
    await prisma.activityReadBlock.deleteMany({
      where: { sourceReferenceId: refId },
    })
    await prisma.activitySourceReference.delete({ where: { id: refId } })

    // Renumber remaining read blocks to close gaps
    const remainingBlocks = await prisma.activityReadBlock.findMany({
      where: { lessonActivityId: id },
      orderBy: { orderNumber: 'asc' },
    })
    for (let i = 0; i < remainingBlocks.length; i++) {
      if (remainingBlocks[i].orderNumber !== i + 1) {
        await prisma.activityReadBlock.update({
          where: { id: remainingBlocks[i].id },
          data: { orderNumber: i + 1 },
        })
      }
    }

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting source reference:', error)
    res.status(500).json({ success: false, error: 'Failed to delete source reference' })
  }
})

// ============================================================================
// Exegesis Highlights
// ============================================================================

async function syncExegesisSelectionsForBlock(readBlockId: string): Promise<void> {
  const highlights = await prisma.exegesisHighlight.findMany({
    where: { readBlockId },
    orderBy: { orderNumber: 'asc' },
    select: { start: true, end: true },
  })

  const selections = highlights.map((h) => ({ start: h.start, end: h.end, style: 'highlight' }))

  await prisma.activityReadBlock.update({
    where: { id: readBlockId },
    data: { selections: selections.length ? (selections as unknown as Prisma.InputJsonValue) : Prisma.DbNull },
  })
}

/**
 * Defensive sanitation for leader-authored markdown fields.
 *
 * We already sanitize/normalize pasted rich text on iOS (MarkdownEditor), but
 * we also sanitize on the server so any HTML/RTF-ish paste that slips through
 * can't be rendered as raw HTML in member clients (v-html surfaces).
 */
function sanitizeMarkdownInput(input: string): string {
  let out = input

  // Normalise newlines
  out = out.replace(/\r\n?/g, '\n')

  // If HTML tags are present, strip them (keep inner text) while preserving
  // newlines for <br>/<p>/<div>.
  if (/<\/?[a-z][\s\S]*?>/i.test(out)) {
    out = out
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<\/li>/gi, '\n')
      .replace(/<[^>]+>/g, '')
  }

  // Decode a small set of entities we expect from pasted content.
  out = out
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')

  // Drop control chars (keep \n and \t)
  out = out.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '')

  // Collapse excessive blank lines
  out = out.replace(/\n{3,}/g, '\n\n')

  return out.trim()
}

/**
 * List exegesis highlights for an EXEGESIS activity.
 */
router.get('/activities/:activityId/exegesis-highlights', requireAuth, async (req, res) => {
  try {
    const { activityId } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.lessonActivity.findUnique({
      where: { id: activityId },
      include: { lesson: { include: { studyProgram: true } } },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    if (activity.activityType !== 'EXEGESIS') {
      return res.status(400).json({ success: false, error: 'Activity is not an EXEGESIS activity' })
    }

    const block = await prisma.activityReadBlock.findFirst({
      where: { lessonActivityId: activityId, isLocked: true },
      orderBy: { orderNumber: 'asc' },
      select: { id: true },
    })

    if (!block) {
      return res.json({ success: true, readBlockId: null, highlights: [] })
    }

    const highlights = await prisma.exegesisHighlight.findMany({
      where: { readBlockId: block.id },
      orderBy: { orderNumber: 'asc' },
    })

    res.json({ success: true, readBlockId: block.id, highlights })
  } catch (error) {
    console.error('Error listing exegesis highlights:', error)
    res.status(500).json({ success: false, error: 'Failed to list exegesis highlights' })
  }
})

/**
 * Create a new exegesis highlight.
 */
router.post('/activities/:activityId/exegesis-highlights', requireAuth, async (req, res) => {
  try {
    const { activityId } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      readBlockId: z.string().uuid(),
      start: z.number().int().min(0),
      end: z.number().int().min(1),
      noteMarkdown: z.string().default(''),
    }).refine((v) => v.end > v.start, { message: 'end must be greater than start' })

    const body = schema.parse(req.body)

    const activity = await prisma.lessonActivity.findUnique({
      where: { id: activityId },
      include: { lesson: { include: { studyProgram: true } } },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    if (activity.activityType !== 'EXEGESIS') {
      return res.status(400).json({ success: false, error: 'Activity is not an EXEGESIS activity' })
    }

    const block = await prisma.activityReadBlock.findFirst({
      where: { id: body.readBlockId, lessonActivityId: activityId, isLocked: true },
      select: { id: true },
    })

    if (!block) {
      return res.status(404).json({ success: false, error: 'Read block not found' })
    }

    // Enforce non-overlapping highlights
    const existing = await prisma.exegesisHighlight.findMany({
      where: { readBlockId: block.id },
      select: { start: true, end: true },
    })

    const overlaps = existing.some((h) => !(body.end <= h.start || body.start >= h.end))
    if (overlaps) {
      return res.status(400).json({ success: false, error: 'Highlight overlaps an existing highlight' })
    }

    const nextOrder = await prisma.exegesisHighlight.aggregate({
      where: { readBlockId: block.id },
      _max: { orderNumber: true },
    })

    const created = await prisma.exegesisHighlight.create({
      data: {
        readBlockId: block.id,
        orderNumber: (nextOrder._max.orderNumber ?? 0) + 1,
        start: body.start,
        end: body.end,
        noteMarkdown: sanitizeMarkdownInput(body.noteMarkdown),
      },
    })

    await syncExegesisSelectionsForBlock(block.id)

    res.status(201).json({ success: true, highlight: created })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error creating exegesis highlight:', error)
    res.status(500).json({ success: false, error: 'Failed to create exegesis highlight' })
  }
})

/**
 * Update an existing exegesis highlight (noteMarkdown only).
 */
router.patch('/activities/:activityId/exegesis-highlights/:highlightId', requireAuth, async (req, res) => {
  try {
    const { activityId, highlightId } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      noteMarkdown: z.string(),
    })
    const body = schema.parse(req.body)

    const activity = await prisma.lessonActivity.findUnique({
      where: { id: activityId },
      include: { lesson: { include: { studyProgram: true } } },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    if (activity.activityType !== 'EXEGESIS') {
      return res.status(400).json({ success: false, error: 'Activity is not an EXEGESIS activity' })
    }

    // Ensure highlight belongs to this activity via the read block
    const highlight = await prisma.exegesisHighlight.findUnique({
      where: { id: highlightId },
      include: { readBlock: { select: { lessonActivityId: true, id: true } } },
    })

    if (!highlight || highlight.readBlock.lessonActivityId !== activityId) {
      return res.status(404).json({ success: false, error: 'Highlight not found' })
    }

    const updated = await prisma.exegesisHighlight.update({
      where: { id: highlightId },
      data: { noteMarkdown: sanitizeMarkdownInput(body.noteMarkdown) },
    })

    res.json({ success: true, highlight: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating exegesis highlight:', error)
    res.status(500).json({ success: false, error: 'Failed to update exegesis highlight' })
  }
})

/**
 * Delete an exegesis highlight.
 */
router.delete('/activities/:activityId/exegesis-highlights/:highlightId', requireAuth, async (req, res) => {
  try {
    const { activityId, highlightId } = req.params
    const userId = (req.user as any).id

    const activity = await prisma.lessonActivity.findUnique({
      where: { id: activityId },
      include: { lesson: { include: { studyProgram: true } } },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    if (activity.activityType !== 'EXEGESIS') {
      return res.status(400).json({ success: false, error: 'Activity is not an EXEGESIS activity' })
    }

    const highlight = await prisma.exegesisHighlight.findUnique({
      where: { id: highlightId },
      include: { readBlock: { select: { lessonActivityId: true, id: true } } },
    })

    if (!highlight || highlight.readBlock.lessonActivityId !== activityId) {
      return res.status(404).json({ success: false, error: 'Highlight not found' })
    }

    await prisma.exegesisHighlight.delete({ where: { id: highlightId } })
    await syncExegesisSelectionsForBlock(highlight.readBlock.id)

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting exegesis highlight:', error)
    res.status(500).json({ success: false, error: 'Failed to delete exegesis highlight' })
  }
})

// ============================================================================
// Activity Read Blocks
// ============================================================================

/**
 * @openapi
 * /api/activities/{id}/read-blocks:
 *   post:
 *     tags: [Activities]
 *     summary: Add a read block to an activity
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
 *               content:
 *                 type: string
 *                 nullable: true
 *               isLocked:
 *                 type: boolean
 *               sourceReferenceId:
 *                 type: string
 *                 nullable: true
 *               orderNumber:
 *                 type: integer
 *     responses:
 *       201:
 *         description: Read block created
 *       404:
 *         description: Activity not found
 */
router.post('/activities/:id/read-blocks', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      title: z.string().nullable().optional(),
      content: z.string().nullable().optional(),
      isLocked: z.boolean().optional().default(false),
      sourceReferenceId: z.string().uuid().nullable().optional(),
      orderNumber: z.number().int().min(1).optional(),
    })

    const body = schema.parse(req.body)

    // Verify ownership
    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        lesson: { include: { studyProgram: true } },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    if (activity.activityType === 'EXEGESIS') {
      return res
        .status(400)
        .json({ success: false, error: 'EXEGESIS activities do not support manual read blocks' })
    }

    // Determine order number
    let orderNumber = body.orderNumber
    if (!orderNumber) {
      const maxBlock = await prisma.activityReadBlock.findFirst({
        where: { lessonActivityId: id },
        orderBy: { orderNumber: 'desc' },
        select: { orderNumber: true },
      })
      orderNumber = (maxBlock?.orderNumber ?? 0) + 1
    }

    const isScriptureLinkedBlock = body.sourceReferenceId != null
    const content = isScriptureLinkedBlock
      ? normalizeScriptureMarkdown(body.content)
      : (body.content ?? null)

    const block = await prisma.activityReadBlock.create({
      data: {
        lessonActivityId: id,
        orderNumber,
        title: body.title ?? null,
        content,
        contentFormat: 'markdown',
        isLocked: body.isLocked,
        sourceReferenceId: body.sourceReferenceId ?? null,
      },
    })

    // Return the updated activity with all read blocks
    const updatedActivity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    // Recalculate lesson time estimate
    await recalculateLessonEstimate(activity.lessonId)

    res.status(201).json({ success: true, block, activity: updatedActivity })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error adding read block:', error)
    res.status(500).json({ success: false, error: 'Failed to add read block' })
  }
})

/**
 * @openapi
 * /api/activities/{activityId}/read-blocks/{blockId}:
 *   patch:
 *     tags: [Activities]
 *     summary: Update a read block
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: blockId
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
 *               content:
 *                 type: string
 *                 nullable: true
 *               orderNumber:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Read block updated
 *       400:
 *         description: Cannot edit locked block content
 *       404:
 *         description: Not found
 */
router.patch('/activities/:activityId/read-blocks/:blockId', requireAuth, async (req, res) => {
  try {
    const { activityId, blockId } = req.params
    const userId = (req.user as any).id

    const selectionSchema = z.object({
      start: z.number().int().min(0),
      end: z.number().int().min(1),
      style: z.string().min(1),
    }).refine((s) => s.end > s.start, { message: 'end must be greater than start' })

    const schema = z.object({
      title: z.string().nullable().optional(),
      content: z.string().nullable().optional(),
      orderNumber: z.number().int().min(1).optional(),
      themeId: z.string().uuid().nullable().optional(),
      contentFormat: z.enum(['html', 'markdown']).optional(),
      backgroundImageUrl: z.string().nullable().optional(),
      backgroundColor: z.string().nullable().optional(),
      backgroundOverlayOpacity: z.number().min(0).max(1).nullable().optional(),
      fontSize: z.enum(['xs', 's', 'm', 'lg', 'xl']).nullable().optional(),
      selections: z.array(selectionSchema).nullable().optional(),
    })

    const body = schema.parse(req.body)

    // Verify ownership
    const activity = await prisma.lessonActivity.findUnique({
      where: { id: activityId },
      include: {
        lesson: { include: { studyProgram: true } },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    const block = await prisma.activityReadBlock.findFirst({
      where: { id: blockId, lessonActivityId: activityId },
    })

    if (!block) {
      return res.status(404).json({ success: false, error: 'Read block not found' })
    }

    // Reject content changes on locked blocks
    if (block.isLocked && body.content !== undefined) {
      return res.status(400).json({ success: false, error: 'Cannot edit content of a locked block' })
    }

    const content = block.sourceReferenceId
      ? normalizeScriptureMarkdown(body.content)
      : (body.content ?? null)

    const updated = await prisma.activityReadBlock.update({
      where: { id: blockId },
      data: {
        ...(body.title !== undefined && { title: body.title }),
        ...(body.content !== undefined && { content }),
        ...(body.orderNumber !== undefined && { orderNumber: body.orderNumber }),
        ...(body.themeId !== undefined && { themeId: body.themeId }),
        ...(body.contentFormat !== undefined && { contentFormat: body.contentFormat }),
        ...(body.backgroundImageUrl !== undefined && { backgroundImageUrl: body.backgroundImageUrl }),
        ...(body.backgroundColor !== undefined && { backgroundColor: body.backgroundColor }),
        ...(body.backgroundOverlayOpacity !== undefined && { backgroundOverlayOpacity: body.backgroundOverlayOpacity }),
        ...(body.fontSize !== undefined && { fontSize: body.fontSize }),
        ...(body.selections !== undefined && { selections: body.selections === null ? Prisma.DbNull : (body.selections as Prisma.InputJsonValue) }),
      },
    })

    // Recalculate lesson time estimate if content changed
    if (body.content !== undefined) {
      await recalculateLessonEstimate(activity.lessonId)
    }

    res.json({ success: true, block: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating read block:', error)
    const msg = error instanceof Error ? error.message : 'Failed to update read block'
    res.status(500).json({ success: false, error: msg })
  }
})

/**
 * @openapi
 * /api/activities/{activityId}/read-blocks/{blockId}:
 *   delete:
 *     tags: [Activities]
 *     summary: Delete a read block
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: blockId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Read block deleted
 *       400:
 *         description: Cannot delete the last block
 *       404:
 *         description: Not found
 */
router.delete('/activities/:activityId/read-blocks/:blockId', requireAuth, async (req, res) => {
  try {
    const { activityId, blockId } = req.params
    const userId = (req.user as any).id

    // Verify ownership
    const activity = await prisma.lessonActivity.findUnique({
      where: { id: activityId },
      include: {
        lesson: { include: { studyProgram: true } },
        readBlocks: { include: { theme: { select: { id: true, slug: true, name: true } } } },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    const block = activity.readBlocks.find(b => b.id === blockId)
    if (!block) {
      return res.status(404).json({ success: false, error: 'Read block not found' })
    }

    // Enforce minimum 1 block
    if (activity.readBlocks.length <= 1) {
      return res.status(400).json({ success: false, error: 'Cannot delete the last read block' })
    }

    await prisma.activityReadBlock.delete({ where: { id: blockId } })

    // Renumber remaining blocks to close gaps
    const remainingBlocks = await prisma.activityReadBlock.findMany({
      where: { lessonActivityId: activityId },
      orderBy: { orderNumber: 'asc' },
    })
    for (let i = 0; i < remainingBlocks.length; i++) {
      if (remainingBlocks[i].orderNumber !== i + 1) {
        await prisma.activityReadBlock.update({
          where: { id: remainingBlocks[i].id },
          data: { orderNumber: i + 1 },
        })
      }
    }

    // Return the updated activity
    const updatedActivity = await prisma.lessonActivity.findUnique({
      where: { id: activityId },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    // Recalculate lesson time estimate
    await recalculateLessonEstimate(activity.lessonId)

    res.json({ success: true, activity: updatedActivity })
  } catch (error) {
    console.error('Error deleting read block:', error)
    res.status(500).json({ success: false, error: 'Failed to delete read block' })
  }
})

/**
 * @openapi
 * /api/activities/{id}/read-blocks/reorder:
 *   patch:
 *     tags: [Activities]
 *     summary: Reorder all read blocks for an activity
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
 *             required: [blockIds]
 *             properties:
 *               blockIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Blocks reordered
 *       400:
 *         description: Invalid block IDs
 *       404:
 *         description: Activity not found
 */
router.patch('/activities/:id/read-blocks/reorder', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      blockIds: z.array(z.string().uuid()).min(1),
    })

    const { blockIds } = schema.parse(req.body)

    // Verify ownership
    const activity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: {
        lesson: { include: { studyProgram: true } },
        readBlocks: { include: { theme: { select: { id: true, slug: true, name: true } } } },
      },
    })

    if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    // Validate all IDs belong to this activity
    const activityBlockIds = new Set(activity.readBlocks.map(b => b.id))
    for (const blockId of blockIds) {
      if (!activityBlockIds.has(blockId)) {
        return res.status(400).json({
          success: false,
          error: `Block ${blockId} does not belong to this activity`,
        })
      }
    }

    if (blockIds.length !== activity.readBlocks.length) {
      return res.status(400).json({
        success: false,
        error: `Expected ${activity.readBlocks.length} blocks, got ${blockIds.length}`,
      })
    }

    // Update orderNumbers using parameterized values
    await prisma.$transaction(
      blockIds.map((blockId, index) =>
        prisma.activityReadBlock.update({
          where: { id: blockId },
          data: { orderNumber: index + 1 },
        })
      )
    )

    // Return the updated activity
    const updatedActivity = await prisma.lessonActivity.findUnique({
      where: { id },
      include: { video: true, sourceReferences: true, readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } } },
    })

    res.json({ success: true, activity: updatedActivity })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error reordering read blocks:', error)
    res.status(500).json({ success: false, error: 'Failed to reorder read blocks' })
  }
})

// ============================================================================
// Image Upload
// ============================================================================

/**
 * @openapi
 * /api/programs/{id}/cover-image:
 *   post:
 *     tags: [Programs]
 *     summary: Upload a cover image for a program
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
 *             required: [imageData]
 *             properties:
 *               imageData:
 *                 type: string
 *               contentType:
 *                 type: string
 *                 default: image/jpeg
 *     responses:
 *       200:
 *         description: Image uploaded
 */
router.post('/programs/:id/cover-image', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    const schema = z.object({
      imageData: z.string().min(1, 'Image data is required'),
      contentType: z.string().default('image/jpeg'),
    })

    const body = schema.parse(req.body)

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...mutationFilter(userId), isActive: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const base64Data = body.imageData.replace(/^data:image\/\w+;base64,/, '')
    const imageBuffer = Buffer.from(base64Data, 'base64')

    const timestamp = Date.now()
    const baseName = `program-${id}-${timestamp}`
    const extension = 'jpeg'

    const [originalBuffer, mediumBuffer, thumbBuffer] = await Promise.all([
      sharp(imageBuffer).resize(1200, null, { withoutEnlargement: true }).jpeg({ quality: 85 }).toBuffer(),
      sharp(imageBuffer).resize(400, null, { withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer(),
      sharp(imageBuffer).resize(150, null, { withoutEnlargement: true }).jpeg({ quality: 75 }).toBuffer(),
    ])

    const { url: coverImageUrl } = await uploadImageVariants(
      'programs',
      baseName,
      extension,
      originalBuffer,
      mediumBuffer,
      thumbBuffer,
    )

    const updatedProgram = await prisma.studyProgram.update({
      where: { id },
      data: { coverImageUrl },
      include: {
        template: { select: { id: true, name: true } },
        lessons: {
          orderBy: { dayNumber: 'asc' },
          include: {
            activities: { orderBy: { orderNumber: 'asc' } },
          },
        },
      },
    })

    // Auto-capture to media library with metadata
    if (userOrgId) {
      const imageMeta = await extractImageMetadata(imageBuffer)
      captureToLibrary({
        title: `${program.name} - Cover Image`,
        url: coverImageUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        fileSize: originalBuffer.length,
        thumbnailUrl: coverImageUrl.replace('.jpeg', '-thumb.jpeg'),
        organizationId: userOrgId,
        uploadedBy: userId,
        source: 'auto_capture',
        usageType: 'PROGRAM_COVER',
        resourceId: program.id,
        resourceName: program.name,
        width: imageMeta.width,
        height: imageMeta.height,
        aspectRatio: imageMeta.aspectRatio,
        dominantColor: imageMeta.dominantColor ?? undefined,
        fileHash: imageMeta.fileHash,
        exifData: imageMeta.exifData ?? undefined,
      })
    }

    res.json({ success: true, coverImageUrl, program: updatedProgram })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error uploading cover image:', error)
    res.status(500).json({ success: false, error: 'Failed to upload cover image' })
  }
})

// ============================================================================
// Add Lesson to Program
// ============================================================================

/**
 * @openapi
 * /api/programs/{id}/lessons:
 *   post:
 *     tags: [Programs]
 *     summary: Add a lesson to a study program
 *     description: |
 *       Appends a new lesson at the end of the study program.
 *       Template activities are copied into the new lesson automatically.
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
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 maxLength: 200
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Lesson created with activities
 *       404:
 *         description: Program not found or not owned by user
 */
router.post('/programs/:id/lessons', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const bodySchema = z.object({
      title: z.string().max(200).nullable().optional(),
    })
    const body = bodySchema.parse(req.body ?? {})

    // Verify program exists and caller has access
    const program = await prisma.studyProgram.findFirst({
      where: {
        id,
        ...mutationFilter(userId),
        isActive: true,
      },
      include: {
        template: {
          include: {
            activities: {
              orderBy: { orderNumber: 'asc' },
            },
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const lesson = await prisma.$transaction(async (tx) => {
      // Find current max dayNumber
      const maxDay = await tx.lesson.aggregate({
        where: { studyProgramId: id },
        _max: { dayNumber: true },
      })
      const newDayNumber = (maxDay._max.dayNumber ?? 0) + 1

      // Create the new lesson
      const newLesson = await tx.lesson.create({
        data: {
          studyProgramId: id,
          dayNumber: newDayNumber,
          title: body.title ?? program.template?.name ?? null,
        },
      })

      // Copy template activities into the lesson
      if (program.template?.activities.length) {
        const activityData = program.template.activities.map((ta) => ({
          lessonId: newLesson.id,
          activityType: ta.type,
          orderNumber: ta.orderNumber,
          title: ta.title,
          referenceTitle: ta.referenceTitle,
          helpTitle: ta.helpTitle,
          helpDescription: ta.helpDescription,
          helpAlwaysVisible: ta.helpAlwaysVisible,
          helpIcon: ta.helpIcon,
        }))

        await tx.lessonActivity.createMany({ data: activityData })

        // Create default unlocked read block for every READ activity
        const readActivities = await tx.lessonActivity.findMany({
          where: { lessonId: newLesson.id, activityType: 'READ' },
          select: { id: true },
        })
        if (readActivities.length > 0) {
          await tx.activityReadBlock.createMany({
            data: readActivities.map((a) => ({
              lessonActivityId: a.id,
              orderNumber: 1,
              isLocked: false,
            })),
          })
        }
      }

      // Sync days count with actual lesson count
      const lessonCount = await tx.lesson.count({ where: { studyProgramId: id } })
      await tx.studyProgram.update({
        where: { id },
        data: { days: lessonCount },
      })

      // Return the new lesson with activities
      return tx.lesson.findUnique({
        where: { id: newLesson.id },
        include: {
          activities: {
            orderBy: { orderNumber: 'asc' },
            include: {
              video: true,
              sourceReferences: true,
              readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
            },
          },
        },
      })
    })

    if (lesson) {
      trackActivity({
        actorId: userId,
        action: 'CREATED',
        resourceType: 'LESSON',
        resourceId: lesson.id,
        resourceName: lesson.title || `Day ${lesson.dayNumber}`,
        organizationId: program.organizationId,
        metadata: { programId: id, programName: program.name },
      })
    }

    res.json({ success: true, lesson })
  } catch (error) {
    console.error('Error adding lesson to program:', error)
    res.status(500).json({ success: false, error: 'Failed to add lesson' })
  }
})

// ============================================================================
// Update Lesson Title
// ============================================================================

/**
 * @openapi
 * /api/programs/{id}/lessons/{lessonId}:
 *   patch:
 *     tags: [Programs]
 *     summary: Update a lesson's title
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: path
 *         name: lessonId
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
 *         description: Lesson updated
 *       404:
 *         description: Program or lesson not found
 */
router.patch('/programs/:id/lessons/:lessonId', requireAuth, async (req, res) => {
  try {
    const { id, lessonId } = req.params
    const userId = (req.user as any).id

    const updateSchema = z.object({
      title: z.string().max(200).nullable(),
    })
    const data = updateSchema.parse(req.body)

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...mutationFilter(userId), isActive: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const lesson = await prisma.lesson.findFirst({
      where: { id: lessonId, studyProgramId: id },
    })

    if (!lesson) {
      return res.status(404).json({ success: false, error: 'Lesson not found' })
    }

    const updated = await prisma.lesson.update({
      where: { id: lessonId },
      data: { title: data.title },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
          include: {
            video: true,
            sourceReferences: true,
            readBlocks: { orderBy: { orderNumber: 'asc' }, include: { theme: { select: { id: true, slug: true, name: true } } } },
          },
        },
      },
    })

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'LESSON',
      resourceId: lessonId,
      resourceName: updated.title || `Day ${updated.dayNumber}`,
      organizationId: program.organizationId,
      metadata: { programId: id, programName: program.name },
    })

    res.json({ success: true, lesson: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating lesson:', error)
    res.status(500).json({ success: false, error: 'Failed to update lesson' })
  }
})

// ============================================================================
// Program Import / Export
// ============================================================================

/**
 * @openapi
 * /api/programs/{id}/export-preview:
 *   get:
 *     tags: [Programs]
 *     summary: Preview what a program export will contain
 *     description: |
 *       Returns a summary of the program that would be exported, including lesson count,
 *       activity counts by type, video and scripture reference counts, and cover image
 *       presence. Useful for showing a confirmation dialog before triggering the actual export.
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
 *         description: Export preview summary
 *       404:
 *         description: Program not found
 */
router.get('/programs/:id/export-preview', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    const program = await prisma.studyProgram.findFirst({
      where: { id: req.params.id, ...accessFilter(userOrgId, userId), isActive: true },
      select: {
        id: true,
        name: true,
        description: true,
        days: true,
        coverImageUrl: true,
        isPublished: true,
        createdAt: true,
        updatedAt: true,
        template: {
          select: { id: true, name: true },
        },
        lessons: {
          select: {
            activities: {
              select: {
                activityType: true,
                videoId: true,
                videoUrl: true,
                _count: {
                  select: {
                    sourceReferences: true,
                    readBlocks: true,
                  },
                },
              },
            },
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const allActivities = program.lessons.flatMap((l) => l.activities)
    const activityCounts = {
      READ: allActivities.filter((a) => a.activityType === 'READ').length,
      VIDEO: allActivities.filter((a) => a.activityType === 'VIDEO').length,
      USER_INPUT: allActivities.filter((a) => a.activityType === 'USER_INPUT').length,
    }
    const videoCount = allActivities.filter((a) => a.videoId || a.videoUrl).length
    const scriptureCount = allActivities.reduce((sum, a) => sum + a._count.sourceReferences, 0)
    const readBlockCount = allActivities.reduce((sum, a) => sum + a._count.readBlocks, 0)

    res.json({
      success: true,
      preview: {
        id: program.id,
        name: program.name,
        description: program.description,
        days: program.days,
        coverImageUrl: program.coverImageUrl,
        isPublished: program.isPublished,
        template: program.template,
        createdAt: program.createdAt,
        updatedAt: program.updatedAt,
        counts: {
          lessons: program.lessons.length,
          activities: allActivities.length,
          activityTypes: activityCounts,
          videos: videoCount,
          scriptureReferences: scriptureCount,
          readBlocks: readBlockCount,
        },
      },
    })
  } catch (error) {
    console.error('Error generating export preview:', error)
    res.status(500).json({ success: false, error: 'Failed to generate export preview' })
  }
})

/**
 * @openapi
 * /api/programs/{id}/export:
 *   post:
 *     tags: [Programs]
 *     summary: Export a study program as a ZIP file
 *     description: |
 *       Exports the complete study program (lessons, activities, read blocks, source references,
 *       template) as a ZIP file containing a manifest.json. Media (cover images, videos) are
 *       referenced by URL, not embedded. The exported file can be imported by any authenticated
 *       user, even in a different organization.
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
 *         description: ZIP file download
 *         content:
 *           application/zip:
 *             schema:
 *               type: string
 *               format: binary
 *       404:
 *         description: Program not found
 */
router.post('/programs/:id/export', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    const result = await exportProgram(req.params.id, userId)

    if (!result.success) {
      return res.status(404).json({ success: false, error: result.error })
    }

    res.set({
      'Content-Type': 'application/zip',
      'Content-Disposition': `attachment; filename="${result.filename}"`,
    })
    res.send(result.buffer)
  } catch (error) {
    console.error('Error exporting program:', error)
    res.status(500).json({ success: false, error: 'Failed to export program' })
  }
})

/**
 * @openapi
 * /api/programs/import:
 *   post:
 *     tags: [Programs]
 *     summary: Import a study program from a ZIP file
 *     description: |
 *       Accepts a ZIP file previously exported via the export endpoint. Creates a new study
 *       program with all lessons, activities, read blocks, and source references. The program
 *       is always created as a draft (isPublished=false). A new lesson template is created
 *       owned by the importing user. Video references are preserved as URLs but no Video
 *       records are created.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - file
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *                 description: ZIP file from program export
 *     responses:
 *       200:
 *         description: Program imported successfully
 *       400:
 *         description: Invalid ZIP or manifest
 */
router.post('/programs/import', requireAuth, uploadZip.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'No file uploaded' })
    }

    const userId = (req.user as any).id
    const result = await importProgram(req.file.buffer, userId)

    if (!result.success) {
      return res.status(400).json({ success: false, error: result.error })
    }

    if (result.program) {
      const creatorOrg = await prisma.organization.findFirst({
        where: { ownerId: userId },
        select: { id: true },
      })

      trackActivity({
        actorId: userId,
        action: 'CREATED',
        resourceType: 'PROGRAM',
        resourceId: result.program.id,
        resourceName: result.program.name,
        organizationId: creatorOrg?.id,
        metadata: { importedFrom: 'zip' },
      })
    }

    res.json({ success: true, program: result.program, warnings: result.warnings })
  } catch (error) {
    console.error('Error importing program:', error)
    res.status(500).json({ success: false, error: 'Failed to import program' })
  }
})

// ============================================================================
// Program Tag Management
// ============================================================================

/**
 * @openapi
 * /api/programs/{id}/tags:
 *   get:
 *     tags: [Programs]
 *     summary: Get tags for a program
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
 *         description: List of tags
 */
router.get('/programs/:id/tags', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...accessFilter(userOrgId, userId), isActive: true },
      select: {
        id: true,
        tags: { select: { id: true, tag: true, createdAt: true }, orderBy: { createdAt: 'asc' } },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    res.json({ success: true, tags: program.tags.map((t) => t.tag) })
  } catch (error) {
    console.error('Error fetching program tags:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /api/programs/{id}/tags:
 *   post:
 *     tags: [Programs]
 *     summary: Add tags to a program
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
router.post('/programs/:id/tags', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const { tags } = z.object({ tags: z.array(z.string()).min(1).max(20) }).parse(req.body)

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...mutationFilter(userId), isActive: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const normalized = tags.map((t) => t.toLowerCase().trim()).filter(Boolean)

    await Promise.all(
      normalized.map((tag) =>
        prisma.studyProgramTag.upsert({
          where: { studyProgramId_tag: { studyProgramId: id, tag } },
          update: {},
          create: { studyProgramId: id, tag },
        })
      )
    )

    const allTags = await prisma.studyProgramTag.findMany({
      where: { studyProgramId: id },
      select: { tag: true },
      orderBy: { createdAt: 'asc' },
    })

    res.json({ success: true, tags: allTags.map((t) => t.tag) })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors[0].message })
    }
    console.error('Error adding program tags:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /api/programs/{id}/tags:
 *   delete:
 *     tags: [Programs]
 *     summary: Remove tags from a program
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
router.delete('/programs/:id/tags', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const { tags } = z.object({ tags: z.array(z.string()).min(1) }).parse(req.body)

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...mutationFilter(userId), isActive: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const normalized = tags.map((t) => t.toLowerCase().trim()).filter(Boolean)

    await prisma.studyProgramTag.deleteMany({
      where: { studyProgramId: id, tag: { in: normalized } },
    })

    const allTags = await prisma.studyProgramTag.findMany({
      where: { studyProgramId: id },
      select: { tag: true },
      orderBy: { createdAt: 'asc' },
    })

    res.json({ success: true, tags: allTags.map((t) => t.tag) })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors[0].message })
    }
    console.error('Error removing program tags:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

// ============================================================================
// AI Tag Suggestions
// ============================================================================

/**
 * @openapi
 * /api/programs/{id}/suggest-tags:
 *   post:
 *     tags: [Programs]
 *     summary: Get AI-suggested tags for a program
 *     description: |
 *       Sends the full program content (lessons, activities, scripture references)
 *       to Claude AI and returns 5-10 suggested tags.
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
 *         description: Suggested tags
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 tags:
 *                   type: array
 *                   items:
 *                     type: string
 */
router.post('/programs/:id/suggest-tags', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...accessFilter(userOrgId, userId), isActive: true },
      include: {
        lessons: {
          orderBy: { dayNumber: 'asc' },
          include: {
            activities: {
              orderBy: { orderNumber: 'asc' },
              select: {
                activityType: true,
                title: true,
                referenceTitle: true,
                readContent: true,
                helpTitle: true,
                helpDescription: true,
              },
            },
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const result = await suggestProgramTags({
      name: program.name,
      description: program.description,
      days: program.days,
      lessons: program.lessons.map((l) => ({
        dayNumber: l.dayNumber,
        title: l.title,
        activities: l.activities,
      })),
    })

    res.json({ success: true, tags: result.tags })
  } catch (error) {
    console.error('Error suggesting program tags:', error)
    res.status(500).json({ success: false, error: 'Failed to generate tag suggestions' })
  }
})

/**
 * @openapi
 * /api/programs/{id}/suggest-and-apply-tags:
 *   post:
 *     tags: [Programs]
 *     summary: Get AI-suggested tags and apply them to the program
 *     description: |
 *       Combines suggest-tags and add-tags into one call.
 *       Gets suggestions from Claude and saves them to the program.
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
 *         description: Tags suggested and applied
 */
router.post('/programs/:id/suggest-and-apply-tags', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...mutationFilter(userId), isActive: true },
      include: {
        lessons: {
          orderBy: { dayNumber: 'asc' },
          include: {
            activities: {
              orderBy: { orderNumber: 'asc' },
              select: {
                activityType: true,
                title: true,
                referenceTitle: true,
                readContent: true,
                helpTitle: true,
                helpDescription: true,
              },
            },
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const result = await suggestProgramTags({
      name: program.name,
      description: program.description,
      days: program.days,
      lessons: program.lessons.map((l) => ({
        dayNumber: l.dayNumber,
        title: l.title,
        activities: l.activities,
      })),
    })

    // Apply suggested tags
    await Promise.all(
      result.tags.map((tag) =>
        prisma.studyProgramTag.upsert({
          where: { studyProgramId_tag: { studyProgramId: id, tag } },
          update: {},
          create: { studyProgramId: id, tag },
        })
      )
    )

    // Return all tags (existing + new)
    const allTags = await prisma.studyProgramTag.findMany({
      where: { studyProgramId: id },
      select: { tag: true },
      orderBy: { createdAt: 'asc' },
    })

    res.json({
      success: true,
      suggestedTags: result.tags,
      allTags: allTags.map((t) => t.tag),
    })
  } catch (error) {
    console.error('Error suggesting and applying tags:', error)
    res.status(500).json({ success: false, error: 'Failed to generate and apply tag suggestions' })
  }
})

export default router
