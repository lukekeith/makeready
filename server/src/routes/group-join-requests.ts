import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import { requireAuth, requireMemberAuth } from '../middleware/auth.js'
import { logSuccess, logWarning } from '../lib/activity-log.js'
import { ActivityTypes } from '../lib/activity-types.js'
import { trackActivity } from '../services/activity.js'
import { recordMembershipEvent } from '../services/membership-event.js'
import { groupManageFilter } from '../services/permission.js'

const router = Router({ mergeParams: true }) // Access :groupId from parent

/**
 * @openapi
 * components:
 *   schemas:
 *     JoinRequest:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the join request
 *           example: "clxyz123abc"
 *         groupId:
 *           type: string
 *           description: ID of the group being requested to join
 *           example: "clxyz456def"
 *         status:
 *           type: string
 *           enum: [pending, approved, rejected]
 *           description: Current status of the join request
 *           example: "pending"
 *         message:
 *           type: string
 *           nullable: true
 *           description: Optional message from the requester
 *           example: "I'd love to join your study group!"
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: When the request was submitted
 *         reviewedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *           description: When the request was reviewed (approved/rejected)
 *     JoinRequestWithMember:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the join request
 *         status:
 *           type: string
 *           enum: [pending, approved, rejected]
 *         message:
 *           type: string
 *           nullable: true
 *         createdAt:
 *           type: string
 *           format: date-time
 *         member:
 *           type: object
 *           properties:
 *             id:
 *               type: string
 *               description: Member's unique identifier
 *             firstName:
 *               type: string
 *               description: Member's first name
 *             lastName:
 *               type: string
 *               description: Member's last name
 *             avatarUrl:
 *               type: string
 *               nullable: true
 *               description: URL to member's profile picture
 *     MembershipInfo:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: Membership record ID
 *         role:
 *           type: string
 *           description: Member's role in the group
 *           example: "member"
 *         joinedAt:
 *           type: string
 *           format: date-time
 *           description: When the member joined the group
 *         groupName:
 *           type: string
 *           description: Name of the group
 */

// =============================================================================
// MEMBER ENDPOINTS (Phone-authenticated)
// =============================================================================

