import { Router, type Response } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import {
  MemoServiceError,
  completeMemo,
  createMemo,
  createMemoBody,
  getMemo,
  listMemos,
  listMemosQuery,
  remintUpload,
  renameMemo,
  renameMemoBody,
  softDeleteMemo,
} from '../services/memos.service.js'

const router = Router()

const emptyBody = z.object({}).strict()

const userId = (req: { user?: unknown }) => (req.user as { id: string }).id

/** Parses with a zod schema; a failure answers 400 and returns undefined (never strips). */
function parse<T extends z.ZodTypeAny>(schema: T, data: unknown, res: Response): z.infer<T> | undefined {
  const result = schema.safeParse(data)
  if (result.success) return result.data
  res.status(400).json({ success: false, error: 'Invalid request', details: result.error.issues })
  return undefined
}

function fail(res: Response, error: unknown) {
  if (error instanceof MemoServiceError) {
    return res.status(error.status).json({ success: false, error: error.message })
  }
  console.error('Error processing memo request:', error)
  return res.status(500).json({ success: false, error: 'Failed to process memo request' })
}

router.post('/', requireAuth, async (req, res) => {
  try {
    const input = parse(createMemoBody, req.body, res)
    if (!input) return
    res.status(201).json(await createMemo(userId(req), input))
  } catch (error) {
    fail(res, error)
  }
})

router.get('/', requireAuth, async (req, res) => {
  try {
    const query = parse(listMemosQuery, req.query, res)
    if (!query) return
    res.json(await listMemos(userId(req), query))
  } catch (error) {
    fail(res, error)
  }
})

router.patch('/:id/complete', requireAuth, async (req, res) => {
  try {
    if (!parse(emptyBody, req.body, res)) return
    res.json({ memo: await completeMemo(userId(req), req.params.id) })
  } catch (error) {
    fail(res, error)
  }
})

router.post('/:id/upload', requireAuth, async (req, res) => {
  try {
    if (!parse(emptyBody, req.body, res)) return
    res.json({ upload: await remintUpload(userId(req), req.params.id) })
  } catch (error) {
    fail(res, error)
  }
})

router.get('/:id', requireAuth, async (req, res) => {
  try {
    res.json({ memo: await getMemo(userId(req), req.params.id) })
  } catch (error) {
    fail(res, error)
  }
})

router.patch('/:id', requireAuth, async (req, res) => {
  try {
    const input = parse(renameMemoBody, req.body, res)
    if (!input) return
    res.json({ memo: await renameMemo(userId(req), req.params.id, input.title) })
  } catch (error) {
    fail(res, error)
  }
})

router.delete('/:id', requireAuth, async (req, res) => {
  try {
    await softDeleteMemo(userId(req), req.params.id)
    res.status(204).end()
  } catch (error) {
    fail(res, error)
  }
})

export default router
