/**
 * Request Logger Middleware
 *
 * Logs every API request to the ActivityLog table when VERBOSE_LOGGING=true.
 * Captures: route, method, status code, IP, user agent, session info,
 * and response time. Runs after the response is sent so it never blocks.
 */

import { Request, Response, NextFunction } from 'express'
import { prisma } from '../lib/prisma.js'
import { LogCategory, LogStatus } from '../generated/prisma/index.js'

const ENABLED = process.env.VERBOSE_LOGGING === 'true'

// Routes to skip (health checks, static assets, noisy endpoints)
const SKIP_ROUTES = [
  '/health',
  '/api/status',
  '/favicon.ico',
  '/logo',
  '/logs',
]

const SKIP_PREFIXES = [
  '/themes/',                // static CSS files
  '/_capture/',              // screenshot capture
  '/api/activity-logs',      // don't log log queries
  '/api/admin/activity-logs', // don't log admin log queries
]

function shouldSkip(path: string): boolean {
  if (SKIP_ROUTES.includes(path)) return true
  for (const prefix of SKIP_PREFIXES) {
    if (path.startsWith(prefix)) return true
  }
  return false
}

function resolveCategory(path: string): LogCategory {
  if (path.startsWith('/auth/') || path.includes('/verify') || path.includes('/confirm') || path.includes('/login') || path.includes('/logout')) return 'AUTH'
  if (path.includes('/join') || path.includes('/join-request') || path.includes('/attend') || path.includes('/enrollment')) return 'JOIN'
  return 'ACCESS'
}

function resolveActivityType(method: string, path: string): string {
  const prefix = resolveCategory(path) === 'AUTH' ? 'AUTH' : resolveCategory(path) === 'JOIN' ? 'JOIN' : 'ACCESS'
  // Normalize path: strip UUIDs and IDs for cleaner type names
  const cleaned = path
    .replace(/\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, '/:id')
    .replace(/\/[A-Z0-9]{6}(?=\/|$)/g, '/:code')
    .replace(/\/\d+(?=\/|$)/g, '/:n')
  return `${prefix}_${method}_${cleaned}`.toUpperCase().replace(/[^A-Z0-9_]/g, '_').replace(/_+/g, '_')
}

// Truncate large objects for storage — keep metadata under ~10KB
const MAX_BODY_KEYS = 50
const MAX_STRING_LEN = 500
const MAX_ARRAY_LEN = 10
const SENSITIVE_BODY_KEYS = new Set([
  'idToken',
  'idtoken',
  'token',
  'accessToken',
  'refreshToken',
  'authorization',
  'password',
])

function truncateValue(val: unknown): unknown {
  if (val === null || val === undefined) return val
  if (typeof val === 'string') return val.length > MAX_STRING_LEN ? val.substring(0, MAX_STRING_LEN) + '…' : val
  if (Array.isArray(val)) {
    const truncated = val.slice(0, MAX_ARRAY_LEN).map(truncateValue)
    if (val.length > MAX_ARRAY_LEN) truncated.push(`... +${val.length - MAX_ARRAY_LEN} more`)
    return truncated
  }
  if (typeof val === 'object') return truncateBody(val as Record<string, unknown>)
  return val
}

function truncateBody(obj: Record<string, unknown> | null | undefined): Record<string, unknown> | null {
  if (!obj || typeof obj !== 'object') return null
  const keys = Object.keys(obj)
  const result: Record<string, unknown> = {}
  for (const key of keys.slice(0, MAX_BODY_KEYS)) {
    if (SENSITIVE_BODY_KEYS.has(key)) {
      result[key] = '[REDACTED]'
      continue
    }
    result[key] = truncateValue(obj[key])
  }
  if (keys.length > MAX_BODY_KEYS) result['__truncated'] = `${keys.length - MAX_BODY_KEYS} keys omitted`
  return result
}

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  if (!ENABLED) return next()
  if (shouldSkip(req.path)) return next()

  const startTime = Date.now()

  // Capture response body by intercepting res.json()
  let responseBody: Record<string, unknown> | null = null
  const originalJson = res.json.bind(res)
  res.json = function (body: any) {
    responseBody = body
    return originalJson(body)
  }

  // Capture response finish to log after the response is sent
  res.on('finish', () => {
    const duration = Date.now() - startTime
    const statusCode = res.statusCode
    const status: LogStatus = statusCode >= 500 ? 'FAILURE' : statusCode >= 400 ? 'WARNING' : 'SUCCESS'

    const userId = (req.user as any)?.id || null
    const memberId = req.session?.memberId || null

    // Extract entity IDs from route params
    const groupId = req.params?.groupId || null
    const eventId = req.params?.eventId || null
    const lessonId = req.params?.lessonId || req.params?.lessonScheduleId || null
    const enrollmentId = req.params?.enrollmentId || null

    // Build message
    const message = `${req.method} ${req.path} → ${statusCode} (${duration}ms)`

    // Capture request body (for POST/PATCH/PUT) and response body
    const requestBody = (req.method !== 'GET' && req.body && Object.keys(req.body).length > 0)
      ? truncateBody(req.body)
      : undefined

    const resBody = responseBody ? truncateBody(responseBody as Record<string, unknown>) : undefined

    // Fire-and-forget — don't await, don't block
    prisma.activityLog.create({
      data: {
        category: resolveCategory(req.path),
        activityType: resolveActivityType(req.method, req.path),
        status,
        message,
        userId,
        memberId,
        actorIp: req.ip || req.socket.remoteAddress || null,
        userAgent: req.get('user-agent')?.substring(0, 500) || null,
        route: req.path,
        method: req.method,
        groupId,
        eventId,
        lessonId,
        enrollmentId,
        metadata: {
          statusCode,
          duration,
          query: Object.keys(req.query).length > 0 ? req.query : undefined,
          requestBody: requestBody as any,
          responseBody: resBody as any,
        } as any,
      },
    }).catch(err => {
      // Swallow — logging must never crash the server
      if (process.env.NODE_ENV !== 'production') {
        console.error('[request-logger] Failed to log:', err.message)
      }
    })
  })

  next()
}
