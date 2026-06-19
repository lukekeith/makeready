import { Router } from 'express'
import { z } from 'zod'
import {
  addMemberToGroup,
  removeMemberFromGroup,
} from '../services/member.js'
import { prisma } from '../lib/prisma.js'
import {
  requireAuth,
  requirePermission,
} from '../middleware/auth.js'
import { trackActivity } from '../services/activity.js'
import {
  recordMembershipEvent,
  getMembershipHistory,
} from '../services/membership-event.js'
import { MembershipEventAction } from '../generated/prisma/index.js'

/** Narrow a query-string value to a valid MembershipEventAction, else undefined. */
function parseAction(value: unknown): MembershipEventAction | undefined {
  return typeof value === 'string' &&
    (Object.values(MembershipEventAction) as string[]).includes(value)
    ? (value as MembershipEventAction)
    : undefined
}

/**
 * @openapi
 * components:
 *   schemas:
 *     GroupMember:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: The GroupMember relationship ID
 *           example: "clxyz123abc"
 *         userId:
 *           type: string
 *           description: The Member ID
 *           example: "clmember456def"
 *         groupId:
 *           type: string
 *           description: The Group ID
 *           example: "clgroup789ghi"
 *         role:
 *           type: string
 *           enum: [OWNER, ADMIN, MEMBER]
 *           description: The member's role in the group
 *           example: "MEMBER"
 *         name:
 *           type: string
 *           description: The member's full name
 *           example: "John Doe"
 *         avatarUrl:
 *           type: string
 *           nullable: true
 *           description: URL to the member's profile picture
 *           example: "https://example.com/avatar.jpg"
 *         joinedAt:
 *           type: string
 *           format: date-time
 *           description: When the member joined the group
 *           example: "2024-01-15T10:30:00.000Z"
 *     GroupMembersResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
 *         members:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/GroupMember'
 *     AddMemberRequest:
 *       type: object
 *       required:
 *         - memberId
 *       properties:
 *         memberId:
 *           type: string
 *           description: The ID of the member to add to the group
 *           example: "clmember456def"
 *         role:
 *           type: string
 *           enum: [member, leader]
 *           default: member
 *           description: The role to assign to the member
 *           example: "member"
 *     SuccessResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
 *         message:
 *           type: string
 *           example: "Operation completed successfully"
 *     ErrorResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: false
 *         error:
 *           type: string
 *           example: "Error message describing what went wrong"
 */

const router = Router()

