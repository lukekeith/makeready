import { Router } from 'express'
import { z } from 'zod'
import sharp from 'sharp'
import QRCode from 'qrcode'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { uploadImageVariants } from '../services/storage.js'
import { generateUniqueGroupCode, normalizeGroupCode } from '../lib/group-code.js'
import { trackActivity } from '../services/activity.js'
import { captureToLibrary } from '../services/media-library.js'
import { isSuperAdmin, groupManageFilter } from '../services/permission.js'
import { extractImageMetadata } from '../services/media-metadata.js'
import { resolveUserOrganizationId } from '../services/organization.js'

const router = Router()

// ============================================================================
// Group CRUD
// ============================================================================

/**
 * @openapi
 * /api/groups:
 *   post:
 *     tags: [Groups]
 *     summary: Create a new group
 *     description: Creates a new group in the user's organization.
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
 *             properties:
 *               name:
 *                 type: string
 *                 maxLength: 200
 *               description:
 *                 type: string
 *                 maxLength: 2000
 *               coverImageUrl:
 *                 type: string
 *                 format: uri
 *               isPrivate:
 *                 type: boolean
 *                 default: false
 *               allowInvites:
 *                 type: boolean
 *                 default: true
 *               welcomeMessage:
 *                 type: string
 *                 maxLength: 1000
 *               ageRange:
 *                 type: object
 *                 properties:
 *                   min:
 *                     type: integer
 *                     minimum: 0
 *                     maximum: 120
 *                   max:
 *                     type: integer
 *                     minimum: 0
 *                     maximum: 120
 *               maxMembers:
 *                 type: integer
 *                 minimum: 1
 *     responses:
 *       200:
 *         description: Group created
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 group:
 *                   $ref: '#/components/schemas/Group'
 *       400:
 *         description: Validation error or no organization
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/', requireAuth, async (req, res) => {
  try {
    const schema = z.object({
      name: z.string().min(1).max(200),
      description: z.string().max(2000).optional(),
      coverImageUrl: z.string().url().optional(),
      isPrivate: z.boolean().default(false),
      allowInvites: z.boolean().default(true),
      welcomeMessage: z.string().max(1000).optional(),
      ageRange: z
        .object({
          min: z.number().int().min(0).max(120).optional(),
          max: z.number().int().min(0).max(120).optional(),
        })
        .optional(),
      maxMembers: z.number().int().min(1).optional(),
    })

    const body = schema.parse(req.body)
    const userId = (req.user as any).id

    // Resolve the organization this group belongs to. A user can create groups
    // in any org they belong to — one they own OR hold a role in — so a
    // role-granted Owner/Admin isn't blocked, and the group's organization
    // association is always set correctly. Every group MUST have an org.
    const organizationId = await resolveUserOrganizationId(userId)

    if (!organizationId) {
      return res.status(400).json({
        success: false,
        error: 'You must belong to an organization before creating groups'
      })
    }

    // Generate unique 6-character code for public joining
    const code = await generateUniqueGroupCode()

    const group = await prisma.group.create({
      data: {
        name: body.name,
        organizationId,
        code,
        description: body.description,
        coverImageUrl: body.coverImageUrl,
        isPrivate: body.isPrivate,
        allowInvites: body.allowInvites,
        welcomeMessage: body.welcomeMessage,
        ageRangeMin: body.ageRange?.min,
        ageRangeMax: body.ageRange?.max,
        maxMembers: body.maxMembers,
        creatorId: userId,
      },
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
      },
    })

    // Transform response to match iOS model
    const response = {
      id: group.id,
      organizationId: group.organizationId,
      code: group.code,
      name: group.name,
      description: group.description,
      coverImageUrl: group.coverImageUrl,
      isPrivate: group.isPrivate,
      allowInvites: group.allowInvites,
      welcomeMessage: group.welcomeMessage,
      ageRange:
        group.ageRangeMin !== null || group.ageRangeMax !== null
          ? { min: group.ageRangeMin, max: group.ageRangeMax }
          : null,
      maxMembers: group.maxMembers,
      memberCount: group._count.members,
      creatorId: group.creatorId,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    }

    trackActivity({
      actorId: userId,
      action: 'CREATED',
      resourceType: 'GROUP',
      resourceId: group.id,
      resourceName: group.name,
      organizationId: group.organizationId,
      groupId: group.id,
    })

    res.json({ success: true, group: response })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error creating group:', error)
    res.status(500).json({ success: false, error: 'Failed to create group' })
  }
})

/**
 * @openapi
 * /api/groups:
 *   get:
 *     tags: [Groups]
 *     summary: List user's groups
 *     description: Returns all groups created by the authenticated user.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of groups
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 groups:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Group'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    // Scope by the caller's real role, not by auth method — a self-minted API
    // key must not list more than the user's session would. Group leaders/owners
    // see every group in their org; super admins see all; others see their own.
    const groups = await prisma.group.findMany({
      where: {
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
      orderBy: { updatedAt: 'desc' },
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
      },
    })

    // Transform response to match iOS model
    const response = groups.map((group) => ({
      id: group.id,
      code: group.code,
      name: group.name,
      description: group.description,
      coverImageUrl: group.coverImageUrl,
      isPrivate: group.isPrivate,
      allowInvites: group.allowInvites,
      welcomeMessage: group.welcomeMessage,
      ageRange:
        group.ageRangeMin !== null || group.ageRangeMax !== null
          ? { min: group.ageRangeMin, max: group.ageRangeMax }
          : null,
      maxMembers: group.maxMembers,
      memberCount: group._count.members,
      creatorId: group.creatorId,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    }))

    res.json({ success: true, groups: response })
  } catch (error) {
    console.error('Error fetching groups:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch groups' })
  }
})

/**
 * @openapi
 * /api/groups/code/{code}:
 *   get:
 *     tags: [Groups]
 *     summary: Look up group by join code
 *     description: |
 *       Looks up a group by its 6-character join code. No authentication required.
 *       If member is authenticated, returns their membership status.
 *     parameters:
 *       - in: path
 *         name: code
 *         required: true
 *         schema:
 *           type: string
 *           pattern: '^[A-Za-z0-9]{6}$'
 *         description: 6-character group join code
 *     responses:
 *       200:
 *         description: Group found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 group:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     code:
 *                       type: string
 *                     name:
 *                       type: string
 *                     description:
 *                       type: string
 *                       nullable: true
 *                     coverImageUrl:
 *                       type: string
 *                       nullable: true
 *                     isPrivate:
 *                       type: boolean
 *                     memberCount:
 *                       type: integer
 *                 member:
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Member'
 *                     - type: 'null'
 *                 membershipStatus:
 *                   type: string
 *                   enum: [member, pending, approved, rejected, none]
 *                 membership:
 *                   type: object
 *                   nullable: true
 *                 request:
 *                   type: object
 *                   nullable: true
 *       400:
 *         description: Invalid code format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/code/:code', async (req, res) => {
  try {
    const { code } = req.params
    const normalizedCode = normalizeGroupCode(code)

    // Validate code format (6 alphanumeric characters)
    if (!/^[A-Z0-9]{6}$/.test(normalizedCode)) {
      return res.status(400).json({ success: false, error: 'Invalid group code format' })
    }

    const group = await prisma.group.findFirst({
      where: {
        code: normalizedCode,
        isActive: true,
      },
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
        creator: {
          select: {
            id: true,
            name: true,
            picture: true,
          },
        },
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Build group response
    const groupResponse = {
      id: group.id,
      code: group.code,
      name: group.name,
      description: group.description,
      coverImageUrl: group.coverImageUrl,
      isPrivate: group.isPrivate,
      memberCount: group._count.members,
      organizationId: group.organizationId,
      creator: group.creator,
      createdAt: group.createdAt,
    }

    // Check if member is authenticated (optional - no error if not)
    const memberId = req.session?.memberId

    if (!memberId) {
      // Not authenticated - return just the group
      return res.json({
        success: true,
        group: groupResponse,
        member: null,
        membershipStatus: 'none',
      })
    }

    // Load member info
    const member = await prisma.member.findUnique({
      where: { id: memberId },
      select: {
        id: true,
        phoneNumber: true,
        firstName: true,
        lastName: true,
        isActive: true,
      },
    })

    if (!member || !member.isActive) {
      // Member not found or inactive - treat as not authenticated
      return res.json({
        success: true,
        group: groupResponse,
        member: null,
        membershipStatus: 'none',
      })
    }

    // Check if member is already in the group
    const membership = await prisma.groupMember.findFirst({
      where: {
        groupId: group.id,
        memberId: member.id,
        isActive: true,
      },
      select: {
        id: true,
        role: true,
        joinedAt: true,
      },
    })

    if (membership) {
      return res.json({
        success: true,
        group: groupResponse,
        member: {
          id: member.id,
          phoneNumber: member.phoneNumber,
          firstName: member.firstName,
          lastName: member.lastName,
        },
        membershipStatus: 'member',
        membership: {
          id: membership.id,
          role: membership.role,
          joinedAt: membership.joinedAt,
          groupName: group.name,
        },
      })
    }

    // Check for existing join request
    const joinRequest = await prisma.groupJoinRequest.findUnique({
      where: {
        groupId_memberId: {
          groupId: group.id,
          memberId: member.id,
        },
      },
      select: {
        id: true,
        status: true,
        message: true,
        createdAt: true,
        reviewedAt: true,
      },
    })

    if (joinRequest) {
      return res.json({
        success: true,
        group: groupResponse,
        member: {
          id: member.id,
          phoneNumber: member.phoneNumber,
          firstName: member.firstName,
          lastName: member.lastName,
        },
        membershipStatus: joinRequest.status,
        request: joinRequest,
      })
    }

    // Authenticated but not a member and no request
    res.json({
      success: true,
      group: groupResponse,
      member: {
        id: member.id,
        phoneNumber: member.phoneNumber,
        firstName: member.firstName,
        lastName: member.lastName,
      },
      membershipStatus: 'none',
    })
  } catch (error) {
    console.error('Error looking up group by code:', error)
    res.status(500).json({ success: false, error: 'Failed to look up group' })
  }
})

/**
 * @openapi
 * /api/groups/{id}:
 *   get:
 *     tags: [Groups]
 *     summary: Get group by ID
 *     description: Returns a group's full details. User must be the creator.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Group ID
 *     responses:
 *       200:
 *         description: Group details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 group:
 *                   $ref: '#/components/schemas/Group'
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const group = await prisma.group.findFirst({
      where: {
        id,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Transform response to match iOS model
    const response = {
      id: group.id,
      code: group.code,
      name: group.name,
      description: group.description,
      coverImageUrl: group.coverImageUrl,
      isPrivate: group.isPrivate,
      allowInvites: group.allowInvites,
      welcomeMessage: group.welcomeMessage,
      ageRange:
        group.ageRangeMin !== null || group.ageRangeMax !== null
          ? { min: group.ageRangeMin, max: group.ageRangeMax }
          : null,
      maxMembers: group.maxMembers,
      memberCount: group._count.members,
      creatorId: group.creatorId,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    }

    res.json({ success: true, group: response })
  } catch (error) {
    console.error('Error fetching group:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch group' })
  }
})

/**
 * @openapi
 * /api/groups/{id}/invite:
 *   get:
 *     tags: [Groups]
 *     summary: Get group invite info with QR code
 *     description: Returns invite URL and QR code for sharing.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Group ID
 *     responses:
 *       200:
 *         description: Invite info
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 invite:
 *                   type: object
 *                   properties:
 *                     groupId:
 *                       type: string
 *                     groupName:
 *                       type: string
 *                     code:
 *                       type: string
 *                     inviteUrl:
 *                       type: string
 *                       format: uri
 *                     qrCode:
 *                       type: string
 *                       description: Base64 data URL of QR code image
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/:id/invite', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const group = await prisma.group.findFirst({
      where: {
        id,
        ...(await groupManageFilter(userId)),
        isActive: true,
      },
      select: {
        id: true,
        code: true,
        name: true,
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    const inviteUrl = `https://app.makeready.org/join/group/${group.code}`

    // Generate QR code as base64 data URL
    const qrCodeDataUrl = await QRCode.toDataURL(inviteUrl, {
      width: 512,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#FFFFFF',
      },
    })

    res.json({
      success: true,
      invite: {
        groupId: group.id,
        groupName: group.name,
        code: group.code,
        inviteUrl,
        qrCode: qrCodeDataUrl,
      },
    })
  } catch (error) {
    console.error('Error generating invite:', error)
    res.status(500).json({ success: false, error: 'Failed to generate invite' })
  }
})

/**
 * @openapi
 * /api/groups/{id}/public:
 *   get:
 *     tags: [Groups]
 *     summary: Get public group info
 *     description: Returns limited public info for a group. No authentication required.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Group ID
 *     responses:
 *       200:
 *         description: Public group info
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 group:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     code:
 *                       type: string
 *                     name:
 *                       type: string
 *                     description:
 *                       type: string
 *                       nullable: true
 *                     coverImageUrl:
 *                       type: string
 *                       nullable: true
 *                     isPrivate:
 *                       type: boolean
 *                     memberCount:
 *                       type: integer
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/:id/public', async (req, res) => {
  try {
    const { id } = req.params

    const group = await prisma.group.findFirst({
      where: {
        id,
        isActive: true,
      },
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
        creator: {
          select: { name: true, picture: true, email: true, phoneNumber: true },
        },
      },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Organization name (no relation on Group — look it up by id)
    let organizationName: string | null = null
    if (group.organizationId) {
      const org = await prisma.organization.findUnique({
        where: { id: group.organizationId },
        select: { name: true },
      })
      organizationName = org?.name ?? null
    }

    // Return limited public info
    const response = {
      id: group.id,
      code: group.code,
      name: group.name,
      description: group.description,
      coverImageUrl: group.coverImageUrl,
      isPrivate: group.isPrivate,
      memberCount: group._count.members,
      createdAt: group.createdAt,
      organizationName,
      creator: group.creator
        ? {
            name: group.creator.name,
            picture: group.creator.picture,
            email: group.creator.email,
            phoneNumber: group.creator.phoneNumber,
          }
        : null,
    }

    res.json({ success: true, group: response })
  } catch (error) {
    console.error('Error fetching public group:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch group' })
  }
})

/**
 * @openapi
 * /api/groups/{id}:
 *   patch:
 *     tags: [Groups]
 *     summary: Update group
 *     description: Updates group metadata. User must be the creator.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Group ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 maxLength: 200
 *               description:
 *                 type: string
 *                 maxLength: 2000
 *                 nullable: true
 *               coverImageUrl:
 *                 type: string
 *                 format: uri
 *                 nullable: true
 *               isPrivate:
 *                 type: boolean
 *               allowInvites:
 *                 type: boolean
 *               welcomeMessage:
 *                 type: string
 *                 maxLength: 1000
 *                 nullable: true
 *               ageRange:
 *                 type: object
 *                 nullable: true
 *                 properties:
 *                   min:
 *                     type: integer
 *                     nullable: true
 *                   max:
 *                     type: integer
 *                     nullable: true
 *               maxMembers:
 *                 type: integer
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Group updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 group:
 *                   $ref: '#/components/schemas/Group'
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.patch('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id
    // Authorization is by the caller's real role, not by auth method: a
    // self-minted API key must not grant more than the user's session. Only
    // super admins (incl. the global admin key's owner) bypass org scoping.
    const isSuperAdminUser = await isSuperAdmin(userId)

    const schema = z.object({
      name: z.string().min(1).max(200).optional(),
      description: z.string().max(2000).optional().nullable(),
      coverImageUrl: z.string().url().optional().nullable(),
      isPrivate: z.boolean().optional(),
      allowInvites: z.boolean().optional(),
      welcomeMessage: z.string().max(1000).optional().nullable(),
      ageRange: z
        .object({
          min: z.number().int().min(0).max(120).optional().nullable(),
          max: z.number().int().min(0).max(120).optional().nullable(),
        })
        .optional()
        .nullable(),
      maxMembers: z.number().int().min(1).optional().nullable(),
      organizationId: z.string().uuid().optional(),
    })

    const body = schema.parse(req.body)

    // Creator, the group org's owner/role-holders, or a super admin may update.
    const existingGroup = await prisma.group.findFirst({
      where: { id, ...(await groupManageFilter(userId)), isActive: true },
    })

    if (!existingGroup) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Build update data
    const updateData: any = {}
    if (body.name !== undefined) updateData.name = body.name
    if (body.description !== undefined) updateData.description = body.description
    if (body.coverImageUrl !== undefined) updateData.coverImageUrl = body.coverImageUrl
    if (body.isPrivate !== undefined) updateData.isPrivate = body.isPrivate
    if (body.allowInvites !== undefined) updateData.allowInvites = body.allowInvites
    if (body.welcomeMessage !== undefined) updateData.welcomeMessage = body.welcomeMessage
    if (body.ageRange !== undefined) {
      updateData.ageRangeMin = body.ageRange?.min ?? null
      updateData.ageRangeMax = body.ageRange?.max ?? null
    }
    if (body.maxMembers !== undefined) updateData.maxMembers = body.maxMembers
    // Keep the group's organization association accurate on edit: a group must
    // always belong to a real org, and a (non-admin) user may only move it to an
    // organization they themselves belong to. Super admins may set any existing
    // org. The org can never be cleared.
    if (body.organizationId !== undefined) {
      const targetOrg = await prisma.organization.findUnique({
        where: { id: body.organizationId },
        select: { id: true, ownerId: true },
      })
      if (!targetOrg) {
        return res.status(400).json({ success: false, error: 'Organization not found' })
      }
      if (!isSuperAdminUser) {
        const belongs =
          targetOrg.ownerId === userId ||
          (await prisma.userRole.findFirst({
            where: { userId, organizationId: targetOrg.id },
            select: { id: true },
          })) !== null
        if (!belongs) {
          return res.status(403).json({
            success: false,
            error: 'You do not belong to that organization',
          })
        }
      }
      updateData.organizationId = targetOrg.id
    }
    updateData.updatedById = userId

    const group = await prisma.group.update({
      where: { id },
      data: updateData,
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
      },
    })

    // Transform response to match iOS model
    const response = {
      id: group.id,
      code: group.code,
      name: group.name,
      description: group.description,
      coverImageUrl: group.coverImageUrl,
      isPrivate: group.isPrivate,
      allowInvites: group.allowInvites,
      welcomeMessage: group.welcomeMessage,
      ageRange:
        group.ageRangeMin !== null || group.ageRangeMax !== null
          ? { min: group.ageRangeMin, max: group.ageRangeMax }
          : null,
      maxMembers: group.maxMembers,
      memberCount: group._count.members,
      creatorId: group.creatorId,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    }

    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'GROUP',
      resourceId: group.id,
      resourceName: group.name,
      organizationId: group.organizationId,
      groupId: group.id,
    })

    res.json({ success: true, group: response })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error updating group:', error)
    res.status(500).json({ success: false, error: 'Failed to update group' })
  }
})

/**
 * @openapi
 * /api/groups/{id}:
 *   delete:
 *     tags: [Groups]
 *     summary: Delete group
 *     description: Soft deletes a group (sets isActive = false). User must be the creator.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Group ID
 *     responses:
 *       200:
 *         description: Group deleted
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
 *                   example: Group deleted successfully
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    // Creator, the group org's owner/role-holders, or a super admin may delete.
    const existingGroup = await prisma.group.findFirst({
      where: { id, ...(await groupManageFilter(userId)), isActive: true },
    })

    if (!existingGroup) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    await prisma.group.update({
      where: { id },
      data: { isActive: false },
    })

    trackActivity({
      actorId: userId,
      action: 'DELETED',
      resourceType: 'GROUP',
      resourceId: existingGroup.id,
      resourceName: existingGroup.name,
      organizationId: existingGroup.organizationId,
      groupId: existingGroup.id,
    })

    res.json({ success: true, message: 'Group deleted successfully' })
  } catch (error) {
    console.error('Error deleting group:', error)
    res.status(500).json({ success: false, error: 'Failed to delete group' })
  }
})

// ============================================================================
// Cover Image Upload
// ============================================================================

/**
 * @openapi
 * /api/groups/{id}/cover-image:
 *   post:
 *     tags: [Groups]
 *     summary: Upload group cover image
 *     description: |
 *       Uploads a cover image for the group. Accepts base64-encoded image data.
 *       Automatically generates multiple sizes (original, medium, thumbnail).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Group ID
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
 *                 description: Base64-encoded image data
 *               contentType:
 *                 type: string
 *                 default: image/jpeg
 *     responses:
 *       200:
 *         description: Image uploaded
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
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/:id/cover-image', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    const schema = z.object({
      imageData: z.string().min(1, 'Image data is required'),
      contentType: z.string().default('image/jpeg'),
    })

    const body = schema.parse(req.body)

    // Creator, the group org's owner/role-holders, or a super admin may edit.
    const group = await prisma.group.findFirst({
      where: { id, ...(await groupManageFilter(userId)), isActive: true },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    // Decode base64 image
    const base64Data = body.imageData.replace(/^data:image\/\w+;base64,/, '')
    const imageBuffer = Buffer.from(base64Data, 'base64')

    // Determine file naming
    const timestamp = Date.now()
    const baseName = `group-${id}-${timestamp}`
    const extension = 'jpeg' // Always output as JPEG for consistency

    // Generate image variants using sharp
    console.log(`📸 Processing image variants for group ${id}...`)

    const [originalBuffer, mediumBuffer, thumbBuffer] = await Promise.all([
      // Original: max 1200px width, 85% quality
      sharp(imageBuffer)
        .resize(1200, null, { withoutEnlargement: true })
        .jpeg({ quality: 85 })
        .toBuffer(),
      // Medium: max 400px width, 80% quality
      sharp(imageBuffer)
        .resize(400, null, { withoutEnlargement: true })
        .jpeg({ quality: 80 })
        .toBuffer(),
      // Thumbnail: max 150px width, 75% quality
      sharp(imageBuffer)
        .resize(150, null, { withoutEnlargement: true })
        .jpeg({ quality: 75 })
        .toBuffer(),
    ])

    console.log(
      `📸 Generated variants: original=${originalBuffer.length}b, medium=${mediumBuffer.length}b, thumb=${thumbBuffer.length}b`
    )

    // Upload to R2
    const { url: coverImageUrl } = await uploadImageVariants(
      'groups',
      baseName,
      extension,
      originalBuffer,
      mediumBuffer,
      thumbBuffer,
    )

    console.log(`📸 Uploaded group cover image: ${coverImageUrl}`)

    // Update group with cover image URL
    await prisma.group.update({
      where: { id },
      data: { coverImageUrl },
    })

    // Auto-capture to media library with metadata
    if (group.organizationId) {
      const imageMeta = await extractImageMetadata(imageBuffer)
      captureToLibrary({
        title: `${group.name} - Cover Image`,
        url: coverImageUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        fileSize: originalBuffer.length,
        thumbnailUrl: coverImageUrl.replace('.jpeg', '-thumb.jpeg'),
        organizationId: group.organizationId,
        uploadedBy: userId,
        source: 'auto_capture',
        usageType: 'GROUP_COVER',
        resourceId: group.id,
        resourceName: group.name,
        width: imageMeta.width,
        height: imageMeta.height,
        aspectRatio: imageMeta.aspectRatio,
        dominantColor: imageMeta.dominantColor ?? undefined,
        fileHash: imageMeta.fileHash,
        exifData: imageMeta.exifData ?? undefined,
      })
    }

    res.json({
      success: true,
      coverImageUrl,
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error uploading cover image:', error)
    res.status(500).json({ success: false, error: 'Failed to upload cover image' })
  }
})

export default router
