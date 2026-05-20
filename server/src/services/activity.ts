/**
 * Activity Ledger Service
 *
 * Tracks user-facing activities (created group, edited program, etc.)
 * Fire-and-forget — never breaks the main request.
 *
 * When targetUserId + title are present, also sends a push notification
 * to the targeted user (unified notification system).
 */

import { prisma } from '../lib/prisma.js'
import { ActivityAction } from '../generated/prisma/index.js'
import { sendToUser } from './push-notification.js'

interface TrackActivityParams {
  actorId: string
  action: ActivityAction
  resourceType: string
  resourceId: string
  resourceName: string
  organizationId?: string | null
  groupId?: string | null
  targetUserId?: string | null
  title?: string | null
  body?: string | null
  metadata?: Record<string, unknown>
}

/**
 * Record an activity in the ledger.
 * Catches its own errors so callers can fire-and-forget.
 *
 * If targetUserId and title are provided, also sends a push notification
 * to the target user's devices.
 */
export function trackActivity(params: TrackActivityParams): void {
  prisma.activity
    .create({
      data: {
        actorId: params.actorId,
        action: params.action,
        resourceType: params.resourceType,
        resourceId: params.resourceId,
        resourceName: params.resourceName,
        organizationId: params.organizationId ?? undefined,
        groupId: params.groupId ?? undefined,
        targetUserId: params.targetUserId ?? undefined,
        title: params.title ?? undefined,
        body: params.body ?? undefined,
        metadata: (params.metadata as any) ?? undefined,
      },
    })
    .then((activity) => {
      // Send push notification for targeted activities
      if (params.targetUserId && params.title) {
        sendToUser(params.targetUserId, {
          title: params.title,
          body: params.body ?? params.resourceName,
          data: {
            activityId: activity.id,
            resourceType: params.resourceType,
            resourceId: params.resourceId,
            action: params.action,
          },
        }).catch((pushError) => {
          console.error('Failed to send push notification:', pushError)
        })
      }
    })
    .catch((error) => {
      console.error('Failed to track activity:', error)
    })
}
