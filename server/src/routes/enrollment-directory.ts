/**
 * The leader's enrollment directory (ui2-enrollments-browse SC4, SC5). Thin: parse, call the service,
 * map errors. Logic lives in services/enrollment-directory.service.ts.
 */
import { Router, type Request, type Response } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import { DirectoryError, feedQuerySchema, getEnrollmentFeed } from '../services/enrollment-directory.service.js'

const router = Router()
const userIdOf = (req: Request): string => (req.user as { id: string }).id

function fail(res: Response, error: unknown, label: string) {
  if (error instanceof z.ZodError) {
    return res.status(400).json({
      success: false,
      error: 'invalid_request',
      message: error.issues.map((i) => `${i.path.join('.') || 'query'}: ${i.message}`).join('; '),
    })
  }
  if (error instanceof DirectoryError) return res.status(error.status).json({ success: false, error: error.message })
  console.error(`Error ${label}:`, error)
  return res.status(500).json({ success: false, error: 'Internal server error' })
}

router.get('/enrollments-feed', requireAuth, async (req, res) => {
  try {
    const feed = await getEnrollmentFeed(userIdOf(req), feedQuerySchema.parse(req.query))
    res.json({ success: true, ...feed })
  } catch (error) {
    fail(res, error, 'building the enrollments feed')
  }
})

export default router
