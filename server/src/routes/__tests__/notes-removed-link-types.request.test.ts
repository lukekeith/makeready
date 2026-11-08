/**
 * text-activity Task 14 (D42): a note can no longer link a lesson activity, scheduled activity or lesson schedule.
 * The refusals sit before any database call, so prisma is an empty mock: reaching it would throw.
 */
import express from 'express'
import request from 'supertest'
import { describe, expect, it, vi } from 'vitest'

vi.mock('../../lib/prisma.js', () => ({ prisma: {}, Prisma: {} }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  requireMemberAuth: (req: express.Request, _res: express.Response, next: () => void) => {
    Object.assign(req, { member: { id: 'member-1' } })
    next()
  },
}))

import { addNoteLink } from '../../services/notes.service.js'
import notesRoutes from '../notes.js'

const app = express()
app.use(express.json())
app.use('/api', notesRoutes)

describe('removed note link types', () => {
  it.each(['LESSON_ACTIVITY', 'SCHEDULED_ACTIVITY', 'LESSON_SCHEDULE'])('addNoteLink refuses %s with VALIDATION', async (refType) => {
    const result = await addNoteLink('note-1', { refType, refId: 'ref-1' } as never)
    expect(result).toEqual({ success: false, code: 'VALIDATION', error: `Link type ${refType} is no longer supported` })
  })

  it.each(['LESSON_ACTIVITY', 'SCHEDULED_ACTIVITY', 'LESSON_SCHEDULE'])('the entity read answers 400 for %s', async (refType) => {
    const res = await request(app).get(`/api/member/notes/entity/${refType}/ref-1`)
    expect(res.status).toBe(400)
    expect(res.body).toMatchObject({ success: false, error: `Link type ${refType} is no longer supported` })
  })
})
