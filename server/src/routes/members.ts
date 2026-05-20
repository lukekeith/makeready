import { Router } from 'express'
import { z } from 'zod'
import multer from 'multer'
import sharp from 'sharp'
import {
  getMember,
  getMemberByPhone,
  createMember,
  updateMember,
  deleteMember,
  getMemberGroups,
  addMemberToOrganization,
} from '../services/member.js'
import {
  unlinkGoogleProfile,
  syncGoogleProfile,
} from '../services/member-google.js'
import {
  unlinkMemberFromUser,
  getLinkedUser,
} from '../services/account-linking.js'
import {
  requireAuth,
  requireMemberOrOrgOwner,
  requireMemberAuth,
} from '../middleware/auth.js'
import { sendVerificationCode, verifyCode } from '../services/twilio.js'
import { uploadMemberAvatar, deleteMemberAvatar } from '../services/storage.js'
import { prisma } from '../lib/prisma.js'
import { logSuccess } from '../lib/activity-log.js'
import { ActivityTypes } from '../lib/activity-types.js'

// Configure multer for memory storage (we'll process and upload to R2)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB
  },
  fileFilter: (_req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true)
    } else {
      cb(new Error('Invalid file type. Allowed: JPEG, PNG, GIF, WebP'))
    }
  },
})

const router = Router()

/**
 * @openapi
 * /api/members/me:
 *   get:
 *     tags: [Members]
 *     summary: Get current member profile
 *     description: Returns the currently authenticated member's profile.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: Member profile
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Member'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/me', requireMemberAuth, async (req, res) => {
  try {
    // Member is already loaded by requireMemberAuth middleware
    const member = req.member

    if (!member) {
      return res.status(401).json({
        success: false,
        error: 'Member not authenticated',
      })
    }

    res.json({
      success: true,
      data: member,
    })
  } catch (error) {
    console.error('Error fetching current member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/me/linked-user:
 *   get:
 *     tags: [Members, Account Linking]
 *     summary: Get linked User account for current Member
 *     description: Returns the User account linked to the authenticated Member, if any.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: Linked User (or null if not linked)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 user:
 *                   type: object
 *                   nullable: true
 *                   properties:
 *                     id:
 *                       type: string
 *                     email:
 *                       type: string
 *                     name:
 *                       type: string
 *                     picture:
 *                       type: string
 *       401:
 *         description: Member not authenticated
 */
