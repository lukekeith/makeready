/** notes Task 2: title/preview are written by createNote/updateNote for leader and member notes (D11). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createNote, updateNote, NOTE_TYPES } from '../src/services/notes.service.js'
import { createContentWorld, destroyContentWorld, type ContentWorld } from './helpers/content-world.js'

describe('note title and preview on write', () => {
  let w: ContentWorld
  let memberId: string
  const noteIds: string[] = []
  beforeAll(async () => {
    w = await createContentWorld()
    memberId = (await prisma.member.create({ data: { phoneNumber: `+1558${Math.floor(1e7 + Math.random() * 9e7)}` } })).id
  })
  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { OR: [{ id: { in: noteIds } }, { memberId }] } })
    await prisma.member.delete({ where: { id: memberId } })
    await destroyContentWorld(w)
  })

  it('the leader POST stores title and preview', async () => {
    const r = await request(app).post('/api/notes').set('Authorization', bearer(w.leader.token)).send({ type: NOTE_TYPES.NOTE, content: '# Walk\nPsalm 23 thoughts' })
    expect(r.status).toBe(201)
    noteIds.push(r.body.data.id)
    expect(r.body.data).toMatchObject({ type: 'NOTE', title: 'Walk', preview: 'Psalm 23 thoughts' })
  })

  it('member notes get title and preview on create and update', async () => {
    const c = await createNote({ memberId, type: 'JOURNAL', content: 'First\nSecond' })
    expect(c.data).toMatchObject({ title: 'First', preview: 'Second' })
    const u = await updateNote(c.data!.id, 'New top\n\nNew next')
    expect(u.data).toMatchObject({ title: 'New top', preview: 'New next' })
  })
})
