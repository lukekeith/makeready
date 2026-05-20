/**
 * Notification Service
 *
 * Creates in-app notifications (persisted to DB) and sends push notifications.
 * Replaces direct sendToUser calls so both channels happen together.
 */

import { prisma } from '../lib/prisma.js'
import { sendToUser } from './push-notification.js'

interface CreateNotificationParams {
  userId: string
  type: string
  title: string
  body: string
  data?: Record<string, string>
}

/**
 * Create a notification record in the database and send a push notification.
 * Push is best-effort — failures don't throw.
 */
export async function createNotification({
  userId,
  type,
  title,
  body,
  data,
}: CreateNotificationParams) {
  // 1. Persist to DB for in-app feed
  const notification = await prisma.notification.create({
    data: {
      userId,
      type,
      title,
      body,
      data: data ?? undefined,
    },
  })

  // 2. Send push notification (best-effort, non-blocking)
  try {
    await sendToUser(userId, {
      title,
      body,
      data: { ...data, type },
    })
  } catch (pushError) {
    console.error('Failed to send push notification:', pushError)
  }

  return notification
}
