/**
 * ui2-members-browse D13/T7 against a throwaway database: the Members list and
 * the member page read live, non-empty data for the Fixtures owner, and the
 * Group-Leader fixture user sees only its group's members. Gated on
 * FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate } from '../context.js'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { JOINED_OFFSETS, MULTI_GROUP_MEMBER_INDICES } from '../screens/members-home.js'
import { LEADER_MEMBER_INDEX } from '../screens/members-profile.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const owner = { kind: 'user' as const, userId: FIXTURE_USER_ID }
const leader = { kind: 'user' as const, userId: FIXTURE_LEADER_USER_ID }
const idOf = (i: number) => FIXTURE_MEMBER_IDS[i]

describe.skipIf(!TEST_DB_URL)('members layers against the test database (ui2-members-browse D13, T7)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('fills the D13 fields on all 24 members', async () => {
    const members = await db.prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS } } })
    expect(members).toHaveLength(24)
    for (const m of members) {
      expect(m.email).toMatch(/^[a-z]+\.[a-z]+@example\.org$/)
      expect(m.birthday).not.toBeNull()
      expect(['male', 'female']).toContain(m.gender)
      expect(m.address).toContain('\n')
      expect(m.emergencyContactName).toBeTruthy()
      expect(m.emergencyContactPhone).toMatch(/^\+1555020\d{4}$/)
    }
  })

  it('makes the Group-Leader user a system Group Leader of the org with exactly one group', async () => {
    const role = await db.prisma.userRole.findFirstOrThrow({ where: { userId: FIXTURE_LEADER_USER_ID }, include: { role: true } })
    expect(role).toMatchObject({ organizationId: FIXTURE_ORG_ID, role: { name: 'Group Leader', isSystem: true, organizationId: null } })
    expect(await db.prisma.group.findMany({ where: { creatorId: FIXTURE_LEADER_USER_ID }, select: { id: true } })).toEqual([
      { id: FIXTURE_LEADER_GROUP_ID },
    ])
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_LEADER_GROUP_ID, isActive: true } })).toBe(3)
  })

  it('lists 24 for the owner, newest join first, groupCount 2 for the three multi-group members', async () => {
    const { getOrganizationMembers } = await import('../../src/services/organization.js')
    const list = await getOrganizationMembers(FIXTURE_ORG_ID, FIXTURE_USER_ID)
    expect(list.viewerScope).toEqual({ all: true, groupIds: [] })
    expect(list.data).toHaveLength(24)
    expect(list.data!.slice(0, JOINED_OFFSETS.length).map((m) => m.id)).toEqual(JOINED_OFFSETS.map(([i]) => idOf(i)))
    const counts = new Map(list.data!.map((m) => [m.id, m.groupCount]))
    for (const i of MULTI_GROUP_MEMBER_INDICES) expect(counts.get(idOf(i))).toBe(2)
    expect([...counts.values()].filter((c) => c === 1)).toHaveLength(21)
  })

  it('lists only the Prayer Team for the Group-Leader user, with its scope (D7, D15)', async () => {
    const { getOrganizationMembers } = await import('../../src/services/organization.js')
    const list = await getOrganizationMembers(FIXTURE_ORG_ID, FIXTURE_LEADER_USER_ID)
    expect(list.viewerScope).toEqual({ all: false, groupIds: [FIXTURE_LEADER_GROUP_ID] })
    expect(list.data!.map((m) => m.id).sort()).toEqual(MULTI_GROUP_MEMBER_INDICES.map(idOf).sort())
  })

  it('AND-combines search tokens', async () => {
    const { getOrganizationMembers } = await import('../../src/services/organization.js')
    const list = await getOrganizationMembers(FIXTURE_ORG_ID, FIXTURE_USER_ID, { search: 'james carter' })
    expect(list.data!.map((m) => m.id)).toEqual([idOf(0)])
  })

  it('reads Role and Organization (D8) and hides members outside the leader’s groups (D7)', async () => {
    const { getScopedMember } = await import('../../src/services/member.js')
    const nathan = await getScopedMember(idOf(LEADER_MEMBER_INDEX), owner)
    expect(nathan.data?.isGroupLeader).toBe(true)
    expect(nathan.data?.organizations.map((o) => o.organization.name)).toEqual(['MakeReady Fixtures'])
    expect((await getScopedMember(idOf(1), owner)).data?.isGroupLeader).toBe(false)
    expect((await getScopedMember(idOf(0), leader)).success).toBe(true)
    expect(await getScopedMember(idOf(1), leader)).toEqual({ success: false, error: 'Member not found' })
  })

  it('fills Engagement with a Complete row and live hours for a caught-up member (D11, D14, D16)', async () => {
    const { getMemberEngagement } = await import('../../src/services/member-engagement.js')
    const asOwner = await getMemberEngagement(idOf(0), owner, TZ)
    expect(asOwner!.programs.length).toBeGreaterThan(0)
    expect(asOwner!.programs.some((p) => p.totalCount > 0 && p.completedCount >= p.totalCount)).toBe(true)
    expect(asOwner!.programs.some((p) => p.hours > 0)).toBe(true)
    for (const p of asOwner!.programs) {
      expect(Number.isInteger(p.hours)).toBe(true)
      expect(p.percent).toBeGreaterThanOrEqual(0)
      expect(p.percent).toBeLessThanOrEqual(100)
    }
    // D16: a Group Leader who can see the member sees every group's enrollments of that member in the org.
    const asLeader = await getMemberEngagement(idOf(0), leader, TZ)
    expect(asLeader!.programs.map((p) => p.enrollmentId).sort()).toEqual(asOwner!.programs.map((p) => p.enrollmentId).sort())
  })

  it('fills the member’s 30-day rail with sessions and lastActivityAt (D12)', async () => {
    const { getHomeDays } = await import('../../src/services/home-dashboard.js')
    const today = localDate(new Date())
    const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }
    const { days } = await getHomeDays(scope, addDays(today, -29), today, TZ, { memberId: idOf(0) })
    expect(days).toHaveLength(30)
    expect(days.some((d) => d.sessionSeconds > 0)).toBe(true)
    for (const d of days) expect(d.lastActivityAt === null).toBe(d.sessionSeconds === 0)
  })

  it('leaves Home’s membership events at 24 (members-home adds memberships, not events)', async () => {
    expect(await db.prisma.membershipEvent.count({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })).toBe(24)
  })
})
