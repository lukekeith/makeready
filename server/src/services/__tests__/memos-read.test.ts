import { randomUUID } from 'node:crypto'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const presignGet = vi.hoisted(() => vi.fn(async (key: string) => `https://r2.test/get/${key}`))
const deleteFromR2 = vi.hoisted(() => vi.fn(async (_key: string) => {}))
vi.mock('../storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../storage.js')>()),
  presignGet,
  deleteFromR2,
}))

const { prisma } = await import('../../lib/prisma.js')
const { listMemos, getMemo, softDeleteMemo, purgeUserMemoObjects } = await import('../memos.service.js')

describe('memos.service reads', () => {
  const stamp = Date.now()
  let userId: string
  let otherUserId: string

  const seed = (owner: string, patch: Record<string, unknown>) => {
    const id = randomUUID()
    return prisma.voiceMemo.create({
      data: {
        id, userId: owner, key: `memos/${owner}/${id}.m4a`, title: 'Memo', fileSize: 10, durationMs: 1000,
        uploadStatus: 'ready', recordedAt: new Date('2026-11-10'), ...patch,
      },
    })
  }
  const ids = async (q?: string) => (await listMemos(userId, { q, limit: 50, offset: 0 })).memos.map((m) => m.id)

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-mread-a-${stamp}`, email: `mread-a-${stamp}@cl.test`, name: 'Read A' } })).id
    otherUserId = (await prisma.user.create({ data: { googleId: `gid-mread-b-${stamp}`, email: `mread-b-${stamp}@cl.test`, name: 'Read B' } })).id
  })

  afterAll(async () => {
    await prisma.voiceMemo.deleteMany({ where: { userId: { in: [userId, otherUserId] } } })
    await prisma.user.deleteMany({ where: { id: { in: [userId, otherUserId] } } })
  })

  beforeEach(async () => {
    await prisma.voiceMemo.deleteMany({ where: { userId: { in: [userId, otherUserId] } } })
    presignGet.mockClear()
    deleteFromR2.mockClear()
  })

  it("list shows only the owner's ready, active memos, newest first", async () => {
    const a = await seed(userId, { recordedAt: new Date('2026-11-01') }); const b = await seed(userId, { recordedAt: new Date('2026-11-02') })
    await seed(userId, { uploadStatus: 'pending' }); await seed(userId, { isActive: false }); await seed(otherUserId, {})
    const { memos, total } = await listMemos(userId, { limit: 50, offset: 0 })
    expect(memos.map((m) => m.id)).toEqual([b.id, a.id]); expect(total).toBe(2)
    await prisma.voiceMemo.update({ where: { id: b.id }, data: { transcript: 'x'.repeat(400), waveformPeaks: [0.1] } })
    const [s] = (await listMemos(userId, { limit: 50, offset: 0 })).memos
    expect(s.transcriptPreview).toHaveLength(280)  // D24: no heavy fields
    for (const k of ['transcript', 'transcriptSegments', 'waveformPeaks', 'url', 'urlExpiresAt']) expect(s).not.toHaveProperty(k)
  })

  it('q matches title or transcript, case-insensitively', async () => {
    const t = await seed(userId, { title: 'Sermon Ideas' }); const r = await seed(userId, { transcript: 'about GRACE today' })
    await seed(userId, { title: 'other' })
    expect(await ids('sermon')).toEqual([t.id])
    expect(await ids('grace')).toEqual([r.id])
  })

  it('q treats % and _ literally', async () => {
    const pct = await seed(userId, { title: '100% sure' }); await seed(userId, { title: 'plain' })
    const und = await seed(userId, { title: 'a_b' }); await seed(userId, { title: 'axb' })
    expect(await ids('%')).toEqual([pct.id])
    expect(await ids('_')).toEqual([und.id])
  })

  it('detail carries a 60-min presigned GET', async () => {
    const m = await seed(userId, {}); presignGet.mockResolvedValueOnce('https://signed.test/get')
    const memo = await getMemo(userId, m.id)
    expect(presignGet).toHaveBeenCalledWith(m.key, 3600)
    expect(memo.url).toBe('https://signed.test/get')
    await softDeleteMemo(userId, m.id)
    expect((await prisma.voiceMemo.findUnique({ where: { id: m.id } }))!.deletedAt).toBeInstanceOf(Date)
    expect(Date.parse(memo.urlExpiresAt!) - Date.now()).toBeGreaterThan(3_590_000)
    await expect(getMemo(otherUserId, m.id)).rejects.toMatchObject({ status: 404 })
  })

  it('purgeUserMemoObjects deletes every key and survives one failure', async () => {
    const a = await seed(userId, {}); const b = await seed(userId, { isActive: false })
    deleteFromR2.mockRejectedValueOnce(new Error('r2 down'))
    expect(await purgeUserMemoObjects(userId)).toBe(1)
    expect(deleteFromR2.mock.calls.map((c) => c[0]).sort()).toEqual([a.key, b.key].sort())
  })
})
