import { Router } from 'express'
import { z } from 'zod'
import rateLimit from 'express-rate-limit'
import { prisma } from '../lib/prisma.js'
import { sendVerificationCode, verifyCode } from '../services/twilio.js'
import {
  linkMemberToUser,
  findOrCreateMemberByPhone,
  unlinkMemberFromUser,
  getLinkedMember,
} from '../services/account-linking.js'
import { logSuccess, logFailure } from '../lib/activity-log.js'
import { ActivityTypes } from '../lib/activity-types.js'
import { requireAuth, requirePermission } from '../middleware/auth.js'
import type { User } from '../generated/prisma/index.js'

const router = Router()

/**
 * Phone number validation schema (E.164 format)
 */
const phoneNumberSchema = z.string().regex(/^\+[1-9]\d{1,14}$/, {
  message: 'Phone number must be in E.164 format (e.g., +1234567890)',
})

/**
 * Rate limiter for sending link-phone verification codes
 * Limits to 3 requests per 15 minutes per IP address
 */
const linkPhoneSendLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3,
  message: {
    success: false,
    error: 'Too many verification requests. Please try again in 15 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
})

/**
 * Rate limiter for verifying link-phone codes
 * Limits to 5 requests per 15 minutes per IP address
 */
const linkPhoneVerifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: {
    success: false,
    error: 'Too many verification attempts. Please try again in 15 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
})

/**
 * @openapi
 * /api/users:
 *   get:
 *     tags: [Users]
 *     summary: List all users
 *     description: Returns all users in the system, ordered by creation date (newest first). This endpoint returns the complete list of users with their profile information.
 *     operationId: listUsers
 *     responses:
 *       200:
 *         description: Successfully retrieved list of users
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 users:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 *                   description: Array of user objects
 *                 count:
 *                   type: integer
 *                   description: Total number of users returned
 *                   example: 3
 *             example:
 *               users:
 *                 - id: "clx1234567890"
 *                   email: "john@example.com"
 *                   name: "John Doe"
 *                   picture: "https://example.com/avatar.jpg"
 *                   googleId: "123456789"
 *                   createdAt: "2024-01-15T10:30:00.000Z"
 *                   updatedAt: "2024-01-15T10:30:00.000Z"
 *                 - id: "clx0987654321"
 *                   email: "jane@example.com"
 *                   name: "Jane Smith"
 *                   picture: null
 *                   googleId: "987654321"
 *                   createdAt: "2024-01-14T08:00:00.000Z"
 *                   updatedAt: "2024-01-14T08:00:00.000Z"
 *               count: 2
 *       500:
 *         description: Internal server error - Failed to fetch users from database
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "Failed to fetch users"
 */
router.get('/', async (_req, res) => {
  try {
    const users = await prisma.user.findMany({
      orderBy: {
        createdAt: 'desc'
      }
    })
    res.json({ users, count: users.length })
  } catch (error) {
    console.error('Error fetching users:', error)
    res.status(500).json({ error: 'Failed to fetch users' })
  }
})

/**
 * @openapi
 * /api/users/{id}:
 *   get:
 *     tags: [Users]
 *     summary: Get user by ID
 *     description: Retrieves a single user by their unique identifier. Returns the complete user profile including email, name, and profile picture.
 *     operationId: getUserById
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: The unique identifier of the user (CUID format)
 *         schema:
 *           type: string
 *           example: "clx1234567890"
 *     responses:
 *       200:
 *         description: Successfully retrieved user
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *             example:
 *               user:
 *                 id: "clx1234567890"
 *                 email: "john@example.com"
 *                 name: "John Doe"
 *                 picture: "https://example.com/avatar.jpg"
 *                 googleId: "123456789"
 *                 createdAt: "2024-01-15T10:30:00.000Z"
 *                 updatedAt: "2024-01-15T10:30:00.000Z"
 *       404:
 *         description: User not found - No user exists with the specified ID
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "User not found"
 *       500:
 *         description: Internal server error - Failed to fetch user from database
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "Failed to fetch user"
 */
router.get('/:id', async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id }
    })

    if (!user) {
      return res.status(404).json({ error: 'User not found' })
    }

    res.json({ user })
  } catch (error) {
    console.error('Error fetching user:', error)
    res.status(500).json({ error: 'Failed to fetch user' })
  }
})

// ============================================================================
// Account Linking Endpoints (User -> Member via Phone)
// ============================================================================

