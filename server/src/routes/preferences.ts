import { Router } from 'express'
import * as preferences from '../services/preferences.js'
import type { PreferenceIdentity } from '../services/preferences.js'

const router = Router()

/**
 * Extract preference identity from request.
 * Supports both User (session/API key) and Member (phone session) auth.
 */
function getIdentity(req: any): PreferenceIdentity | null {
  // User auth (Google OAuth via session or API key)
  if (req.user?.id) {
    return { userId: req.user.id }
  }
  // Member auth (phone verification session)
  if (req.session?.memberId) {
    return { memberId: req.session.memberId }
  }
  return null
}

// ============================================
// GET /api/preferences
// ============================================

/**
 * @openapi
 * /api/preferences:
 *   get:
 *     tags: [Preferences]
 *     summary: Get all preferences
 *     description: Returns all preferences for the authenticated user or member, with defaults filled in.
 *     security:
 *       - userSession: []
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: All preferences as key-value pairs
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 preferences:
 *                   type: object
 *                   additionalProperties:
 *                     type: string
 *                   example:
 *                     bible_translation: NASB
 *       401:
 *         description: Authentication required
 */
router.get('/', async (req, res) => {
  try {
    const identity = getIdentity(req)
    if (!identity) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const prefs = await preferences.getAllPreferences(identity)
    res.json({ preferences: prefs })
  } catch (error) {
    console.error('Error fetching preferences:', error)
    res.status(500).json({ error: 'Failed to fetch preferences' })
  }
})

// ============================================
// POST /api/preferences/batch
// ============================================

/**
 * @openapi
 * /api/preferences/batch:
 *   post:
 *     tags: [Preferences]
 *     summary: Get multiple preferences by key
 *     description: Returns values for the specified preference keys. Missing keys are omitted from the response.
 *     security:
 *       - userSession: []
 *       - memberSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [keys]
 *             properties:
 *               keys:
 *                 type: array
 *                 items:
 *                   type: string
 *                 example: ["filters.library.programs", "filters.library.media"]
 *     responses:
 *       200:
 *         description: Preferences for the requested keys
 *       401:
 *         description: Authentication required
 */
router.post('/batch', async (req, res) => {
  try {
    const identity = getIdentity(req)
    if (!identity) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const { keys } = req.body
    if (!Array.isArray(keys) || keys.length === 0) {
      return res.status(400).json({ error: 'keys array is required' })
    }

    const prefs = await preferences.getPreferencesBatch(identity, keys)
    res.json({ preferences: prefs })
  } catch (error) {
    console.error('Error fetching preferences batch:', error)
    res.status(500).json({ error: 'Failed to fetch preferences' })
  }
})

// ============================================
// GET /api/preferences/:key
// ============================================

/**
 * @openapi
 * /api/preferences/{key}:
 *   get:
 *     tags: [Preferences]
 *     summary: Get a single preference
 *     description: Returns the value of a specific preference key, falling back to the default if not set.
 *     security:
 *       - userSession: []
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: key
 *         required: true
 *         schema:
 *           type: string
 *           example: bible_translation
 *     responses:
 *       200:
 *         description: Preference value
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 key:
 *                   type: string
 *                   example: bible_translation
 *                 value:
 *                   type: string
 *                   example: NASB
 *                 isDefault:
 *                   type: boolean
 *                   example: true
 *       401:
 *         description: Authentication required
 */
router.get('/:key', async (req, res) => {
  try {
    const identity = getIdentity(req)
    if (!identity) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const { key } = req.params
    const value = await preferences.getPreference(identity, key)
    const defaultValue = preferences.getDefault(key)
    const isDefault = value === null

    res.json({
      key,
      value: value ?? defaultValue ?? '',
      isDefault,
    })
  } catch (error) {
    console.error('Error fetching preference:', error)
    res.status(500).json({ error: 'Failed to fetch preference' })
  }
})

// ============================================
// PUT /api/preferences/:key
// ============================================

/**
 * @openapi
 * /api/preferences/{key}:
 *   put:
 *     tags: [Preferences]
 *     summary: Set a preference
 *     description: Sets or updates a preference value for the authenticated user or member.
 *     security:
 *       - userSession: []
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: key
 *         required: true
 *         schema:
 *           type: string
 *           example: bible_translation
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - value
 *             properties:
 *               value:
 *                 type: string
 *                 example: ESV
 *     responses:
 *       200:
 *         description: Preference updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 key:
 *                   type: string
 *                 value:
 *                   type: string
 *                 message:
 *                   type: string
 *       400:
 *         description: Value is required
 *       401:
 *         description: Authentication required
 */
router.put('/:key', async (req, res) => {
  try {
    const identity = getIdentity(req)
    if (!identity) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const { key } = req.params
    const { value } = req.body

    if (value === undefined || value === null) {
      return res.status(400).json({ error: 'Value is required' })
    }

    await preferences.setPreference(identity, key, String(value))

    res.json({
      key,
      value: String(value),
      message: 'Preference updated',
    })
  } catch (error) {
    console.error('Error setting preference:', error)
    res.status(500).json({ error: 'Failed to set preference' })
  }
})

// ============================================
// DELETE /api/preferences/:key
// ============================================

/**
 * @openapi
 * /api/preferences/{key}:
 *   delete:
 *     tags: [Preferences]
 *     summary: Reset a preference to default
 *     description: Deletes a preference, resetting it to its default value.
 *     security:
 *       - userSession: []
 *       - memberSession: []
 *     parameters:
 *       - in: path
 *         name: key
 *         required: true
 *         schema:
 *           type: string
 *           example: bible_translation
 *     responses:
 *       200:
 *         description: Preference reset to default
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 key:
 *                   type: string
 *                 defaultValue:
 *                   type: string
 *                 message:
 *                   type: string
 *       401:
 *         description: Authentication required
 */
router.delete('/:key', async (req, res) => {
  try {
    const identity = getIdentity(req)
    if (!identity) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const { key } = req.params
    await preferences.deletePreference(identity, key)

    res.json({
      key,
      defaultValue: preferences.getDefault(key) ?? null,
      message: 'Preference reset to default',
    })
  } catch (error) {
    console.error('Error deleting preference:', error)
    res.status(500).json({ error: 'Failed to delete preference' })
  }
})

export default router
