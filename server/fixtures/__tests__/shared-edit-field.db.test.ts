/**
 * ui2-members-edit T5 against a throwaway database: `fixtures:reset -- sparse` leaves exactly one
 * Prayer Team member with the five optional fields null, and the Group-Leader user can still open
 * that member. Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS } from '../ids.js'
import { SPARSE_MEMBER_INDEX } from '../screens/shared-edit-field.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const leader = { kind: 'user' as const, userId: FIXTURE_LEADER_USER_ID }
const sparseId = FIXTURE_MEMBER_IDS[SPARSE_MEMBER_INDEX]

describe.skipIf(!TEST_DB_URL)('shared-edit-field sparse scenario against the test database (ui2-members-edit T5)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'sparse')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('nulls gender, birthday, address and both emergency fields on the one sparse member', async () => {
    const m = await db.prisma.member.findUniqueOrThrow({ where: { id: sparseId } })
    expect(m).toMatchObject({ gender: null, birthday: null, address: null, emergencyContactName: null, emergencyContactPhone: null })
    expect(m.email).toMatch(/@example\.org$/)
    expect(m.phoneNumber).toMatch(/^\+1555010\d{4}$/)
  })

  it('leaves the other 23 members populated', async () => {
    const rest = await db.prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS.filter((id) => id !== sparseId) } } })
    expect(rest).toHaveLength(23)
    for (const m of rest) {
      expect(m.gender).not.toBeNull()
      expect(m.birthday).not.toBeNull()
      expect(m.address).not.toBeNull()
      expect(m.emergencyContactName).not.toBeNull()
      expect(m.emergencyContactPhone).not.toBeNull()
    }
  })

  it('keeps the Prayer Team, so the Group-Leader user opens the sparse member', async () => {
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_LEADER_GROUP_ID, isActive: true } })).toBe(3)
    const { getScopedMember } = await import('../../src/services/member.js')
    const res = await getScopedMember(sparseId, leader)
    expect(res.success).toBe(true)
    expect(res.data?.gender).toBeNull()
    expect(res.data?.birthday).toBeNull()
  })
})
