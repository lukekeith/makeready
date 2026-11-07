import { Router } from 'express'
import { requireAuth } from '../middleware/auth.js'
import { ContentError, sendContentError } from '../services/content-errors.js'
import { getOrCreateDraft } from '../services/lesson-version.service.js'

const router = Router()

// GET /api/lessons/:id/draft: the lesson's draft, created from the latest published version if none (D31).
router.get('/:id/draft', requireAuth, async (req, res) => {
  try {
    const payload = await getOrCreateDraft((req.user as { id: string }).id, req.params.id)
    if (!payload) throw new ContentError(404, 'NOT_FOUND', 'Not found')
    res.json(payload)
  } catch (err) {
    sendContentError(res, err)
  }
})

export default router