router.get('/me/linked-user', requireMemberAuth, async (req, res) => {
  try {
    const member = req.member

    if (!member) {
      return res.status(401).json({
        success: false,
        error: 'Member not authenticated',
      })
    }

    const user = await getLinkedUser(member.id)

    res.json({
      success: true,
      user: user
        ? {
            id: user.id,
            email: user.email,
            name: user.name,
            picture: user.picture,
          }
        : null,
    })
  } catch (error) {
    console.error('Error fetching linked user:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/me/linked-user:
 *   delete:
 *     tags: [Members, Account Linking]
 *     summary: Unlink User account from current Member
 *     description: Removes the link between the authenticated Member and their linked User account.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: User unlinked successfully
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
 *                   example: 'User account unlinked'
 *       400:
 *         description: No linked User or unlink failed
 *       401:
 *         description: Not authenticated
 */
router.delete('/me/linked-user', requireMemberAuth, async (req, res) => {
  try {
    const member = req.member

    if (!member) {
      return res.status(401).json({
        success: false,
        error: 'Member not authenticated',
      })
    }

    const unlinkResult = await unlinkMemberFromUser(member.id)

    if (!unlinkResult.success) {
      return res.status(400).json({
        success: false,
        error: unlinkResult.error,
      })
    }

    logSuccess(ActivityTypes.AUTH.ACCOUNT_UNLINK_SUCCESS, req, {
      memberId: member.id,
      userId: unlinkResult.data?.userId,
    })

    res.json({
      success: true,
      message: 'User account unlinked',
    })
  } catch (error) {
    console.error('Error unlinking user:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/session:
 *   get:
 *     tags: [Members]
 *     summary: Check member authentication status
 *     description: |
 *       Returns the current member's authentication status and profile if authenticated.
 *       Does not require authentication - returns `authenticated: false` if not logged in.
 *     responses:
 *       200:
 *         description: Authentication status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 authenticated:
 *                   type: boolean
 *                 member:
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Member'
 *                     - type: 'null'
 *                 authenticatedAt:
 *                   type: string
 *                   format: date-time
 *                   nullable: true
 */
router.get('/session', async (req, res) => {
  try {
    const memberId = req.session.memberId
    const isAuthenticated = !!memberId

    if (!isAuthenticated) {
      return res.json({
        success: true,
        authenticated: false,
        member: null,
      })
    }

    // Load member data
    const result = await getMember(memberId)

    if (!result.success) {
      // Clear invalid session
      req.session.memberId = undefined
      return res.json({
        success: true,
        authenticated: false,
        member: null,
      })
    }

    res.json({
      success: true,
      authenticated: true,
      member: result.data,
      authenticatedAt: req.session.memberAuthenticatedAt,
    })
  } catch (error) {
    console.error('Error checking member session:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/logout:
 *   post:
 *     tags: [Members]
 *     summary: Logout current member
 *     description: Clears the current member session.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: Logged out successfully
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
 *                   example: Logged out successfully
 */
router.post('/logout', requireMemberAuth, async (req, res) => {
  try {
    const memberId = req.session.memberId

    // Clear member session
    req.session.memberId = undefined
    req.session.memberAuthenticatedAt = undefined

    console.log(`✅ Member logged out: ${memberId}`)

    res.json({
      success: true,
      message: 'Logged out successfully',
    })
  } catch (error) {
    console.error('Error logging out member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/verify-phone:
 *   post:
 *     tags: [Members]
 *     summary: Send phone verification code
 *     description: |
 *       Initiates phone verification by sending an SMS code via Twilio Verify.
 *       Returns whether the member already exists in the system.
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
 *                 example: '+15551234567'
 *                 description: Phone number in E.164 format
 *               organizationId:
 *                 type: string
 *                 description: Organization ID (optional, for org-specific Twilio service)
 *     responses:
 *       200:
 *         description: Verification code sent
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 memberExists:
 *                   type: boolean
 *                   description: Whether member with this phone already exists
 *                 memberId:
 *                   type: string
 *                   description: Member ID if exists
 *                 organizations:
 *                   type: array
 *                   items:
 *                     type: string
 *                   description: Organization IDs the member belongs to
 *                 message:
 *                   type: string
 *                   example: Verification code sent
 *       400:
 *         description: Invalid phone number format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
const verifyPhoneSchema = z.object({
  phoneNumber: z
    .string()
    .regex(/^\+[1-9]\d{1,14}$/, 'Phone number must be in E.164 format'),
  organizationId: z.string().optional(), // Optional: For new member creation
})

// Handler function for sending verification (shared by both routes)
async function handleSendVerification(req: any, res: any) {
  try {
    const validation = verifyPhoneSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const { phoneNumber, organizationId } = validation.data

    // Check if member exists
    const memberResult = await getMemberByPhone(phoneNumber)
    const memberExists = memberResult.success

    // Look up organization's Twilio Verify service SID if organizationId provided
    let verifyServiceSid: string | null = null
    if (organizationId) {
      const org = await prisma.organization.findUnique({
        where: { id: organizationId },
        select: { twilioVerifyServiceSid: true },
      })
      verifyServiceSid = org?.twilioVerifyServiceSid ?? null
    }

    // Send verification code (uses org's service or default)
    const verificationResult = await sendVerificationCode(phoneNumber, verifyServiceSid)

    if (!verificationResult.success) {
      return res.status(500).json({
        success: false,
        error: verificationResult.error,
      })
    }

    // Get organization IDs if member exists
    const memberData = memberResult.data as any
    const organizationIds = memberExists
      ? memberData?.organizations?.map((mo: any) => mo.organizationId) || []
      : []

    res.json({
      success: true,
      memberExists,
      memberId: memberExists ? memberResult.data?.id : undefined,
      organizations: organizationIds,
      message: 'Verification code sent',
    })
  } catch (error) {
    console.error('Error initiating phone verification:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}

/**
 * @openapi
 * /api/members/send-verification:
 *   post:
 *     tags: [Members]
 *     summary: Send phone verification code (alias)
 *     description: Alias for /verify-phone for client compatibility.
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
 *                 example: '+15551234567'
 *               organizationId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Verification code sent
 */
router.post('/send-verification', handleSendVerification)

router.post('/verify-phone', async (req, res) => {
  try {
    const validation = verifyPhoneSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const { phoneNumber, organizationId } = validation.data

    // Check if member exists
    const memberResult = await getMemberByPhone(phoneNumber)
    const memberExists = memberResult.success

    // Look up organization's Twilio Verify service SID if organizationId provided
    let verifyServiceSid: string | null = null
    if (organizationId) {
      const org = await prisma.organization.findUnique({
        where: { id: organizationId },
        select: { twilioVerifyServiceSid: true },
      })
      verifyServiceSid = org?.twilioVerifyServiceSid ?? null
    }

    // Send verification code (uses org's service or default)
    const verificationResult = await sendVerificationCode(phoneNumber, verifyServiceSid)

    if (!verificationResult.success) {
      return res.status(500).json({
        success: false,
        error: verificationResult.error,
      })
    }

    // Get organization IDs if member exists
    const memberData = memberResult.data as any
    const organizationIds = memberExists
      ? memberData?.organizations?.map((mo: any) => mo.organizationId) || []
      : []

    res.json({
      success: true,
      memberExists,
      memberId: memberExists ? memberResult.data?.id : undefined,
      organizations: organizationIds,
      message: 'Verification code sent',
    })
  } catch (error) {
    console.error('Error initiating phone verification:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/confirm-verification:
 *   post:
 *     tags: [Members]
 *     summary: Verify code and create session
 *     description: |
 *       Verifies the SMS code and either creates a new member or updates an existing one.
 *       On success, establishes a member session (sets session cookie).
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - phoneNumber
 *               - code
 *               - organizationId
 *             properties:
 *               phoneNumber:
 *                 type: string
 *                 pattern: '^\+[1-9]\d{1,14}$'
 *                 example: '+15551234567'
 *               code:
 *                 type: string
 *                 minLength: 6
 *                 maxLength: 6
 *                 example: '123456'
 *               organizationId:
 *                 type: string
 *                 description: Organization to add member to
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               birthday:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       200:
 *         description: Phone verified, session established
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Member'
 *                 message:
 *                   type: string
 *                   example: Phone verified successfully
 *       400:
 *         description: Invalid verification code
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
const confirmVerificationSchema = z.object({
  phoneNumber: z
    .string()
    .regex(/^\+[1-9]\d{1,14}$/, 'Phone number must be in E.164 format'),
  code: z.string().length(6, 'Verification code must be 6 digits'),
  organizationId: z.string().optional().nullable(), // Optional: For new member creation
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  email: z.string().email().optional(),
  birthday: z.string().datetime().optional(),
  smsConsent: z.boolean().optional(),
  groupId: z.string().uuid().optional(), // If provided, auto-submit a join request after verification
})

router.post('/confirm-verification', async (req, res) => {
  try {
    console.log('[confirm-verification] Request body:', req.body)

    const validation = confirmVerificationSchema.safeParse(req.body)
    if (!validation.success) {
      console.log('[confirm-verification] Validation failed:', validation.error.errors)
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const { phoneNumber, code, organizationId, firstName, lastName, email, birthday, smsConsent, groupId: joinGroupId } = validation.data
    console.log('[confirm-verification] Validated data:', { phoneNumber, organizationId, joinGroupId: joinGroupId || 'NOT PROVIDED' })

    // Look up organization's Twilio Verify service SID
    let verifyServiceSid: string | null = null
    if (organizationId) {
      const org = await prisma.organization.findUnique({
        where: { id: organizationId },
        select: { twilioVerifyServiceSid: true },
      })
      verifyServiceSid = org?.twilioVerifyServiceSid ?? null
    }

    // Verify code with Twilio (uses org's service or default)
    const verificationResult = await verifyCode(phoneNumber, code, verifyServiceSid)

    if (!verificationResult.success || !verificationResult.valid) {
      return res.status(400).json({
        success: false,
        error: verificationResult.error || 'Invalid verification code',
      })
    }

    // Check if member exists
    const memberResult = await getMemberByPhone(phoneNumber)
    console.log('[confirm-verification] Member lookup result:', {
      success: memberResult.success,
      found: !!memberResult.data,
      memberId: memberResult.data?.id,
    })

    let member

    if (memberResult.success) {
      // Update existing member
      const updateResult = await updateMember(memberResult.data!.id, {
        phoneVerified: true,
        lastVerifiedAt: new Date(),
        firstName: firstName || memberResult.data!.firstName || undefined,
        lastName: lastName || memberResult.data!.lastName || undefined,
        email: email || memberResult.data!.email || undefined,
        birthday: birthday ? new Date(birthday) : memberResult.data!.birthday || undefined,
        ...(smsConsent !== undefined && {
          smsConsent,
          smsConsentAt: smsConsent ? new Date() : null,
        }),
      })

      if (!updateResult.success) {
        return res.status(500).json({
          success: false,
          error: updateResult.error,
        })
      }

      // Check if member is already part of this organization (only if organizationId provided)
      const existingMemberData = memberResult.data as any
      if (organizationId) {
        const alreadyInOrg = existingMemberData.organizations?.some(
          (mo: any) => mo.organizationId === organizationId
        )

        if (!alreadyInOrg) {
          // Add member to the new organization
          const addResult = await addMemberToOrganization(existingMemberData.id, organizationId)
          if (!addResult.success) {
            console.warn('Failed to add member to organization:', addResult.error)
          }
        }
      }

      // Reload member with updated organizations
      const reloadedResult = await getMember(existingMemberData.id)
      member = reloadedResult.success ? reloadedResult.data : updateResult.data
    } else {
      // Create new member
      const createResult = await createMember({
        organizationId: organizationId || undefined, // Handle null/undefined
        phoneNumber,
        phoneVerified: true,
        smsConsent: smsConsent ?? false,
        smsConsentAt: smsConsent ? new Date() : undefined,
        firstName,
        lastName,
        email,
        birthday: birthday ? new Date(birthday) : undefined,
      })

      if (!createResult.success) {
        return res.status(500).json({
          success: false,
          error: createResult.error,
        })
      }

      member = createResult.data
    }

    // Create member session
    req.session.memberId = member!.id
    req.session.memberAuthenticatedAt = new Date()

    console.log('[confirm-verification] Session set:', {
      memberId: req.session.memberId,
      memberAuthenticatedAt: req.session.memberAuthenticatedAt,
      sessionID: req.sessionID,
    })
    console.log(`✅ Member session created for: ${member!.phoneNumber}`)

    // If groupId was provided, auto-submit a join request in the same
    // request so we don't need a second HTTP call with cookie forwarding.
    //
    // The Laravel client uses two response flags to pick the right confirmed
    // screen for the user:
    //   alreadyMember = true   → the user already has an active membership
    //   wasNewRequest = false  → joinRequest is an existing one we returned
    //                            unchanged (the user has filed before)
    //   wasNewRequest = true   → joinRequest was just created or re-submitted
    let joinRequest = null
    let wasNewRequest = false
    let alreadyMember = false
    if (joinGroupId && member) {
      const groupId = joinGroupId
      try {
        const group = await prisma.group.findFirst({
          where: { id: groupId, isActive: true },
          select: { id: true, name: true },
        })

        if (group) {
          // Check not already a member
          const existingMembership = await prisma.groupMember.findFirst({
            where: { groupId, memberId: member.id, isActive: true },
          })

          if (!existingMembership) {
            // Check for existing pending request
            const existingRequest = await prisma.groupJoinRequest.findUnique({
              where: { groupId_memberId: { groupId, memberId: member.id } },
            })

            if (!existingRequest || existingRequest.status === 'rejected') {
              if (existingRequest) {
                // Re-submit after rejection
                joinRequest = await prisma.groupJoinRequest.update({
                  where: { id: existingRequest.id },
                  data: { status: 'pending', reviewedAt: null, reviewedBy: { disconnect: true } },
                })
              } else {
                joinRequest = await prisma.groupJoinRequest.create({
                  data: { groupId, memberId: member.id, status: 'pending' },
                })
              }
              wasNewRequest = true
              console.log(`✅ Join request created for group ${group.name}`)
            } else {
              console.log(`⚠ Join request already exists (${existingRequest.status}) for group ${group.name}`)
              joinRequest = existingRequest
              wasNewRequest = false
            }
          } else {
            console.log(`⚠ Already a member of group ${group.name}`)
            alreadyMember = true
          }
        }
      } catch (joinError) {
        console.error('Error creating join request:', joinError)
        // Don't fail the whole verification — log and continue
      }
    }

    res.json({
      success: true,
      data: member,
      message: 'Phone verified successfully',
      joinRequest,
      wasNewRequest,
      alreadyMember,
    })
  } catch (error) {
    console.error('Error confirming verification:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}/profile:
 *   get:
 *     tags: [Members]
 *     summary: Get full member profile for member detail page
 *     description: |
 *       Returns a member's complete profile including contact info, Google-linked
 *       account data, and group memberships. Accessible by the member themselves
 *       or any member who shares a group with them.
 *     security:
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     responses:
 *       200:
 *         description: Full member profile
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
 *                     firstName:
 *                       type: string
 *                     lastName:
 *                       type: string
 *                     phoneNumber:
 *                       type: string
 *                     email:
 *                       type: string
 *                     gender:
 *                       type: string
 *                     birthday:
 *                       type: string
 *                       format: date-time
 *                     profilePicture:
 *                       type: string
 *                     googleEmail:
 *                       type: string
 *                     googlePicture:
 *                       type: string
 *                     googleLinkedAt:
 *                       type: string
 *                       format: date-time
 *                     groups:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                           name:
 *                             type: string
 *                           role:
 *                             type: string
 *                           joinedAt:
 *                             type: string
 *                             format: date-time
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: No shared group with this member
 *       404:
 *         description: Member not found
 */
router.get('/:memberId/profile', requireAuth, async (req, res) => {
  try {
    const { memberId } = req.params
    const userId = (req.user as any)?.id

    // Load target member with all profile data
    const member = await prisma.member.findUnique({
      where: { id: memberId, isActive: true },
      include: {
        groupMemberships: {
          where: { isActive: true },
          select: {
            role: true,
            joinedAt: true,
            group: {
              select: {
                id: true,
                name: true,
                coverImageUrl: true,
                creatorId: true,
              },
            },
          },
        },
      },
    })

    if (!member) {
      return res.status(404).json({
        success: false,
        error: 'Member not found',
      })
    }

    // Authorization: user must be the creator of at least one group this member belongs to,
    // OR the member has a pending join request for a group the user created
    let hasAccess = member.groupMemberships.some(
      (gm) => gm.group.creatorId === userId
    )

    if (!hasAccess) {
      // Check if member has a pending join request for a group owned by this user
      const pendingRequest = await prisma.groupJoinRequest.findFirst({
        where: {
          memberId: memberId,
          status: 'pending',
          group: { creatorId: userId },
        },
      })
      if (pendingRequest) {
        hasAccess = true
      }
    }

    if (!hasAccess) {
      return res.status(403).json({
        success: false,
        error: 'You do not have access to this member',
      })
    }

    res.json({
      success: true,
      data: {
        id: member.id,
        firstName: member.firstName,
        lastName: member.lastName,
        phoneNumber: member.phoneNumber,
        email: member.email,
        gender: member.gender,
        birthday: member.birthday,
        profilePicture: member.profilePicture,
        googleEmail: member.googleEmail,
        googlePicture: member.googlePicture,
        googleLinkedAt: member.googleLinkedAt,
        createdAt: member.createdAt,
        groups: member.groupMemberships.map((gm) => ({
          id: gm.group.id,
          name: gm.group.name,
          coverImageUrl: gm.group.coverImageUrl,
          role: gm.role,
          joinedAt: gm.joinedAt,
        })),
      },
    })
  } catch (error) {
    console.error('Error fetching member profile:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}:
 *   get:
 *     tags: [Members]
 *     summary: Get member by ID
 *     description: Returns a member's profile. Requires member auth (self) or user auth (org owner).
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     responses:
 *       200:
 *         description: Member profile
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Member'
 *       404:
 *         description: Member not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/:memberId', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params

    const result = await getMember(memberId)

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
    console.error('Error fetching member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}:
 *   patch:
 *     tags: [Members]
 *     summary: Update member profile
 *     description: Updates a member's profile. Requires member auth (self) or user auth (org owner).
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               birthday:
 *                 type: string
 *                 format: date-time
 *               profilePicture:
 *                 type: string
 *                 format: uri
 *     responses:
 *       200:
 *         description: Member updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Member'
 *       400:
 *         description: Invalid request body
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
const updateMemberSchema = z.object({
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  email: z.string().email().optional(),
  gender: z.enum(['male', 'female']).optional().nullable(),
  birthday: z.string().optional().nullable(), // Allow ISO date string or null
  profilePicture: z.string().url().optional().nullable(),
  smsConsent: z.boolean().optional(),
})

router.patch('/:memberId', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params

    const validation = updateMemberSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: validation.error.errors[0].message,
      })
    }

    const { birthday, gender, profilePicture, smsConsent, ...rest } = validation.data
    const updateData = {
      ...rest,
      gender: gender === null ? null : gender,
      birthday: birthday ? new Date(birthday) : birthday === null ? null : undefined,
      profilePicture: profilePicture === null ? null : profilePicture,
      ...(smsConsent !== undefined && {
        smsConsent,
        smsConsentAt: smsConsent ? new Date() : null,
      }),
    }

    const result = await updateMember(memberId, updateData)

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
    console.error('Error updating member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}:
 *   delete:
 *     tags: [Members]
 *     summary: Delete member
 *     description: Soft deletes a member. Requires member auth (self) or user auth (org owner).
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     responses:
 *       200:
 *         description: Member deleted
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
 *                   example: Member deleted successfully
 */
router.delete('/:memberId', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params

    const result = await deleteMember(memberId)

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error,
      })
    }

    res.json({
      success: true,
      message: 'Member deleted successfully',
    })
  } catch (error) {
    console.error('Error deleting member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}/avatar:
 *   post:
 *     tags: [Members]
 *     summary: Upload member avatar
 *     description: |
 *       Uploads a new avatar image for the member. The image is processed,
 *       resized to a maximum of 512x512 pixels, and uploaded to cloud storage.
 *       Any existing avatar is automatically deleted.
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
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
 *                 description: Image file (JPEG, PNG, GIF, WebP). Max 5MB.
 *     responses:
 *       200:
 *         description: Avatar uploaded successfully
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
 *                     url:
 *                       type: string
 *                       format: uri
 *                       description: Public URL of the uploaded avatar
 *       400:
 *         description: No file uploaded or invalid file type
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post(
  '/:memberId/avatar',
  requireMemberOrOrgOwner,
  upload.single('file'),
  async (req, res) => {
    try {
      const { memberId } = req.params
      const file = req.file

      if (!file) {
        return res.status(400).json({
          success: false,
          error: 'No file uploaded',
        })
      }

      // Get current member to check for existing avatar
      const memberResult = await getMember(memberId)
      if (!memberResult.success) {
        return res.status(404).json({
          success: false,
          error: 'Member not found',
        })
      }

      const oldAvatarUrl = memberResult.data?.profilePicture

      // Process image with sharp - resize to max 512x512 and convert to webp for efficiency
      let processedBuffer: Buffer
      let mimeType: string

      try {
        processedBuffer = await sharp(file.buffer)
          .resize(512, 512, {
            fit: 'cover',
            withoutEnlargement: true,
          })
          .webp({ quality: 85 })
          .toBuffer()
        mimeType = 'image/webp'
      } catch (sharpError) {
        console.error('Error processing image:', sharpError)
        return res.status(400).json({
          success: false,
          error: 'Failed to process image',
        })
      }

      // Upload to R2
      const uploadResult = await uploadMemberAvatar(
        memberId,
        processedBuffer,
        mimeType
      )

      if (!uploadResult.success) {
        return res.status(500).json({
          success: false,
          error: uploadResult.error || 'Failed to upload avatar',
        })
      }

      // Update member's profilePicture in database
      const updateResult = await updateMember(memberId, {
        profilePicture: uploadResult.url,
      })

      if (!updateResult.success) {
        return res.status(500).json({
          success: false,
          error: 'Failed to update member profile',
        })
      }

      // Delete old avatar if it exists
      if (oldAvatarUrl) {
        await deleteMemberAvatar(oldAvatarUrl)
      }

      res.json({
        success: true,
        data: {
          url: uploadResult.url,
        },
      })
    } catch (error) {
      console.error('Error uploading avatar:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/members/{memberId}/avatar/sync-google:
 *   post:
 *     tags: [Members]
 *     summary: Sync avatar from linked Google account
 *     description: |
 *       If the member has an email matching a Google-linked user account,
 *       this endpoint will copy the Google profile picture to the member's avatar.
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     responses:
 *       200:
 *         description: Avatar synced successfully
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
 *                     url:
 *                       type: string
 *                       format: uri
 *                       description: Google profile picture URL
 *       404:
 *         description: Member not found or no linked Google account
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post(
  '/:memberId/avatar/sync-google',
  requireMemberOrOrgOwner,
  async (req, res) => {
    try {
      const { memberId } = req.params

      // Get the member
      const memberResult = await getMember(memberId)
      if (!memberResult.success || !memberResult.data) {
        return res.status(404).json({
          success: false,
          error: 'Member not found',
        })
      }

      const member = memberResult.data
      if (!member.email) {
        return res.status(404).json({
          success: false,
          error: 'Member does not have an email address. Add an email to link to a Google account.',
        })
      }

      // Find a Google-linked user with the same email
      const linkedUser = await prisma.user.findUnique({
        where: { email: member.email },
        select: {
          id: true,
          picture: true,
          googleId: true,
        },
      })

      if (!linkedUser) {
        return res.status(404).json({
          success: false,
          error: 'No Google account linked. Sign in with Google using the same email to link accounts.',
        })
      }

      if (!linkedUser.picture) {
        return res.status(404).json({
          success: false,
          error: 'Linked Google account does not have a profile picture.',
        })
      }

      // Update member's profile picture with the Google picture URL
      const updateResult = await updateMember(memberId, {
        profilePicture: linkedUser.picture,
      })

      if (!updateResult.success) {
        return res.status(500).json({
          success: false,
          error: 'Failed to update member profile',
        })
      }

      console.log(`✅ Synced Google avatar for member ${memberId}`)

      res.json({
        success: true,
        data: {
          url: linkedUser.picture,
        },
      })
    } catch (error) {
      console.error('Error syncing Google avatar:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/members/{memberId}/groups:
 *   get:
 *     tags: [Members]
 *     summary: Get member's groups
 *     description: Returns all groups a member belongs to.
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *       - in: query
 *         name: includeInactive
 *         schema:
 *           type: boolean
 *         description: Include inactive memberships
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
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Group'
 *                 count:
 *                   type: integer
 */
router.get('/:memberId/groups', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params
    const { includeInactive } = req.query

    const result = await getMemberGroups(
      memberId,
      includeInactive === 'true'
    )

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
    console.error('Error fetching member groups:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}/link-google:
 *   get:
 *     tags: [Members]
 *     summary: Get Google profile link status
 *     description: |
 *       Returns whether the member has a Google account linked for profile sync.
 *       This does NOT affect authentication - Members always auth via phone.
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     responses:
 *       200:
 *         description: Link status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 linked:
 *                   type: boolean
 *                   description: Whether a Google account is linked
 *                 googleEmail:
 *                   type: string
 *                   nullable: true
 *                   description: Email of linked Google account
 *                 googleLinkedAt:
 *                   type: string
 *                   format: date-time
 *                   nullable: true
 *                   description: When the Google account was linked
 */
router.get('/:memberId/link-google', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params

    const result = await getMember(memberId)

    if (!result.success || !result.data) {
      return res.status(404).json({
        success: false,
        error: 'Member not found',
      })
    }

    const member = result.data as any

    res.json({
      success: true,
      linked: !!member.googleId,
      googleEmail: member.googleEmail || null,
      googleLinkedAt: member.googleLinkedAt || null,
    })
  } catch (error) {
    console.error('Error checking Google link status:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}/link-google:
 *   delete:
 *     tags: [Members]
 *     summary: Unlink Google account from member
 *     description: |
 *       Removes the linked Google account from the member profile.
 *       This clears googleId, googleEmail, googlePicture, and googleLinkedAt.
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     responses:
 *       200:
 *         description: Google account unlinked
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
 *                   example: Google account unlinked successfully
 *       404:
 *         description: Member not found or no Google account linked
 */
router.delete('/:memberId/link-google', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params

    const result = await unlinkGoogleProfile(memberId)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        error: result.error,
      })
    }

    logSuccess(ActivityTypes.AUTH.GOOGLE_PROFILE_UNLINKED, req, { memberId })

    res.json({
      success: true,
      message: 'Google account unlinked successfully',
    })
  } catch (error) {
    console.error('Error unlinking Google account:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/members/{memberId}/sync-google-profile:
 *   post:
 *     tags: [Members]
 *     summary: Sync profile picture from linked Google account
 *     description: |
 *       Updates the member's profilePicture with the picture from their linked Google account.
 *       Requires a Google account to be linked first.
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     responses:
 *       200:
 *         description: Profile synced
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
 *                     profilePicture:
 *                       type: string
 *                       format: uri
 *                       description: Updated profile picture URL
 *       404:
 *         description: Member not found or no Google account linked
 */
router.post('/:memberId/sync-google-profile', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params

    const result = await syncGoogleProfile(memberId)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        error: result.error,
      })
    }

    logSuccess(ActivityTypes.AUTH.GOOGLE_PROFILE_SYNCED, req, { memberId })

    res.json({
      success: true,
      data: {
        profilePicture: result.data?.profilePicture,
      },
    })
  } catch (error) {
    console.error('Error syncing Google profile:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

export default router
