/**
 * memo-screens D19 against a throwaway database: after a reset the leader has the 5 memos, memo 1 with
 * segments, none due for a transcript retry. Gated on FIXTURES_TEST_DATABASE_URL.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_USER_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('memo-detail fixture', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('after reset full the leader has the 5 D19 memos, memo 1 with segments', async () => {
    const memos = await db.prisma.voiceMemo.findMany({ where: { userId: FIXTURE_USER_ID }, orderBy: { recordedAt: 'desc' } })
    expect(memos.map((m) => m.transcriptStatus)).toEqual(['ready', 'pending', 'failed', 'none', 'ready'])
    expect((memos[0].transcriptSegments as unknown[]).length).toBe(3)
    const { memoIdsDueForTranscriptRetry } = await import('../../src/services/memos.service.js')
    expect(await memoIdsDueForTranscriptRetry()).toEqual([])
  }, 180_000)

  it('a second reset succeeds with the same memo ids', async () => {
    const ids = async () => (await db.prisma.voiceMemo.findMany({ where: { userId: FIXTURE_USER_ID }, orderBy: { id: 'asc' }, select: { id: true } })).map((r) => r.id)
    const first = await ids()
    await db.run('reset', 'full')
    expect(await ids()).toEqual(first)
  }, 180_000)
})
