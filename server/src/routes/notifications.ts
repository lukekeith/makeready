/**
 * Notification Routes (Backward Compatible)
 *
 * These endpoints now query the unified Activity table (filtering by targetUserId)
 * instead of the deprecated Notification table. Response shapes are preserved
 * so existing iPhone app versions continue to work.
 */

import { Router, Request, Response } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { trackActivity } from '../services/activity.js'

const router = Router()

/**
 * @openapi
 * /api/notifications:
 *   get:
 *     tags: [Notifications]
 *     summary: List notifications for current user (backward compatible)
 *     description: >
 *       Queries the unified Activity table for activities targeted at the current user.
 *       Returns a response shape compatible with the legacy notification endpoint.
 *       Prefer GET /api/activities?targetUserId=me for new clients.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *           maximum: 100
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *     responses:
 *       200:
 *         description: Notifications retrieved
 */
router.get('/', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100)
    const offset = parseInt(req.query.offset as string) || 0

    const [activities, storedNotifications] = await Promise.all([
      prisma.activity.findMany({
        where: { targetUserId: userId },
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
        include: {
          actor: {
            select: { id: true, name: true, picture: true },
          },
        },
      }),
      // Notification-table rows (study-sync updates etc.) merge into the feed
      prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
      }),
    ])

    // Map to notification-compatible shape
    const notifications = activities.map((a) => ({
      id: a.id,
      userId: a.targetUserId,
      type: a.resourceType,
      title: a.title ?? a.resourceName,
      body: a.body ?? a.resourceName,
      isRead: a.isRead,
      data: {
        activityId: a.id,
        resourceType: a.resourceType,
        resourceId: a.resourceId,
        action: a.action,
        groupId: a.groupId,
        ...(a.metadata as Record<string, unknown> ?? {}),
      },
      createdAt: a.createdAt,
      // Include activity-specific fields for new clients
      actor: a.actor,
      action: a.action,
      resourceType: a.resourceType,
      resourceId: a.resourceId,
      resourceName: a.resourceName,
      groupId: a.groupId,
    }))

    // Merge, newest first (Notification rows carry dedupeKey + actions the
    // clients use to render inline views, e.g. enrollment sync settings)
    const merged = [
      ...notifications,
      ...storedNotifications.map((n) => ({
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        isRead: n.isRead,
        data: n.data,
        actions: n.actions,
        dedupeKey: n.dedupeKey,
        createdAt: n.createdAt,
        actor: null,
      })),
    ].sort((x: any, y: any) => new Date(y.createdAt).getTime() - new Date(x.createdAt).getTime())
      .slice(0, limit)

    res.json({
      success: true,
      notifications: merged,
    })
  } catch (error) {
    console.error('Failed to list notifications:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to list notifications',
    })
  }
})

/**
 * @openapi
 * /api/notifications/unread-count:
 *   get:
 *     tags: [Notifications]
 *     summary: Get unread notification count
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Unread count
 */
router.get('/unread-count', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id

    const [activityCount, notificationCount] = await Promise.all([
      prisma.activity.count({ where: { targetUserId: userId, isRead: false } }),
      prisma.notification.count({ where: { userId, isRead: false } }),
    ])
    const count = activityCount + notificationCount

    res.json({
      success: true,
      count,
    })
  } catch (error) {
    console.error('Failed to get unread count:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to get unread count',
    })
  }
})

/**
 * @openapi
 * /api/notifications/summary:
 *   get:
 *     tags: [Notifications]
 *     summary: Unread notification summary for the dashboard banner
 *     description: Unread count plus the newest unread notification's timestamp.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Summary
 */
router.get('/summary', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id

    const [activityCount, notificationCount, latestActivity, latestNotification] =
      await Promise.all([
        prisma.activity.count({ where: { targetUserId: userId, isRead: false } }),
        prisma.notification.count({ where: { userId, isRead: false } }),
        prisma.activity.findFirst({
          where: { targetUserId: userId, isRead: false },
          orderBy: { createdAt: 'desc' },
          select: { createdAt: true },
        }),
        prisma.notification.findFirst({
          where: { userId, isRead: false },
          orderBy: { createdAt: 'desc' },
          select: { createdAt: true },
        }),
      ])

    const timestamps = [latestActivity?.createdAt, latestNotification?.createdAt]
      .filter((t): t is Date => t != null)
      .sort((a, b) => b.getTime() - a.getTime())

    res.json({
      success: true,
      summary: {
        unreadCount: activityCount + notificationCount,
        latestAt: timestamps[0]?.toISOString() ?? null,
      },
    })
  } catch (error) {
    console.error('Failed to get notification summary:', error)
    res.status(500).json({ success: false, error: 'Failed to get notification summary' })
  }
})

