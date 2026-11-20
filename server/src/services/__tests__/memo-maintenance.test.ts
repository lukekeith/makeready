import { randomUUID } from 'node:crypto'
import pg from 'pg'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const deleteFromR2 = vi.hoisted(() => vi.fn(async (_key: string) => {}))
vi.mock('../storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../storage.js')>()),
  deleteFromR2,
}))

const { prisma } = await import('../../lib/prisma.js')
const { expireStalePendingUploads, purgeDeletedMemos } = await import('../memos.service.js')
const { runMemoMaintenance } = await import('../../jobs/memo-maintenance.js')

const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000)
const daysAgo = (d: number) => hoursAgo(d * 24)

describe('memo maintenance', () => {
  const stamp = Date.now()
  let userId: string

  const seed = (owner: string, patch: Record<string, unknown>) => {
    const id = randomUUID()
    return prisma.voiceMemo.create({
      data: {
        id, userId: owner, key: `memos/${owner}/${id}.m4a`, title: 'Memo', fileSize: 10, durationMs: 1000,
        uploadStatus: 'ready', recordedAt: new Date('2026-11-10'), ...patch,
      },
    })
  }

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-mmaint-${stamp}`, email: `mmaint-${stamp}@cl.test`, name: 'Maint' } })).id
  })

  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { userId } })
    await prisma.voiceMemo.deleteMany({ where: { userId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  beforeEach(async () => {
    await prisma.studyNote.deleteMany({ where: { userId } })
    await prisma.voiceMemo.deleteMany({ where: { userId } })
    deleteFromR2.mockClear()
  })

  it('expires pending uploads older than 24 h with their objects', async () => {
    const old = await seed(userId, { uploadStatus: 'pending', createdAt: hoursAgo(25) }); const young = await seed(userId, { uploadStatus: 'pending', createdAt: hoursAgo(23) })
    expect(await expireStalePendingUploads(new Date())).toBe(1)
    expect(deleteFromR2).toHaveBeenCalledWith(old.key)
    expect(await prisma.voiceMemo.findUnique({ where: { id: old.id } })).toBeNull()
    expect(await prisma.voiceMemo.findUnique({ where: { id: young.id } })).not.toBeNull()
  })

  it('purges memos deleted over 30 days ago with their note links', async () => {
    const gone = await seed(userId, { isActive: false, deletedAt: daysAgo(31) }); const kept = await seed(userId, { isActive: false, deletedAt: daysAgo(29) })
    const note = await prisma.studyNote.create({ data: { userId, type: 'JOURNAL', content: 'n', links: { create: [{ refType: 'MEMO', refId: gone.id }] } } })
    expect(await purgeDeletedMemos(new Date())).toBe(1)
    expect(await prisma.voiceMemo.findUnique({ where: { id: gone.id } })).toBeNull()
    expect(await prisma.noteLink.count({ where: { noteId: note.id } })).toBe(0)
    expect(await prisma.voiceMemo.findUnique({ where: { id: kept.id } })).not.toBeNull()
    expect(deleteFromR2).toHaveBeenCalledWith(gone.key)
  })

  it('retries only eligible transcripts, and nothing without a key', async () => {
    const due = await seed(userId, { transcriptStatus: 'failed', transcriptAttempts: 2 })
    await seed(userId, { transcriptStatus: 'failed', transcriptAttempts: 3 }); await seed(userId, { transcriptStatus: 'ready' })
    await seed(userId, { transcriptStatus: 'pending', uploadStatus: 'pending' })
    const transcribe = vi.fn(async (_id: string) => 'ready')
    await runMemoMaintenance({ transcribe, env: { ...process.env, GROQ_API_KEY: '' } })
    expect(transcribe).not.toHaveBeenCalled()
    await runMemoMaintenance({ transcribe, env: { ...process.env, GROQ_API_KEY: 'k' } })
    expect(transcribe.mock.calls.map((c) => c[0])).toContain(due.id)
    expect(transcribe.mock.calls.map((c) => c[0])).toHaveLength(1)
  })

  it('a failing step does not stop the next', async () => {
    const gone = await seed(userId, { isActive: false, deletedAt: daysAgo(31) })
    const transcribe = vi.fn(async () => { throw new Error('boom') })
    await seed(userId, { transcriptStatus: 'pending' })
    const out = await runMemoMaintenance({ transcribe, env: { ...process.env, GROQ_API_KEY: 'k' } })
    expect(out).toMatchObject({ purged: 1 })
    expect(await prisma.voiceMemo.findUnique({ where: { id: gone.id } })).toBeNull()
  })

  it('a pass is skipped while another holds the lock', async () => {
    const holder = new pg.Client({ connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL }); await holder.connect()
    await holder.query('SELECT pg_advisory_lock($1)', [727201002])
    try { expect(await runMemoMaintenance({ transcribe: vi.fn() })).toEqual({ skippedLockHeld: true }) }
    finally { await holder.query('SELECT pg_advisory_unlock($1)', [727201002]); await holder.end() }
  })
})
