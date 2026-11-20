import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { prisma } from '../src/lib/prisma.js'

describe('VoiceMemo schema (memo SC1)', () => {
  const stamp = Date.now()
  let userId: string

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { email: `memo-schema-${stamp}@cl.test`, name: 'Memo Schema' } })).id
  })

  afterAll(async () => {
    await prisma.voiceMemo.deleteMany({ where: { userId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('a memo row gets the SC1 defaults', async () => {
    const memo = await prisma.voiceMemo.create({ data: { userId, title: 'Memo 1', key: 'memos/u/m.m4a', recordedAt: new Date() } })
    expect(memo).toMatchObject({ mimeType: 'audio/mp4', transcriptStatus: 'none', transcriptSource: null, transcriptAttempts: 0,
      transcriptClaimedAt: null, uploadStatus: 'pending', isActive: true, deletedAt: null, memberId: null })
    expect('url' in memo).toBe(false)
  })

  it('deleting a user deletes their memos by cascade', async () => {
    const other = await prisma.user.create({ data: { email: `memo-cascade-${stamp}@cl.test`, name: 'Memo Cascade' } })
    const memo = await prisma.voiceMemo.create({ data: { userId: other.id, title: 'Gone', key: 'memos/o/m.m4a', recordedAt: new Date() } })
    await prisma.user.delete({ where: { id: other.id } })
    expect(await prisma.voiceMemo.findUnique({ where: { id: memo.id } })).toBeNull()
  })
})
