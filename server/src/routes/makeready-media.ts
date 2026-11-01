/**
 * media-library D2/D15/D18: MakeReady's own media library, written only by super admins (a session,
 * or an API key whose user is a super admin). No consumer app calls PATCH/DELETE yet — the future
 * admin UI will; the import command calls POST.
 */
import { Router } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import {
  MakeReadyMediaError,
  createMakeReadyMedia,
  deleteMakeReadyMedia,
  updateMakeReadyMedia,
} from '../services/makeready-media.js'

const router = Router()

const requireSuperAdmin = (req: any, res: any, next: any) => {
  if (!(req.user as any)?.isSuperAdmin) {
    return res.status(403).json({ success: false, error: 'Super admin access required' })
  }
  next()
}

const tagsSchema = z.array(z.string().min(1).max(40)).max(40)

const createSchema = z.object({
  imageData: z.string().min(1, 'imageData is required'),
  title: z.string().min(1).max(200),
  description: z.string().max(2000).optional(),
  altText: z.string().max(2000).optional(),
  tags: tagsSchema.optional(),
  d2mSlug: z.string().min(1).max(200).optional(),
})

const patchSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  description: z.string().max(2000).nullable().optional(),
  altText: z.string().max(2000).nullable().optional(),
  tags: tagsSchema.optional(),
})

function fail(res: any, error: unknown, what: string) {
  if (error instanceof MakeReadyMediaError) return res.status(error.status).json({ success: false, error: error.message })
  console.error(`Error ${what} MakeReady media:`, error)
  return res.status(500).json({ success: false, error: 'Internal server error' })
}

/**
 * @openapi
 * /api/makeready/media:
 *   post:
 *     summary: Add an image to MakeReady's own media library (super admin)
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     responses:
 *       201: { description: Created }
 *       403: { description: Not a super admin }
 *       409: { description: d2mSlug already imported }
 */
router.post('/makeready/media', requireAuth, requireSuperAdmin, async (req, res) => {
  const parsed = createSchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json({ success: false, error: parsed.error.errors[0].message })
  try {
    const { imageData, ...rest } = parsed.data
    const image = Buffer.from(imageData.replace(/^data:image\/\w+;base64,/, ''), 'base64')
    const media = await createMakeReadyMedia({ image, ...rest })
    res.status(201).json({ success: true, data: media })
  } catch (error) {
    fail(res, error, 'creating')
  }
})

/**
 * @openapi
 * /api/makeready/media/{id}:
 *   patch:
 *     summary: Edit a MakeReady library image's title, description, alt text or tags (super admin)
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     responses:
 *       200: { description: Updated }
 *       403: { description: Not a super admin }
 *       404: { description: Not MakeReady media }
 *   delete:
 *     summary: Hide a MakeReady library image (super admin; isActive false)
 *     tags: [Media Library]
 *     security:
 *       - userSession: []
 *     responses:
 *       200: { description: Hidden }
 *       403: { description: Not a super admin }
 *       404: { description: Not MakeReady media }
 */
router.patch('/makeready/media/:id', requireAuth, requireSuperAdmin, async (req, res) => {
  const parsed = patchSchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json({ success: false, error: parsed.error.errors[0].message })
  try {
    res.json({ success: true, data: await updateMakeReadyMedia(req.params.id, parsed.data) })
  } catch (error) {
    fail(res, error, 'updating')
  }
})

router.delete('/makeready/media/:id', requireAuth, requireSuperAdmin, async (req, res) => {
  try {
    await deleteMakeReadyMedia(req.params.id)
    res.json({ success: true })
  } catch (error) {
    fail(res, error, 'deleting')
  }
})

export default router
