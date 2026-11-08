import { Router } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import { parseContentBody, sendContentError } from '../services/content-errors.js'
import { deleteActivity, replaceActivity } from '../services/lesson-version.service.js'

const router = Router()

const putBody = z.object({ title: z.string().min(1).max(200).optional(), document: z.unknown() }).strict()

// PUT /api/content-activities/:id: replaces the activity's whole document (and title when sent).
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const body = parseContentBody(putBody, req.body)
    res.json(await replaceActivity((req.user as { id: string }).id, req.params.id, body))
  } catch (err) {
    sendContentError(res, err)
  }
})

// DELETE /api/content-activities/:id: removes the activity and closes the positions up.
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    await deleteActivity((req.user as { id: string }).id, req.params.id)
    res.json({ success: true })
  } catch (err) {
    sendContentError(res, err)
  }
})

export default router