/**
 * @openapi
 * /api/groups/{groupId}/members:
 *   get:
 *     tags:
 *       - Group Members
 *     summary: Get all members in a group
 *     description: |
 *       Retrieves all members belonging to a specific group. By default, only active
 *       members are returned. Use the includeInactive query parameter to include
 *       inactive members as well.
 *
 *       Authorization: User must be authenticated. Group membership check is implicit -
 *       you can only access groups you're a member of via the groups list.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *         example: "clgroup789ghi"
 *       - in: query
 *         name: includeInactive
 *         required: false
 *         schema:
 *           type: string
 *           enum: ['true', 'false']
 *         description: Whether to include inactive members in the response
 *         example: "false"
 *     responses:
 *       200:
 *         description: Successfully retrieved group members
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/GroupMembersResponse'
 *             example:
 *               success: true
 *               members:
 *                 - id: "clxyz123abc"
 *                   userId: "clmember456def"
 *                   groupId: "clgroup789ghi"
 *                   role: "OWNER"
 *                   name: "John Doe"
 *                   avatarUrl: "https://example.com/avatar.jpg"
 *                   joinedAt: "2024-01-15T10:30:00.000Z"
 *                 - id: "clxyz124abd"
 *                   userId: "clmember457deg"
 *                   groupId: "clgroup789ghi"
 *                   role: "MEMBER"
 *                   name: "Jane Smith"
 *                   avatarUrl: null
 *                   joinedAt: "2024-01-20T14:45:00.000Z"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Not authenticated"
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
  '/:groupId/members',
  requireAuth,
  async (req, res) => {
  try {
    const { groupId } = req.params
    const { includeInactive } = req.query

    const where: any = {
      groupId,
      memberId: { not: null }, // Only get members (not deprecated user relationships)
    }

    if (includeInactive !== 'true') {
      where.isActive = true
      where.member = { isActive: true }
    }

    const groupMembers = await prisma.groupMember.findMany({
      where,
      include: {
        member: true,
      },
      orderBy: {
        joinedAt: 'desc',
      },
    })

    // Transform to match iPhone app's GroupMember model
    const members = groupMembers.map((gm) => ({
      id: gm.id,  // GroupMember ID
      userId: gm.memberId,  // Member ID
      groupId: gm.groupId,
      role: gm.role.toUpperCase(),  // OWNER, ADMIN, MEMBER
      name: [gm.member?.firstName, gm.member?.lastName].filter(Boolean).join(' ') || 'Unknown',
      avatarUrl: gm.member?.profilePicture || null,
      joinedAt: gm.joinedAt,
    }))

    res.json({
      success: true,
      members: members,
    })
  } catch (error) {
    console.error('Error fetching group members:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/members:
 *   post:
 *     tags:
 *       - Group Members
 *     summary: Add a member to a group
 *     description: |
 *       Adds an existing member to a group with a specified role. The member must
 *       belong to the same organization as the group.
 *
 *       Authorization: Requires 'group.invite' permission on the target group.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *         example: "clgroup789ghi"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/AddMemberRequest'
 *           example:
 *             memberId: "clmember456def"
 *             role: "member"
 *     responses:
 *       200:
 *         description: Member successfully added to the group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *             example:
 *               success: true
 *               message: "Member added to group successfully"
 *       400:
 *         description: Invalid request body or member already in group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             examples:
 *               validationError:
 *                 summary: Validation error
 *                 value:
 *                   success: false
 *                   error: "Required"
 *               alreadyMember:
 *                 summary: Member already in group
 *                 value:
 *                   success: false
 *                   error: "Member is already in this group"
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
 *         description: Forbidden - insufficient permissions or organization mismatch
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             examples:
 *               noPermission:
 *                 summary: Insufficient permissions
 *                 value:
 *                   success: false
 *                   error: "You do not have permission to perform this action"
 *               orgMismatch:
 *                 summary: Organization mismatch
 *                 value:
 *                   success: false
 *                   error: "Member and group must belong to the same organization"
 *       404:
 *         description: Group or member not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Group or member not found"
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
const addMemberSchema = z.object({
  memberId: z.string(),
  role: z.enum(['member', 'leader']).default('member'),
})

router.post(
  '/:groupId/members',
  requireAuth,
  requirePermission('group.invite', 'group', (req) => req.params.groupId),
  async (req, res) => {
    try {
      const { groupId } = req.params

      const validation = addMemberSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { memberId, role } = validation.data

      // Verify member and group belong to same organization
      const [group, member] = await Promise.all([
        prisma.group.findUnique({
          where: { id: groupId },
          select: { organizationId: true, name: true },
        }),
        prisma.member.findUnique({
          where: { id: memberId },
          include: {
            organizations: {
              select: { organizationId: true },
            },
          },
        }),
      ])

      if (!group || !member) {
        return res.status(404).json({
          success: false,
          error: 'Group or member not found',
        })
      }

      // Check if member belongs to the group's organization
      const memberBelongsToOrg = member.organizations.some(
        (mo) => mo.organizationId === group.organizationId
      )

      if (!memberBelongsToOrg) {
        // A member who is an active member of another group in this org belongs
        // to the org even when their MemberOrganization row is missing (e.g.
        // approved via a join request before org links were written). Heal the
        // missing link instead of rejecting; only truly-foreign members (in no
        // group in this org) are blocked.
        const inOrgGroup = group.organizationId
          ? await prisma.groupMember.findFirst({
              where: {
                memberId,
                isActive: true,
                group: { organizationId: group.organizationId },
              },
              select: { id: true },
            })
          : null

        if (inOrgGroup && group.organizationId) {
          await prisma.memberOrganization.create({
            data: { memberId, organizationId: group.organizationId },
          })
        } else {
          return res.status(403).json({
            success: false,
            error: 'Member and group must belong to the same organization',
          })
        }
      }

      // Add member to group
      const result = await addMemberToGroup(memberId, groupId, role)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      const userId = (req.user as any)?.id
      if (userId) {
        const memberName = [member.firstName, member.lastName].filter(Boolean).join(' ') || 'Member'
        trackActivity({
          actorId: userId,
          action: 'JOINED',
          resourceType: 'MEMBER',
          resourceId: memberId,
          resourceName: `${memberName} joined ${group.name}`,
          organizationId: group.organizationId,
          groupId,
        })
      }

      // Immutable membership audit trail. Re-adding a member who was previously
      // removed reactivates their existing membership (REJOINED) — none of
      // their prior group data is lost.
      await recordMembershipEvent({
        memberId,
        action: result.reactivated ? 'REJOINED' : 'ADDED',
        groupId,
        organizationId: group.organizationId,
        actorId: userId ?? null,
        actorType: 'user',
        metadata: { role },
      })

      res.json({
        success: true,
        message: 'Member added to group successfully',
      })
    } catch (error) {
      console.error('Error adding member to group:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/groups/{groupId}/members/{memberId}:
 *   patch:
 *     tags:
 *       - Group Members
 *     summary: Update a group member's role
 *     description: Changes the role of a member within a group. Requires group.update permission.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: memberId
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
 *               - role
 *             properties:
 *               role:
 *                 type: string
 *                 enum: [member, admin, owner]
 *     responses:
 *       200:
 *         description: Member role updated
 *       404:
 *         description: Group member not found
 */