/**
 * @openapi
 * /api/users/link-phone/send:
 *   post:
 *     tags: [Users, Account Linking]
 *     summary: Send verification code to link phone to User account
 *     description: |
 *       Initiates phone linking by sending a verification code via SMS.
 *       This allows a User (Google OAuth) to link their account to a Member (phone verified) account.
 *
 *       **Rate Limited:** 3 requests per 15 minutes per IP address.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - phoneNumber
 *             properties:
 *               phoneNumber:
 *                 type: string
 *                 pattern: '^\+[1-9]\d{1,14}$'
 *                 description: Phone number in E.164 format
 *                 example: '+15551234567'
 *     responses:
 *       200:
 *         description: Verification code sent successfully
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
 *                   example: 'Verification code sent'
 *                 memberExists:
 *                   type: boolean
 *                   description: Whether a Member already exists with this phone
 *                 currentlyLinkedToUser:
 *                   type: boolean
 *                   description: Whether the Member is already linked to a different User
 *       400:
 *         description: Invalid request
 *       401:
 *         description: Not authenticated
 *       429:
 *         description: Rate limit exceeded
 */
router.post('/link-phone/send', linkPhoneSendLimiter, async (req, res) => {
  try {
    // Require User authentication
    if (!req.isAuthenticated() || !req.user) {
      return res.status(401).json({
        success: false,
        error: 'User authentication required',
      })
    }

    const user = req.user as User

    const sendSchema = z.object({
      phoneNumber: phoneNumberSchema,
    })

    const { phoneNumber } = sendSchema.parse(req.body)

    // Check if a Member exists with this phone
    const existingMember = await prisma.member.findUnique({
      where: { phoneNumber },
      select: { id: true, userId: true, phoneNumber: true },
    })

    // Check if user already has a linked Member
    const userLinkedMember = await getLinkedMember(user.id)
    if (userLinkedMember) {
      return res.status(400).json({
        success: false,
        error: `You already have a linked Member account (${userLinkedMember.phoneNumber}). Unlink it first.`,
        linkedMemberId: userLinkedMember.id,
      })
    }

    // Send verification code
    const result = await sendVerificationCode(phoneNumber)

    if (!result.success) {
      logFailure(ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_SEND_FAILED, req, {
        userId: user.id,
        phoneNumber,
        errorMessage: result.error || 'Failed to send verification code',
      })
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to send verification code',
      })
    }

    // Log success
    logSuccess(ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_SEND, req, {
      userId: user.id,
      phoneNumber,
      memberExists: !!existingMember,
    })

    res.json({
      success: true,
      message: 'Verification code sent',
      status: result.status,
      memberExists: !!existingMember,
      currentlyLinkedToUser: existingMember?.userId ? existingMember.userId !== user.id : false,
    })
  } catch (error: any) {
    console.error('[API] Error in /users/link-phone/send:', error)

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      })
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/users/link-phone/verify:
 *   post:
 *     tags: [Users, Account Linking]
 *     summary: Verify code and link Member to User account
 *     description: |
 *       Verifies the SMS code and links the Member account to the authenticated User.
 *       If no Member exists with this phone number, a new Member is created.
 *
 *       **Re-linking:** If the Member is already linked to a different User, it will be
 *       re-linked to the current User (phone verification proves ownership).
 *
 *       **Rate Limited:** 5 requests per 15 minutes per IP address.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - phoneNumber
 *               - code
 *             properties:
 *               phoneNumber:
 *                 type: string
 *                 pattern: '^\+[1-9]\d{1,14}$'
 *                 description: Phone number in E.164 format
 *                 example: '+15551234567'
 *               code:
 *                 type: string
 *                 minLength: 4
 *                 maxLength: 6
 *                 description: Verification code received via SMS
 *                 example: '123456'
 *     responses:
 *       200:
 *         description: Phone linked successfully
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
 *                   example: 'Phone linked successfully'
 *                 member:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     phoneNumber:
 *                       type: string
 *                     created:
 *                       type: boolean
 *                       description: Whether the Member was newly created
 *                 relinked:
 *                   type: boolean
 *                   description: Whether the Member was re-linked from another User
 *                 previousUserId:
 *                   type: string
 *                   description: Previous User ID if re-linked
 *       400:
 *         description: Invalid request or verification failed
 *       401:
 *         description: Not authenticated
 *       429:
 *         description: Rate limit exceeded
 */
