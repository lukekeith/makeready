/** notes Task 6: idempotent title/preview backfill (D11, F6). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { prisma } from '../src/lib/prisma.js'
import { backfillNoteTitles } from '../src/scripts/backfill-note-titles.js'
import { createContentWorld, destroyContentWorld, type ContentWorld } from './helpers/content-world.js'

describe('backfillNoteTitles', () => {
  let w: ContentWorld
  const user = { get id() { return w.leader.userId } }
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { userId: w.leader.userId } })
    await destroyContentWorld(w)
  })

  it('fills title/preview, keeps updatedAt, and a second run updates nothing', async () => {
    const n = await prisma.studyNote.create({ data: { userId: user.id, type: 'NOTE', content: '# Old title\nold preview' } })
    await prisma.$executeRaw`UPDATE study_notes SET title = NULL, preview = NULL, "updatedAt" = '2025-01-02T03:04:05.678Z' WHERE id = ${n.id}::uuid`
    const first = await backfillNoteTitles({ batchSize: 2 })
    expect(first.updated).toBeGreaterThanOrEqual(1)
    const row = await prisma.studyNote.findUniqueOrThrow({ where: { id: n.id } })
    expect(row).toMatchObject({ title: 'Old title', preview: 'old preview' })
    expect(row.updatedAt.toISOString()).toBe('2025-01-02T03:04:05.678Z')
    expect((await backfillNoteTitles({ batchSize: 2 })).updated).toBe(0)
  })

  it('a dry run writes nothing', async () => {
    const n = await prisma.studyNote.create({ data: { userId: user.id, type: 'NOTE', content: 'Dry\nrun' } })
    await prisma.$executeRaw`UPDATE study_notes SET title = NULL WHERE id = ${n.id}::uuid`
    const r = await backfillNoteTitles({ dryRun: true })
    expect(r.updated).toBeGreaterThanOrEqual(1)
    expect((await prisma.studyNote.findUniqueOrThrow({ where: { id: n.id } })).title).toBeNull()
  })
})
