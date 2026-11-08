import crypto from 'crypto'
import { Router } from 'express'
import { z } from 'zod'
import multer from 'multer'
import { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { deleteFromR2, extractKeyFromUrl } from '../services/storage.js'
import { trackActivity } from '../services/activity.js'
import { exportProgram, importProgram, previewProgramExport } from '../services/program-export.js'
import { captureToLibrary, getUserOrgId, checkLibraryPick, LibraryPickError, recordLibraryPick } from '../services/media-library.js'
import { extractImageMetadata } from '../services/media-metadata.js'
import { suggestProgramTags } from '../services/claude.js'
import { publishProgram } from '../services/program-publish.service.js'
import { parseContentBody, sendContentError } from '../services/content-errors.js'
import {
  createLesson,
  createProgramFromTemplate,
  deleteLesson,
  getProgramForUser,
  loadProgramPayload,
  loadTemplate,
  programContentForAi,
  reorderLessons,
  resizeProgramLessons,
  updateLesson,
} from '../services/program-lessons.service.js'
import { extractYouTubeVideoId, fetchYouTubeMetadata } from '../services/youtube.js'
import { isSuperAdmin, programManageFilter } from '../services/permission.js'
import { AGE_RANGE_INVERTED_MESSAGE, isAgeRangeInverted } from '../services/group-fields.js'
import { CoverUploadError, coverFramingSchema, saveCover } from '../services/group-cover.js'
import { deleteProgramPermanently } from '../services/program-permanent-delete.service.js'
import {
  PROGRAM_NAME_INCLUDE,
  buildProgramListWhere,
  createBlankProgram,
  isEligibleProgramLeader,
  privateProgramVisibility,
  programListScope,
  toProgramPayload,
} from '../services/study-program.service.js'

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
 * program or its nested resources). Org-scoped, matching `canManageOrgContent`
 * (the rule already applied to a program's activities and read blocks): the
 * creator, the program org's owner, any role-holder in that org, or a super
 * admin may mutate. A program that matches none of these falls through the
 * filter and reads as 404 — preserving the existing "stranger gets 404"
 * behavior without a separate ownership branch in every handler.
 */
// ui2-programs D20: the filter lives in the service layer now (`permission.programManageFilter`).
const mutationFilter = programManageFilter

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
      name: z.string().trim().min(1).max(200),
      description: z.string().max(2000).optional(),
      // ui2-programs D8: optional — without it the program is created blank (no lessons, days 0).
      templateId: z.string().uuid().optional(),
      days: z.number().int().min(1).max(360).default(30),
      coverImageUrl: z.string().url().optional(),
      isPublished: z.boolean().default(false),
    })

    const body = schema.parse(req.body)
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    // ui2-programs D8: a title alone makes a blank program — `days` and `isPublished` are ignored on
    // this path (an empty program can't be enrolled, so it is never published at create).
    if (!body.templateId) {
      const blank = await createBlankProgram({
        name: body.name,
        description: body.description ?? null,
        userId,
        organizationId: userOrgId ?? null,
      })
      trackActivity({
        actorId: userId,
        action: 'CREATED',
        resourceType: 'PROGRAM',
        resourceId: blank.id,
        resourceName: blank.name,
        organizationId: userOrgId,
      })
      return res.json({ success: true, program: toProgramPayload(blank) })
    }
    const templateId = body.templateId

    // One program, its lessons and their drafts in one transaction (the service owns the template access check).
    const programId = await createProgramFromTemplate({
      userId,
      organizationId: userOrgId ?? null,
      name: body.name,
      description: body.description,
      templateId,
      days: body.days,
      coverImageUrl: body.coverImageUrl,
      isPublished: body.isPublished,
    })
    if (!programId) {
      return res.status(404).json({ success: false, error: 'Template not found' })
    }

    // A program created published needs its baseline version to be enrollable (as the PATCH toggle does).
    if (body.isPublished) {
      try {
        await publishProgram(userId, programId)
      } catch (versionError) {
        console.error('Failed to cut baseline program version:', versionError)
      }
    }
    const program = (await loadProgramPayload(programId))?.program ?? null

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
 *         description: List of programs; each carries completedEnrollmentCount (integer, enrollments ended before today UTC)
 */
