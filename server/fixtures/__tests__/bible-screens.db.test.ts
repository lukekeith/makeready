/**
 * The bible-books and bible-reader layers against a throwaway database (bible-verse-picker Task 4).
 * Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { parseActivityDocument } from '../../src/services/activity-document.js'
import { FIXTURE_USER_ID, FIXTURE_IDS as ids } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('bible screens (bible-verse-picker Task 4)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('the full scenario seeds bible recents and a valid D10 activity', async () => {
    await db.run('reset', 'full')
    expect(await db.prisma.searchHistory.count({ where: { userId: FIXTURE_USER_ID, searchType: 'bible' } })).toBe(6)
    const acts = await db.prisma.contentActivity.findMany({ where: { lessonVersionId: ids.bibleReader.lessonVersionId, kind: 'bible' } })
    const d10 = acts.find((a) => (a.document as any).content.passages?.[0]?.startOffset !== undefined)!
    expect(parseActivityDocument(d10.document, 'bible')).toMatchObject({ ok: true })
    expect((d10.document as any).content.objects.find((o: any) => o.role === 'citation').text).toBe('John 3:16b-18 ENGKJV')
  }, 180_000)
})