const updateMemberRoleSchema = z.object({
  role: z.enum(['member', 'admin', 'owner']),
})

router.patch(
  '/:groupId/members/:memberId',
  requireAuth,
  requirePermission('group.update', 'group', (req) => req.params.groupId),
  async (req, res) => {
    try {
      const { groupId, memberId } = req.params

      const validation = updateMemberRoleSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({ success: false, error: validation.error.errors[0].message })
      }

      const { role } = validation.data

      const groupMember = await prisma.groupMember.findFirst({
        where: { groupId, memberId, isActive: true },
      })

      if (!groupMember) {
        return res.status(404).json({ success: false, error: 'Group member not found' })
      }

      await prisma.groupMember.update({
        where: { id: groupMember.id },
        data: { role },
      })

      res.json({ success: true, message: 'Member role updated' })
    } catch (error) {
      console.error('Error updating group member role:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

/**
 * @openapi
 * /api/groups/{groupId}/members/{memberId}:
 *   delete:
 *     tags:
 *       - Group Members
 *     summary: Remove a member from a group
 *     description: |
 *       Removes a member from a group using a soft delete. The GroupMember record
 *       is marked as inactive rather than being permanently deleted.
 *
 *       Authorization: Requires 'group.update' permission on the target group.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *         example: "clgroup789ghi"
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the member to remove
 *         example: "clmember456def"
 *     responses:
 *       200:
 *         description: Member successfully removed from the group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *             example:
 *               success: true
 *               message: "Member removed from group successfully"
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
 *               error: "You do not have permission to perform this action"
 *       500:
 *         description: Internal server error or removal failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
router.delete(
  '/:groupId/members/:memberId',
  requireAuth,
  requirePermission('group.update', 'group', (req) => req.params.groupId),
  async (req, res) => {
    try {
      const { groupId, memberId } = req.params

      const result = await removeMemberFromGroup(memberId, groupId)

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      const userId = (req.user as any)?.id
      if (userId) {
        const group = await prisma.group.findUnique({
          where: { id: groupId },
          select: { name: true, organizationId: true },
        })
        trackActivity({
          actorId: userId,
          action: 'LEFT',
          resourceType: 'MEMBER',
          resourceId: memberId,
          resourceName: `Member removed from ${group?.name ?? 'group'}`,
          organizationId: group?.organizationId,
          groupId,
        })

        // Immutable membership audit trail. This is a soft removal — the
        // GroupMember row is deactivated, never deleted, so re-adding restores
        // the member and all their data.
        await recordMembershipEvent({
          memberId,
          action: 'REMOVED_GROUP',
          groupId,
          organizationId: group?.organizationId ?? null,
          actorId: userId,
          actorType: 'user',
        })
      }

      res.json({
        success: true,
        message: 'Member removed from group successfully',
      })
    } catch (error) {
      console.error('Error removing member from group:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/groups/{groupId}/membership-history:
 *   get:
 *     summary: Searchable membership audit trail for a group
 *     description: >
 *       Returns the immutable history of every membership transition in the
 *       group (invited, requested, approved, rejected, added, rejoined,
 *       removed), newest first. A leader can search by member name or phone to
 *       find someone they previously rejected/removed and reverse the decision —
 *       no one is ever lost.
 *     tags: [Group Members]
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *         description: Filter by member first/last name or phone number
 *       - in: query
 *         name: action
 *         schema:
 *           type: string
 *           enum: [INVITED, REQUESTED, APPROVED, REJECTED, ADDED, REJOINED, REMOVED_GROUP, REMOVED_ORG]
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 100, maximum: 500 }
 *     responses:
 *       200:
 *         description: Membership events, newest first
 */
router.get('/:groupId/membership-history', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const { search, limit } = req.query

    const events = await getMembershipHistory({
      groupId,
      search: typeof search === 'string' ? search : undefined,
      action: parseAction(req.query.action),
      limit: limit ? Number(limit) : undefined,
    })

    res.json({ success: true, events })
  } catch (error) {
    console.error('Error fetching group membership history:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

export default router
