import { Router } from 'express';
import { z } from 'zod';
import { sendGroupInvite, getInviteByToken } from '../services/invite.js';
import { prisma } from '../lib/prisma.js';
import { isValidPhoneNumber } from '../services/twilio.js';
import type { User } from '../generated/prisma/index.js';

const router = Router();

/**
 * Middleware to ensure user is authenticated
 */
const requireAuth = (req: any, res: any, next: any) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({
      success: false,
      error: 'Authentication required',
    });
  }
  next();
};

/**
 * Generate a random alphanumeric token
 */
function generateInviteToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let token = '';
  for (let i = 0; i < 10; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}

/**
 * @openapi
 * /api/invites:
 *   get:
 *     tags: [Invites]
 *     summary: List invites for the current user
 *     description: Returns all invites created by the authenticated user, ordered by creation date (newest first).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: groupId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by group ID
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, accepted, expired]
 *         description: Filter by invite status
 *     responses:
 *       200:
 *         description: Invites retrieved
 *       401:
 *         description: Not authenticated
 */
router.get('/', requireAuth, async (req, res) => {
  try {
    const user = req.user as User;
    const { groupId, status } = req.query;

    const where: any = { inviterId: user.id };
    if (groupId) where.groupId = groupId as string;
    if (status) where.status = status as string;

    const invites = await prisma.invite.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        group: { select: { id: true, name: true } },
      },
    });

    res.json({
      success: true,
      invites: invites.map((inv) => ({
        id: inv.id,
        code: inv.token,
        groupId: inv.groupId,
        groupName: inv.group?.name || null,
        recipientPhone: inv.recipientPhone,
        status: inv.status,
        createdAt: inv.createdAt.toISOString(),
        expiresAt: inv.expiresAt?.toISOString() || null,
      })),
      count: invites.length,
    });
  } catch (error) {
    console.error('[API] Error in GET /invites:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

/**
 * @openapi
 * /api/invites:
 *   post:
 *     tags: [Invites]
 *     summary: Create a new invite
 *     description: |
 *       Creates a new invite token for QR code generation.
 *       The token can optionally be associated with a specific group.
 *       If a groupId is provided, only the group creator can create invites for that group.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               groupId:
 *                 type: string
 *                 format: uuid
 *                 description: UUID of the group to associate with the invite (optional)
 *               expiresAt:
 *                 type: string
 *                 format: date-time
 *                 description: ISO 8601 date-time when the invite expires (optional)
 *           example:
 *             groupId: "123e4567-e89b-12d3-a456-426614174000"
 *             expiresAt: "2024-12-31T23:59:59Z"
 *     responses:
 *       200:
 *         description: Invite created successfully
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
 *                     id:
 *                       type: string
 *                       description: Unique invite ID
 *                     code:
 *                       type: string
 *                       description: 10-character alphanumeric invite token
 *                       example: "ABC123XYZ9"
 *                     groupId:
 *                       type: string
 *                       nullable: true
 *                       description: Associated group ID if provided
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     expiresAt:
 *                       type: string
 *                       format: date-time
 *                       nullable: true
 *                     userId:
 *                       type: string
 *                       description: ID of the user who created the invite
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Invalid uuid"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Authentication required"
 *       403:
 *         description: Not authorized to create invites for this group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Only the group creator can send invites"
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Group not found"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
router.post('/', requireAuth, async (req, res) => {
  try {
    const createInviteSchema = z.object({
      groupId: z.string().uuid().optional(),
      expiresAt: z.string().datetime().optional(),
    });

    const body = createInviteSchema.parse(req.body);
    const user = req.user as User;

    // Generate unique token
    let token = generateInviteToken();

    // Ensure token is unique
    let existing = await prisma.invite.findUnique({ where: { token } });
    while (existing) {
      token = generateInviteToken();
      existing = await prisma.invite.findUnique({ where: { token } });
    }

    // If groupId provided, verify group exists and user is the creator
    if (body.groupId) {
      const group = await prisma.group.findUnique({
        where: { id: body.groupId },
      });

      if (!group) {
        return res.status(404).json({
          success: false,
          error: 'Group not found',
        });
      }

      // Only group creators can send invites
      if (group.creatorId !== user.id) {
        return res.status(403).json({
          success: false,
          error: 'Only the group creator can send invites',
        });
      }
    }

    // Create invite
    const invite = await prisma.invite.create({
      data: {
        token,
        inviterId: user.id,
        groupId: body.groupId,
        expiresAt: body.expiresAt ? new Date(body.expiresAt) : null,
        status: 'pending',
      },
    });

    // Return invite in format expected by iPhone app
    res.json({
      success: true,
      invite: {
        id: invite.id,
        code: invite.token,  // Map "token" to "code" for iPhone app
        groupId: invite.groupId,
        createdAt: invite.createdAt.toISOString(),
        expiresAt: invite.expiresAt?.toISOString() || null,
        userId: invite.inviterId,  // Map "inviterId" to "userId" for iPhone app
      },
    });
  } catch (error: any) {
    console.error('[API] Error in POST /invites:', error);

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
 * /api/invites/send:
 *   post:
 *     tags: [Invites]
 *     summary: Send group invitation via SMS
 *     description: |
 *       Sends a group invitation to a phone number via SMS.
 *       Only the group creator can send invitations.
 *       The recipient will receive an SMS with a link to join the group.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - groupId
 *               - recipientPhone
 *             properties:
 *               groupId:
 *                 type: string
 *                 format: uuid
 *                 description: UUID of the group to invite to
 *               recipientPhone:
 *                 type: string
 *                 pattern: '^\+[1-9]\d{1,14}$'
 *                 description: Phone number in E.164 format (e.g., +1234567890)
 *           example:
 *             groupId: "123e4567-e89b-12d3-a456-426614174000"
 *             recipientPhone: "+12025551234"
 *     responses:
 *       200:
 *         description: Invite sent successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 inviteId:
 *                   type: string
 *                   description: ID of the created invite record
 *                 inviteUrl:
 *                   type: string
 *                   format: uri
 *                   description: URL the recipient can use to join the group
 *                 message:
 *                   type: string
 *                   example: "Invite sent successfully"
 *       400:
 *         description: Validation error or failed to send
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             examples:
 *               invalidPhone:
 *                 summary: Invalid phone number
 *                 value:
 *                   success: false
 *                   error: "Invalid phone number format. Must be E.164 format (e.g., +1234567890)"
 *               sendFailed:
 *                 summary: SMS send failed
 *                 value:
 *                   success: false
 *                   error: "Failed to send invite"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Authentication required"
 *       403:
 *         description: Not authorized to send invites for this group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Only the group creator can send invites"
 *       404:
 *         description: Group not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Group not found"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
router.post('/send', requireAuth, async (req, res) => {
  try {
    const sendInviteSchema = z.object({
      groupId: z.string().uuid(),
      recipientPhone: z.string().refine(isValidPhoneNumber, {
        message: 'Invalid phone number format. Must be E.164 format (e.g., +1234567890)',
      }),
    });

    const { groupId, recipientPhone } = sendInviteSchema.parse(req.body);
    const user = req.user as User;

    // Verify group exists and user is the creator
    const group = await prisma.group.findUnique({
      where: { id: groupId },
    });

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }

    // Only group creators can send invites
    if (group.creatorId !== user.id) {
      return res.status(403).json({
        success: false,
        error: 'Only the group creator can send invites',
      });
    }

    // Get base URL from environment or request
    const baseUrl = process.env.CLIENT_URL || `${req.protocol}://${req.get('host')}`;

    // Send invite
    const result = await sendGroupInvite(
      groupId,
      user.id,
      user.name,
      recipientPhone,
      group.name,
      baseUrl
    );

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to send invite',
      });
    }

    res.json({
      success: true,
      inviteId: result.inviteId,
      inviteUrl: result.inviteUrl,
      message: 'Invite sent successfully',
    });
  } catch (error: any) {
    console.error('[API] Error in /invites/send:', error);

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
 * /api/invites/{token}:
 *   get:
 *     tags: [Invites]
 *     summary: Get invite details by token
 *     description: |
 *       Retrieves the details of an invite by its token.
 *       This is a public endpoint (no authentication required) to allow
 *       recipients to view invite details before signing up or logging in.
 *       Returns group and inviter information if the invite is valid and not expired.
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *         description: The 10-character alphanumeric invite token
 *         example: "ABC123XYZ9"
 *     responses:
 *       200:
 *         description: Invite details retrieved successfully
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
 *                     id:
 *                       type: string
 *                       description: Unique invite ID
 *                     token:
 *                       type: string
 *                       description: The invite token
 *                       example: "ABC123XYZ9"
 *                     recipientPhone:
 *                       type: string
 *                       nullable: true
 *                       description: Phone number the invite was sent to (if SMS invite)
 *                     expiresAt:
 *                       type: string
 *                       format: date-time
 *                       nullable: true
 *                       description: When the invite expires
 *                     group:
 *                       type: object
 *                       nullable: true
 *                       description: Group details if invite is associated with a group
 *                       properties:
 *                         id:
 *                           type: string
 *                         name:
 *                           type: string
 *                         description:
 *                           type: string
 *                           nullable: true
 *                     inviter:
 *                       type: object
 *                       description: Details of the user who created the invite
 *                       properties:
 *                         id:
 *                           type: string
 *                         name:
 *                           type: string
 *                         picture:
 *                           type: string
 *                           nullable: true
 *                           format: uri
 *       400:
 *         description: Invalid or missing token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Invite token is required"
 *       404:
 *         description: Invite not found or expired
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Invite not found or expired"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               success: false
 *               error: "Internal server error"
 */
/**
 * @openapi
 * /api/invites/{id}:
 *   patch:
 *     tags: [Invites]
 *     summary: Update an invite
 *     description: Updates an invite's status or expiration. Only the invite creator can update.
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
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, accepted, expired]
 *               expiresAt:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Invite updated
 *       403:
 *         description: Not authorized
 *       404:
 *         description: Invite not found
 */
router.patch('/:id', requireAuth, async (req, res) => {
  try {
    const user = req.user as User;
    const { id } = req.params;

    const invite = await prisma.invite.findUnique({ where: { id } });

    if (!invite) {
      return res.status(404).json({ success: false, error: 'Invite not found' });
    }

    if (invite.inviterId !== user.id) {
      return res.status(403).json({ success: false, error: 'Not authorized to update this invite' });
    }

    const schema = z.object({
      status: z.enum(['pending', 'accepted', 'expired']).optional(),
      expiresAt: z.string().datetime().nullable().optional(),
    });

    const body = schema.parse(req.body);

    const updated = await prisma.invite.update({
      where: { id },
      data: {
        ...body,
        expiresAt: body.expiresAt !== undefined
          ? (body.expiresAt ? new Date(body.expiresAt) : null)
          : undefined,
      },
    });

    res.json({
      success: true,
      invite: {
        id: updated.id,
        code: updated.token,
        groupId: updated.groupId,
        status: updated.status,
        expiresAt: updated.expiresAt?.toISOString() || null,
      },
    });
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors[0].message });
    }
    console.error('[API] Error in PATCH /invites/:id:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

/**
 * @openapi
 * /api/invites/{id}:
 *   delete:
 *     tags: [Invites]
 *     summary: Delete an invite
 *     description: Permanently deletes an invite. Only the invite creator can delete.
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
 *         description: Invite deleted
 *       403:
 *         description: Not authorized
 *       404:
 *         description: Invite not found
 */
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const user = req.user as User;
    const { id } = req.params;

    const invite = await prisma.invite.findUnique({ where: { id } });

    if (!invite) {
      return res.status(404).json({ success: false, error: 'Invite not found' });
    }

    if (invite.inviterId !== user.id) {
      return res.status(403).json({ success: false, error: 'Not authorized to delete this invite' });
    }

    await prisma.invite.delete({ where: { id } });

    res.json({ success: true });
  } catch (error) {
    console.error('[API] Error in DELETE /invites/:id:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

router.get('/:token', async (req, res) => {
  try {
    const { token } = req.params;

    if (!token) {
      return res.status(400).json({
        success: false,
        error: 'Invite token is required',
      });
    }

    const invite = await getInviteByToken(token);

    if (!invite) {
      return res.status(404).json({
        success: false,
        error: 'Invite not found or expired',
      });
    }

    // Return invite details
    res.json({
      success: true,
      invite: {
        id: invite.id,
        token: invite.token,
        recipientPhone: invite.recipientPhone,
        expiresAt: invite.expiresAt,
        group: invite.group ? {
          id: invite.group.id,
          name: invite.group.name,
          description: invite.group.description,
        } : null,
        inviter: {
          id: invite.inviter.id,
          name: invite.inviter.name,
          picture: invite.inviter.picture,
        },
      },
    });
  } catch (error: any) {
    console.error('[API] Error in /invites/:token:', error);

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

export default router;
