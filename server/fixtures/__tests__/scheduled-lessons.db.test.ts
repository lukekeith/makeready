/**
 * scheduled_lessons against a real analytics_events (home-dashboard-data D10, D14, F7, F8).
 * Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, fixtureId } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const MIDNIGHT_ID = fixtureId('schedule', 9_000_001)
const REMOVED_ID = fixtureId('schedule', 9_000_002)
const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }
const total = (rows: Record<string, unknown>[], key: string) => rows.reduce((s, r) => s + Number(r[key] ?? 0), 0)

describe.skipIf(!TEST_DB_URL)('scheduled_lessons metric against the test database', () => {
  let db: FixturesDb
  let today: string
  let target: string

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
    const { refreshAnalytics, todayInTimezone } = await import('../../src/services/analytics.service.js')
    today = todayInTimezone(TZ)
    target = addDays(today, 10) // clear of every base schedule (the latest is today + 7)
    // Under the fixture enrollment 4, so reset's cascade removes them too. lessonId stays null
    // (@@unique([enrollmentId, lessonId]) admits several nulls).
    await db.prisma.lessonSchedule.createMany({
      data: [
        // Production writes UTC midnight (routes/enrollments.ts:197-198) — AT TIME ZONE Chicago would call it target − 1.
        { id: MIDNIGHT_ID, enrollmentId: FIXTURE_ENROLLMENT_IDS[3], scheduledDate: new Date(`${target}T00:00:00.000Z`), title: 'UTC midnight' },
        { id: REMOVED_ID, enrollmentId: FIXTURE_ENROLLMENT_IDS[3], scheduledDate: new Date(`${target}T12:00:00.000Z`), title: 'Removed', removedAt: new Date() },
      ],
    })
    const refreshed = await refreshAnalytics()
    expect(refreshed.refreshed).toBe(true)
  }, 180_000)

  afterAll(async () => {
    if (!db) return
    await db.prisma.lessonSchedule.deleteMany({ where: { id: { in: [MIDNIGHT_ID, REMOVED_ID] } } })
    await db.close()
  })

  it('counts a UTC-midnight schedule on its stored date under America/Chicago, and skips a removed one (F8)', async () => {
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const result = await runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(target, -1), to: target },
        timezone: TZ,
      },
      scope
    )
    expect(result.rows).toEqual([
      { day: addDays(target, -1), scheduled_lessons: 0 },
      { day: target, scheduled_lessons: 1 },
    ])
  })

  it('counts every non-removed fixture schedule exactly once over the base span', async () => {
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const result = await runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -48), to: addDays(today, 7) },
        timezone: TZ,
      },
      scope
    )
    const expected = await db.prisma.lessonSchedule.count({
      where: { enrollmentId: { in: FIXTURE_ENROLLMENT_IDS }, removedAt: null, id: { not: MIDNIGHT_ID } },
    })
    expect(expected).toBe(102) // 30 + 30 + 21 + 21 (base.ts ENROLLMENT_PLAN)
    expect(total(result.rows, 'scheduled_lessons')).toBe(expected)
  })

  it('leaves lesson_completions totals unchanged by the new arm', async () => {
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const result = await runAnalyticsQuery(
      { metrics: ['lesson_completions'], dimensions: [], filters: { organizationId: FIXTURE_ORG_ID }, timezone: TZ },
      scope
    )
    const source = await db.prisma.memberLessonProgress.count({
      where: { memberId: { in: FIXTURE_MEMBER_IDS }, completedAt: { not: null } },
    })
    expect(Number(result.rows[0]?.lesson_completions)).toBe(source)
  })

  it('reconciles the ls: arm with its source rows (the quality-check predicate, F7)', async () => {
    const [view] = await db.prisma.$queryRaw<{ n: number }[]>`
      SELECT COUNT(*)::int AS n FROM analytics_events WHERE event_id LIKE 'ls:%'`
    const [source] = await db.prisma.$queryRaw<{ n: number }[]>`
      SELECT COUNT(*)::int AS n
        FROM lesson_schedules ls
        JOIN enrollments e ON e.id = ls."enrollmentId"
        JOIN groups g ON g.id = e."groupId"`
    expect(view.n).toBe(source.n)
    const [nulls] = await db.prisma.$queryRaw<{ n: number }[]>`
      SELECT COUNT(*)::int AS n FROM analytics_events
       WHERE event_type = 'LESSON_SCHEDULED' AND (event_id IS NULL OR entity_id IS NULL OR member_id IS NOT NULL)`
    expect(nulls.n).toBe(0)
  })
})
