/** F1: the per-request sessionizer over the fixture org's 730-day window (home-dashboard-data D8). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('loadSessions against the fixture world (F1)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('loads 730 days for the fixture org in under 2 s, only fixture members', async () => {
    const { loadSessions } = await import('../../src/services/home-sessions.js')
    const to = new Date()
    const from = new Date(to.getTime() - 730 * 86_400_000)
    const started = Date.now()
    const sessions = await loadSessions({ all: false, orgIds: [FIXTURE_ORG_ID], groupIds: [] }, { from, to })
    const elapsed = Date.now() - started
    console.log(`F1: loadSessions(730 d, fixture org) → ${sessions.length} sessions in ${elapsed} ms`)
    expect(sessions.length).toBeGreaterThan(0)
    expect(elapsed).toBeLessThan(2_000)
    for (const s of sessions) expect(FIXTURE_MEMBER_IDS).toContain(s.memberId)
  }, 60_000)
})
