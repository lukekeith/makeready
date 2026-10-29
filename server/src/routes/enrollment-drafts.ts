/**
 * /api/enrollment-drafts (ui2-enrollments-browse SC2). Thin: parse, call the service, map errors.
 * Logic and scope live in services/enrollment-draft.service.ts.
 */
import { Router, type Request, type Response } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import {
  DraftError,
  createDraft,
  deleteDraft,
  draftCreateSchema,
  draftPatchSchema,
  getDraft,
  listGroupDrafts,
  updateDraft,
} from '../services/enrollment-draft.service.js'

const router = Router()
const uuid = z.string().uuid()
const userIdOf = (req: Request): string => (req.user as { id: string }).id
const notFound = (res: Response) => res.status(404).json({ success: false, error: 'Draft not found' })

function fail(res: Response, error: unknown, label: string) {
  if (error instanceof z.ZodError) {
    return res.status(400).json({
      success: false,
      error: 'invalid_request',
      message: error.issues.map((i) => `${i.path.join('.') || 'body'}: ${i.message}`).join('; '),
    })
  }
  if (error instanceof DraftError) {
    if (error.status === 409) return res.status(409).json({ success: false, error: 'draft_exists', draftId: error.draftId })
    return res.status(error.status).json({ success: false, error: error.message })
  }
  console.error(`Error ${label}:`, error)
  return res.status(500).json({ success: false, error: 'Internal server error' })
}

router.post('/enrollment-drafts', requireAuth, async (req, res) => {
  try {
    const draft = await createDraft(userIdOf(req), draftCreateSchema.parse(req.body))
    res.status(201).json({ success: true, draft })
  } catch (error) {
    fail(res, error, 'creating enrollment draft')
  }
})

router.get('/enrollment-drafts', requireAuth, async (req, res) => {
  try {
    const drafts = await listGroupDrafts(userIdOf(req), uuid.parse(req.query.groupId))
    res.json({ success: true, drafts })
  } catch (error) {
    fail(res, error, 'listing enrollment drafts')
  }
})

router.get('/enrollment-drafts/:id', requireAuth, async (req, res) => {
  if (!uuid.safeParse(req.params.id).success) return notFound(res)
  try {
    res.json({ success: true, draft: await getDraft(userIdOf(req), req.params.id) })
  } catch (error) {
    fail(res, error, 'reading enrollment draft')
  }
})

router.patch('/enrollment-drafts/:id', requireAuth, async (req, res) => {
  if (!uuid.safeParse(req.params.id).success) return notFound(res)
  try {
    const draft = await updateDraft(userIdOf(req), req.params.id, draftPatchSchema.parse(req.body))
    res.json({ success: true, draft })
  } catch (error) {
    fail(res, error, 'updating enrollment draft')
  }
})

router.delete('/enrollment-drafts/:id', requireAuth, async (req, res) => {
  if (!uuid.safeParse(req.params.id).success) return notFound(res)
  try {
    await deleteDraft(userIdOf(req), req.params.id)
    res.json({ success: true })
  } catch (error) {
    fail(res, error, 'deleting enrollment draft')
  }
})

export default router
