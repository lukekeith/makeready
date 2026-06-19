import { Router } from 'express'
import { z } from 'zod'
import {
  getOrganization,
  getOrganizationByOwner,
  updateOrganizationName,
  getOrganizationMembers,
} from '../services/organization.js'
import { requireAuth, requirePermission } from '../middleware/auth.js'
import { recordMembershipEvent } from '../services/membership-event.js'
import { prisma } from '../lib/prisma.js'

const router = Router()

/**
 * @openapi
 * /api/organizations:
 *   post:
 *     tags: [Organizations]
 *     summary: Create a new organization
 *     description: Creates a new organization and assigns the authenticated user as the owner.
 *     security:
 *       - userSession: []
 *       - apiKey: []
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
 *                 minLength: 1
 *                 description: The name of the organization
 *               ownerId:
 *                 type: string
 *                 format: uuid
 *                 description: User ID to set as owner (defaults to authenticated user)
 *     responses:
 *       201:
 *         description: Organization created successfully
 *       400:
 *         description: Validation error
 *       401:
 *         description: Not authenticated
 */
router.post('/', requireAuth, async (req, res) => {
  try {
    const schema = z.object({
      name: z.string().min(1, 'Organization name is required'),
      ownerId: z.string().uuid().optional(),
    })

    const { name, ownerId } = schema.parse(req.body)
    const userId = ownerId || (req.user as any)?.id

    const organization = await prisma.organization.create({
      data: { name, ownerId: userId },
    })

    // Update the owner's organizationId
    await prisma.user.update({
      where: { id: userId },
      data: { organizationId: organization.id },
    })

    res.status(201).json({ success: true, data: organization })
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors[0].message })
    }
    console.error('Error creating organization:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /api/organizations/migrate-leader:
 *   post:
 *     tags: [Organizations]
 *     summary: Migrate a group leader to a different organization
 *     description: |
 *       Moves a group leader's content (study programs, media, templates) to a target organization.
 *       Optionally moves their groups and community (members, posts, events, enrollments) as well.
 *       All mutations run in a single transaction for atomicity.
 *     security:
 *       - userSession: []
 *       - apiKey: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - userId
 *               - targetOrganizationId
 *             properties:
 *               userId:
 *                 type: string
 *                 format: uuid
 *                 description: The group leader's user ID
 *               targetOrganizationId:
 *                 type: string
 *                 format: uuid
 *                 description: The organization to migrate to
 *               includeGroups:
 *                 type: boolean
 *                 default: false
 *                 description: Whether to also move the leader's groups and their communities
 *               groupIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uuid
 *                 description: Specific group IDs to move (implies includeGroups=true). If omitted, moves all groups.
 *     responses:
 *       200:
 *         description: Migration completed successfully
 *       400:
 *         description: Validation error
 *       404:
 *         description: User or organization not found
 */
const migrateLeaderSchema = z.object({
  userId: z.string().uuid(),
  targetOrganizationId: z.string().uuid(),
  includeGroups: z.boolean().default(false),
  groupIds: z.array(z.string().uuid()).optional(),
})

router.post('/migrate-leader', requireAuth, async (req, res) => {
  try {
    const body = migrateLeaderSchema.parse(req.body)
    const { userId, targetOrganizationId } = body
    const includeGroups = body.includeGroups || (body.groupIds && body.groupIds.length > 0)
    const groupIds = body.groupIds

    // Look up the user to migrate
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, organizationId: true },
    })

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' })
    }

    const sourceOrgId = user.organizationId
    if (!sourceOrgId) {
      return res.status(400).json({ success: false, error: 'User has no source organization' })
    }

    if (sourceOrgId === targetOrganizationId) {
      return res.status(400).json({ success: false, error: 'User is already in the target organization' })
    }

    // Verify target org exists and is active
    const targetOrg = await prisma.organization.findUnique({
      where: { id: targetOrganizationId },
    })

    if (!targetOrg || !targetOrg.isActive) {
      return res.status(404).json({ success: false, error: 'Target organization not found' })
    }

    // Validate specific groupIds if provided
    if (groupIds && groupIds.length > 0) {
      const ownedGroups = await prisma.group.findMany({
        where: { id: { in: groupIds }, creatorId: userId, organizationId: sourceOrgId },
        select: { id: true },
      })
      const ownedIds = new Set(ownedGroups.map((g) => g.id))
      const invalid = groupIds.filter((id) => !ownedIds.has(id))
      if (invalid.length > 0) {
        return res.status(400).json({
          success: false,
          error: `Groups not found, not owned by this user, or not in source organization: ${invalid.join(', ')}`,
        })
      }
    }

    // Run everything in a transaction
    const result = await prisma.$transaction(async (tx) => {
      const migrated: Record<string, number> = {}

      // Step 1: Move content (always)
      const programs = await tx.studyProgram.updateMany({
        where: { creatorId: userId, organizationId: sourceOrgId },
        data: { organizationId: targetOrganizationId },
      })
      migrated.studyPrograms = programs.count

      const orgMedia = await tx.media.updateMany({
        where: { uploadedBy: userId, organizationId: sourceOrgId, groupId: null },
        data: { organizationId: targetOrganizationId },
      })
      migrated.media = orgMedia.count

      const templates = await tx.lessonTemplate.updateMany({
        where: { creatorId: userId, organizationId: sourceOrgId },
        data: { organizationId: targetOrganizationId },
      })
      migrated.lessonTemplates = templates.count

      // Step 2: Move groups (conditional)
      migrated.groups = 0
      migrated.groupMedia = 0
      migrated.memberOrganizationsCreated = 0

      if (includeGroups) {
        const groupFilter: any = { creatorId: userId, organizationId: sourceOrgId }
        if (groupIds) groupFilter.id = { in: groupIds }

        const groupsToMove = await tx.group.findMany({
          where: groupFilter,
          select: { id: true },
        })
        const movingGroupIds = groupsToMove.map((g) => g.id)

        if (movingGroupIds.length > 0) {
          const groupResult = await tx.group.updateMany({
            where: { id: { in: movingGroupIds } },
            data: { organizationId: targetOrganizationId },
          })
          migrated.groups = groupResult.count

          const groupMediaResult = await tx.media.updateMany({
            where: { groupId: { in: movingGroupIds }, organizationId: sourceOrgId },
            data: { organizationId: targetOrganizationId },
          })
          migrated.groupMedia = groupMediaResult.count

          // Create MemberOrganization records for members in moving groups
          const groupMembers = await tx.groupMember.findMany({
            where: { groupId: { in: movingGroupIds }, memberId: { not: null } },
            select: { memberId: true },
          })
          const uniqueMemberIds = [
            ...new Set(groupMembers.map((gm) => gm.memberId).filter(Boolean)),
          ] as string[]

          if (uniqueMemberIds.length > 0) {
            const existing = await tx.memberOrganization.findMany({
              where: { memberId: { in: uniqueMemberIds }, organizationId: targetOrganizationId },
              select: { memberId: true },
            })
            const existingSet = new Set(existing.map((r) => r.memberId))
            const toCreate = uniqueMemberIds.filter((id) => !existingSet.has(id))

            if (toCreate.length > 0) {
              const created = await tx.memberOrganization.createMany({
                data: toCreate.map((memberId) => ({
                  memberId,
                  organizationId: targetOrganizationId,
                })),
                skipDuplicates: true,
              })
              migrated.memberOrganizationsCreated = created.count
            }
          }
        }
      }

      // Step 3: Update the user (last)
      await tx.user.update({
        where: { id: userId },
        data: { organizationId: targetOrganizationId },
      })

      return migrated
    })

    res.json({ success: true, migrated: result })
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors[0].message })
    }
    console.error('Error migrating leader:', error)
    res.status(500).json({ success: false, error: 'Migration failed' })
  }
})

