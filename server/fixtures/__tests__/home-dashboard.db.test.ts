import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate, zonedTime } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const total = (rows: Record<string, unknown>[] | undefined, key: string) =>
  (rows ?? []).reduce((s, r) => s + Number(r[key] ?? 0), 0)
const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }
const chicagoHour = (d: Date) =>
  Number(new Intl.DateTimeFormat('en-US', { timeZone: TZ, hour: 'numeric', hourCycle: 'h23' }).format(d)) % 24

describe.skipIf(!TEST_DB_URL)('home-dashboard layer against the test database (D18)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
  }, 60_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('(b) reset full twice gives identical row counts', async () => {
    const first = await db.run('reset', 'full')
    const second = await db.run('reset', 'full')
    expect(second).toEqual(first)
    expect(first.member_lesson_progress).toBeGreaterThanOrEqual(696)
    expect(first.member_video_progress).toBe(first.member_lesson_progress)
    expect(first.client_events).toBe(first.member_lesson_progress)
    expect(first.membership_events).toBe(24)
  }, 180_000)

  it('(d) Home reads ≥ 18 non-empty days, a positive trend, and 40 h (±2 h) of video', async () => {
    const before = Date.now()
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const today = todayInTimezone(TZ)

    // Home's Overview query (DashboardActions.swift: from today−23 to today, compareToPrevious).
    const series = await runAnalyticsQuery(
      {
        metrics: ['lesson_completions'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -23), to: today },
        timezone: TZ,
        compareToPrevious: true,
      },
      scope
    )
    expect(series.rows).toHaveLength(24)
    const nonEmpty = series.rows.filter((r) => Number(r.lesson_completions) > 0).length
    expect(nonEmpty).toBeGreaterThanOrEqual(18)
    const current = total(series.rows, 'lesson_completions')
    const previous = total(series.previousRows, 'lesson_completions')
    expect(previous).toBe(240) // D17: E1 −47…−24 (8 × 24) + E2 −29…−24 (8 × 6), every member done
    expect(current).toBeGreaterThan(previous)

    // watch_seconds is a snapshot metric: no range (the service 400s on one), as Home queries it.
    const watch = await runAnalyticsQuery(
      { metrics: ['watch_seconds'], dimensions: [], filters: { organizationId: FIXTURE_ORG_ID }, timezone: TZ },
      scope
    )
    const seconds = Number(watch.rows[0]?.watch_seconds)
    expect(seconds).toBeGreaterThanOrEqual(144_000 - 7_200)
    expect(seconds).toBeLessThanOrEqual(144_000 + 7_200)

    // F15: the explicit lastWatchedAt survived @updatedAt — every watch ends ≥ 5 min before the run.
    const watched = await db.prisma.memberVideoProgress.aggregate({
      where: { memberId: { in: FIXTURE_MEMBER_IDS } },
      _max: { lastWatchedAt: true },
    })
    expect(watched._max.lastWatchedAt).not.toBeNull()
    expect(watched._max.lastWatchedAt!.getTime()).toBeLessThan(before - 60_000)

    // D11: completions, watches and opens all sit in the 07:00–21:00 Chicago band.
    const progress = await db.prisma.memberLessonProgress.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
    for (const p of progress) {
      const date = localDate(p.completedAt!)
      expect(p.completedAt!.getTime()).toBeGreaterThanOrEqual(zonedTime(date, 7).getTime())
      expect(p.completedAt!.getTime()).toBeLessThanOrEqual(zonedTime(date, 21).getTime())
      expect(p.pinnedVersionId).toBeNull()
    }
    const opens = await db.prisma.clientEvent.findMany({ where: { organizationId: FIXTURE_ORG_ID } })
    for (const e of opens) {
      expect(e.eventType).toBe('LESSON_OPENED')
      const date = localDate(e.occurredAt)
      expect(e.occurredAt.getTime()).toBeGreaterThanOrEqual(zonedTime(date, 7).getTime())
      expect(e.occurredAt.getTime()).toBeLessThanOrEqual(zonedTime(date, 21).getTime())
    }
    const joins = await db.prisma.membershipEvent.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
    expect(joins).toHaveLength(24)
    for (const j of joins) {
      expect(j.action).toBe('ADDED')
      expect(j.organizationId).toBe(FIXTURE_ORG_ID)
    }
  }, 180_000)

  it('(f) every D1 field source is non-zero after full (home-dashboard-data D1, D12, D17)', async () => {
    const before = Date.now()
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const { getHomeDays, getHomeEngagement, getHomeSessions } = await import('../../src/services/home-dashboard.js')
    const { FOLLOWED_ENROLLMENTS_KEY, getHomeFollowing } = await import('../../src/services/home-following.js')
    const { loadSessions } = await import('../../src/services/home-sessions.js')
    const today = todayInTimezone(TZ)
    // The layer places today's sittings only when ≥ 10 min fit between 07:00 and now − 5 min.
    const todayHasSittings = before - 5 * 60_000 - zonedTime(today, 7).getTime() >= 10 * 60_000

    // Activity: scheduled column over the chart's 36 days (today − 28 … today + 7).
    const scheduled = await runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -28), to: addDays(today, 7) },
        timezone: TZ,
      },
      scope
    )
    expect(scheduled.rows).toHaveLength(36)
    for (const r of scheduled.rows) expect(Number(r.scheduled_lessons)).toBeGreaterThan(0)

    // Activity + day cards: completed per day and session minutes/blocks for the past 7 days.
    const completed = await runAnalyticsQuery(
      {
        metrics: ['lesson_completions'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -6), to: today },
        timezone: TZ,
      },
      scope
    )
    const { days } = await getHomeDays(scope, addDays(today, -6), today, TZ)
    expect(days).toHaveLength(7)
    days.forEach((d, i) => {
      expect(d.blocks).toHaveLength(12)
      expect(d.blocks.reduce((a, b) => a + b, 0)).toBe(d.sessionSeconds)
      if (i < 6 || todayHasSittings) {
        expect(d.sessionSeconds).toBeGreaterThan(0)
        expect(d.blocks.some((b) => b > 0)).toBe(true)
        expect(Number(completed.rows[i].lesson_completions)).toBeGreaterThan(0)
      }
    })

    // Sessions: every range maps (D13), each non-empty.
    for (const range of ['all', 'year', 'month', 'week'] as const) {
      const s = await getHomeSessions(scope, range, TZ, new Date())
      expect(s.sessionCount).toBeGreaterThan(0)
      expect(s.averageSeconds).toBeGreaterThanOrEqual(5 * 60)
      expect(s.averageSeconds).toBeLessThanOrEqual(40 * 60)
      expect(s.hourly).toHaveLength(24)
      expect(s.hourly.some((v) => v > 0)).toBe(true)
      expect(s.bins).toHaveLength(88)
      expect(Math.max(...s.bins)).toBe(1)
      expect(s.ticks).toHaveLength(4)
    }

    // D12: sittings last 5–40 min, across morning, midday and evening.
    const now = new Date()
    const sessions = await loadSessions(scope, { from: new Date(now.getTime() - 60 * 86_400_000), to: now })
    for (const s of sessions) {
      expect(s.seconds).toBeGreaterThanOrEqual(5 * 60)
      expect(s.seconds).toBeLessThanOrEqual(40 * 60)
    }
    const hours = sessions.map((s) => chicagoHour(s.start))
    expect(hours.some((h) => h < 10)).toBe(true)
    expect(hours.some((h) => h >= 11 && h < 14)).toBe(true)
    expect(hours.some((h) => h >= 18)).toBe(true)

    // Engagement (D3, D15, D17): 10 of 24 caught up across 3 groups.
    const engagement = await getHomeEngagement(scope, TZ, new Date())
    expect(engagement).toMatchObject({ currentCount: 10, enrolledCount: 24, groupCount: 3, percent: 42 })
    expect(engagement.activeCount).toBeGreaterThan(0)

    // Following (D4, D11, D12): 3 enrollments across 2 programs, from a JSON-encoded string.
    const pref = await db.prisma.userPreference.findUnique({
      where: { userId_key: { userId: FIXTURE_USER_ID, key: FOLLOWED_ENROLLMENTS_KEY } },
    })
    expect(JSON.parse(pref!.value)).toEqual([FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]])
    const following = await getHomeFollowing(scope, FIXTURE_USER_ID, new Date())
    expect(following.programs.map((p) => p.title)).toEqual(['Foundations of Faith', 'Walking Through John'])
    expect(following.programs.map((p) => p.groups.map((g) => g.groupName))).toEqual([
      ["Tuesday Men's Group", "Women's Bible Study"],
      ['Young Adults'],
    ])
    expect(following.programs[0].author).toBe('Fixture Leader')
    for (const g of following.programs.flatMap((p) => p.groups)) {
      expect(g.memberCount).toBe(8)
      expect(g.percent).toBeGreaterThan(0)
    }
  }, 180_000)
})
