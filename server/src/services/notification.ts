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

export interface NotificationAction {
  label: string
  view: string
  params?: Record<string, string>
}

/**
 * Create a notification, coalescing by dedupeKey (study-sync): while an
 * UNREAD notification with the same key exists for the user, new events
 * update it in place (fresh title/body/data/actions/timestamp) instead of
 * stacking — N publishes before the leader looks = 1 notification.
 * Push is sent only when a new notification is created, not on coalesce.
 */
export async function upsertNotificationByDedupeKey(params: {
  userId: string
  type: string
  title: string
  body: string
  dedupeKey: string
  data?: Record<string, string>
  actions?: NotificationAction[]
}) {
  const { userId, type, title, body, dedupeKey, data, actions } = params

  const existing = await prisma.notification.findFirst({
    where: { userId, dedupeKey, isRead: false },
  })

  if (existing) {
    return prisma.notification.update({
      where: { id: existing.id },
      data: {
        type,
        title,
        body,
        data: data ?? undefined,
        actions: (actions as unknown as import('../generated/prisma/index.js').Prisma.InputJsonValue) ?? undefined,
        createdAt: new Date(), // banner shows "last one happened"
      },
    })
  }

  const notification = await prisma.notification.create({
    data: {
      userId,
      type,
      title,
      body,
      dedupeKey,
      data: data ?? undefined,
      actions: (actions as unknown as import('../generated/prisma/index.js').Prisma.InputJsonValue) ?? undefined,
    },
  })

  try {
    await sendToUser(userId, { title, body, data: { ...data, type } })
  } catch (pushError) {
    console.error('Failed to send push notification:', pushError)
  }

  return notification
}

/** Mark unread notifications with a dedupeKey read (the condition resolved). */
export async function resolveNotificationsByDedupeKey(userId: string, dedupeKey: string) {
  await prisma.notification.updateMany({
    where: { userId, dedupeKey, isRead: false },
    data: { isRead: true },
  })
}
