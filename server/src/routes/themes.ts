import { Router } from 'express'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { getUserOrgId } from '../services/media-library.js'

const router = Router()

// ============================================================================
// Public endpoints (no auth required)
// ============================================================================

/**
 * @openapi
 * /api/themes/public/list:
 *   get:
 *     tags: [Themes]
 *     summary: List all system themes (public, no auth)
 *     description: Returns all active system themes with full definitions. Used by the theme preview tool.
 *     responses:
 *       200:
 *         description: List of system themes
 */
router.get('/public/list', async (_req, res) => {
  try {
    const themes = await prisma.textTheme.findMany({
      where: { isSystem: true, isActive: true },
      select: {
        id: true,
        name: true,
        slug: true,
        description: true,
        definition: true,
        fontScale: true,
        maxCharacters: true,
      },
      orderBy: { name: 'asc' },
    })
    res.json({ success: true, themes })
  } catch (error) {
    console.error('Error fetching public themes:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch themes' })
  }
})

// ============================================================================
// Authenticated theme routes
// ============================================================================

/**
 * @openapi
 * /api/themes:
 *   get:
 *     tags: [Themes]
 *     summary: List available themes
 *     description: Returns all active system themes plus org-specific themes for the user's organization.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of themes
 */
router.get('/', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as any).id
    const userOrgId = await getUserOrgId(userId)

    const themes = await prisma.textTheme.findMany({
      where: {
        isActive: true,
        OR: [
          { isSystem: true },
          ...(userOrgId ? [{ organizationId: userOrgId }] : []),
        ],
      },
      select: {
        id: true,
        name: true,
        slug: true,
        description: true,
        isSystem: true,
        definition: true,
        fontScale: true,
        maxCharacters: true,
      },
      orderBy: { name: 'asc' },
    })

    // URL template the iPhone uses to open the canonical web preview inside a
    // WKWebView. `{activityId}` is a literal placeholder the client substitutes.
    const clientBaseUrl =
      process.env.CLIENT_BASE_URL ||
      (process.env.NODE_ENV === 'production'
        ? 'https://app.makeready.org'
        : 'http://localhost:8000')   // Laravel dev server — NOT Vite (:5173)
    const previewUrlTemplate = `${clientBaseUrl}/preview/activity/{activityId}`

    res.json({ success: true, themes, previewUrlTemplate })
  } catch (error) {
    console.error('Error fetching themes:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch themes' })
  }
})

/**
 * @openapi
 * /api/themes/{idOrSlug}:
 *   get:
 *     tags: [Themes]
 *     summary: Get a single theme by ID or slug
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: idOrSlug
 *         required: true
 *         schema:
 *           type: string
 *         description: Theme UUID or slug
 *     responses:
 *       200:
 *         description: Theme details
 *       404:
 *         description: Theme not found
 */
router.get('/:idOrSlug', requireAuth, async (req, res) => {
  try {
    const { idOrSlug } = req.params

    // Detect UUID format
    const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug)

    const theme = await prisma.textTheme.findFirst({
      where: isUUID ? { id: idOrSlug } : { slug: idOrSlug },
      select: {
        id: true,
        name: true,
        slug: true,
        description: true,
        isSystem: true,
        definition: true,
        fontScale: true,
        maxCharacters: true,
      },
    })

    if (!theme) {
      return res.status(404).json({ success: false, error: 'Theme not found' })
    }

    res.json({ success: true, theme })
  } catch (error) {
    console.error('Error fetching theme:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch theme' })
  }
})

export default router
