import { randomUUID } from 'node:crypto'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'

const { prisma } = await import('../../lib/prisma.js')
const { LINK_TYPES, createNote, addNoteLink } = await import('../notes.service.js')

describe('notes MEMO link type', () => {
  const stamp = Date.now()
  let userId: string
  let otherUserId: string
  let memberId: string
  let memo: { id: string }
  let otherUsersMemo: { id: string }
  let inactiveMemo: { id: string }

  const seed = (owner: string, patch: Record<string, unknown> = {}) => {
    const id = randomUUID()
    return prisma.voiceMemo.create({
      data: { id, userId: owner, key: `memos/${owner}/${id}.m4a`, title: 'Memo', uploadStatus: 'ready', recordedAt: new Date('2026-11-10'), ...patch },
    })
  }

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-nml-a-${stamp}`, email: `nml-a-${stamp}@cl.test`, name: 'Link A' } })).id
    otherUserId = (await prisma.user.create({ data: { googleId: `gid-nml-b-${stamp}`, email: `nml-b-${stamp}@cl.test`, name: 'Link B' } })).id
    memberId = randomUUID()
    memo = await seed(userId)
    otherUsersMemo = await seed(otherUserId)
    inactiveMemo = await seed(userId, { isActive: false })
  })

  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { userId: { in: [userId, otherUserId] } } })
    await prisma.voiceMemo.deleteMany({ where: { userId: { in: [userId, otherUserId] } } })
    await prisma.user.deleteMany({ where: { id: { in: [userId, otherUserId] } } })
  })

  it('LINK_TYPES gains MEMO', () => { expect(LINK_TYPES.MEMO).toBe('MEMO') })

  it("a note may link its owner's active memo", async () => {
    const r = await createNote({ userId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: memo.id }] })
    expect(r.success).toBe(true)
  })

  it("addNoteLink accepts the owner's active memo", async () => {
    const note = await createNote({ userId, type: 'JOURNAL', content: 'c' })
    const r = await addNoteLink(note.data!.id, { refType: 'MEMO', refId: memo.id })
    expect(r.success).toBe(true)
  })

  const refusal = { success: false, code: 'VALIDATION', error: 'Memo link must reference one of your memos' }
  it('foreign, inactive or member-owned memo links are refused', async () => {
    expect(await createNote({ userId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: otherUsersMemo.id }] })).toEqual(refusal)
    expect(await createNote({ userId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: inactiveMemo.id }] })).toEqual(refusal)
    expect(await createNote({ memberId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: memo.id }] })).toEqual(refusal)
    const note = await createNote({ userId: otherUserId, type: 'JOURNAL', content: 'c' })
    expect(await addNoteLink(note.data!.id, { refType: 'MEMO', refId: memo.id })).toEqual(refusal)
  })
})
