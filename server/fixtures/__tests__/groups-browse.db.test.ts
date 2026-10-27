/**
 * groups-home / groups-detail layers against a throwaway database (ui2-groups-browse D19, D25):
 * the rich group fills every group-page section, the Empty Group none. Gated on
 * FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { activityThumbnailUrl } from '../../src/services/next-study-thumbnail.js'
import { addDays, localDate } from '../context.js'
import { FIXTURE_EMPTY_GROUP_ID, FIXTURE_ORG_ID } from '../ids.js'
import { NEXT_LESSON_SCHEDULE_IDS, RICH_GROUP_FIELDS, RICH_GROUP_ID } from '../screens/groups-detail.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }

describe.skipIf(!TEST_DB_URL)('groups-browse layers against the test database (D19, D25)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('lists five fixture groups, two leaders (groups-home)', async () => {
    const groups = await db.prisma.group.findMany({ where: { organizationId: FIXTURE_ORG_ID, isActive: true } })
    expect(groups.map((g) => g.name).sort()).toEqual(
      ['Empty Group', 'Prayer Team', "Tuesday Men's Group", "Women's Bible Study", 'Young Adults'].sort()
    )
    expect(new Set(groups.map((g) => g.creatorId)).size).toBe(2)
    // ui2-groups-edit T5: the rich group is Names only; every other group keeps the default.
    expect(groups.filter((g) => g.id !== RICH_GROUP_ID).every((g) => g.memberDirectoryAccess === 'ALLOWED')).toBe(true)
  })

  it('stores the rich group settings and leaves the Empty Group on defaults (ui2-groups-edit T5)', async () => {
    const rich = await db.prisma.group.findUniqueOrThrow({ where: { id: RICH_GROUP_ID } })
    expect(rich).toMatchObject(RICH_GROUP_FIELDS)
    const empty = await db.prisma.group.findUniqueOrThrow({ where: { id: FIXTURE_EMPTY_GROUP_ID } })
    expect(empty).toMatchObject({
      description: null,
      ageRangeMin: null,
      ageRangeMax: null,
      maxMembers: null,
      memberDirectoryAccess: 'ALLOWED',
      memberDirectoryEnabled: true,
    })
  })

  it('leaves the Empty Group with nothing in any section', async () => {
    const { getGroupHistory } = await import('../../src/services/group-history.js')
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID } })).toBe(0)
    expect(await db.prisma.enrollment.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID } })).toBe(0)
    expect(await db.prisma.groupJoinRequest.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID } })).toBe(0)
    expect(await getGroupHistory(FIXTURE_EMPTY_GROUP_ID, 50)).toEqual([])
  })

  it('gives the rich group two pending join requests', async () => {
    const requests = await db.prisma.groupJoinRequest.findMany({
      where: { groupId: RICH_GROUP_ID, status: 'pending' },
      include: { member: { select: { firstName: true, lastName: true } } },
      orderBy: { createdAt: 'desc' },
    })
    expect(requests.map((r) => `${r.member.firstName} ${r.member.lastName}`)).toEqual(['Esther Graham', 'Ruth Hamilton'])
  })

  it('gives the next lessons three activities, each with a thumbnail', async () => {
    for (const id of NEXT_LESSON_SCHEDULE_IDS) {
      const activities = await db.prisma.scheduledLessonActivity.findMany({
        where: { lessonScheduleId: id },
        orderBy: { orderNumber: 'asc' },
        select: {
          type: true,
          youtubeThumbnailUrl: true,
          video: { select: { thumbnailUrl: true } },
          readBlocks: { where: { backgroundImageUrl: { not: null } }, orderBy: { orderNumber: 'asc' }, take: 1, select: { backgroundImageUrl: true } },
        },
      })
      expect(activities.map((a) => a.type)).toEqual(['YOUTUBE', 'VIDEO', 'READ'])
      for (const a of activities) expect(activityThumbnailUrl(a)).toMatch(/^https:\/\//)
    }
  })

  it('serves history across all seven kinds, newest first, without future or LESSON events', async () => {
    const { getGroupHistory } = await import('../../src/services/group-history.js')
    const all = await getGroupHistory(RICH_GROUP_ID, 50)
    expect(new Set(all.map((e) => e.kind))).toEqual(
      new Set(['member_joined', 'member_left', 'join_requested', 'settings_updated', 'cover_updated', 'group_created', 'event_held'])
    )
    expect(all.filter((e) => e.kind === 'event_held').map((e) => e.text)).toEqual(['Held event at Corner Bakery'])
    const latest = await getGroupHistory(RICH_GROUP_ID, 5)
    expect(latest.map((e) => e.kind)).toEqual(['join_requested', 'join_requested', 'cover_updated', 'event_held', 'member_left'])
    expect(latest[0].text).toBe('Esther Graham requested to join')
    expect(all[all.length - 1].kind).toBe('group_created')
  })

  it('fills the rail: scheduled lessons, partial completions and sessions over the last 30 days', async () => {
    const { getHomeDays } = await import('../../src/services/home-dashboard.js')
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const today = localDate(new Date())
    const from = addDays(today, -29)
    const { days } = await getHomeDays(scope, from, today, TZ, { groupId: RICH_GROUP_ID })
    expect(days).toHaveLength(30)
    expect(days.filter((d) => d.sessionSeconds > 0).length).toBeGreaterThanOrEqual(15)
    const filters = { organizationId: FIXTURE_ORG_ID, groupId: RICH_GROUP_ID, from, to: today }
    const scheduled = await runAnalyticsQuery({ metrics: ['scheduled_lessons'], dimensions: ['day'], filters, timezone: TZ }, scope)
    const completed = await runAnalyticsQuery({ metrics: ['lesson_completions'], dimensions: ['day'], filters, timezone: TZ }, scope)
    const sum = (rows: Record<string, unknown>[], key: string) => rows.reduce((s, r) => s + Number(r[key] ?? 0), 0)
    expect(scheduled.rows.filter((r) => Number(r.scheduled_lessons) > 0).length).toBeGreaterThanOrEqual(20)
    expect(completed.rows.filter((r) => Number(r.lesson_completions) > 0).length).toBeGreaterThanOrEqual(10)
    expect(sum(completed.rows, 'lesson_completions')).toBeLessThan(sum(scheduled.rows, 'scheduled_lessons'))
  })
})
