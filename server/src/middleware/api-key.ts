/**
 * API Key Authentication Middleware
 *
 * Handles authentication via API keys (Bearer tokens starting with "mr_").
 * Provides rate limiting and usage tracking.
 */

import { Request, Response, NextFunction } from 'express'
import { prisma } from '../lib/prisma.js'
import {
  extractBearerToken,
  isValidApiKeyFormat,
  hashApiKey,
} from '../lib/api-key.js'

/**
 * Rate limiter storage
 * Key: API key hash, Value: { count: number, resetAt: number }
 */
const rateLimitStore = new Map<string, { count: number; resetAt: number }>()

/** Rate limit: requests per minute */
const RATE_LIMIT_MAX = 120

/** Rate limit window in milliseconds (1 minute) */
const RATE_LIMIT_WINDOW_MS = 60 * 1000

/**
 * Clean up expired rate limit entries periodically
 */
setInterval(() => {
  const now = Date.now()
  for (const [key, value] of rateLimitStore.entries()) {
    if (value.resetAt < now) {
      rateLimitStore.delete(key)
    }
  }
}, RATE_LIMIT_WINDOW_MS)

/**
 * Check rate limit for an API key
 * @param keyHash - The hashed API key
 * @returns Object with allowed status and remaining requests
 */
function checkRateLimit(keyHash: string): {
  allowed: boolean
  remaining: number
  resetAt: number
} {
  const now = Date.now()
  const entry = rateLimitStore.get(keyHash)

  if (!entry || entry.resetAt < now) {
    // New window
    const resetAt = now + RATE_LIMIT_WINDOW_MS
    rateLimitStore.set(keyHash, { count: 1, resetAt })
    return { allowed: true, remaining: RATE_LIMIT_MAX - 1, resetAt }
  }

  if (entry.count >= RATE_LIMIT_MAX) {
    return { allowed: false, remaining: 0, resetAt: entry.resetAt }
  }

  entry.count++
  return {
    allowed: true,
    remaining: RATE_LIMIT_MAX - entry.count,
    resetAt: entry.resetAt,
  }
}

/**
 * Update API key usage stats asynchronously (fire-and-forget)
 * @param apiKeyId - The API key ID
 */
function updateUsageAsync(apiKeyId: string): void {
  prisma.apiKey
    .update({
      where: { id: apiKeyId },
      data: {
        lastUsedAt: new Date(),
        usageCount: { increment: 1 },
      },
    })
    .catch((error) => {
      console.error('Failed to update API key usage:', error)
    })
}

/**
 * Middleware to authenticate requests using API keys
 *
 * This middleware attempts to authenticate using an API key from the
 * Authorization header. If a valid API key is found:
 * - Sets req.user to the API key owner
 * - Sets req.apiKeyId to the API key ID
 *
 * If no API key is present, the request continues without modification
 * (allowing session-based auth to handle it).
 */
export const authenticateApiKey = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization
    const apiKey = extractBearerToken(authHeader)

    // No API key in header, continue to next middleware
    if (!apiKey) {
      return next()
    }

    // Check if it's an mr_ key
    if (!apiKey.startsWith('mr_')) {
      // Not an MR API key, might be another bearer token type
      return next()
    }

    // Validate format
    if (!isValidApiKeyFormat(apiKey)) {
      return res.status(401).json({
        success: false,
        error: 'Invalid API key format',
      })
    }

    // Hash the key and look it up
    const keyHash = hashApiKey(apiKey)
    const apiKeyRecord = await prisma.apiKey.findUnique({
      where: { keyHash },
      include: {
        user: true,
      },
    })

    if (!apiKeyRecord) {
      return res.status(401).json({
        success: false,
        error: 'Invalid API key',
      })
    }

    // Check if key is active
    if (!apiKeyRecord.isActive) {
      return res.status(401).json({
        success: false,
        error: 'API key has been revoked',
      })
    }

    // Check if key has expired
    if (apiKeyRecord.expiresAt && apiKeyRecord.expiresAt < new Date()) {
      return res.status(401).json({
        success: false,
        error: 'API key has expired',
      })
    }

    // Check if the owning user is active
    if (apiKeyRecord.user.isActive === false) {
      return res.status(401).json({
        success: false,
        error: 'User account is inactive',
      })
    }

    // Check rate limit
    const rateLimit = checkRateLimit(keyHash)
    res.setHeader('X-RateLimit-Limit', RATE_LIMIT_MAX.toString())
    res.setHeader('X-RateLimit-Remaining', rateLimit.remaining.toString())
    res.setHeader('X-RateLimit-Reset', rateLimit.resetAt.toString())

    if (!rateLimit.allowed) {
      return res.status(429).json({
        success: false,
        error: 'Rate limit exceeded. Please try again later.',
        retryAfter: Math.ceil((rateLimit.resetAt - Date.now()) / 1000),
      })
    }

    // Attach user and API key ID to request
    req.user = apiKeyRecord.user
    req.apiKeyId = apiKeyRecord.id

    // Update usage stats asynchronously
    updateUsageAsync(apiKeyRecord.id)

    next()
  } catch (error) {
    console.error('Error in API key authentication:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}
