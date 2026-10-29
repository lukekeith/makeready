import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate, zonedTime } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_GROUP_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS } from '../screens/groups-detail.js'
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
    // Base sittings carry video progress; the ~6-month history sittings (owner ruling 2026-10-25) do not.
    expect(first.member_video_progress).toBeGreaterThan(300)
    expect(first.member_lesson_progress).toBeGreaterThan(first.member_video_progress + 1000)
    expect(first.client_events).toBeGreaterThanOrEqual(first.member_lesson_progress) // + mid-sitting resume opens
    expect(first.membership_events).toBe(24 + GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS.length) // + groups-detail's history (ui2-groups-browse D19)
  }, 180_000)

  it('(d) Home reads ≥ 18 non-empty days, a populated trend windows, and 40 h (±2 h) of video', async () => {
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
    // D21: completion varies by member, day and week, so the windows are populated, not pinned.
    expect(previous).toBeGreaterThan(0)
    expect(current).toBeGreaterThan(0)

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

    // D21: a sitting never crosses local midnight (it completes on the day it opened), and the
    // opens follow the habits — busy mornings and evenings, near-silent 1–4 AM.
    const progress = await db.prisma.memberLessonProgress.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
    for (const p of progress) {
      expect(localDate(p.completedAt!)).toBe(localDate(p.startedAt!))
      expect(p.pinnedVersionId).toBeNull()
    }
    const opens = await db.prisma.clientEvent.findMany({ where: { organizationId: FIXTURE_ORG_ID } })
    const byHour = Array(24).fill(0)
    for (const e of opens) {
      expect(e.eventType).toBe('LESSON_OPENED')
      byHour[chicagoHour(e.occurredAt)] += 1
    }
    const share = (from: number, to: number) => byHour.slice(from, to).reduce((a, b) => a + b, 0) / opens.length
    expect(share(1, 5)).toBeLessThan(0.01)
    expect(share(6, 9)).toBeGreaterThan(0.2)
    expect(share(19, 23)).toBeGreaterThan(0.25)
    expect(share(14, 17)).toBeLessThan(0.05)
    const joins = await db.prisma.membershipEvent.findMany({
      where: { memberId: { in: FIXTURE_MEMBER_IDS }, id: { notIn: GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS } },
    })
    expect(joins).toHaveLength(24)
    for (const j of joins) {
      expect(j.action).toBe('ADDED')
      expect(j.organizationId).toBe(FIXTURE_ORG_ID)
    }
  }, 180_000)

  it('(h) history: uneven schedules with breaks, uneven completion, never above member-lessons (D10, D21)', async () => {
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const today = todayInTimezone(TZ)
    const query = (metric: string) =>
      runAnalyticsQuery(
        {
          metrics: [metric],
          dimensions: ['day'],
          filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -182), to: today },
          timezone: TZ,
        },
        scope
      )
    const scheduled = await query('scheduled_lessons')
    const completed = await query('lesson_completions')
    expect(scheduled.rows).toHaveLength(183)
    expect(completed.rows).toHaveLength(183)

    // Member-lessons due per day = Σ over that day's schedules of the group's member count (8).
    const schedules = await db.prisma.lessonSchedule.findMany({
      where: { enrollment: { group: { organizationId: FIXTURE_ORG_ID } }, removedAt: null },
    })
    const enrollmentGroup = new Map(
      (await db.prisma.enrollment.findMany({ where: { group: { organizationId: FIXTURE_ORG_ID } } })).map((e) => [e.id, e.groupId])
    )
    const memberLessons = new Map<string, number>()
    for (const s of schedules) memberLessons.set(localDate(s.scheduledDate), (memberLessons.get(localDate(s.scheduledDate)) ?? 0) + 8)

    // D21 cadence: Men's history meets Mon/Wed/Fri only, Women's never on a weekend.
    const weekdaysOf = (groupId: string) =>
      new Set(
        schedules
          .filter((x) => x.enrollmentId && enrollmentGroup.get(x.enrollmentId) === groupId)
          .map((x) => new Date(`${localDate(x.scheduledDate)}T12:00:00Z`).getUTCDay())
      )
    expect([...weekdaysOf(FIXTURE_GROUP_IDS[2])].some((d) => d === 0 || d === 6)).toBe(false)

    const counts = scheduled.rows.map((row, i) => {
      const day = String(row.day)
      const done = Number(completed.rows[i].lesson_completions)
      expect(done, `completed on ${day}`).toBeLessThanOrEqual(memberLessons.get(day) ?? 0)
      return { day, scheduled: Number(row.scheduled_lessons), done }
    })
    // Breaks: some days have nothing scheduled; the grey column varies.
    expect(counts.some((c) => c.scheduled === 0)).toBe(true)
    expect(new Set(counts.map((c) => c.scheduled)).size).toBeGreaterThanOrEqual(3)
    // Uneven completion: ≥ 5 days under 40% and ≥ 5 days at 90% or more.
    const rates = counts.filter((c) => c.scheduled > 0 && c.day < today).map((c) => c.done / c.scheduled)
    expect(rates.filter((r) => r < 0.4).length).toBeGreaterThanOrEqual(5)
    expect(rates.filter((r) => r >= 0.9).length).toBeGreaterThanOrEqual(5)
    // Weekends sag: the mean weekend rate is below the mean weekday rate.
    const mean = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / Math.max(xs.length, 1)
    const isWeekend = (day: string) => [0, 6].includes(new Date(`${day}T12:00:00Z`).getUTCDay())
    const rated = counts.filter((c) => c.scheduled > 0 && c.day < today)
    expect(mean(rated.filter((c) => isWeekend(c.day)).map((c) => c.done / c.scheduled))).toBeLessThan(
      mean(rated.filter((c) => !isWeekend(c.day)).map((c) => c.done / c.scheduled))
    )

    // Video time is untouched by history sittings: exactly 40 h.
    const video = await db.prisma.memberVideoProgress.aggregate({
      where: { memberId: { in: FIXTURE_MEMBER_IDS } },
      _sum: { watchedSeconds: true },
    })
    expect(video._sum.watchedSeconds).toBe(144_000)
  }, 180_000)

  it('(f) every D1 field source is non-zero after full (home-dashboard-data D1, D12, D17)', async () => {
    const before = Date.now()
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const { getHomeDays, getHomeEngagement, getHomeSessions } = await import('../../src/services/home-dashboard.js')
    const { FOLLOWED_ENROLLMENTS_KEY, getHomeFollowing } = await import('../../src/services/home-following.js')
    const { loadSessions } = await import('../../src/services/home-sessions.js')
    const today = todayInTimezone(TZ)
    // The layer places today's sittings only when ≥ 10 min fit between 05:00 and now − 5 min.
    const todayHasSittings = before - 5 * 60_000 - zonedTime(today, 5).getTime() >= 10 * 60_000

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
      expect(s.ticks[0]).toBe(0)                    // D18: a session-length axis in minutes
      expect(s.ticks.length).toBeLessThanOrEqual(4)
      expect(s.ticks[s.ticks.length - 1]).toBe(s.axisMinutes)
    }

    // D21: sessions run from a 2-min check-in to about an hour, across morning, midday and evening.
    const now = new Date()
    const sessions = await loadSessions(scope, { from: new Date(now.getTime() - 60 * 86_400_000), to: now })
    // History reaches past the window's left edge, which clips a sitting's opening event (floor 60 s):
    // check sessions that start a day or more inside the window.
    for (const s of sessions.filter((x) => x.start.getTime() >= now.getTime() - 59 * 86_400_000)) {
      expect(s.seconds).toBeGreaterThanOrEqual(60)
      expect(s.seconds).toBeLessThanOrEqual(2 * 3600) // two sittings < 30 min apart merge
    }
    const minutes = sessions.map((s) => s.seconds / 60).sort((a, b) => a - b)
    expect(minutes[Math.floor(minutes.length / 2)]).toBeGreaterThan(8)
    expect(minutes[Math.floor(minutes.length / 2)]).toBeLessThan(25)
    expect(minutes.some((m) => m < 5)).toBe(true)
    expect(minutes.some((m) => m > 45)).toBe(true)
    const hours = sessions.map((s) => chicagoHour(s.start))
    expect(hours.some((h) => h < 10)).toBe(true)
    expect(hours.some((h) => h >= 11 && h < 14)).toBe(true)
    expect(hours.some((h) => h >= 18)).toBe(true)

    // Engagement (D3, D15, D17): 24 enrolled members across 4 groups -- the three home-dashboard groups plus
    // the Prayer Team, which enrollments-home (ui2-enrollments-browse D22) gives due schedules. How many are
    // caught up depends on today's date (schedules are dated relative to it), so pin the shape, not the count.
    const engagement = await getHomeEngagement(scope, TZ, new Date())
    expect(engagement).toMatchObject({ enrolledCount: 24, groupCount: 4 })
    expect(engagement.currentCount).toBeGreaterThan(0)
    expect(engagement.currentCount).toBeLessThan(engagement.enrolledCount)
    expect(engagement.percent).toBe(Math.round((engagement.currentCount / engagement.enrolledCount) * 100))
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
