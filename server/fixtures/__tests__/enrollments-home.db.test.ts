/**
 * enrollments-home + enrollment-home layers (ui2-enrollments-browse D22) against a throwaway database:
 * the two drafts, every status bucket of the feed, two group creators, and the rich detail enrollment.
 * Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_TZ, localDate } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_LEADER_USER_ID, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { HOME_ENROLLMENT_ID, HOME_LESSON_COUNT, HOME_SMS_TIME } from '../screens/enrollment-home.js'
import { DRAFT_PARTIAL_ID, DRAFT_STALE_ID, UPCOMING_ENROLLMENT_ID } from '../screens/enrollments-home.js'
import { DRAFT_PRAYER_TEAM_ID, ENROLL_ENDED_ENROLLMENT_ID } from '../screens/groups-enroll-program.js'
import { READ_IMAGE_URL, YOUTUBE_THUMBNAIL_URL } from '../screens/groups-detail.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

type Directory = typeof import('../../src/services/enrollment-directory.service.js')

describe.skipIf(!TEST_DB_URL)('enrollments-home + enrollment-home full scenario against the test database', () => {
  let db: FixturesDb
  let dir: Directory
  const ids = (feed: Awaited<ReturnType<Directory['getEnrollmentFeed']>>) =>
    feed.sections.flatMap((s) => s.items.map((i) => (i.kind === 'draft' ? i.draft.id : i.id)))
  const feedOf = (status: 'active' | 'upcoming' | 'completed' | 'draft' | 'all') =>
    dir.getEnrollmentFeed(FIXTURE_USER_ID, dir.feedQuerySchema.parse({ status, tz: FIXTURE_TZ }))

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
    dir = await import('../../src/services/enrollment-directory.service.js')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('seeds a 2/6 draft (group + program only) and a 6/6 draft whose first lesson date is past', async () => {
    const partial = await db.prisma.enrollmentDraft.findUniqueOrThrow({ where: { id: DRAFT_PARTIAL_ID } })
    expect(partial).toMatchObject({ startDate: null, scheduleDates: null, smsTime: null, syncMode: null, lessonAccess: null, createdById: FIXTURE_USER_ID })
    const stale = await db.prisma.enrollmentDraft.findUniqueOrThrow({ where: { id: DRAFT_STALE_ID } })
    expect(stale).toMatchObject({ smsTime: '08:00', timezone: FIXTURE_TZ, syncMode: 'AUTO', lessonAccess: 'ONE_AT_A_TIME', createdById: FIXTURE_LEADER_USER_ID })
    const dates = stale.scheduleDates as string[]
    expect(dates).toHaveLength(21)
    expect(stale.startDate).toBe(dates[0])
    expect(dates[0] < localDate(new Date(), FIXTURE_TZ)).toBe(true)
  })

  it('Draft lists exactly the three drafts', async () => {
    expect(ids(await feedOf('draft')).sort()).toEqual([DRAFT_PARTIAL_ID, DRAFT_STALE_ID, DRAFT_PRAYER_TEAM_ID].sort())
  })

  it("a group's drafts lead its list (owner 2026-10-30)", async () => {
    for (const section of (await feedOf('all')).sections) {
      const kinds = section.items.map((i) => i.kind)
      expect(kinds).toEqual([...kinds].sort((a, b) => (a === 'draft' ? 0 : 1) - (b === 'draft' ? 0 : 1)))
    }
    const prayer = (await feedOf('all')).sections.find((s) => s.group.name === 'Prayer Team')!
    expect(prayer.items[0]).toMatchObject({ kind: 'draft', draft: { id: DRAFT_PRAYER_TEAM_ID } })
  })

  it('Upcoming lists exactly the Prayer Team upcoming enrollment', async () => {
    expect(ids(await feedOf('upcoming'))).toEqual([UPCOMING_ENROLLMENT_ID])
  })

  it('Active lists base enrollments 2–4 and the Prayer Team detail enrollment, across four groups', async () => {
    const active = await feedOf('active')
    expect(ids(active).sort()).toEqual([...FIXTURE_ENROLLMENT_IDS.slice(1), HOME_ENROLLMENT_ID].sort())
    expect(active.sections).toHaveLength(4)
  })

  it('Completed lists every fixture enrollment that ended before today (Chicago)', async () => {
    const today = localDate(new Date(), FIXTURE_TZ)
    const ended = (await db.prisma.enrollment.findMany({ where: { group: { organizationId: FIXTURE_ORG_ID } }, select: { id: true, endDate: true } }))
      .filter((e) => localDate(e.endDate, FIXTURE_TZ) < today)
      .map((e) => e.id)
    const completed = ids(await feedOf('completed'))
    expect(completed.sort()).toEqual(ended.sort())
    expect(completed).toContain(FIXTURE_ENROLLMENT_IDS[0])
    expect(completed).toContain(ENROLL_ENDED_ENROLLMENT_ID)
  })

  it('All offers both group creators as leaders', async () => {
    expect((await feedOf('all')).options.leaders.map((l) => l.name)).toEqual(['Fixture Leader', 'Nathan Hughes'])
  })

  it('the detail enrollment reads 21 lessons, its invite time, Nathan as leader and slide thumbnails', async () => {
    const home = await dir.getEnrollmentHome(FIXTURE_USER_ID, HOME_ENROLLMENT_ID)
    expect(home).not.toBeNull()
    expect(home!.lessons).toHaveLength(HOME_LESSON_COUNT)
    expect(home!.smsTime).toBe(HOME_SMS_TIME)
    expect(home!.group.leader?.name).toBe('Nathan Hughes')
    expect(home!.memberCount).toBe(3)
    expect(home!.lessons[0].activities.map((a) => a.thumbnailUrl)).toEqual([YOUTUBE_THUMBNAIL_URL, READ_IMAGE_URL])
  })
})
