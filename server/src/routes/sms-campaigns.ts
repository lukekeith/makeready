import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { sendCampaignSms } from '../services/sms-campaign.js';
import { isValidPhoneNumber } from '../services/twilio.js';
import type { User } from '../generated/prisma/index.js';

const router = Router();

/**
 * Middleware to ensure user is authenticated
 */
const requireAuth = (req: any, res: any, next: any) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ success: false, error: 'Authentication required' });
  }
  next();
};

/**
 * Middleware to require super admin
 */
const requireSuperAdmin = (req: any, res: any, next: any) => {
  const user = req.user as User;
  if (!user?.isSuperAdmin) {
    return res.status(403).json({ success: false, error: 'Super admin access required' });
  }
  next();
};

/**
 * @openapi
 * /api/sms-campaigns:
 *   get:
 *     tags: [SMS Campaigns]
 *     summary: List all SMS campaigns with templates
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of campaigns
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Not a super admin
 */
router.get('/', requireAuth, requireSuperAdmin, async (_req, res) => {
  try {
    const campaigns = await prisma.smsCampaign.findMany({
      include: {
        templates: {
          orderBy: { version: 'desc' },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    res.json({ success: true, campaigns });
  } catch (error: any) {
    console.error('[API] Error listing SMS campaigns:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

/**
 * @openapi
 * /api/sms-campaigns/{slug}/logs:
 *   get:
 *     tags: [SMS Campaigns]
 *     summary: Get send logs for a campaign
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: slug
 *         in: path
 *         required: true
 *         schema:
 *           type: string
 *       - name: status
 *         in: query
 *         schema:
 *           type: string
 *           enum: [QUEUED, SENT, DELIVERED, UNDELIVERED, FAILED]
 *       - name: phone
 *         in: query
 *         schema:
 *           type: string
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           default: 50
 *       - name: offset
 *         in: query
 *         schema:
 *           type: integer
 *           default: 0
 *     responses:
 *       200:
 *         description: Paginated send logs
 *       404:
 *         description: Campaign not found
 */
router.get('/:slug/logs', requireAuth, requireSuperAdmin, async (req, res) => {
  try {
    const { slug } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
    const offset = parseInt(req.query.offset as string) || 0;
    const status = req.query.status as string | undefined;
    const phone = req.query.phone as string | undefined;

    const campaign = await prisma.smsCampaign.findUnique({
      where: { slug },
      select: { id: true, templates: { select: { id: true } } },
    });

    if (!campaign) {
      return res.status(404).json({ success: false, error: 'Campaign not found' });
    }

    const templateIds = campaign.templates.map(t => t.id);

    const where: any = { templateId: { in: templateIds } };
    if (status) where.status = status;
    if (phone) where.recipientPhone = phone;

    const [logs, total] = await Promise.all([
      prisma.smsLog.findMany({
        where,
        include: {
          template: { select: { slug: true, version: true } },
          sentBy: { select: { id: true, name: true, email: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
      }),
      prisma.smsLog.count({ where }),
    ]);

    res.json({ success: true, logs, total, limit, offset });
  } catch (error: any) {
    console.error('[API] Error fetching SMS campaign logs:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

/**
 * @openapi
 * /api/sms-campaigns/send:
 *   post:
 *     tags: [SMS Campaigns]
 *     summary: Send a campaign SMS (super admin only, for testing)
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - templateSlug
 *               - recipientPhone
 *               - context
 *             properties:
 *               templateSlug:
 *                 type: string
 *               recipientPhone:
 *                 type: string
 *               context:
 *                 type: object
 *     responses:
 *       200:
 *         description: SMS sent or error details
 *       400:
 *         description: Validation error
 *       403:
 *         description: Not a super admin
 */
router.post('/send', requireAuth, requireSuperAdmin, async (req, res) => {
  try {
    const sendSchema = z.object({
      templateSlug: z.string().min(1),
      recipientPhone: z.string().refine(isValidPhoneNumber, {
        message: 'Invalid phone number format. Must be E.164 format (e.g., +1234567890)',
      }),
      context: z.record(z.string()),
      metadata: z.record(z.any()).optional(),
    });

    const { templateSlug, recipientPhone, context, metadata } = sendSchema.parse(req.body);
    const user = req.user as User;

    const result = await sendCampaignSms({
      templateSlug,
      recipientPhone,
      context,
      sentById: user.id,
      metadata,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors[0].message });
    }
    console.error('[API] Error sending campaign SMS:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

export default router;
