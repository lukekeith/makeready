/**
 * groups-enroll-program layer (ui2-enrollment-create D12) against a throwaway database: the picker's
 * visible/hidden split and the completed count. Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_EMPTY_GROUP_ID, FIXTURE_ORG_ID } from '../ids.js'
import { ENROLL_EMPTY_PROGRAM_ID, ENROLL_PROGRAM_ID } from '../screens/groups-enroll-program.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('groups-enroll-program full scenario against the test database', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('adds a published 12-lesson program with exactly one ended enrollment', async () => {
    const p = await db.prisma.studyProgram.findUniqueOrThrow({ where: { id: ENROLL_PROGRAM_ID }, include: { lessons: true } })
    expect(p).toMatchObject({ isPublished: true, days: 12, organizationId: FIXTURE_ORG_ID })
    expect(p.lessons).toHaveLength(12)
    const ended = await db.prisma.enrollment.count({ where: { studyProgramId: ENROLL_PROGRAM_ID, endDate: { lt: new Date() } } })
    expect(ended).toBe(1)
  })

  it('adds a published 0-day program the picker hides', async () => {
    const p = await db.prisma.studyProgram.findUniqueOrThrow({ where: { id: ENROLL_EMPTY_PROGRAM_ID }, include: { lessons: true } })
    expect(p.isPublished).toBe(true)
    expect(p.days).toBe(0)
    expect(p.lessons).toHaveLength(0)
  })

  it('keeps the 0-member base group (the picker hides it)', async () => {
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID, isActive: true } })).toBe(0)
  })
})
