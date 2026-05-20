import { Router } from 'express';
import { z } from 'zod';
import QRCode from 'qrcode';
import sharp from 'sharp';
import * as path from 'path';
import * as fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { prisma } from '../lib/prisma.js';
import { normalizeGroupCode } from '../lib/group-code.js';

// ES module compatibility: define __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const router = Router();

const faqScopeSchema = z.string().trim().min(1).max(80).regex(/^[a-z0-9-]+$/);

router.get('/faqs/:scope', async (req, res) => {
  const parsedScope = faqScopeSchema.safeParse(req.params.scope);
  if (!parsedScope.success) {
    return res.status(400).json({ success: false, error: 'Invalid FAQ scope' });
  }

  try {
    const faqs = await prisma.faqItem.findMany({
      where: {
        scope: parsedScope.data,
        isActive: true,
      },
      orderBy: [
        { sortOrder: 'asc' },
        { createdAt: 'asc' },
      ],
      select: {
        id: true,
        scope: true,
        question: true,
        answer: true,
        sortOrder: true,
      },
    });

    return res.json({
      success: true,
      scope: parsedScope.data,
      faqs,
      count: faqs.length,
    });
  } catch (error) {
    console.error('[Public FAQs] Error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch FAQs' });
  }
});

// ============================================================================
// Public Data Endpoints (for OG meta tag generation)
// ============================================================================

/**
 * @openapi
 * /public/groups/{code}:
 *   get:
 *     tags: [Public]
 *     summary: Get public group info by code
 *     description: |
 *       Retrieves public information about a group using its unique code.
 *       This endpoint is designed for social media preview generation (OG meta tags)
 *       and does not require authentication.
 *     parameters:
 *       - in: path
 *         name: code
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique group code (case-insensitive, will be normalized)
 *         example: "ABC123"
 *     responses:
 *       200:
 *         description: Group found successfully
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
 *                       description: Unique group identifier
 *                       example: "clx1234567890"
 *                     code:
 *                       type: string
 *                       description: Normalized group code
 *                       example: "ABC123"
 *                     name:
 *                       type: string
 *                       description: Group display name
 *                       example: "Bible Study Group"
 *                     description:
 *                       type: string
 *                       nullable: true
 *                       description: Group description
 *                       example: "Weekly Bible study for young adults"
 *                     coverImageUrl:
 *                       type: string
 *                       nullable: true
 *                       description: URL to the group's cover image
 *                       example: "https://storage.example.com/groups/cover.jpg"
 *                     memberCount:
 *                       type: integer
 *                       description: Number of active members in the group
 *                       example: 25
 *       404:
 *         description: Group not found
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
 *         description: Server error
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
 *                   example: "Failed to fetch group"
 */
router.get('/groups/:code', async (req, res) => {
  try {
    const { code } = req.params;
    const normalizedCode = normalizeGroupCode(code);

    const group = await prisma.group.findUnique({
      where: { code: normalizedCode },
      select: {
        id: true,
        code: true,
        name: true,
        description: true,
        coverImageUrl: true,
        _count: {
          select: { members: { where: { isActive: true } } },
        },
      },
    });

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }

    res.json({
      success: true,
      group: {
        id: group.id,
        code: group.code,
        name: group.name,
        description: group.description,
        coverImageUrl: group.coverImageUrl,
        memberCount: group._count.members,
      },
    });
  } catch (error) {
    console.error('[Public Groups] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch group' });
  }
});

/**
 * @openapi
 * /public/programs/{id}:
 *   get:
 *     tags: [Public]
 *     summary: Get public study program info
 *     description: |
 *       Retrieves public information about a study program using its unique ID.
 *       This endpoint is designed for social media preview generation (OG meta tags)
 *       and does not require authentication.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique study program identifier
 *         example: "clx1234567890"
 *     responses:
 *       200:
 *         description: Program found successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 program:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       description: Unique program identifier
 *                       example: "clx1234567890"
 *                     name:
 *                       type: string
 *                       description: Program display name
 *                       example: "30 Days of Prayer"
 *                     description:
 *                       type: string
 *                       nullable: true
 *                       description: Program description
 *                       example: "A 30-day journey through prayer and reflection"
 *                     coverImageUrl:
 *                       type: string
 *                       nullable: true
 *                       description: URL to the program's cover image
 *                       example: "https://storage.example.com/programs/cover.jpg"
 *                     days:
 *                       type: integer
 *                       description: Total number of days in the study program
 *                       example: 30
 *       404:
 *         description: Program not found
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
 *                   example: "Program not found"
 *       500:
 *         description: Server error
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
 *                   example: "Failed to fetch program"
 */