router.post('/link-phone/verify', linkPhoneVerifyLimiter, async (req, res) => {
  try {
    // Require User authentication
    if (!req.isAuthenticated() || !req.user) {
      return res.status(401).json({
        success: false,
        error: 'User authentication required',
      })
    }

    const user = req.user as User

    const verifySchema = z.object({
      phoneNumber: phoneNumberSchema,
      code: z.string().min(4).max(6),
    })

    const { phoneNumber, code } = verifySchema.parse(req.body)

    // Check if user already has a linked Member
    const userLinkedMember = await getLinkedMember(user.id)
    if (userLinkedMember) {
      return res.status(400).json({
        success: false,
        error: `You already have a linked Member account (${userLinkedMember.phoneNumber}). Unlink it first.`,
        linkedMemberId: userLinkedMember.id,
      })
    }

    // Verify the code
    const verifyResult = await verifyCode(phoneNumber, code)

    if (!verifyResult.success) {
      logFailure(ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_VERIFY_FAILED, req, {
        userId: user.id,
        phoneNumber,
        errorMessage: verifyResult.error || 'Verification failed',
      })
      return res.status(400).json({
        success: false,
        error: verifyResult.error || 'Failed to verify code',
      })
    }

    if (!verifyResult.valid) {
      logFailure(ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_VERIFY_FAILED, req, {
        userId: user.id,
        phoneNumber,
        errorMessage: 'Invalid verification code',
      })
      return res.status(400).json({
        success: false,
        valid: false,
        error: 'Invalid verification code',
      })
    }

    // Find or create Member by phone
    const memberResult = await findOrCreateMemberByPhone(phoneNumber)

    if (!memberResult.success || !memberResult.data) {
      logFailure(ActivityTypes.AUTH.ACCOUNT_LINK_FAILED, req, {
        userId: user.id,
        phoneNumber,
        errorMessage: memberResult.error || 'Failed to find or create Member',
      })
      return res.status(400).json({
        success: false,
        error: memberResult.error || 'Failed to process phone linking',
      })
    }

    const { member, created } = memberResult.data

    // Link the Member to the User
    const linkResult = await linkMemberToUser(member.id, user.id)

    if (!linkResult.success) {
      logFailure(ActivityTypes.AUTH.ACCOUNT_LINK_FAILED, req, {
        userId: user.id,
        memberId: member.id,
        phoneNumber,
        errorMessage: linkResult.error,
      })
      return res.status(400).json({
        success: false,
        error: linkResult.error,
      })
    }

    // Update session with linked Member ID
    req.session.linkedMemberId = member.id

    // Log success
    const activityType = linkResult.data?.previousUserId
      ? ActivityTypes.AUTH.ACCOUNT_LINK_RELINKED
      : ActivityTypes.AUTH.ACCOUNT_LINK_SUCCESS

    logSuccess(activityType, req, {
      userId: user.id,
      memberId: member.id,
      phoneNumber,
      created,
      previousUserId: linkResult.data?.previousUserId,
    })

    res.json({
      success: true,
      message: linkResult.data?.previousUserId
        ? 'Phone linked successfully (re-linked from another account)'
        : 'Phone linked successfully',
      member: {
        id: member.id,
        phoneNumber: member.phoneNumber,
        firstName: member.firstName,
        lastName: member.lastName,
        created,
      },
      relinked: !!linkResult.data?.previousUserId,
      previousUserId: linkResult.data?.previousUserId,
    })
  } catch (error: any) {
    console.error('[API] Error in /users/link-phone/verify:', error)

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      })
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/users/me/linked-member:
 *   get:
 *     tags: [Users, Account Linking]
 *     summary: Get linked Member account for current User
 *     description: Returns the Member account linked to the authenticated User, if any.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Linked Member (or null if not linked)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 member:
 *                   type: object
 *                   nullable: true
 *                   properties:
 *                     id:
 *                       type: string
 *                     phoneNumber:
 *                       type: string
 *                     firstName:
 *                       type: string
 *                     lastName:
 *                       type: string
 *                     userLinkedAt:
 *                       type: string
 *                       format: date-time
 *       401:
 *         description: Not authenticated
 */
router.get('/me/linked-member', async (req, res) => {
  try {
    if (!req.isAuthenticated() || !req.user) {
      return res.status(401).json({
        success: false,
        error: 'User authentication required',
      })
    }

    const user = req.user as User
    const member = await getLinkedMember(user.id)

    res.json({
      success: true,
      member: member
        ? {
            id: member.id,
            phoneNumber: member.phoneNumber,
            firstName: member.firstName,
            lastName: member.lastName,
            email: member.email,
            profilePicture: member.profilePicture,
            userLinkedAt: member.userLinkedAt,
          }
        : null,
    })
  } catch (error) {
    console.error('[API] Error in /users/me/linked-member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/users/me/linked-member:
 *   delete:
 *     tags: [Users, Account Linking]
 *     summary: Unlink Member account from current User
 *     description: Removes the link between the authenticated User and their linked Member account.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Member unlinked successfully
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
 *                   example: 'Member account unlinked'
 *       400:
 *         description: No linked Member or unlink failed
 *       401:
 *         description: Not authenticated
 */
router.delete('/me/linked-member', async (req, res) => {
  try {
    if (!req.isAuthenticated() || !req.user) {
      return res.status(401).json({
        success: false,
        error: 'User authentication required',
      })
    }

    const user = req.user as User
    const member = await getLinkedMember(user.id)

    if (!member) {
      return res.status(400).json({
        success: false,
        error: 'No linked Member account',
      })
    }

    const unlinkResult = await unlinkMemberFromUser(member.id)

    if (!unlinkResult.success) {
      logFailure(ActivityTypes.AUTH.ACCOUNT_UNLINK_FAILED, req, {
        userId: user.id,
        memberId: member.id,
        errorMessage: unlinkResult.error,
      })
      return res.status(400).json({
        success: false,
        error: unlinkResult.error,
      })
    }

    // Clear from session
    delete req.session.linkedMemberId

    logSuccess(ActivityTypes.AUTH.ACCOUNT_UNLINK_SUCCESS, req, {
      userId: user.id,
      memberId: member.id,
      phoneNumber: member.phoneNumber,
    })

    res.json({
      success: true,
      message: 'Member account unlinked',
      unlinkedMemberId: member.id,
    })
  } catch (error) {
    console.error('[API] Error in DELETE /users/me/linked-member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/users/{id}:
 *   delete:
 *     tags: [Users]
 *     summary: Delete a user
 *     description: Permanently deletes a user account and clears their organizationId. Requires authentication via API key.
 *     operationId: deleteUser
 *     security:
 *       - apiKey: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: User deleted
 *       404:
 *         description: User not found
 *       500:
 *         description: Internal server error
 */
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.params.id } })

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' })
    }

    await prisma.user.delete({ where: { id: req.params.id } })

    res.json({ success: true })
  } catch (error) {
    console.error('Error deleting user:', error)
    res.status(500).json({ success: false, error: 'Failed to delete user' })
  }
})

/**
 * @openapi
 * /api/users/{id}/organization:
 *   patch:
 *     tags: [Users]
 *     summary: Update a user's organization
 *     description: |
 *       Moves a user to a different organization. Requires the authenticated user
 *       to have organization.update permission on the target organization.
 *     operationId: updateUserOrganization
 *     security:
 *       - userSession: []
 *       - apiKey: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: The user ID to update
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - organizationId
 *             properties:
 *               organizationId:
 *                 type: string
 *                 format: uuid
 *                 description: The target organization ID
 *     responses:
 *       200:
 *         description: User organization updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     name:
 *                       type: string
 *                     email:
 *                       type: string
 *                     organizationId:
 *                       type: string
 *       400:
 *         description: Invalid request
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Insufficient permissions
 *       404:
 *         description: User or organization not found
 */
router.patch(
  '/:id/organization',
  requireAuth,
  requirePermission('organization.update', 'organization', (req) => req.body.organizationId),
  async (req, res) => {
    try {
      const { id } = req.params

      const schema = z.object({
        organizationId: z.string().uuid(),
      })

      const { organizationId } = schema.parse(req.body)

      // Verify user exists
      const user = await prisma.user.findUnique({
        where: { id },
        select: { id: true, name: true, email: true, organizationId: true },
      })

      if (!user) {
        return res.status(404).json({ success: false, error: 'User not found' })
      }

      // Verify target organization exists
      const organization = await prisma.organization.findUnique({
        where: { id: organizationId },
        select: { id: true, name: true },
      })

      if (!organization) {
        return res.status(404).json({ success: false, error: 'Organization not found' })
      }

      // Update user's organization
      const updated = await prisma.user.update({
        where: { id },
        data: { organizationId },
        select: { id: true, name: true, email: true, organizationId: true },
      })

      res.json({ success: true, user: updated })
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: error.errors[0].message })
      }
      console.error('Error updating user organization:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)

export default router