const markReadSchema = z.object({
  ids: z.array(z.string()).optional(),
  all: z.boolean().optional(),
})

/**
 * @openapi
 * /api/notifications/mark-read:
 *   post:
 *     tags: [Notifications]
 *     summary: Mark notifications as read
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               ids:
 *                 type: array
 *                 items:
 *                   type: string
 *               all:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Notifications marked as read
 */
router.post('/mark-read', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id
    const validation = markReadSchema.safeParse(req.body)

    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validation.error.errors,
      })
    }

    const { ids, all } = validation.data

    // Action-required notifications (data.requiresAction, e.g. study-sync
    // "updates available") can NOT be cleared by viewing/mark-read — they
    // resolve only when the underlying decision happens (sync applied or
    // sync mode changed), via resolveNotificationsByDedupeKey. Filtered in
    // app code: a Prisma JSON `NOT { path: equals }` silently drops rows
    // MISSING the key (SQL NULL semantics), which would exempt every normal
    // notification from mark-read.
    const dismissableIds = async (scope: { ids?: string[] }) => {
      const rows = await prisma.notification.findMany({
        where: {
          userId,
          isRead: false,
          ...(scope.ids ? { id: { in: scope.ids } } : {}),
        },
        select: { id: true, data: true },
      })
      return rows
        .filter((n) => (n.data as { requiresAction?: boolean } | null)?.requiresAction !== true)
        .map((n) => n.id)
    }

    if (all) {
      const notificationIds = await dismissableIds({})
      await Promise.all([
        prisma.activity.updateMany({
          where: { targetUserId: userId, isRead: false },
          data: { isRead: true },
        }),
        prisma.notification.updateMany({
          where: { id: { in: notificationIds } },
          data: { isRead: true },
        }),
      ])
    } else if (ids && ids.length > 0) {
      const notificationIds = await dismissableIds({ ids })
      await Promise.all([
        prisma.activity.updateMany({
          where: { id: { in: ids }, targetUserId: userId },
          data: { isRead: true },
        }),
        prisma.notification.updateMany({
          where: { id: { in: notificationIds } },
          data: { isRead: true },
        }),
      ])
    } else {
      return res.status(400).json({
        success: false,
        error: 'Provide either "ids" array or "all": true',
      })
    }

    res.json({ success: true })
  } catch (error) {
    console.error('Failed to mark notifications as read:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to mark notifications as read',
    })
  }
})

const testNotificationSchema = z.object({
  userId: z.string(),
  title: z.string().optional(),
  body: z.string().optional(),
  data: z.record(z.string()).optional(),
})

/**
 * @openapi
 * /api/notifications/test:
 *   post:
 *     tags: [Notifications]
 *     summary: Send a test notification (API key only)
 *     security:
 *       - apiKey: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - userId
 *             properties:
 *               userId:
 *                 type: string
 *               title:
 *                 type: string
 *               body:
 *                 type: string
 *               data:
 *                 type: object
 *     responses:
 *       200:
 *         description: Test notification sent
 */
router.post('/test', requireAuth, async (req: Request, res: Response) => {
  try {
    const isApiKey = !!(req as any).apiKeyId
    if (!isApiKey) {
      return res.status(403).json({
        success: false,
        error: 'This endpoint requires API key authentication',
      })
    }

    const validation = testNotificationSchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validation.error.errors,
      })
    }

    const {
      userId,
      title = 'Test Notification',
      body = 'This is a test notification from MakeReady.',
      data,
    } = validation.data

    // Use unified activity system for test notifications
    trackActivity({
      actorId: userId,
      action: 'NOTIFIED',
      resourceType: 'NOTIFICATION',
      resourceId: userId,
      resourceName: title,
      targetUserId: userId,
      title,
      body,
      metadata: data,
    })

    res.json({
      success: true,
      message: 'Test notification sent via unified activity system',
    })
  } catch (error) {
    console.error('Failed to send test notification:', error)
    res.status(500).json({
      success: false,
      error: 'Failed to send test notification',
    })
  }
})

/**
 * @openapi
 * /api/notifications/{id}:
 *   delete:
 *     tags: [Notifications]
 *     summary: Delete a notification
 *     description: Permanently deletes a notification (activity record targeted at the user).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Notification deleted
 *       404:
 *         description: Notification not found
 */
router.delete('/:id', requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req.user as any)?.id
    const { id } = req.params

    const activity = await prisma.activity.findFirst({
      where: { id, targetUserId: userId },
    })

    if (!activity) {
      return res.status(404).json({ success: false, error: 'Notification not found' })
    }

    await prisma.activity.delete({ where: { id } })

    res.json({ success: true })
  } catch (error) {
    console.error('Failed to delete notification:', error)
    res.status(500).json({ success: false, error: 'Failed to delete notification' })
  }
})

export default router