/**
 * @openapi
 * /api/organizations/{organizationId}:
 *   get:
 *     tags: [Organizations]
 *     summary: Get organization details
 *     description: Retrieves the details of a specific organization by its ID. Requires the user to have 'organization.read' permission for the organization.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the organization
 *         example: "clx1234567890"
 *     responses:
 *       200:
 *         description: Organization retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Organization'
 *             example:
 *               success: true
 *               data:
 *                 id: "clx1234567890"
 *                 name: "Acme Corporation"
 *                 ownerId: "user_abc123"
 *                 createdAt: "2024-01-15T10:30:00.000Z"
 *                 updatedAt: "2024-01-15T10:30:00.000Z"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Not authenticated"
 *       403:
 *         description: Forbidden - insufficient permissions
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Insufficient permissions"
 *       404:
 *         description: Organization not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Organization not found"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
router.get(
  '/:organizationId',
  requireAuth,
  requirePermission('organization.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params

      const result = await getOrganization(organizationId)

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
      console.error('Error fetching organization:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/my/organization:
 *   get:
 *     tags: [Organizations]
 *     summary: Get current user's organization
 *     description: Retrieves the organization owned by the currently authenticated user. Returns 404 if the user does not own an organization.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: User's organization retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Organization'
 *             example:
 *               success: true
 *               data:
 *                 id: "clx1234567890"
 *                 name: "My Organization"
 *                 ownerId: "user_abc123"
 *                 createdAt: "2024-01-15T10:30:00.000Z"
 *                 updatedAt: "2024-01-15T10:30:00.000Z"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Not authenticated"
 *       404:
 *         description: User does not own an organization
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Organization not found"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
router.get('/my/organization', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Not authenticated',
      })
    }

    const result = await getOrganizationByOwner(userId)

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
    console.error('Error fetching user organization:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/organizations/{organizationId}:
 *   patch:
 *     tags: [Organizations]
 *     summary: Update organization name
 *     description: Updates the name of a specific organization. Requires the user to have 'organization.update' permission for the organization.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the organization to update
 *         example: "clx1234567890"
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
 *                 minLength: 1
 *                 description: The new name for the organization
 *                 example: "Updated Organization Name"
 *           example:
 *             name: "Updated Organization Name"
 *     responses:
 *       200:
 *         description: Organization updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Organization'
 *             example:
 *               success: true
 *               data:
 *                 id: "clx1234567890"
 *                 name: "Updated Organization Name"
 *                 ownerId: "user_abc123"
 *                 createdAt: "2024-01-15T10:30:00.000Z"
 *                 updatedAt: "2024-01-20T14:45:00.000Z"
 *       400:
 *         description: Invalid request body - validation failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Organization name is required"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Not authenticated"
 *       403:
 *         description: Forbidden - insufficient permissions
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Insufficient permissions"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
const updateOrganizationSchema = z.object({
  name: z.string().min(1, 'Organization name is required'),
})

router.patch(
  '/:organizationId',
  requireAuth,
  requirePermission('organization.update', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params

      // Validate request body
      const validation = updateOrganizationSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { name } = validation.data

      const result = await updateOrganizationName(organizationId, name)

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error updating organization:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/members:
 *   get:
 *     tags: [Organizations]
 *     summary: Get all members in an organization
 *     description: Retrieves all members belonging to a specific organization. Supports optional search filtering and the ability to include inactive members. Requires the user to have 'member.read' permission for the organization.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the organization
 *         example: "clx1234567890"
 *       - in: query
 *         name: search
 *         required: false
 *         schema:
 *           type: string
 *         description: Search query to filter members by name or other attributes
 *         example: "john"
 *       - in: query
 *         name: includeInactive
 *         required: false
 *         schema:
 *           type: string
 *           enum: ["true", "false"]
 *         description: Whether to include inactive members in the results (default is false)
 *         example: "true"
 *     responses:
 *       200:
 *         description: Organization members retrieved successfully
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
 *                     $ref: '#/components/schemas/Member'
 *                 count:
 *                   type: integer
 *                   description: Total number of members returned
 *                   example: 5
 *             example:
 *               success: true
 *               data:
 *                 - id: "member_123"
 *                   firstName: "John"
 *                   lastName: "Doe"
 *                   email: "john.doe@example.com"
 *                   phoneNumber: "+15551234567"
 *                   isActive: true
 *                   organizationId: "clx1234567890"
 *                   createdAt: "2024-01-15T10:30:00.000Z"
 *                   updatedAt: "2024-01-15T10:30:00.000Z"
 *                 - id: "member_456"
 *                   firstName: "Jane"
 *                   lastName: "Smith"
 *                   email: "jane.smith@example.com"
 *                   phoneNumber: "+15559876543"
 *                   isActive: true
 *                   organizationId: "clx1234567890"
 *                   createdAt: "2024-01-16T08:00:00.000Z"
 *                   updatedAt: "2024-01-16T08:00:00.000Z"
 *               count: 2
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Not authenticated"
 *       403:
 *         description: Forbidden - insufficient permissions
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Insufficient permissions"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
router.get(
  '/:organizationId/members',
  requireAuth,
  requirePermission('member.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const { search, includeInactive } = req.query

      const result = await getOrganizationMembers(organizationId, {
        search: search as string | undefined,
        includeInactive: includeInactive === 'true',
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
      console.error('Error fetching organization members:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}:
 *   delete:
 *     tags: [Organizations]
 *     summary: Delete an organization
 *     description: Soft-deletes an organization by setting isActive to false. Requires organization.update permission.
 *     security:
 *       - userSession: []
 *       - apiKey: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Organization deleted successfully
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Insufficient permissions
 *       404:
 *         description: Organization not found
 */
