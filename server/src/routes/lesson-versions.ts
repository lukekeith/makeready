import { Router } from 'express'
import { requireAuth } from '../middleware/auth.js'
import { ContentError, parseContentBody, sendContentError } from '../services/content-errors.js'
import { z } from 'zod'
import { createActivity, getLessonVersion, reorderActivities, serializeContentActivity } from '../services/lesson-version.service.js'

const router = Router()
const userId = (req: { user?: unknown }) => (req.user as { id: string }).id

const createBody = z.object({ kind: z.string().min(1), title: z.string().min(1).max(200), document: z.unknown() }).strict()
const orderBody = z.object({ activityIds: z.array(z.string()) }).strict()

// GET /api/lesson-versions/:id: a version with its activities and media, read-only.
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const payload = await getLessonVersion((req.user as { id: string }).id, req.params.id)
    if (!payload) throw new ContentError(404, 'NOT_FOUND', 'Not found')
    res.json(payload)
  } catch (err) {
    sendContentError(res, err)
  }
})

// POST /api/lesson-versions/:id/activities: appends an activity to a draft.
router.post('/:id/activities', requireAuth, async (req, res) => {
  try {
    const body = parseContentBody(createBody, req.body)
    res.status(201).json(await createActivity(userId(req), req.params.id, body))
  } catch (err) {
    sendContentError(res, err)
  }
})

// PATCH /api/lesson-versions/:id/activities/order: reorders a draft's activities (exact set).
router.patch('/:id/activities/order', requireAuth, async (req, res) => {
  try {
    const { activityIds } = parseContentBody(orderBody, req.body)
    const rows = await reorderActivities(userId(req), req.params.id, activityIds)
    res.json({ activities: rows.map(serializeContentActivity) })
  } catch (err) {
    sendContentError(res, err)
  }
})

export default router
