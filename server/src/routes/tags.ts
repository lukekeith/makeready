import { Router } from 'express'
import { requireAuth } from '../middleware/auth.js'
import { listTagCategories } from '../services/tag-categories.js'

const router = Router()

/**
 * @openapi
 * /api/tags/categories:
 *   get:
 *     tags: [Tags]
 *     summary: MakeReady-defined tag categories (tag-categories D3, D15)
 *     description: >
 *       Global and read-only. Each category lists its member spellings — normalized (lowercase, no
 *       whitespace) — with a display label and a position; the spellings of one member share both.
 *       A tag belongs to a category when its normalized text equals a member's tag.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: "{ success, categories: [{ key, name, position, tags: [{ tag, label, position }] }] }"
 *       401:
 *         description: Not authenticated
 */
router.get('/categories', requireAuth, async (_req, res) => {
  try {
    res.json({ success: true, categories: await listTagCategories() })
  } catch (error) {
    console.error('Error listing tag categories:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

export default router
