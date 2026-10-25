import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate, zonedTime } from '../context.js'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const total = (rows: Record<string, unknown>[] | undefined, key: string) =>
  (rows ?? []).reduce((s, r) => s + Number(r[key] ?? 0), 0)

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
    expect(first.member_lesson_progress).toBeGreaterThan(0)
    expect(first.member_video_progress).toBe(first.member_lesson_progress)
    expect(first.client_events).toBe(first.member_lesson_progress)
    expect(first.membership_events).toBe(24)
  }, 180_000)

  it('(d) Home reads ≥ 18 non-empty days, +15% (±3%), and 40 h (±2 h) of video', async () => {
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const today = todayInTimezone(TZ)
    const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }

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
    expect(previous).toBeGreaterThan(0)
    expect(current / previous).toBeGreaterThanOrEqual(1.12)
    expect(current / previous).toBeLessThanOrEqual(1.18)

    // watch_seconds is a snapshot metric: no range (the service 400s on one), as Home queries it.
    const watch = await runAnalyticsQuery(
      { metrics: ['watch_seconds'], dimensions: [], filters: { organizationId: FIXTURE_ORG_ID }, timezone: TZ },
      scope
    )
    const seconds = Number(watch.rows[0]?.watch_seconds)
    expect(seconds).toBeGreaterThanOrEqual(144_000 - 7_200)
    expect(seconds).toBeLessThanOrEqual(144_000 + 7_200)

    // F15: the explicit lastWatchedAt survived @updatedAt — every watch is before today.
    const watched = await db.prisma.memberVideoProgress.aggregate({
      where: { memberId: { in: FIXTURE_MEMBER_IDS } },
      _max: { lastWatchedAt: true },
    })
    expect(watched._max.lastWatchedAt).not.toBeNull()
    expect(watched._max.lastWatchedAt!.getTime()).toBeLessThan(zonedTime(today, 0).getTime())

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
})
