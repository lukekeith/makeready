import { Router } from 'express';
import { z } from 'zod';
import rateLimit from 'express-rate-limit';
import { sendVerificationCode, verifyCode } from '../services/twilio.js';
import { prisma } from '../lib/prisma.js';
import { acceptInvite } from '../services/invite.js';
import type { User } from '../generated/prisma/index.js';
import { logSuccess, logFailure } from '../lib/activity-log.js';
import { ActivityTypes } from '../lib/activity-types.js';

const router = Router();

/**
 * Rate limiter for sending verification codes
 * Limits to 3 requests per 15 minutes per IP address
 * This prevents SMS spam and abuse of the Twilio service
 */
const sendCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3, // Limit each IP to 3 requests per windowMs
  message: {
    success: false,
    error: 'Too many verification requests. Please try again in 15 minutes.',
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  // Skip rate limiting for test environment
  skip: () => process.env.NODE_ENV === 'test',
});

/**
 * Rate limiter for verifying codes
 * Limits to 5 requests per 15 minutes per IP address
 * This prevents brute force attacks on verification codes
 */
const verifyCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs
  message: {
    success: false,
    error: 'Too many verification attempts. Please try again in 15 minutes.',
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  // Skip rate limiting for test environment
  skip: () => process.env.NODE_ENV === 'test',
});

/**
 * Phone number validation schema (E.164 format)
 */
const phoneNumberSchema = z.string().regex(/^\+[1-9]\d{1,14}$/, {
  message: 'Phone number must be in E.164 format (e.g., +1234567890)',
});

/**
 * @openapi
 * /api/verification/send:
 *   post:
 *     tags:
 *       - Verification
 *     summary: Send verification code to phone number
 *     description: |
 *       Sends a 6-digit verification code to the specified phone number via SMS using Twilio.
 *       If an organizationId is provided, the organization's custom Twilio Verify service will be used
 *       for branded messaging. Otherwise, the default MakeReady Verify service is used.
 *
 *       **Rate Limited:** 3 requests per 15 minutes per IP address to prevent SMS spam.
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
 *               organizationId:
 *                 type: string
 *                 format: uuid
 *                 description: Optional organization ID for org-branded SMS messaging
 *                 example: '123e4567-e89b-12d3-a456-426614174000'
 *           examples:
 *             basic:
 *               summary: Basic verification request
 *               value:
 *                 phoneNumber: '+15551234567'
 *             withOrg:
 *               summary: Organization-branded verification
 *               value:
 *                 phoneNumber: '+15551234567'
 *                 organizationId: '123e4567-e89b-12d3-a456-426614174000'
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
 *                   example: 'Verification code sent successfully'
 *                 status:
 *                   type: string
 *                   description: Twilio verification status
 *                   example: 'pending'
 *       400:
 *         description: Invalid request or failed to send code
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
 *                   example: 'Phone number must be in E.164 format (e.g., +1234567890)'
 *       429:
 *         description: Rate limit exceeded
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
 *                   example: 'Too many verification requests. Please try again in 15 minutes.'
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
 *                   example: 'Internal server error'
 */