router.get('/programs/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const program = await prisma.studyProgram.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        description: true,
        coverImageUrl: true,
        days: true,
      },
    });

    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' });
    }

    res.json({
      success: true,
      program,
    });
  } catch (error) {
    console.error('[Public Programs] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch program' });
  }
});

/**
 * @openapi
 * /public/groups/{code}/events/{eventCode}:
 *   get:
 *     tags: [Public]
 *     summary: Get public event info
 *     description: |
 *       Retrieves public information about an event within a group using the group code and event code.
 *       This endpoint is designed for social media preview generation (OG meta tags)
 *       and does not require authentication.
 *     parameters:
 *       - in: path
 *         name: code
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique group code (case-insensitive, will be normalized)
 *         example: "ABC123"
 *       - in: path
 *         name: eventCode
 *         required: true
 *         schema:
 *           type: string
 *         description: The unique event code within the group (case-insensitive, will be uppercased)
 *         example: "EVT001"
 *     responses:
 *       200:
 *         description: Event found successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 event:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       description: Unique event identifier
 *                       example: "clx1234567890"
 *                     code:
 *                       type: string
 *                       description: Event code (uppercase)
 *                       example: "EVT001"
 *                     title:
 *                       type: string
 *                       description: Event title
 *                       example: "Sunday Service"
 *                     description:
 *                       type: string
 *                       nullable: true
 *                       description: Event description
 *                       example: "Join us for our weekly worship service"
 *                     coverImageUrl:
 *                       type: string
 *                       nullable: true
 *                       description: URL to the event's cover image
 *                       example: "https://storage.example.com/events/cover.jpg"
 *                     date:
 *                       type: string
 *                       format: date-time
 *                       description: Event date
 *                       example: "2024-01-15T00:00:00.000Z"
 *                     startTime:
 *                       type: string
 *                       nullable: true
 *                       description: Event start time
 *                       example: "09:00"
 *                     endTime:
 *                       type: string
 *                       nullable: true
 *                       description: Event end time
 *                       example: "11:00"
 *                     type:
 *                       type: string
 *                       description: Event type
 *                       example: "WORSHIP"
 *       404:
 *         description: Group or event not found
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
 *                   example: "Event not found"
 *       500:
 *         description: Server error
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
 *                   example: "Failed to fetch event"
 */
router.get('/groups/:code/events/:eventCode', async (req, res) => {
  try {
    const { code, eventCode } = req.params;
    const normalizedCode = normalizeGroupCode(code);

    // First find the group
    const group = await prisma.group.findUnique({
      where: { code: normalizedCode },
      select: { id: true },
    });

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }

    // Then find the event
    const event = await prisma.event.findFirst({
      where: {
        groupId: group.id,
        code: eventCode.toUpperCase(),
      },
      select: {
        id: true,
        code: true,
        title: true,
        description: true,
        coverImageUrl: true,
        date: true,
        startTime: true,
        endTime: true,
        type: true,
      },
    });

    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }

    res.json({
      success: true,
      event,
    });
  } catch (error) {
    console.error('[Public Events] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch event' });
  }
});

// ============================================================================
// QR Code Generation
// ============================================================================

