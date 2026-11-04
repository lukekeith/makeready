/**
 * master-search D25 against a throwaway database: after a reset, the shared word returns mixed
 * types with the exact title first and the recents hydrate. Gated on FIXTURES_TEST_DATABASE_URL.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_USER_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('search-home fixture', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('after reset, grace returns mixed types, exact title first, and recents hydrate', async () => {
    const { searchRanked, listRecentResults } = await import('../../src/services/master-search.js')
    const { parseRankedParams } = await import('../../src/services/master-search-query.js')
    const { items } = await searchRanked(FIXTURE_USER_ID, parseRankedParams({ q: 'grace', limit: '50' }))
    expect(items[0].title).toBe('Grace')
    expect(new Set(items.map((i: any) => i.type)).size).toBeGreaterThanOrEqual(8)
    expect((await listRecentResults(FIXTURE_USER_ID, {})).map((i: any) => i.type)).toEqual(['PROGRAM', 'LESSON', 'GROUP', 'PHOTO', 'POST', 'MEMBER'])
  }, 180_000)

  it('a second reset succeeds with the same ids', async () => {
    const ids = async () => (await db.prisma.searchRecentResult.findMany({ where: { userId: FIXTURE_USER_ID }, orderBy: { id: 'asc' }, select: { id: true } })).map((r) => r.id)
    const first = await ids()
    await db.run('reset', 'full')
    expect(await ids()).toEqual(first)
  }, 180_000)
})
