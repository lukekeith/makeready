/**
 * Push Notification Service
 *
 * Handles sending push notifications via Apple Push Notification service (APNs).
 * Uses @parse/node-apn for APNs communication.
 */

import apn from '@parse/node-apn'
import { prisma } from '../lib/prisma.js'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// APNs provider instance (lazy initialized)
let apnProvider: apn.Provider | null = null

// Track initialization status
let initializationAttempted = false

/**
 * Get the APNs provider, initializing if needed
 */
function getProvider(): apn.Provider | null {
  if (apnProvider) {
    return apnProvider
  }

  if (initializationAttempted) {
    // Already tried to initialize and failed
    return null
  }

  initializationAttempted = true

  // Check for required environment variables
  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID
  const bundleId = process.env.APNS_BUNDLE_ID
  const keyPath = process.env.APNS_KEY_PATH
  const environment = process.env.APNS_ENVIRONMENT || 'production'

  if (!keyId || !teamId || !bundleId || !keyPath) {
    console.warn('⚠️ APNs not configured. Missing environment variables:')
    if (!keyId) console.warn('  - APNS_KEY_ID')
    if (!teamId) console.warn('  - APNS_TEAM_ID')
    if (!bundleId) console.warn('  - APNS_BUNDLE_ID')
    if (!keyPath) console.warn('  - APNS_KEY_PATH')
    return null
  }

  try {
    // Resolve key path relative to server root
    const absoluteKeyPath = path.resolve(__dirname, '../../', keyPath)

    apnProvider = new apn.Provider({
      token: {
        key: absoluteKeyPath,
        keyId,
        teamId,
      },
      production: environment === 'production',
    })

    console.log(`✅ APNs provider initialized (${environment})`)
    return apnProvider
  } catch (error) {
    console.error('❌ Failed to initialize APNs provider:', error)
    return null
  }
}

export interface PushNotificationPayload {
  title: string
  body: string
  badge?: number
  sound?: string
  data?: Record<string, string | boolean>
}

/**
 * Send a push notification to all devices for a user
 */
export async function sendToUser(
  userId: string,
  notification: PushNotificationPayload
): Promise<{ success: boolean; sent: number; failed: number; errors: string[] }> {
  const provider = getProvider()

  if (!provider) {
    console.warn('📱 Push notification skipped - APNs not configured')
    return {
      success: false,
      sent: 0,
      failed: 0,
      errors: ['APNs not configured'],
    }
  }

  // Get all device tokens for the user
  const deviceTokens = await prisma.deviceToken.findMany({
    where: { userId },
  })

  if (deviceTokens.length === 0) {
    console.log(`📱 No device tokens found for user ${userId}`)
    return {
      success: true,
      sent: 0,
      failed: 0,
      errors: [],
    }
  }

  // Build the APNs notification
  const apnNotification = new apn.Notification()
  apnNotification.topic = process.env.APNS_BUNDLE_ID!
  apnNotification.alert = {
    title: notification.title,
    body: notification.body,
  }

  if (notification.badge !== undefined) {
    apnNotification.badge = notification.badge
  }

  apnNotification.sound = notification.sound || 'default'

  // Add custom data payload
  if (notification.data) {
    apnNotification.payload = notification.data
  }

  // Set expiry to 1 day
  apnNotification.expiry = Math.floor(Date.now() / 1000) + 24 * 60 * 60

  // Send to all devices
  const tokens = deviceTokens.map((dt) => dt.token)
  const result = await provider.send(apnNotification, tokens)

  const errors: string[] = []
  const invalidTokens: string[] = []

  // Process failed tokens
  for (const failure of result.failed) {
    const errorMsg = `${failure.device}: ${failure.response?.reason || failure.error?.message || 'Unknown error'}`
    errors.push(errorMsg)

    // Track invalid tokens for cleanup
    if (
      failure.response?.reason === 'BadDeviceToken' ||
      failure.response?.reason === 'Unregistered' ||
      failure.response?.reason === 'ExpiredToken' ||
      failure.status === 410 // Gone - token no longer valid
    ) {
      invalidTokens.push(failure.device)
    }
  }

  // Clean up invalid tokens
  if (invalidTokens.length > 0) {
    console.log(`📱 Removing ${invalidTokens.length} invalid device tokens`)
    await prisma.deviceToken.deleteMany({
      where: {
        token: { in: invalidTokens },
      },
    })
  }

  const sentCount = result.sent.length
  const failedCount = result.failed.length

  console.log(
    `📱 Push notification sent to user ${userId}: ${sentCount} sent, ${failedCount} failed`
  )

  return {
    success: sentCount > 0 || failedCount === 0,
    sent: sentCount,
    failed: failedCount,
    errors,
  }
}

/**
 * Send a push notification to a specific device token
 */
export async function sendToDevice(
  token: string,
  notification: PushNotificationPayload
): Promise<{ success: boolean; error?: string }> {
  const provider = getProvider()

  if (!provider) {
    return {
      success: false,
      error: 'APNs not configured',
    }
  }

  const apnNotification = new apn.Notification()
  apnNotification.topic = process.env.APNS_BUNDLE_ID!
  apnNotification.alert = {
    title: notification.title,
    body: notification.body,
  }

  if (notification.badge !== undefined) {
    apnNotification.badge = notification.badge
  }

  apnNotification.sound = notification.sound || 'default'

  if (notification.data) {
    apnNotification.payload = notification.data
  }

  apnNotification.expiry = Math.floor(Date.now() / 1000) + 24 * 60 * 60

  const result = await provider.send(apnNotification, token)

  if (result.sent.length > 0) {
    return { success: true }
  }

  const failure = result.failed[0]
  const error =
    failure?.response?.reason || failure?.error?.message || 'Unknown error'

  // Clean up invalid token
  if (
    failure?.response?.reason === 'BadDeviceToken' ||
    failure?.response?.reason === 'Unregistered' ||
    failure?.response?.reason === 'ExpiredToken' ||
    failure?.status === 410
  ) {
    await prisma.deviceToken.deleteMany({
      where: { token },
    })
  }

  return {
    success: false,
    error,
  }
}

/**
 * Check if push notifications are configured
 */
export function isPushConfigured(): boolean {
  return getProvider() !== null
}

/**
 * Shutdown the APNs provider (call on server shutdown)
 */
export function shutdown(): void {
  if (apnProvider) {
    apnProvider.shutdown()
    apnProvider = null
  }
}

export default {
  sendToUser,
  sendToDevice,
  isPushConfigured,
  shutdown,
}
