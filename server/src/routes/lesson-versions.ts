import { Router } from 'express'
import { requireAuth } from '../middleware/auth.js'
import { ContentError, sendContentError } from '../services/content-errors.js'
import { getLessonVersion } from '../services/lesson-version.service.js'

const router = Router()

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

export default router
