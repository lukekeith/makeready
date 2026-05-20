/**
 * Device Tokens Routes
 *
 * Endpoints for registering and removing APNs device tokens for push notifications.
 * Requires session authentication.
 */

import { Router, Request, Response } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'

const router = Router()

/**
 * @openapi
 * components:
 *   schemas:
 *     DeviceToken:
 *       type: object
 *       description: Device token for push notifications
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the device token
 *         userId:
 *           type: string
 *           description: User ID who owns this token
 *         token:
 *           type: string
 *           description: The APNs device token
 *         platform:
 *           type: string
 *           enum: [ios, android]
 *           description: Platform of the device
 *           example: ios
 *         environment:
 *           type: string
 *           enum: [sandbox, production]
 *           description: APNs environment
 *           example: production
 *         createdAt:
 *           type: string
 *           format: date-time
 *         updatedAt:
 *           type: string
 *           format: date-time
 *       required:
 *         - id
 *         - userId
 *         - token
 *         - platform
 *         - environment
 *
 *     RegisterDeviceTokenRequest:
 *       type: object
 *       properties:
 *         token:
 *           type: string
 *           description: The APNs device token (hex string)
 *           example: "a1b2c3d4e5f6..."
 *         platform:
 *           type: string
 *           enum: [ios, android]
 *           default: ios
 *         environment:
 *           type: string
 *           enum: [sandbox, production]
 *           default: production
 *       required:
 *         - token
 */

// Validation schemas
const registerTokenSchema = z.object({
  token: z.string().min(1).max(200),
  platform: z.enum(['ios', 'android']).default('ios'),
  environment: z.enum(['sandbox', 'production']).default('production'),
})

/**
 * @openapi
 * /api/device-tokens:
 *   post:
 *     summary: Register or update a device token
 *     description: Registers a new device token for push notifications, or updates an existing one.
 *     tags:
 *       - Device Tokens
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/RegisterDeviceTokenRequest'
 *     responses:
 *       200:
 *         description: Token registered/updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 deviceToken:
 *                   $ref: '#/components/schemas/DeviceToken'
 *       400:
 *         description: Invalid request body
 *       401:
 *         description: Not authenticated
 */
router.post('/', requireAuth, async (req: Request, res: Response) => {
  try {
    const validation = registerTokenSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validation.error.errors,
      })
    }

    const { token, platform, environment } = validation.data
    const userId = (req.user as any)?.id

    // Upsert the device token (update if exists, create if not)
    const deviceToken = await prisma.deviceToken.upsert({
      where: { token },
      update: {
        userId,
        platform,
        environment,
        updatedAt: new Date(),
      },
      create: {
        userId,
        token,
        platform,
        environment,
      },
    })

    console.log(`📱 Device token registered for user ${userId}: ${token.substring(0, 16)}...`)

    res.json({
      success: true,
      deviceToken,
    })
  } catch (error) {
    console.error('Failed to register device token:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to register device token',
    })
  }
})

/**
 * @openapi
 * /api/device-tokens/{token}:
 *   delete:
 *     summary: Remove a device token
 *     description: Removes a device token when user logs out or disables notifications.
 *     tags:
 *       - Device Tokens
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - name: token
 *         in: path
 *         required: true
 *         description: The device token to remove
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Token removed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Token not found
 */
router.delete('/:token', requireAuth, async (req: Request, res: Response) => {
  try {
    const { token } = req.params
    const userId = (req.user as any)?.id

    // Only delete if the token belongs to the current user
    const result = await prisma.deviceToken.deleteMany({
      where: {
        token,
        userId,
      },
    })

    if (result.count === 0) {
      return res.status(404).json({
        success: false,
        error: 'Device token not found',
      })
    }

    console.log(`📱 Device token removed for user ${userId}: ${token.substring(0, 16)}...`)

    res.json({
      success: true,
    })
  } catch (error) {
    console.error('Failed to remove device token:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to remove device token',
    })
  }
})

/**
 * @openapi
 * /api/device-tokens:
 *   get:
 *     summary: List user's device tokens
 *     description: Lists all device tokens registered for the current user.
 *     tags:
 *       - Device Tokens
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: List of device tokens
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 deviceTokens:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/DeviceToken'
 *       401:
 *         description: Not authenticated
 */
router.get('/', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id

    const deviceTokens = await prisma.deviceToken.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    })

    res.json({
      success: true,
      deviceTokens,
    })
  } catch (error) {
    console.error('Failed to list device tokens:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to list device tokens',
    })
  }
})

export default router
