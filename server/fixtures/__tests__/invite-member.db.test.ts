/**
 * invite-member layer against a throwaway database: the reset leaves the group-invite template and
 * one named invite. Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_GROUP_IDS } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('invite-member full scenario against the test database', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('has the group-invite template and one named invite', async () => {
    const template = await db.prisma.smsTemplate.findUnique({ where: { slug: 'group-invite-v1' } })
    expect(template?.minIntervalMinutes).toBe(1200)
    const invites = await db.prisma.invite.findMany({ where: { recipientName: 'Tony Stark' } })
    expect(invites).toHaveLength(1)
    expect(invites[0].groupId).toBe(FIXTURE_GROUP_IDS[0])
  })
})
