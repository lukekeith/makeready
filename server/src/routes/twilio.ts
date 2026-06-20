import { Router } from 'express'
import type { Request } from 'express'
import Twilio from 'twilio'
import { prisma, Prisma } from '../lib/prisma.js'

const router = Router()

const RESOURCE_SID_FIELDS = [
  'BusinessProfileSid',
  'CustomerProfileSid',
  'TrustProductSid',
  'MessagingServiceSid',
  'ApplicationSid',
  'ServiceSid',
  'EntitySid',
  'Sid',
  'business_profile_sid',
  'customer_profile_sid',
  'trust_product_sid',
  'messaging_service_sid',
  'application_sid',
  'service_sid',
  'entity_sid',
  'resource_sid',
  'sid',
]

const EVENT_TYPE_FIELDS = [
  'EventType',
  'Status',
  'VerificationStatus',
  'ReviewStatus',
  'MessageStatus',
  'event_type',
  'status',
  'verification_status',
  'review_status',
  'message_status',
]

function firstStringValue(source: Record<string, unknown>, fields: string[]): string | null {
  for (const field of fields) {
    const value = source[field]
    if (typeof value === 'string' && value.trim().length > 0) {
      return value
    }
  }
  return null
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>
  }
  return {}
}

function buildPayload(req: Request): Record<string, unknown> {
  const body = asRecord(req.body)
  const query = asRecord(req.query)

  if (Object.keys(query).length === 0) {
    return body
  }

  return {
    ...body,
    _query: query,
  }
}

function inferCallbackType(payload: Record<string, unknown>, query: Record<string, unknown>): string | null {
  const explicit = firstStringValue(payload, ['CallbackType', 'callback_type'])
    ?? firstStringValue(query, ['type', 'callbackType', 'callback_type'])

  if (explicit) return explicit

  if (payload.BusinessProfileSid || payload.business_profile_sid) return 'business_profile'
  if (payload.CustomerProfileSid || payload.TrustProductSid || payload.customer_profile_sid || payload.trust_product_sid) return 'trust_hub'
  if (payload.ApplicationSid || payload.application_sid) return 'app'
  if (payload.MessagingServiceSid || payload.messaging_service_sid) return 'messaging_service'

  return null
}

function validateTwilioSignature(req: Request): { valid: true } | { valid: false; status: number; message: string } {
  const allowUnsignedCallbacks = process.env.ALLOW_UNSIGNED_TWILIO_CALLBACKS === 'true'
    && process.env.NODE_ENV !== 'production'

  if (allowUnsignedCallbacks) {
    return { valid: true }
  }

  const signature = req.headers['x-twilio-signature']
  const authToken = process.env.TWILIO_AUTH_TOKEN
  const apiBaseUrl = process.env.API_BASE_URL

  if (typeof signature !== 'string' || signature.length === 0) {
    return { valid: false, status: 403, message: 'Missing Twilio signature' }
  }

  if (!authToken || !apiBaseUrl) {
    console.error('[Twilio Callback] Missing TWILIO_AUTH_TOKEN or API_BASE_URL')
    return { valid: false, status: 500, message: 'Webhook signature validation is not configured' }
  }

  const callbackUrl = new URL(req.originalUrl, apiBaseUrl.replace(/\/$/, '')).toString()
  const rawBody = (req as Request & { rawBody?: string }).rawBody
  const contentType = req.headers['content-type'] ?? ''
  const isJsonRequest = typeof contentType === 'string' && contentType.includes('application/json')

  const isValid = isJsonRequest
    ? typeof rawBody === 'string'
      && Twilio.validateRequestWithBody(authToken, signature, callbackUrl, rawBody)
    : Twilio.validateRequest(authToken, signature, callbackUrl, req.body)

  if (!isValid) {
    console.warn('[Twilio Callback] Invalid Twilio signature')
    return { valid: false, status: 403, message: 'Invalid Twilio signature' }
  }

  return { valid: true }
}

/**
 * @openapi
 * /api/twilio/callback:
 *   post:
 *     tags: [Twilio]
 *     summary: Receive generic Twilio account/application callbacks
 *     description: |
 *       Stores Twilio Business Profile, Trust Hub, Messaging Service, and other
 *       non-SMS-delivery callback payloads for later inspection. In production,
 *       requests must include a valid Twilio signature for the exact configured
 *       URL: `${API_BASE_URL}/api/twilio/callback`.
 *     requestBody:
 *       required: false
 *       content:
 *         application/x-www-form-urlencoded:
 *           schema:
 *             type: object
 *             additionalProperties: true
 *         application/json:
 *           schema:
 *             type: object
 *             additionalProperties: true
 *     responses:
 *       201:
 *         description: Callback stored
 *       403:
 *         description: Missing or invalid Twilio signature
 *       500:
 *         description: Internal server error
 */
router.post('/callback', async (req, res) => {
  const signatureResult = validateTwilioSignature(req)
  if (!signatureResult.valid) {
    return res.status(signatureResult.status).json({
      success: false,
      error: signatureResult.message,
    })
  }

  try {
    const payload = buildPayload(req)
    const query = asRecord(req.query)
    const accountSid = firstStringValue(payload, ['AccountSid', 'account_sid'])
    const resourceSid = firstStringValue(payload, RESOURCE_SID_FIELDS)
    const eventType = firstStringValue(payload, EVENT_TYPE_FIELDS)
    const callbackType = inferCallbackType(payload, query)

    const callback = await prisma.twilioCallback.create({
      data: {
        callbackType,
        accountSid,
        resourceSid,
        eventType,
        payload: payload as Prisma.InputJsonValue,
      },
      select: { id: true },
    })

    console.log('[Twilio Callback] Stored callback', {
      id: callback.id,
      callbackType,
      accountSid,
      resourceSid,
      eventType,
    })

    return res.status(201).json({
      success: true,
      id: callback.id,
    })
  } catch (error) {
    console.error('[Twilio Callback] Error storing callback:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

export default router
