/**
 * library-home and video-detail video rows against a throwaway database: after a reset the leader has the 4
 * Library videos (one in a lesson) and the detail video. Gated on FIXTURES_TEST_DATABASE_URL.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('video fixtures', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('after reset full the leader has the 4 Library videos and the detail video', async () => {
    const videos = await db.prisma.video.findMany({ where: { userId: FIXTURE_USER_ID, id: { in: [2001, 2002, 2003, 2004, 2101].map((n) => fixtureId('video', n)) } }, orderBy: { id: 'asc' } })
    expect(videos.map((v) => [v.status, v.transcriptStatus])).toEqual([['ready', 'ready'], ['pending', 'pending'], ['ready', 'failed'], ['ready', 'ready'], ['ready', 'ready']])
    expect((videos[4].transcriptSegments as unknown[]).length).toBeGreaterThan(1)
    const usage = await db.prisma.mediaUsage.findMany({ where: { media: { videoId: fixtureId('video', 2004) } } })
    expect(usage.map((u) => u.usageType)).toEqual(['ACTIVITY'])
  }, 180_000)

  it('a second reset succeeds with the same video ids', async () => {
    const ids = async () => (await db.prisma.video.findMany({ where: { userId: FIXTURE_USER_ID }, orderBy: { id: 'asc' }, select: { id: true } })).map((r) => r.id)
    const first = await ids()
    await db.run('reset', 'full')
    expect(await ids()).toEqual(first)
  }, 180_000)
})