router.get('/programs', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    // Scope by the caller's real role, not by auth method — a self-minted API
    // key must not see more than the user's session would. Super admins (incl.
    // the global admin key's owner) see all orgs; everyone else sees every org
    // they manage plus their own programs (ui2-programs D14).
    const isSuperAdminUser = await isSuperAdmin(userId)
    const orgIds = isSuperAdminUser ? null : await programListScope(userId)

    // ui2-programs D14: ?orgId= narrows to one org of the caller's scope.
    const orgId = typeof req.query.orgId === 'string' && req.query.orgId ? req.query.orgId : undefined
    if (orgId && orgIds !== null && !orgIds.includes(orgId)) {
      return res.status(400).json({ success: false, error: 'orgId is not one of your organizations' })
    }

    const split = (v: unknown) =>
      typeof v === 'string' ? v.split(',').map((x) => x.trim()).filter(Boolean) : []

    const where = buildProgramListWhere({
      userId,
      orgIds,
      // ui2-programs D13: other leaders' private programs are not listed.
      privacy: await privateProgramVisibility(userId),
      includeInactive: isSuperAdminUser && req.query.includeInactive === 'true',
      orgId,
      creatorId: typeof req.query.creatorId === 'string' ? req.query.creatorId : undefined,
      // Multiple group leaders — matches the program's leader or its creator (D14).
      leaders: split(req.query.leaders),
      isPublished: req.query.isPublished === 'true' ? true : req.query.isPublished === 'false' ? false : undefined,
      groupId: typeof req.query.groupId === 'string' ? req.query.groupId : undefined,
      // Tag(s) — comma-separated, matches programs with any of the tags
      tags: split(req.query.tag).map((t) => t.toLowerCase()),
    })

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
        // ui2-programs D15: the list carries everything the program page renders, so a list refresh
        // never blanks a cached program's settings on the phone.
        organizationId: true,
        leaderId: true,
        isPrivate: true,
        ageRangeMin: true,
        ageRangeMax: true,
        maxMembers: true,
        memberDirectoryAccess: true,
        coverOriginalUrl: true,
        coverFraming: true,
        ...PROGRAM_NAME_INCLUDE,
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

    // StudyProgram has no Organization relation — one batched lookup for the names (as groups D10).
    const programOrgIds = [...new Set(programs.map((p) => p.organizationId).filter((id): id is string => !!id))]
    const orgs = programOrgIds.length
      ? await prisma.organization.findMany({ where: { id: { in: programOrgIds } }, select: { id: true, name: true } })
      : []
    const orgName = new Map(orgs.map((o) => [o.id, o.name]))

    // ui2-enrollment-create D8: enrollments that ended before today (UTC), one grouped query —
    // a filtered _count can't sit beside the _count.enrollments the iPhone already reads.
    const startOfTodayUtc = new Date()
    startOfTodayUtc.setUTCHours(0, 0, 0, 0)
    const completed = programs.length
      ? await prisma.enrollment.groupBy({
          by: ['studyProgramId'],
          where: { studyProgramId: { in: programs.map((p) => p.id) }, endDate: { lt: startOfTodayUtc } },
          _count: { _all: true },
        })
      : []
    const completedCount = new Map(completed.map((c) => [c.studyProgramId, c._count._all]))

    res.json({
      success: true,
      programs: programs.map((p) => ({
        ...toProgramPayload(p),
        completedEnrollmentCount: completedCount.get(p.id) ?? 0,
        organizationName: p.organizationId ? (orgName.get(p.organizationId) ?? null) : null,
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
    const userId = (req.user as any).id
    const result = await getProgramForUser(userId, req.params.id, {
      page: parseInt(req.query.lessonPage as string),
      limit: parseInt(req.query.lessonLimit as string),
    })
    if (!result) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }
    res.json({ success: true, ...result })
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
    const userOrgId = await getUserOrgId(userId)

    const schema = z.object({
      name: z.string().min(1).max(200).optional(),
      // ui2-programs D10/D15: null clears the description.
      description: z.string().max(2000).optional().nullable(),
      days: z.number().int().min(1).max(360).optional(),
      templateId: z.string().uuid().optional(),
      coverImageUrl: z.string().url().optional().nullable(),
      isPublished: z.boolean().optional(),
      organizationId: z.string().uuid().optional(),
      // ui2-programs D15: the program settings, mirroring PATCH /api/groups/:id.
      isPrivate: z.boolean().optional(),
      ageRange: z
        .object({
          min: z.number().int().min(0).max(120).optional().nullable(),
          max: z.number().int().min(0).max(120).optional().nullable(),
        })
        .optional()
        .nullable(),
      maxMembers: z.number().int().min(1).optional().nullable(),
      memberDirectoryAccess: z.enum(['ALLOWED', 'NAMES_ONLY', 'NOT_ALLOWED']).optional(),
      leaderId: z.string().uuid().optional().nullable(),
    })

    const { ageRange, leaderId, organizationId, ...body } = schema.parse(req.body)
    if (isAgeRangeInverted(ageRange)) {
      return res.status(400).json({ success: false, error: AGE_RANGE_INVERTED_MESSAGE })
    }

    // Authorization is by the caller's actual permissions, NOT by auth method:
    // a self-minted API key must not grant more than the user's session would.
    // mutationFilter returns {} for super admins (incl. the global admin key's
    // owner), so they retain full access; everyone else is org-scoped.
    const existingProgram = await prisma.studyProgram.findFirst({
      where: { id, ...(await mutationFilter(userId)), isActive: true },
    })

    if (!existingProgram) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    // ui2-programs D15/D18: the settings the phone edits, validated before anything is written.
    const settings: Prisma.StudyProgramUncheckedUpdateInput = {}
    if (ageRange !== undefined) {
      const min = ageRange === null ? null : ageRange.min !== undefined ? ageRange.min : existingProgram.ageRangeMin
      const max = ageRange === null ? null : ageRange.max !== undefined ? ageRange.max : existingProgram.ageRangeMax
      // One bound sent is checked against the stored other bound.
      if (isAgeRangeInverted({ min, max })) {
        return res.status(400).json({ success: false, error: AGE_RANGE_INVERTED_MESSAGE })
      }
      settings.ageRangeMin = min
      settings.ageRangeMax = max
    }
    // D18: a program may only move into an org the caller belongs to (as PATCH /api/groups/:id).
    if (organizationId !== undefined) {
      const targetOrg = await prisma.organization.findUnique({
        where: { id: organizationId },
        select: { id: true, ownerId: true },
      })
      if (!targetOrg) {
        return res.status(400).json({ success: false, error: 'Organization not found' })
      }
      if (!(await isSuperAdmin(userId))) {
        const belongs =
          targetOrg.ownerId === userId ||
          (await prisma.userRole.findFirst({
            where: { userId, organizationId: targetOrg.id },
            select: { id: true },
          })) !== null
        if (!belongs) {
          return res.status(403).json({ success: false, error: 'You do not belong to that organization' })
        }
      }
      settings.organizationId = targetOrg.id
    }
    // D15: the leader must belong to the program's org (after any move).
    if (leaderId !== undefined) {
      if (leaderId !== null) {
        const org = organizationId ?? existingProgram.organizationId
        if (!(await isEligibleProgramLeader(leaderId, org, existingProgram.creatorId))) {
          return res.status(400).json({ success: false, error: "The leader must belong to the program's organization" })
        }
      }
      settings.leaderId = leaderId
    }
    if (body.coverImageUrl !== undefined) {
      // ui2-programs D11: a cover set here drops the stored original and framing (group-cover-image D9).
      settings.coverOriginalUrl = null
      settings.coverFraming = Prisma.DbNull
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

    // If days changed, handle lesson creation/deletion (new lessons come from the new or existing template; D36 removal)
    if (body.days !== undefined && body.days !== existingProgram.days) {
      await prisma.$transaction(async (tx) => {
        const template = newTemplate ?? (await loadTemplate(tx, existingProgram.templateId))
        await resizeProgramLessons(tx, id, body.days!, template)
        await tx.studyProgram.update({
          where: { id },
          data: {
            ...body,
            ...settings,
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
          ...settings,
          ...(newTemplate ? { templateId: newTemplate.id } : {}),
          ...(publishedAt !== undefined ? { publishedAt } : {}),
          updatedById: userId,
        },
      })
    }

    // Transitioning to published freezes the drafts into the baseline ProgramVersion so
    // enrollments created from here on have a version to sync against (an unchanged program is a no-op).
    if (body.isPublished === true && !existingProgram.isPublished) {
      try {
        await publishProgram(userId, id)
      } catch (versionError) {
        // The publish toggle itself succeeded; version cutting must not undo it
        console.error('Failed to cut baseline program version:', versionError)
      }
    }

    // Fetch updated program (after the publish above so its lessons show their published versions)
    const program = (await loadProgramPayload(id))?.program ?? null

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
 * /api/programs/{id}/publish:
 *   post:
 *     tags: [Programs]
 *     summary: Publish the program's drafts as a new program version
 *     description: |
 *       Freezes each changed lesson draft, discards unchanged drafts and writes one ProgramVersion.
 *       AUTO enrollments move onto it in the same transaction. Nothing changed returns
 *       `{ programVersion: null, changedLessonIds: [] }`.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               changeSummary:
 *                 type: string
 *                 maxLength: 2000
 *     responses:
 *       200:
 *         description: "{ programVersion | null, changedLessonIds }"
 *       400:
 *         description: VALIDATION
 *       404:
 *         description: Program not found
 */
const publishBody = z.object({ changeSummary: z.string().max(2000).optional() })

router.post('/programs/:id/publish', requireAuth, async (req, res) => {
  try {
    const body = parseContentBody(publishBody, req.body ?? {})
    res.json(await publishProgram((req.user as any).id, req.params.id, body))
  } catch (error) {
    sendContentError(res, error)
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
    const { lessonOrder } = parseContentBody(z.object({ lessonOrder: z.array(z.string().uuid()).min(1) }), req.body)

    const program = await reorderLessons(userId, id, lessonOrder)

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'PROGRAM',
      resourceId: id,
      resourceName: program.name,
      organizationId: program.organizationId,
      metadata: { reordered: 'lessons' },
    })

    res.json({ success: true, program })
  } catch (error) {
    sendContentError(res, error)
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

    // Deliberate carve-out from the org-content rule (`mutationFilter`):
    // deletion is CREATOR-only (+ super admin). Org role-holders may edit
    // org programs but never delete someone else's — a non-creator falls
    // through the filter and reads as the existing 404.
    const superAdmin = await isSuperAdmin(userId)
    const program = await prisma.studyProgram.findFirst({
      where: { id, isActive: true, ...(superAdmin ? {} : { creatorId: userId }) },
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

    await deleteProgramPermanently(id)

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
router.delete('/programs/:programId/lessons/:lessonId', requireAuth, async (req, res) => {
  try {
    const { programId, lessonId } = req.params
    await deleteLesson((req.user as any).id, lessonId, programId)
    res.json({ success: true })
  } catch (error) {
    sendContentError(res, error)
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

    // ui2-programs D11: the group route's body — the legacy (imageData, contentType) still works;
    // framing and the original are optional, and an original needs its framing.
    const schema = z.object({
      imageData: z.string().min(1, 'Image data is required'),
      contentType: z.string().default('image/jpeg'),
      framing: coverFramingSchema.optional(),
      originalData: z.string().min(1).optional(),
      // media-page SC3 / D3: the capture date of a NEW pick (none on a re-edit); parseTakenAt validates it.
      takenAt: z.string().optional(),
      // media-library D10: the library item this cover was framed from (link, don't capture).
      sourceMediaId: z.string().uuid().optional(),
    })

    const body = schema.parse(req.body)
    if (body.originalData !== undefined && body.framing === undefined) {
      return res.status(400).json({ success: false, error: 'originalData requires framing' })
    }

    const program = await prisma.studyProgram.findFirst({
      where: { id, ...(await mutationFilter(userId)), isActive: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    if (body.sourceMediaId) await checkLibraryPick(body.sourceMediaId, program.organizationId)

    const saved = await saveCover(
      { kind: 'program', id: program.id, coverOriginalUrl: program.coverOriginalUrl },
      { imageData: body.imageData, framing: body.framing, originalData: body.originalData },
    )

    const updatedProgram = (await loadProgramPayload(id))?.program ?? null

    // Auto-capture a new image to the program org's media library; a re-edit captures nothing.
    if (body.sourceMediaId) {
      await recordLibraryPick({ sourceMediaId: body.sourceMediaId, usageType: 'PROGRAM_COVER', resourceId: program.id, resourceName: program.name })
    } else if (program.organizationId && saved.isNewImage) {
      const imageMeta = await extractImageMetadata(saved.renderedBuffer)
      captureToLibrary({
        title: `${program.name} - Cover Image`,
        url: saved.coverImageUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        fileSize: saved.renderedSize,
        thumbnailUrl: saved.coverImageUrl.replace('.jpeg', '-thumb.jpeg'),
        organizationId: program.organizationId,
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
        takenAt: body.takenAt,
      })
    }

    res.json({
      success: true,
      coverImageUrl: saved.coverImageUrl,
      coverOriginalUrl: saved.coverOriginalUrl,
      coverFraming: saved.coverFraming,
      program: updatedProgram,
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    if (error instanceof LibraryPickError) {
      return res.status(error.status).json({ success: false, error: error.message })
    }
    if (error instanceof CoverUploadError) {
      return res.status(error.status).json({ success: false, error: error.message })
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
    const body = parseContentBody(z.object({ title: z.string().max(200).nullable().optional() }), req.body ?? {})

    const { lesson, media, program } = await createLesson(userId, id, body)

    trackActivity({
      actorId: userId,
      action: 'CREATED',
      resourceType: 'LESSON',
      resourceId: lesson.id,
      resourceName: lesson.title || `Day ${lesson.position}`,
      organizationId: program.organizationId,
      metadata: { programId: id, programName: program.name },
    })

    res.json({ success: true, lesson, media })
  } catch (error) {
    sendContentError(res, error)
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
    const data = parseContentBody(z.object({ title: z.string().max(200).nullable() }), req.body)

    const { lesson, media, program } = await updateLesson(userId, lessonId, data, id)

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'LESSON',
      resourceId: lessonId,
      resourceName: lesson.title || `Day ${lesson.position}`,
      organizationId: program.organizationId,
      metadata: { programId: id, programName: program.name },
    })

    res.json({ success: true, lesson, media })
  } catch (error) {
    sendContentError(res, error)
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
    const preview = await previewProgramExport(req.params.id, userId)
    if (!preview) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }
    res.json({ success: true, preview })
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
 *       Exports the program (format version 2: each live lesson's draft, else its latest published
 *       version, with every activity's kind, title and document) as a ZIP file containing a
 *       manifest.json. Media are referenced by id, not embedded.
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
 *       Accepts a version 2 ZIP file from the export endpoint. Creates a new program, unpublished,
 *       whose lessons each get a draft with new activity keys. Every document is validated and its
 *       media checked as a lesson-version POST does. A version 1 file is 400 VALIDATION.
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
 *       201:
 *         description: Program imported successfully
 *       400:
 *         description: Invalid ZIP or manifest, or an unsupported export version
 */
router.post('/programs/import', requireAuth, uploadZip.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'No file uploaded' })
    }

    const userId = (req.user as any).id
    const result = await importProgram(req.file.buffer, userId)

    if (!result.success) {
      return res.status(result.status ?? 400).json({ success: false, error: result.error, code: result.code })
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

    res.status(201).json({ success: true, program: result.program, warnings: result.warnings })
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
      where: { id, ...(await mutationFilter(userId)), isActive: true },
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
      where: { id, ...(await mutationFilter(userId)), isActive: true },
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
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const result = await suggestProgramTags({
      name: program.name,
      description: program.description,
      days: program.days,
      lessons: await programContentForAi(program.id),
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
      where: { id, ...(await mutationFilter(userId)), isActive: true },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }

    const result = await suggestProgramTags({
      name: program.name,
      description: program.description,
      days: program.days,
      lessons: await programContentForAi(program.id),
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