/**
 * @openapi
 * /public/qrcode:
 *   get:
 *     tags: [Public]
 *     summary: Generate a QR code for any URL
 *     description: |
 *       Generates a customizable QR code image for the specified URL.
 *       This is a public endpoint that does not require authentication.
 *
 *       The QR code can be customized with:
 *       - Custom size (100-2000 pixels)
 *       - Optional MakeReady logo embedded in the center
 *       - Custom foreground and background colors
 *
 *       The response is cached for 1 hour for performance.
 *     parameters:
 *       - in: query
 *         name: url
 *         required: true
 *         schema:
 *           type: string
 *           format: uri
 *         description: The full URL to encode in the QR code
 *         example: "https://makeready.app/join/ABC123"
 *       - in: query
 *         name: size
 *         required: false
 *         schema:
 *           type: integer
 *           minimum: 100
 *           maximum: 2000
 *           default: 300
 *         description: QR code size in pixels (default 300, range 100-2000)
 *         example: 400
 *       - in: query
 *         name: includeLogo
 *         required: false
 *         schema:
 *           type: boolean
 *           default: true
 *         description: Whether to embed the MakeReady logo in the center (default true)
 *         example: true
 *       - in: query
 *         name: color
 *         required: false
 *         schema:
 *           type: string
 *           pattern: "^#[0-9A-Fa-f]{6}$"
 *           default: "#6c47ff"
 *         description: Hex color for QR code pixels (default #6c47ff - MakeReady purple)
 *         example: "#6c47ff"
 *       - in: query
 *         name: bg
 *         required: false
 *         schema:
 *           type: string
 *           pattern: "^#[0-9A-Fa-f]{6}$"
 *           default: "#ffffff"
 *         description: Hex color for background (default #ffffff - white)
 *         example: "#ffffff"
 *     responses:
 *       200:
 *         description: QR code generated successfully
 *         headers:
 *           Content-Type:
 *             schema:
 *               type: string
 *               example: "image/png"
 *           Cache-Control:
 *             schema:
 *               type: string
 *               example: "public, max-age=3600"
 *         content:
 *           image/png:
 *             schema:
 *               type: string
 *               format: binary
 *               description: PNG image of the generated QR code
 *       400:
 *         description: Invalid request parameters
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
 *                   example: "url parameter must be a valid URL"
 *       500:
 *         description: Server error during QR code generation
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
 *                   example: "Failed to generate QR code"
 */
router.get('/qrcode', async (req, res) => {
  try {
    // Define validation schema
    const querySchema = z.object({
      url: z.string().url({ message: 'url parameter must be a valid URL' }),
      size: z.coerce.number().int().min(100).max(2000).optional().default(300),
      includeLogo: z.coerce.boolean().optional().default(true),
      color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional().default('#6c47ff'),
      bg: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional().default('#ffffff'),
    });

    const { url, size, includeLogo, color, bg } = querySchema.parse(req.query);

    console.log(`[PUBLIC QR] Generating QR code for URL: ${url} (size: ${size}px, logo: ${includeLogo})`);

    // Generate QR code as PNG buffer
    const qrBuffer = await QRCode.toBuffer(url, {
      errorCorrectionLevel: 'H',
      type: 'png',
      width: size,
      color: {
        dark: color,
        light: bg,
      },
      margin: 4,
    });

    let finalBuffer = qrBuffer;

    // Add logo if requested
    if (includeLogo) {
      try {
        const logoPath = path.join(__dirname, '../../../assets/makeready-logo-qr.png');
        const logoExists = await fs.access(logoPath).then(() => true).catch(() => false);

        if (logoExists) {
          const logoSize = Math.floor(size * 0.2);

          const logoBuffer = await sharp(logoPath)
            .resize(logoSize, logoSize, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 1 } })
            .png()
            .toBuffer();

          const logoPadding = Math.floor(logoSize * 0.15);
          const logoWithBackground = await sharp(logoBuffer)
            .extend({
              top: logoPadding,
              bottom: logoPadding,
              left: logoPadding,
              right: logoPadding,
              background: { r: 255, g: 255, b: 255, alpha: 1 },
            })
            .png()
            .toBuffer();

          const logoMetadata = await sharp(logoWithBackground).metadata();
          const logoFinalSize = logoMetadata.width!;

          finalBuffer = await sharp(qrBuffer)
            .composite([{
              input: logoWithBackground,
              top: Math.floor((size - logoFinalSize) / 2),
              left: Math.floor((size - logoFinalSize) / 2),
            }])
            .png()
            .toBuffer();

          console.log(`[PUBLIC QR] Successfully embedded logo`);
        } else {
          console.log(`[PUBLIC QR] Logo file not found, generating without logo`);
        }
      } catch (logoError) {
        console.error('[PUBLIC QR] Error embedding logo:', logoError);
        // Continue with QR code without logo
      }
    }

    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour
    res.send(finalBuffer);
  } catch (error: any) {
    console.error('[PUBLIC QR] Error:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to generate QR code',
    });
  }
});

export default router;
