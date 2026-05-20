import { Router } from 'express';
import { z } from 'zod';
import QRCode from 'qrcode';
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
 * @openapi
 * /api/qrcode/generate:
 *   post:
 *     tags:
 *       - QR Code
 *     summary: Generate a QR code with optional styling
 *     description: |
 *       Generates a QR code image from the provided data with customizable colors, size, and error correction level.
 *       Returns the QR code as a base64-encoded data URL suitable for embedding in HTML or native apps.
 *       Requires authentication.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - data
 *             properties:
 *               data:
 *                 type: string
 *                 minLength: 1
 *                 description: The data to encode in the QR code (URL, text, invite code, etc.)
 *                 example: "https://makeready.app/invite/abc123"
 *               color:
 *                 type: string
 *                 pattern: "^#[0-9A-Fa-f]{6}$"
 *                 default: "#6c47ff"
 *                 description: Hex color for QR code pixels (foreground)
 *                 example: "#6c47ff"
 *               backgroundColor:
 *                 type: string
 *                 pattern: "^#[0-9A-Fa-f]{6}$"
 *                 default: "#ffffff"
 *                 description: Hex color for QR code background
 *                 example: "#ffffff"
 *               size:
 *                 type: integer
 *                 minimum: 100
 *                 maximum: 2000
 *                 default: 300
 *                 description: QR code size in pixels (width and height)
 *                 example: 300
 *               errorCorrectionLevel:
 *                 type: string
 *                 enum: [L, M, Q, H]
 *                 default: H
 *                 description: |
 *                   Error correction level determining how much of the QR code can be damaged while still being readable:
 *                   - L: ~7% recovery
 *                   - M: ~15% recovery
 *                   - Q: ~25% recovery
 *                   - H: ~30% recovery (recommended for most use cases)
 *                 example: "H"
 *     responses:
 *       200:
 *         description: QR code generated successfully
 *         headers:
 *           Cache-Control:
 *             schema:
 *               type: string
 *             description: Set to prevent caching
 *           Pragma:
 *             schema:
 *               type: string
 *             description: Set to prevent caching
 *           Expires:
 *             schema:
 *               type: string
 *             description: Set to prevent caching
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 qrCode:
 *                   type: string
 *                   description: Base64-encoded PNG image as a data URL
 *                   example: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
 *                 data:
 *                   type: string
 *                   description: The data that was encoded in the QR code
 *                   example: "https://makeready.app/invite/abc123"
 *       400:
 *         description: Invalid request body or validation error
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
 *                   example: "Data is required"
 *       401:
 *         description: Authentication required
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
 *                   example: "Authentication required"
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
router.post('/generate', requireAuth, async (req, res) => {
  try {
    const generateSchema = z.object({
      data: z.string().min(1, 'Data is required'),
      color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional().default('#6c47ff'),
      backgroundColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional().default('#ffffff'),
      size: z.number().int().min(100).max(2000).optional().default(300),
      errorCorrectionLevel: z.enum(['L', 'M', 'Q', 'H']).optional().default('H'),
    });

    const {
      data,
      color,
      backgroundColor,
      size,
      errorCorrectionLevel,
    } = generateSchema.parse(req.body);

    const user = req.user as User;
    console.log(`[QR] User ${user.id} generating QR code for data: ${data.substring(0, 50)}${data.length > 50 ? '...' : ''}`);

    // Generate QR code as PNG buffer
    const qrBuffer = await QRCode.toBuffer(data, {
      errorCorrectionLevel,
      type: 'png',
      width: size,
      color: {
        dark: color,
        light: backgroundColor,
      },
      margin: 4,
    });

    // Convert to base64 data URL
    const base64 = qrBuffer.toString('base64');
    const dataUrl = `data:image/png;base64,${base64}`;

    console.log(`✅ [QR] Successfully generated QR code (${base64.length} bytes)`);

    // Prevent caching - QR codes should be generated fresh every time
    res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');

    res.json({
      success: true,
      qrCode: dataUrl,
      data: data,
    });
  } catch (error: any) {
    console.error('[API] Error in /qrcode/generate:', error);

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
 * /api/qrcode/test:
 *   post:
 *     tags:
 *       - QR Code
 *     summary: Test endpoint for QR code generation
 *     description: |
 *       A test endpoint for generating QR codes without authentication.
 *       Returns the QR code directly as a PNG image (not base64 encoded).
 *       Uses default MakeReady styling (purple foreground on white background).
 *       Intended for development and testing purposes.
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               data:
 *                 type: string
 *                 default: "https://makeready.app"
 *                 description: The data to encode in the QR code
 *                 example: "https://makeready.app"
 *               size:
 *                 type: integer
 *                 default: 300
 *                 description: QR code size in pixels (width and height)
 *                 example: 300
 *     responses:
 *       200:
 *         description: QR code generated successfully as PNG image
 *         content:
 *           image/png:
 *             schema:
 *               type: string
 *               format: binary
 *               description: Raw PNG image data
 *       500:
 *         description: Failed to generate QR code
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
router.post('/test', async (req, res) => {
  try {
    const { data = 'https://makeready.app', size = 300 } = req.body;

    // Generate QR code
    const qrBuffer = await QRCode.toBuffer(data, {
      color: {
        dark: '#6c47ff',
        light: '#ffffff',
      },
      width: size,
      errorCorrectionLevel: 'H',
      margin: 4,
    });

    res.setHeader('Content-Type', 'image/png');
    res.send(qrBuffer);
  } catch (error) {
    console.error('[QR TEST] Error:', error);
    res.status(500).json({ success: false, error: 'Failed to generate QR code' });
  }
});

export default router;