router.post('/send', sendCodeLimiter, async (req, res) => {
  try {
    const sendSchema = z.object({
      phoneNumber: phoneNumberSchema,
      organizationId: z.string().uuid().optional(),
    });

    const { phoneNumber, organizationId } = sendSchema.parse(req.body);

    // Look up organization's Twilio Verify service SID if organizationId provided
    let verifyServiceSid: string | null = null;
    if (organizationId) {
      const org = await prisma.organization.findUnique({
        where: { id: organizationId },
        select: { twilioVerifyServiceSid: true },
      });
      verifyServiceSid = org?.twilioVerifyServiceSid ?? null;
    }

    // Send verification code via Twilio (uses org's service or default)
    const result = await sendVerificationCode(phoneNumber, verifyServiceSid);

    if (!result.success) {
      logFailure(ActivityTypes.AUTH.PHONE_VERIFICATION_SEND_FAILED, req, {
        phoneNumber,
        organizationId,
        errorMessage: result.error || 'Failed to send verification code',
      });
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to send verification code',
      });
    }

    // Log successful send
    logSuccess(ActivityTypes.AUTH.PHONE_VERIFICATION_SENT, req, {
      phoneNumber,
      organizationId,
    });

    res.json({
      success: true,
      message: 'Verification code sent successfully',
      status: result.status,
    });
  } catch (error: any) {
    console.error('[API] Error in /verification/send:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * @openapi
 * /api/verification/verify:
 *   post:
 *     tags:
 *       - Verification
 *     summary: Verify code and update user's phone number
 *     description: |
 *       Verifies the SMS code sent to a phone number. Upon successful verification:
 *
 *       1. **Authenticated users:** Updates their phone number and marks it as verified
 *       2. **With invite token:** Accepts the group invite and joins the user to the group
 *       3. **New users with invite:** Creates a new user account with the verified phone number
 *
 *       The organization context for verification can be:
 *       - Explicitly provided via `organizationId`
 *       - Derived from the invite token's associated group
 *
 *       **Rate Limited:** 5 requests per 15 minutes per IP address to prevent brute force attacks.
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
 *               inviteToken:
 *                 type: string
 *                 description: Optional invite token from invite URL to join a group
 *                 example: 'abc123def456'
 *               organizationId:
 *                 type: string
 *                 format: uuid
 *                 description: Optional organization ID (derived from invite if not provided)
 *                 example: '123e4567-e89b-12d3-a456-426614174000'
 *           examples:
 *             basic:
 *               summary: Basic code verification
 *               value:
 *                 phoneNumber: '+15551234567'
 *                 code: '123456'
 *             withInvite:
 *               summary: Verify and accept group invite
 *               value:
 *                 phoneNumber: '+15551234567'
 *                 code: '123456'
 *                 inviteToken: 'abc123def456'
 *     responses:
 *       200:
 *         description: Phone number verified successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 valid:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: 'Phone number verified successfully'
 *                 userId:
 *                   type: string
 *                   description: User ID (returned when invite is accepted)
 *                   example: 'clx1234567890abcdef'
 *                 groupId:
 *                   type: string
 *                   description: Group ID (returned when invite is accepted)
 *                   example: 'clx0987654321fedcba'
 *             examples:
 *               basicSuccess:
 *                 summary: Basic verification success
 *                 value:
 *                   success: true
 *                   valid: true
 *                   message: 'Phone number verified successfully'
 *               inviteAccepted:
 *                 summary: Verification with invite accepted
 *                 value:
 *                   success: true
 *                   valid: true
 *                   message: 'Phone number verified successfully'
 *                   userId: 'clx1234567890abcdef'
 *                   groupId: 'clx0987654321fedcba'
 *       400:
 *         description: Invalid request, code verification failed, or invite acceptance failed
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 valid:
 *                   type: boolean
 *                   description: Whether the code was valid (only present for invalid code errors)
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: 'Invalid verification code'
 *                 message:
 *                   type: string
 *                   description: Alternative to error field for some responses
 *                   example: 'Invalid verification code'
 *             examples:
 *               invalidFormat:
 *                 summary: Invalid phone number format
 *                 value:
 *                   success: false
 *                   error: 'Phone number must be in E.164 format (e.g., +1234567890)'
 *               invalidCode:
 *                 summary: Wrong verification code
 *                 value:
 *                   success: false
 *                   valid: false
 *                   message: 'Invalid verification code'
 *               inviteFailed:
 *                 summary: Invite acceptance failed
 *                 value:
 *                   success: false
 *                   error: 'Failed to accept invite'
 *       404:
 *         description: Invite not found or expired
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
 *                   example: 'Invite not found or expired'
 *       429:
 *         description: Rate limit exceeded
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
 *                   example: 'Too many verification attempts. Please try again in 15 minutes.'
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
 *                   example: 'Internal server error'
 */
router.post('/verify', verifyCodeLimiter, async (req, res) => {
  try {
    const verifySchema = z.object({
      phoneNumber: phoneNumberSchema,
      code: z.string().min(4).max(6),
      inviteToken: z.string().optional(),
      organizationId: z.string().uuid().optional(),
      smsConsent: z.boolean().optional(),
    });

    const { phoneNumber, code, inviteToken, organizationId, smsConsent } = verifySchema.parse(req.body);

    // Determine the organization context for verification
    let verifyServiceSid: string | null = null;
    let effectiveOrgId = organizationId;

    // If invite token provided, get org from the group
    if (inviteToken && !effectiveOrgId) {
      const invite = await prisma.invite.findUnique({
        where: { token: inviteToken },
        include: {
          group: {
            select: { organizationId: true },
          },
        },
      });
      effectiveOrgId = invite?.group?.organizationId ?? undefined;
    }

    // Look up organization's Twilio Verify service SID
    if (effectiveOrgId) {
      const org = await prisma.organization.findUnique({
        where: { id: effectiveOrgId },
        select: { twilioVerifyServiceSid: true },
      });
      verifyServiceSid = org?.twilioVerifyServiceSid ?? null;
    }

    // Verify code via Twilio (uses org's service or default)
    const result = await verifyCode(phoneNumber, code, verifyServiceSid);

    if (!result.success) {
      logFailure(ActivityTypes.AUTH.PHONE_VERIFICATION_FAILED, req, {
        phoneNumber,
        organizationId: effectiveOrgId,
        errorMessage: result.error || 'Failed to verify code',
      });
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to verify code',
      });
    }

    if (!result.valid) {
      logFailure(ActivityTypes.AUTH.PHONE_VERIFICATION_INVALID_CODE, req, {
        phoneNumber,
        organizationId: effectiveOrgId,
        errorMessage: 'Invalid verification code',
      });
      return res.status(400).json({
        success: false,
        valid: false,
        message: 'Invalid verification code',
      });
    }

    let userId: string | undefined;
    let groupId: string | undefined;

    // If user is authenticated, update their phone number
    if (req.isAuthenticated() && req.user) {
      const user = req.user as User;
      await prisma.user.update({
        where: { id: user.id },
        data: {
          phoneNumber,
          phoneVerified: true,
          ...(smsConsent !== undefined && {
            smsConsent,
            smsConsentAt: smsConsent ? new Date() : null,
          }),
        },
      });

      userId = user.id;
      console.log(`[API] User ${user.id} verified phone: ${phoneNumber}`);
    }

    // If invite token provided, handle invite acceptance
    if (inviteToken) {
      // Get invite details
      const invite = await prisma.invite.findUnique({
        where: { token: inviteToken },
      });

      if (!invite) {
        return res.status(404).json({
          success: false,
          error: 'Invite not found or expired',
        });
      }

      // Check if user exists with this phone number
      let user = await prisma.user.findUnique({
        where: { phoneNumber },
      });

      // If no user exists, create a basic user account
      if (!user) {
        user = await prisma.user.create({
          data: {
            phoneNumber,
            phoneVerified: true,
            smsConsent: smsConsent ?? false,
            smsConsentAt: smsConsent ? new Date() : null,
            // Generate placeholder values (user can update later)
            googleId: `phone_${phoneNumber}`,
            email: `${phoneNumber.replace(/\D/g, '')}@phone.makeready.app`,
            name: phoneNumber, // Temporary name
          },
        });

        console.log(`[API] Created new user account for phone: ${phoneNumber}`);
      } else if (!user.phoneVerified) {
        // Update existing user to mark phone as verified
        await prisma.user.update({
          where: { id: user.id },
          data: {
            phoneVerified: true,
            ...(smsConsent !== undefined && {
              smsConsent,
              smsConsentAt: smsConsent ? new Date() : null,
            }),
          },
        });
      }

      userId = user.id;

      // Accept the invite
      const acceptResult = await acceptInvite(invite.id, user.id);

      if (!acceptResult.success) {
        return res.status(400).json({
          success: false,
          error: acceptResult.error || 'Failed to accept invite',
        });
      }

      groupId = acceptResult.groupId;

      console.log(`[API] User ${user.id} accepted invite and joined group ${groupId}`);
    }

    // Log successful verification
    logSuccess(ActivityTypes.AUTH.PHONE_VERIFICATION_SUCCESS, req, {
      phoneNumber,
      userId,
      groupId,
      organizationId: effectiveOrgId,
    });

    res.json({
      success: true,
      valid: true,
      message: 'Phone number verified successfully',
      userId,
      groupId,
    });
  } catch (error: any) {
    console.error('[API] Error in /verification/verify:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * @openapi
 * /api/verification/resend:
 *   post:
 *     tags:
 *       - Verification
 *     summary: Resend verification code to phone number
 *     description: |
 *       Resends a verification code to the specified phone number. This is functionally
 *       identical to the `/send` endpoint but provides better API semantics for resend flows.
 *
 *       If an organizationId is provided, the organization's custom Twilio Verify service
 *       will be used for branded messaging.
 *
 *       **Rate Limited:** 3 requests per 15 minutes per IP address (shares limit with /send).
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
 *               organizationId:
 *                 type: string
 *                 format: uuid
 *                 description: Optional organization ID for org-branded SMS messaging
 *                 example: '123e4567-e89b-12d3-a456-426614174000'
 *           examples:
 *             basic:
 *               summary: Basic resend request
 *               value:
 *                 phoneNumber: '+15551234567'
 *             withOrg:
 *               summary: Organization-branded resend
 *               value:
 *                 phoneNumber: '+15551234567'
 *                 organizationId: '123e4567-e89b-12d3-a456-426614174000'
 *     responses:
 *       200:
 *         description: Verification code resent successfully
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
 *                   example: 'Verification code resent successfully'
 *                 status:
 *                   type: string
 *                   description: Twilio verification status
 *                   example: 'pending'
 *       400:
 *         description: Invalid request or failed to resend code
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
 *                   example: 'Phone number must be in E.164 format (e.g., +1234567890)'
 *       429:
 *         description: Rate limit exceeded
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
 *                   example: 'Too many verification requests. Please try again in 15 minutes.'
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
 *                   example: 'Internal server error'
 */
router.post('/resend', sendCodeLimiter, async (req, res) => {
  try {
    const sendSchema = z.object({
      phoneNumber: phoneNumberSchema,
      organizationId: z.string().uuid().optional(),
    });

    const { phoneNumber, organizationId } = sendSchema.parse(req.body);

    // Look up organization's Twilio Verify service SID if organizationId provided
    let verifyServiceSid: string | null = null;
    if (organizationId) {
      const org = await prisma.organization.findUnique({
        where: { id: organizationId },
        select: { twilioVerifyServiceSid: true },
      });
      verifyServiceSid = org?.twilioVerifyServiceSid ?? null;
    }

    // Send verification code via Twilio (uses org's service or default)
    const result = await sendVerificationCode(phoneNumber, verifyServiceSid);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to resend verification code',
      });
    }

    res.json({
      success: true,
      message: 'Verification code resent successfully',
      status: result.status,
    });
  } catch (error: any) {
    console.error('[API] Error in /verification/resend:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

export default router;