/**
 * @openapi
 * /api/groups/{groupId}/join-requests:
 *   post:
 *     tags:
 *       - Group Join Requests
 *     summary: Submit a join request for a group
 *     description: |
 *       Allows a phone-verified member to submit a request to join a group.
 *       The member must not already be a member of the group or have a pending request.
 *       If a previous request was rejected, a new request can be submitted.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group to join
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               message:
 *                 type: string
 *                 maxLength: 500
 *                 description: Optional message to include with the join request
 *                 example: "I'd love to join your study group!"
 *     responses:
 *       201:
 *         description: Join request submitted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 request:
 *                   $ref: '#/components/schemas/JoinRequest'
 *       400:
 *         description: Bad request - validation error, already a member, or pending request exists
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
 *                   example: "You are already a member of this group"
 *       401:
 *         description: Not authenticated - member session required
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
 *                   example: "Unauthorized"
 *       404:
 *         description: Group not found or inactive
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
 *                   example: "Group not found"
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
const submitRequestSchema = z.object({
  message: z.string().max(500).optional(),
})

router.post('/', async (req, _res, next) => {
  // Debug: log whether member session exists before auth check
  console.log('[join-request] POST received', {
    groupId: req.params.groupId,
    hasCookie: !!req.headers.cookie,
    sessionId: req.sessionID?.substring(0, 8),
    memberId: req.session?.memberId || 'NONE',
  })
  next()
}, requireMemberAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const memberId = req.session.memberId!

    const validation = submitRequestSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const { message } = validation.data

    // Check group exists and is active (include creatorId for push notification)
    const group = await prisma.group.findFirst({
      where: { id: groupId, isActive: true },
      select: { id: true, name: true, creatorId: true, organizationId: true },
    })

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      })
    }

    // Check if member is already in the group
    const existingMembership = await prisma.groupMember.findFirst({
      where: {
        groupId,
        memberId,
        isActive: true,
      },
    })

    if (existingMembership) {
      logWarning(ActivityTypes.JOIN.GROUP_ALREADY_MEMBER, req, {
        memberId,
        groupId,
        groupName: group.name,
      })
      return res.status(400).json({
        success: false,
        error: 'You are already a member of this group',
      })
    }

    // Check if the member was invited — auto-join if so
    const memberRecord = await prisma.member.findUnique({
      where: { id: memberId },
      select: { phoneNumber: true, firstName: true, lastName: true },
    })

    if (memberRecord?.phoneNumber) {
      const invite = await prisma.invite.findFirst({
        where: {
          groupId,
          recipientPhone: memberRecord.phoneNumber,
          status: 'pending',
        },
      })

      if (invite) {
        // Auto-add to group
        await prisma.groupMember.upsert({
          where: { groupId_memberId: { groupId, memberId } },
          update: { isActive: true },
          create: { groupId, memberId },
        })

        // Mark invite as accepted
        await prisma.invite.update({
          where: { id: invite.id },
          data: { status: 'accepted', acceptedAt: new Date() },
        })

        const memberName = `${memberRecord.firstName || ''} ${memberRecord.lastName || ''}`.trim() || 'Someone'

        // Notify group leader via unified activity
        trackActivity({
          actorId: memberId,
          action: 'JOINED',
          resourceType: 'MEMBER',
          resourceId: memberId,
          resourceName: `${memberName} joined ${group.name}`,
          organizationId: group.organizationId,
          groupId,
          targetUserId: group.creatorId,
          title: 'Invited Member Joined',
          body: `${memberName} has joined ${group.name}`,
          metadata: { source: 'invite' },
        })

        logSuccess(ActivityTypes.JOIN.GROUP_REQUEST_SUBMITTED, req, {
          memberId,
          groupId,
          groupName: group.name,
        })

        return res.status(201).json({
          success: true,
          status: 'joined',
        })
      }
    }

    // Check if there's already a pending request
    const existingRequest = await prisma.groupJoinRequest.findUnique({
      where: {
        groupId_memberId: { groupId, memberId },
      },
    })

    if (existingRequest) {
      if (existingRequest.status === 'pending') {
        logWarning(ActivityTypes.JOIN.GROUP_REQUEST_DUPLICATE, req, {
          memberId,
          groupId,
          groupName: group.name,
        })
        return res.status(400).json({
          success: false,
          error: 'You already have a pending request for this group',
        })
      }

    }

    // Create or revive the join request. We NEVER delete the prior row — the
    // unique (groupId, memberId) request is reset to pending so the member's
    // identity and prior decisions are preserved. The full history lives in the
    // immutable MembershipEvent trail recorded below.
    const requestSelect = {
      id: true,
      groupId: true,
      status: true,
      message: true,
      createdAt: true,
    } as const

    const request = existingRequest
      ? await prisma.groupJoinRequest.update({
          where: { id: existingRequest.id },
          data: {
            message,
            status: 'pending',
            reviewedById: null,
            reviewedAt: null,
          },
          select: requestSelect,
        })
      : await prisma.groupJoinRequest.create({
          data: {
            groupId,
            memberId,
            message,
            status: 'pending',
          },
          select: requestSelect,
        })

    // Log successful submission
    logSuccess(ActivityTypes.JOIN.GROUP_REQUEST_SUBMITTED, req, {
      memberId,
      groupId,
      groupName: group.name,
    })

    // Notify group creator via unified activity
    const memberName = memberRecord
      ? `${memberRecord.firstName || ''} ${memberRecord.lastName || ''}`.trim() || 'Someone'
      : 'Someone'

    trackActivity({
      actorId: memberId,
      action: 'NOTIFIED',
      resourceType: 'MEMBER',
      resourceId: request.id,
      resourceName: `${memberName} wants to join ${group.name}`,
      organizationId: group.organizationId,
      groupId,
      targetUserId: group.creatorId,
      title: 'New Join Request',
      body: `${memberName} wants to join ${group.name}`,
      metadata: { requestId: request.id },
    })

    // Immutable audit trail — captures every (re)request against the same
    // member, including re-requests after a prior rejection.
    await recordMembershipEvent({
      memberId,
      action: 'REQUESTED',
      groupId,
      organizationId: group.organizationId,
      actorId: memberId,
      actorType: 'member',
      note: message || null,
      metadata: { requestId: request.id },
    })

    res.status(201).json({
      success: true,
      request,
    })
  } catch (error) {
    console.error('Error submitting join request:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/join-requests/me:
 *   get:
 *     tags:
 *       - Group Join Requests
 *     summary: Check current member's status for a group
 *     description: |
 *       Returns the current member's relationship with the specified group.
 *       Possible statuses:
 *       - `member`: Already a member of the group (includes membership details)
 *       - `pending`: Has a pending join request
 *       - `approved`: Join request was approved (should transition to member)
 *       - `rejected`: Join request was rejected
 *       - `none`: No membership or join request exists
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group to check status for
 *     responses:
 *       200:
 *         description: Status retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               oneOf:
 *                 - type: object
 *                   description: Member status response
 *                   properties:
 *                     success:
 *                       type: boolean
 *                       example: true
 *                     status:
 *                       type: string
 *                       enum: [member]
 *                       example: "member"
 *                     membership:
 *                       $ref: '#/components/schemas/MembershipInfo'
 *                 - type: object
 *                   description: Request status response
 *                   properties:
 *                     success:
 *                       type: boolean
 *                       example: true
 *                     status:
 *                       type: string
 *                       enum: [pending, approved, rejected]
 *                       example: "pending"
 *                     request:
 *                       type: object
 *                       properties:
 *                         id:
 *                           type: string
 *                         status:
 *                           type: string
 *                         message:
 *                           type: string
 *                           nullable: true
 *                         createdAt:
 *                           type: string
 *                           format: date-time
 *                         reviewedAt:
 *                           type: string
 *                           format: date-time
 *                           nullable: true
 *                 - type: object
 *                   description: No relationship response
 *                   properties:
 *                     success:
 *                       type: boolean
 *                       example: true
 *                     status:
 *                       type: string
 *                       enum: [none]
 *                       example: "none"
 *       401:
 *         description: Not authenticated - member session required
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
 *                   example: "Unauthorized"
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
router.get('/me', requireMemberAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const memberId = req.session.memberId!

    // First check if already a member
    const membership = await prisma.groupMember.findFirst({
      where: {
        groupId,
        memberId,
        isActive: true,
      },
      select: {
        id: true,
        role: true,
        joinedAt: true,
        group: {
          select: {
            name: true,
          },
        },
      },
    })

    if (membership) {
      return res.json({
        success: true,
        status: 'member',
        membership: {
          id: membership.id,
          role: membership.role,
          joinedAt: membership.joinedAt,
          groupName: membership.group.name,
        },
      })
    }

    // Check for join request
    const request = await prisma.groupJoinRequest.findUnique({
      where: {
        groupId_memberId: { groupId, memberId },
      },
      select: {
        id: true,
        status: true,
        message: true,
        createdAt: true,
        reviewedAt: true,
      },
    })

    if (request) {
      return res.json({
        success: true,
        status: request.status, // 'pending', 'approved', 'rejected'
        request,
      })
    }

    // Neither a member nor has a request
    res.json({
      success: true,
      status: 'none',
    })
  } catch (error) {
    console.error('Error checking join request status:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

// =============================================================================
// GROUP LEADER ENDPOINTS (User-authenticated)
// =============================================================================

/**
 * @openapi
 * /api/groups/{groupId}/join-requests:
 *   get:
 *     tags:
 *       - Group Join Requests
 *     summary: List join requests for a group
 *     description: |
 *       Retrieves all join requests for a specific group, filtered by status.
 *       Only the group creator can access this endpoint.
 *       Default filter is 'pending' requests.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *       - in: query
 *         name: status
 *         required: false
 *         schema:
 *           type: string
 *           enum: [pending, approved, rejected]
 *           default: pending
 *         description: Filter requests by status (defaults to 'pending')
 *     responses:
 *       200:
 *         description: List of join requests retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 requests:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/JoinRequestWithMember'
 *                 count:
 *                   type: integer
 *                   description: Total number of requests returned
 *                   example: 5
 *       401:
 *         description: Not authenticated - user session required
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
 *                   example: "Unauthorized"
 *       404:
 *         description: Group not found or user is not the group creator
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
 *                   example: "Group not found or you are not the group creator"
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
router.get('/', requireAuth, async (req, res) => {
  try {
    const { groupId } = req.params
    const userId = (req.user as any)?.id

    // Creator, the group org's owner/role-holders, or a super admin may view.
    const group = await prisma.group.findFirst({
      where: { id: groupId, ...(await groupManageFilter(userId)), isActive: true },
      select: { id: true },
    })

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found or you cannot manage this group',
      })
    }

    // Get status filter (default: pending)
    const status = (req.query.status as string) || 'pending'

    const requests = await prisma.groupJoinRequest.findMany({
      where: {
        groupId,
        status,
      },
      include: {
        member: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            profilePicture: true,
            phoneNumber: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    })

    res.json({
      success: true,
      requests: requests.map((r) => ({
        id: r.id,
        status: r.status,
        message: r.message,
        createdAt: r.createdAt,
        member: {
          id: r.member.id,
          firstName: r.member.firstName,
          lastName: r.member.lastName,
          avatarUrl: r.member.profilePicture,
        },
      })),
      count: requests.length,
    })
  } catch (error) {
    console.error('Error listing join requests:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/join-requests/{requestId}/approve:
 *   post:
 *     tags:
 *       - Group Join Requests
 *     summary: Approve a join request
 *     description: |
 *       Approves a pending join request, adding the member to the group.
 *       Only the group creator can approve requests.
 *       This operation is atomic - it updates the request status and creates
 *       the group membership in a single transaction.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *       - in: path
 *         name: requestId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the join request to approve
 *     responses:
 *       200:
 *         description: Join request approved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 request:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       description: Request ID
 *                     status:
 *                       type: string
 *                       example: "approved"
 *                     reviewedAt:
 *                       type: string
 *                       format: date-time
 *                 member:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       description: Member's unique identifier
 *                     firstName:
 *                       type: string
 *                       description: Member's first name
 *                     lastName:
 *                       type: string
 *                       description: Member's last name
 *       401:
 *         description: Not authenticated - user session required
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
 *                   example: "Unauthorized"
 *       404:
 *         description: Group not found, user is not group creator, or pending request not found
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
 *                   example: "Pending request not found"
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
router.post('/:requestId/approve', requireAuth, async (req, res) => {
  try {
    const { groupId, requestId } = req.params
    const userId = (req.user as any)?.id

    // Creator, the group org's owner/role-holders, or a super admin may decide.
    const group = await prisma.group.findFirst({
      where: { id: groupId, ...(await groupManageFilter(userId)), isActive: true },
      select: { id: true, organizationId: true },
    })

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found or you cannot manage this group',
      })
    }

    // Find the request
    const request = await prisma.groupJoinRequest.findFirst({
      where: {
        id: requestId,
        groupId,
        status: 'pending',
      },
      include: {
        member: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
          },
        },
      },
    })

    if (!request) {
      return res.status(404).json({
        success: false,
        error: 'Pending request not found',
      })
    }

    // Transaction: update request status, add member to group, and ensure the
    // member is recorded in the group's organization (an approved member IS an
    // org member — without this they can't later be added to other groups in
    // the org, e.g. via transfer).
    const ops: Prisma.PrismaPromise<unknown>[] = [
      prisma.groupJoinRequest.update({
        where: { id: requestId },
        data: {
          status: 'approved',
          reviewedById: userId,
          reviewedAt: new Date(),
        },
        select: {
          id: true,
          status: true,
          reviewedAt: true,
        },
      }),
      // Add member to group (or reactivate if soft-deleted)
      prisma.groupMember.upsert({
        where: {
          groupId_memberId: { groupId, memberId: request.memberId },
        },
        create: {
          groupId,
          memberId: request.memberId,
          role: 'member',
          isActive: true,
        },
        update: {
          isActive: true,
          role: 'member',
          joinedAt: new Date(),
        },
      }),
    ]

    if (group.organizationId) {
      ops.push(
        prisma.memberOrganization.upsert({
          where: {
            memberId_organizationId: {
              memberId: request.memberId,
              organizationId: group.organizationId,
            },
          },
          create: {
            memberId: request.memberId,
            organizationId: group.organizationId,
          },
          update: {},
        })
      )
    }

    const [updatedRequest] = await prisma.$transaction(ops)

    // Append to the immutable membership audit trail. The upsert reactivates a
    // prior (soft-deleted) membership when present, so none of the member's
    // existing group data is lost.
    await recordMembershipEvent({
      memberId: request.memberId,
      action: 'APPROVED',
      groupId,
      organizationId: group.organizationId,
      actorId: userId,
      actorType: 'user',
      metadata: { requestId },
    })

    // Log approval
    logSuccess(ActivityTypes.JOIN.GROUP_REQUEST_APPROVED, req, {
      userId,
      memberId: request.memberId,
      groupId,
    })

    res.json({
      success: true,
      request: updatedRequest,
      member: {
        id: request.member.id,
        firstName: request.member.firstName,
        lastName: request.member.lastName,
      },
    })
  } catch (error) {
    console.error('Error approving join request:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/groups/{groupId}/join-requests/{requestId}/reject:
 *   post:
 *     tags:
 *       - Group Join Requests
 *     summary: Reject a join request
 *     description: |
 *       Rejects a pending join request.
 *       Only the group creator can reject requests.
 *       The member can submit a new request after being rejected.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the group
 *       - in: path
 *         name: requestId
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique identifier of the join request to reject
 *     responses:
 *       200:
 *         description: Join request rejected successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 request:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       description: Request ID
 *                     status:
 *                       type: string
 *                       example: "rejected"
 *                     reviewedAt:
 *                       type: string
 *                       format: date-time
 *       401:
 *         description: Not authenticated - user session required
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
 *                   example: "Unauthorized"
 *       404:
 *         description: Group not found, user is not group creator, or pending request not found
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
 *                   example: "Pending request not found"
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
router.post('/:requestId/reject', requireAuth, async (req, res) => {
  try {
    const { groupId, requestId } = req.params
    const userId = (req.user as any)?.id
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim() : undefined

    // Creator, the group org's owner/role-holders, or a super admin may decide.
    const group = await prisma.group.findFirst({
      where: { id: groupId, ...(await groupManageFilter(userId)), isActive: true },
      select: { id: true, organizationId: true },
    })

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found or you cannot manage this group',
      })
    }

    // Find the request
    const request = await prisma.groupJoinRequest.findFirst({
      where: {
        id: requestId,
        groupId,
        status: 'pending',
      },
    })

    if (!request) {
      return res.status(404).json({
        success: false,
        error: 'Pending request not found',
      })
    }

    // Mark rejected. The request row is KEPT (not deleted) so the decision is
    // preserved; a later re-request resets this same row to pending.
    const updatedRequest = await prisma.groupJoinRequest.update({
      where: { id: requestId },
      data: {
        status: 'rejected',
        reviewedById: userId,
        reviewedAt: new Date(),
      },
      select: {
        id: true,
        status: true,
        reviewedAt: true,
      },
    })

    // Append to the immutable membership audit trail so the leader can later
    // find this person (search by name/phone) and reverse the decision.
    await recordMembershipEvent({
      memberId: request.memberId,
      action: 'REJECTED',
      groupId,
      organizationId: group.organizationId,
      actorId: userId,
      actorType: 'user',
      note: reason || null,
      metadata: { requestId },
    })

    // Log rejection
    logSuccess(ActivityTypes.JOIN.GROUP_REQUEST_REJECTED, req, {
      userId,
      memberId: request.memberId,
      groupId,
    })

    res.json({
      success: true,
      request: updatedRequest,
    })
  } catch (error) {
    console.error('Error rejecting join request:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

export default router
