import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate } from '../context.js'
import { countFixtureRows } from '../counts.js'
import {
  FIXTURE_ENROLLMENT_IDS,
  FIXTURE_GROUP_IDS,
  FIXTURE_MEMBER_IDS,
  FIXTURE_ORG_ID,
  FIXTURE_USER_EMAIL,
  FIXTURE_USER_ID,
} from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb, subtractCounts } from './db-harness.js'

// A non-fixture graph the reset must never touch (§Testing c).
const SENTINEL = {
  user: '0b0b0b0b-0000-4000-8000-000000000001',
  org: '0b0b0b0b-0000-4000-8000-000000000002',
  group: '0b0b0b0b-0000-4000-8000-000000000003',
  member: '0b0b0b0b-0000-4000-8000-000000000004',
  groupMember: '0b0b0b0b-0000-4000-8000-000000000005',
  event: '0b0b0b0b-0000-4000-8000-000000000006',
}

describe.skipIf(!TEST_DB_URL)('fixtures base layer against the test database (D18)', () => {
  let db: FixturesDb

  async function removeSentinel() {
    await db.prisma.clientEvent.deleteMany({ where: { id: SENTINEL.event } })
    await db.prisma.member.deleteMany({ where: { id: SENTINEL.member } })
    await db.prisma.user.deleteMany({ where: { id: SENTINEL.user } })
  }

  beforeAll(async () => {
    db = await openFixturesDb()
    await removeSentinel()
    await db.prisma.user.create({ data: { id: SENTINEL.user, email: 'sentinel@fixtures-test.local', name: 'Sentinel' } })
    await db.prisma.organization.create({ data: { id: SENTINEL.org, name: 'Sentinel Org', ownerId: SENTINEL.user } })
    await db.prisma.group.create({
      data: { id: SENTINEL.group, name: 'Sentinel Group', creatorId: SENTINEL.user, organizationId: SENTINEL.org },
    })
    await db.prisma.member.create({ data: { id: SENTINEL.member, phoneNumber: '+15559990001' } })
    await db.prisma.groupMember.create({
      data: { id: SENTINEL.groupMember, groupId: SENTINEL.group, memberId: SENTINEL.member },
    })
    await db.prisma.clientEvent.create({
      data: {
        id: SENTINEL.event,
        eventType: 'LESSON_OPENED',
        occurredAt: new Date(),
        memberId: SENTINEL.member,
        organizationId: SENTINEL.org,
      },
    })
  }, 60_000)

  afterAll(async () => {
    if (!db) return
    await removeSentinel()
    await db.close()
  })

  it('(e) reset empty builds exactly the base world and no progress rows', async () => {
    const counts = await db.run('reset', 'empty')
    expect(counts).toEqual({
      users: 1,
      organizations: 1,
      user_roles: 1,
      groups: 3,
      members: 24,
      group_members: 24,
      member_organizations: 24,
      study_programs: 2,
      lessons: 51,
      lesson_activities: 153,
      enrollments: 4,
      lesson_schedules: 102,
      member_lesson_progress: 0,
      member_video_progress: 0,
      membership_events: 0,
      client_events: 0,
    })
  }, 120_000)

  it('builds the D3/D11/D12 identity, groups, members and programs', async () => {
    await db.run('reset', 'empty')
    const user = await db.prisma.user.findUniqueOrThrow({ where: { id: FIXTURE_USER_ID } })
    expect(user).toMatchObject({ email: FIXTURE_USER_EMAIL, name: 'Fixture Leader', googleId: null })
    const org = await db.prisma.organization.findUniqueOrThrow({ where: { id: FIXTURE_ORG_ID } })
    expect(org).toMatchObject({ name: 'MakeReady Fixtures', ownerId: FIXTURE_USER_ID })

    const role = await db.prisma.userRole.findFirstOrThrow({ where: { userId: FIXTURE_USER_ID }, include: { role: true } })
    expect(role.organizationId).toBe(FIXTURE_ORG_ID)
    expect(role.role).toMatchObject({ name: 'Owner', isSystem: true, organizationId: null })

    const groups = await db.prisma.group.findMany({ where: { id: { in: FIXTURE_GROUP_IDS } }, orderBy: { id: 'asc' } })
    expect(groups.map((g) => g.name)).toEqual(["Tuesday Men's Group", 'Young Adults', "Women's Bible Study"])

    const members = await db.prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS } } })
    for (const m of members) {
      expect(m.phoneNumber).toMatch(/^\+1555010\d{4}$/)
      expect(m.phoneVerified).toBe(true)
    }
    for (const groupId of FIXTURE_GROUP_IDS) {
      expect(await db.prisma.groupMember.count({ where: { groupId } })).toBe(8)
    }

    const programs = await db.prisma.studyProgram.findMany({ where: { organizationId: FIXTURE_ORG_ID }, orderBy: { days: 'asc' } })
    expect(programs.map((p) => p.days)).toEqual([21, 30])
    for (const p of programs) {
      expect(p.isPublished).toBe(true)
      expect(p.publishedAt).not.toBeNull()
      expect(p.creatorId).toBe(FIXTURE_USER_ID)
    }
    const videoActivities = await db.prisma.lessonActivity.count({
      where: { activityType: 'VIDEO', lesson: { studyProgram: { organizationId: FIXTURE_ORG_ID } } },
    })
    expect(videoActivities).toBe(51)
  }, 120_000)

  it('staggers E1–E4 over now−48 … now+7 (D11), every day enabled, America/Chicago', async () => {
    await db.run('reset', 'empty')
    const today = localDate(new Date())
    const windows: Array<[number, number]> = [[-48, -19], [-29, 0], [-20, 0], [-13, 7]]
    const enrollments = await db.prisma.enrollment.findMany({ where: { id: { in: FIXTURE_ENROLLMENT_IDS } }, orderBy: { id: 'asc' } })
    expect(enrollments).toHaveLength(4)
    for (const [i, enrollment] of enrollments.entries()) {
      expect(JSON.parse(enrollment.enabledDays)).toEqual(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
      expect(enrollment.timezone).toBe('America/Chicago')
      expect(enrollment.createdById).toBe(FIXTURE_USER_ID)
      const schedules = await db.prisma.lessonSchedule.findMany({ where: { enrollmentId: enrollment.id } })
      const dates = schedules.map((s) => localDate(s.scheduledDate)).sort()
      expect(dates[0]).toBe(addDays(today, windows[i][0]))
      expect(dates[dates.length - 1]).toBe(addDays(today, windows[i][1]))
      expect(new Set(dates).size).toBe(dates.length)
    }
    const covered = new Set(
      (await db.prisma.lessonSchedule.findMany({ where: { enrollmentId: { in: FIXTURE_ENROLLMENT_IDS } } })).map((s) =>
        localDate(s.scheduledDate)
      )
    )
    for (let offset = -48; offset <= 7; offset++) expect(covered.has(addDays(today, offset))).toBe(true)
  }, 120_000)

  it('(c) leaves every non-fixture row untouched', async () => {
    const before = subtractCounts(await db.countAll(), await countFixtureRows(db.prisma))
    await db.run('reset', 'full')
    await db.run('reset', 'full')
    const after = subtractCounts(await db.countAll(), await countFixtureRows(db.prisma))
    expect(after).toEqual(before)
    expect(await db.prisma.clientEvent.count({ where: { id: SENTINEL.event } })).toBe(1)
    expect(await db.prisma.groupMember.count({ where: { id: SENTINEL.groupMember } })).toBe(1)
    expect(await db.prisma.organization.count({ where: { id: SENTINEL.org } })).toBe(1)
  }, 180_000)

  it('(D4) seed refuses when the fixture user already exists', async () => {
    await db.run('reset', 'empty')
    await expect(db.run('seed', 'empty')).rejects.toThrow('already exists')
  }, 120_000)
})