router.delete(
  '/:organizationId',
  requireAuth,
  requirePermission('organization.update', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params

      const organization = await prisma.organization.findUnique({
        where: { id: organizationId },
      })

      if (!organization) {
        return res.status(404).json({ success: false, error: 'Organization not found' })
      }

      await prisma.organization.update({
        where: { id: organizationId },
        data: { isActive: false },
      })

      res.json({ success: true })
    } catch (error) {
      console.error('Error deleting organization:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/member-organizations:
 *   get:
 *     tags: [Organizations]
 *     summary: List member-organization relationships
 *     description: Returns all MemberOrganization records for the given organization.
 *     security:
 *       - userSession: []
 *       - apiKey: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Member-organization records retrieved
 */
router.get(
  '/:organizationId/member-organizations',
  requireAuth,
  requirePermission('member.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params

      const records = await prisma.memberOrganization.findMany({
        where: { organizationId },
        include: {
          member: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              phoneNumber: true,
              email: true,
              isActive: true,
            },
          },
        },
        orderBy: { joinedAt: 'desc' },
      })

      res.json({ success: true, data: records, count: records.length })
    } catch (error) {
      console.error('Error fetching member-organizations:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/member-organizations:
 *   post:
 *     tags: [Organizations]
 *     summary: Add a member to an organization
 *     description: Creates a MemberOrganization record linking a member to an organization.
 *     security:
 *       - userSession: []
 *       - apiKey: []
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
 *             required:
 *               - memberId
 *             properties:
 *               memberId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       201:
 *         description: Member added to organization
 *       400:
 *         description: Member already in organization
 *       404:
 *         description: Member not found
 */
router.post(
  '/:organizationId/member-organizations',
  requireAuth,
  requirePermission('member.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const schema = z.object({ memberId: z.string().uuid() })
      const { memberId } = schema.parse(req.body)

      const member = await prisma.member.findUnique({ where: { id: memberId } })
      if (!member) {
        return res.status(404).json({ success: false, error: 'Member not found' })
      }

      const existing = await prisma.memberOrganization.findFirst({
        where: { memberId, organizationId },
      })
      if (existing) {
        return res.status(400).json({ success: false, error: 'Member already in organization' })
      }

      const record = await prisma.memberOrganization.create({
        data: { memberId, organizationId },
      })

      res.status(201).json({ success: true, data: record })
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: error.errors[0].message })
      }
      console.error('Error adding member to organization:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/member-organizations/{memberId}:
 *   delete:
 *     tags: [Organizations]
 *     summary: Remove a member from an organization
 *     description: Deletes the MemberOrganization record.
 *     security:
 *       - userSession: []
 *       - apiKey: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Member removed from organization
 *       404:
 *         description: Record not found
 */
router.delete(
  '/:organizationId/member-organizations/:memberId',
  requireAuth,
  requirePermission('member.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId, memberId } = req.params
      const userId = (req.user as any)?.id

      const record = await prisma.memberOrganization.findFirst({
        where: { memberId, organizationId },
      })

      if (!record) {
        return res.status(404).json({ success: false, error: 'Member-organization record not found' })
      }

      // Membership-only removal. We deactivate every active group membership the
      // member holds in THIS org's groups, then drop the org link — but the
      // Member record and all of their data/history are preserved. Re-adding
      // them later restores everything. The whole cascade (including the audit
      // trail) runs in one transaction so it can't half-apply.
      const activeMemberships = await prisma.groupMember.findMany({
        where: {
          memberId,
          isActive: true,
          group: { organizationId },
        },
        select: { id: true, groupId: true },
      })

      await prisma.$transaction(async (tx) => {
        if (activeMemberships.length > 0) {
          await tx.groupMember.updateMany({
            where: { id: { in: activeMemberships.map((m) => m.id) } },
            data: { isActive: false },
          })
        }

        await tx.memberOrganization.delete({ where: { id: record.id } })

        // Per-group events keep each group's history continuous...
        for (const m of activeMemberships) {
          await recordMembershipEvent(
            {
              memberId,
              action: 'REMOVED_GROUP',
              groupId: m.groupId,
              organizationId,
              actorId: userId ?? null,
              actorType: 'user',
              metadata: { via: 'org-removal' },
            },
            tx
          )
        }

        // ...and a single REMOVED_ORG event summarizes the cascade.
        await recordMembershipEvent(
          {
            memberId,
            action: 'REMOVED_ORG',
            organizationId,
            actorId: userId ?? null,
            actorType: 'user',
            metadata: { removedGroupIds: activeMemberships.map((m) => m.groupId) },
          },
          tx
        )
      })

      res.json({
        success: true,
        removedFromGroups: activeMemberships.length,
      })
    } catch (error) {
      console.error('Error removing member from organization:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/non-members:
 *   get:
 *     summary: People formerly associated with the org who are not current members
 *     description: >
 *       Returns members who have membership history in this org (from the
 *       immutable MembershipEvent trail) whose most recent action is terminal —
 *       removed from a group/org, or a rejected join request — and who are NOT
 *       currently an active member of any group in the org. Each entry includes
 *       its latest action so the UI can show "Removed from membership",
 *       "Request rejected", etc. Nobody is lost: a removed/rejected person still
 *       surfaces here so a leader can re-engage them.
 *     tags: [Organizations]
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Non-member entries, most recent action first
 */
router.get(
  '/:organizationId/non-members',
  requireAuth,
  requirePermission('member.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params

      // Latest-first history for this org, plus the members currently active in
      // any of its groups.
      const [events, activeMemberships] = await Promise.all([
        prisma.membershipEvent.findMany({
          where: { organizationId },
          orderBy: { createdAt: 'desc' },
          include: {
            member: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                phoneNumber: true,
                profilePicture: true,
              },
            },
            group: { select: { id: true, name: true } },
          },
        }),
        prisma.groupMember.findMany({
          where: { isActive: true, group: { organizationId } },
          select: { memberId: true },
        }),
      ])

      const activeMemberIds = new Set(
        activeMemberships.map((m) => m.memberId).filter((id): id is string => !!id)
      )
      const TERMINAL = new Set(['REJECTED', 'REMOVED_GROUP', 'REMOVED_ORG'])

      const seen = new Set<string>()
      const nonMembers: any[] = []
      for (const ev of events) {
        // Events are newest-first, so the first one per member is their latest.
        if (seen.has(ev.memberId)) continue
        seen.add(ev.memberId)

        if (activeMemberIds.has(ev.memberId)) continue // still a current member
        if (!TERMINAL.has(ev.action)) continue // pending invite/request, not a former member

        nonMembers.push({
          id: ev.member.id,
          firstName: ev.member.firstName,
          lastName: ev.member.lastName,
          phoneNumber: ev.member.phoneNumber,
          avatarUrl: ev.member.profilePicture,
          lastAction: ev.action,
          lastActionAt: ev.createdAt,
          groupId: ev.groupId,
          groupName: ev.group?.name ?? null,
          note: ev.note,
        })
      }

      res.json({ success: true, members: nonMembers })
    } catch (error) {
      console.error('Error loading non-members:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

export default router
