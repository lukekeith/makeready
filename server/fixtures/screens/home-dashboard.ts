/**
 * home-dashboard layer (SPEC ui2-fixtures D1, D9, D11): fills every number
 * Home reads — Overview's 24-day completed-lessons sparkline and its trend,
 * total video time, Activity's day cards — plus membership_events and
 * client_events for Sessions / Engagement / Following, whose endpoints land
 * later. `full` only (D6).
 *
 * Targets are hit BY CONSTRUCTION: a per-day target curve (rising, weekends at
 * 40%) is rounded for the previous 24-day window, the current window's total
 * is fixed at 115% of it and apportioned exactly, and each day's count is then
 * assigned to that day's member × schedule pairs. Video seconds are apportioned
 * to exactly 40 h. Everything sits in the 07:00–21:00 America/Chicago band.
 */
import type { LessonSchedule } from '../../src/generated/prisma/index.js'
import { VIDEO_SECONDS } from '../base.js'
import {
  type FixtureContext,
  FixtureError,
  type Prng,
  addDays,
  localDate,
  weekdayOf,
  zonedTime,
} from '../context.js'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

/** Completions on days −48 … −1 (today stays empty: nothing completes in the future). */
export const HISTORY_DAYS = 48
/** Home's window: today−23 … today, compared with the 24 days before. */
export const WINDOW_DAYS = 24
export const TREND = 1.15
export const WEEKEND_FACTOR = 0.4
export const VIDEO_TOTAL_SECONDS = 40 * 3600
const BAND_START_HOUR = 7

/** Largest-remainder apportionment of `total`: at least one per slot (cap permitting), never above its cap. */
export function apportion(total: number, weights: readonly number[], caps: readonly number[]): number[] {
  const out = caps.map((cap) => Math.min(1, cap))
  let remaining = total - out.reduce((s, n) => s + n, 0)
  if (remaining < 0) throw new FixtureError(`apportion: ${total} is less than one per slot`)
  while (remaining > 0) {
    const open = out.map((_, i) => i).filter((i) => out[i] < caps[i])
    if (open.length === 0) throw new FixtureError(`apportion: capacity exhausted with ${remaining} left`)
    const weightSum = open.reduce((s, i) => s + weights[i], 0)
    const shares = open.map((i) => ({
      i,
      exact: weightSum > 0 ? (remaining * weights[i]) / weightSum : remaining / open.length,
    }))
    let given = 0
    for (const s of shares) {
      const add = Math.min(Math.floor(s.exact), caps[s.i] - out[s.i])
      out[s.i] += add
      given += add
    }
    let left = remaining - given
    const byRemainder = shares
      .slice()
      .sort((a, b) => b.exact - Math.floor(b.exact) - (a.exact - Math.floor(a.exact)) || a.i - b.i)
    for (const s of byRemainder) {
      if (left === 0) break
      if (out[s.i] < caps[s.i]) {
        out[s.i] += 1
        left -= 1
      }
    }
    remaining = left
  }
  return out
}

/** The target curve: 4 → 5.75 completions a weekday across the 48 days, weekends at 40%, ±8% jitter. */
export function dailyWeight(offset: number, date: string, jitter: number): number {
  const t = (offset + HISTORY_DAYS) / (HISTORY_DAYS - 1)
  const base = 4 + 1.75 * t
  const day = weekdayOf(date)
  const weekend = day === 0 || day === 6
  return base * (weekend ? WEEKEND_FACTOR : 1) * (0.92 + 0.16 * jitter)
}

/** Per-day completion counts for offsets −48 … −1; the current window totals exactly round(115% × previous). */
export function dailyCompletionCounts(
  today: string,
  rand: Prng,
  capacity: (offset: number) => number
): Map<number, number> {
  const weights = new Map<number, number>()
  for (let o = -HISTORY_DAYS; o <= -1; o++) weights.set(o, dailyWeight(o, addDays(today, o), rand.next()))

  const counts = new Map<number, number>()
  const currentStart = -(WINDOW_DAYS - 1) // −23
  for (let o = -HISTORY_DAYS; o < currentStart; o++) {
    counts.set(o, Math.min(capacity(o), Math.max(1, Math.round(weights.get(o) ?? 0))))
  }
  let previousTotal = 0
  for (let o = -(2 * WINDOW_DAYS - 1); o <= -WINDOW_DAYS; o++) previousTotal += counts.get(o) ?? 0 // −47 … −24

  const current: number[] = []
  for (let o = currentStart; o <= -1; o++) current.push(o)
  const split = apportion(
    Math.round(previousTotal * TREND),
    current.map((o) => weights.get(o) ?? 0),
    current.map(capacity)
  )
  current.forEach((o, i) => counts.set(o, split[i]))
  return counts
}

interface Pair {
  memberId: string
  groupId: string
  enrollmentId: string
  studyProgramId: string
  schedule: LessonSchedule
}

interface Completion {
  pair: Pair
  date: string
  openedHour: number
  doneHour: number
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma, created } = ctx

  const enrollmentById = new Map(created.enrollments.map((e) => [e.id, e]))
  const membersByGroup = new Map<string, string[]>()
  for (const gm of created.groupMembers) {
    if (!gm.memberId) continue
    const list = membersByGroup.get(gm.groupId) ?? []
    list.push(gm.memberId)
    membersByGroup.set(gm.groupId, list)
  }

  // Every member × schedule pair, keyed by the schedule's Chicago date.
  const pairsByDate = new Map<string, Pair[]>()
  for (const schedule of created.schedules) {
    const enrollment = enrollmentById.get(schedule.enrollmentId)
    if (!enrollment) throw new FixtureError(`schedule ${schedule.id} has no base enrollment`)
    const date = localDate(schedule.scheduledDate)
    const list = pairsByDate.get(date) ?? []
    for (const memberId of membersByGroup.get(enrollment.groupId) ?? []) {
      list.push({
        memberId,
        groupId: enrollment.groupId,
        enrollmentId: enrollment.id,
        studyProgramId: enrollment.studyProgramId,
        schedule,
      })
    }
    pairsByDate.set(date, list)
  }
  const pairsOn = (offset: number) => pairsByDate.get(ctx.dateOf(offset)) ?? []

  const counts = dailyCompletionCounts(ctx.today, ctx.rand, (o) => pairsOn(o).length)

  const completions: Completion[] = []
  for (let offset = -HISTORY_DAYS; offset <= -1; offset++) {
    const chosen = ctx.rand.shuffle(pairsOn(offset)).slice(0, counts.get(offset) ?? 0)
    for (const pair of chosen) {
      const openedHour = BAND_START_HOUR + 13 * ctx.rand.next() // 07:00 … 20:00
      const doneHour = openedHour + 0.25 + 0.25 * ctx.rand.next() // ≤ 20:30
      completions.push({ pair, date: ctx.dateOf(offset), openedHour, doneHour })
    }
  }

  const watchWeights = completions.map(() => 0.7 + 0.3 * ctx.rand.next())
  const watched = apportion(
    VIDEO_TOTAL_SECONDS,
    watchWeights,
    completions.map(() => VIDEO_SECONDS)
  )

  const lessonById = new Map(created.lessons.map((l) => [l.id, l]))
  const videoActivityByLesson = new Map(
    created.activities.filter((a) => a.activityType === 'VIDEO').map((a) => [a.lessonId, a.id])
  )

  await prisma.memberLessonProgress.createMany({
    data: completions.map((c, i) => ({
      id: fixtureId('lessonProgress', i + 1),
      memberId: c.pair.memberId,
      lessonScheduleId: c.pair.schedule.id,
      startedAt: zonedTime(c.date, c.openedHour),
      completedAt: zonedTime(c.date, c.doneHour),
      lastUpdatedAt: zonedTime(c.date, c.doneHour),
    })),
  })

  await prisma.memberVideoProgress.createMany({
    data: completions.map((c, i) => {
      const lessonId = c.pair.schedule.lessonId
      const lessonActivityId = lessonId ? videoActivityByLesson.get(lessonId) : undefined
      if (!lessonActivityId) throw new FixtureError(`schedule ${c.pair.schedule.id} has no VIDEO activity`)
      return {
        id: fixtureId('videoProgress', i + 1),
        memberId: c.pair.memberId,
        lessonScheduleId: c.pair.schedule.id,
        lessonActivityId,
        watchedSeconds: watched[i],
        totalDuration: VIDEO_SECONDS,
        watchPercentage: Math.round((watched[i] / VIDEO_SECONDS) * 1000) / 10,
        startedAt: zonedTime(c.date, c.openedHour + 0.05),
        lastWatchedAt: zonedTime(c.date, c.openedHour + 0.25),
        completedAt: null,
      }
    }),
  })

  await prisma.clientEvent.createMany({
    data: completions.map((c, i) => {
      const lesson = c.pair.schedule.lessonId ? lessonById.get(c.pair.schedule.lessonId) : undefined
      const occurredAt = zonedTime(c.date, c.openedHour)
      return {
        id: fixtureId('clientEvent', i + 1),
        eventType: 'LESSON_OPENED',
        occurredAt,
        receivedAt: occurredAt,
        memberId: c.pair.memberId,
        organizationId: FIXTURE_ORG_ID,
        groupId: c.pair.groupId,
        enrollmentId: c.pair.enrollmentId,
        studyProgramId: c.pair.studyProgramId,
        lessonScheduleId: c.pair.schedule.id,
        lessonId: c.pair.schedule.lessonId,
        dayNumber: lesson?.dayNumber ?? null,
        scheduledDate: c.pair.schedule.scheduledDate,
      }
    }),
  })

  await prisma.membershipEvent.createMany({
    data: created.groupMembers.map((gm, i) => {
      if (!gm.memberId) throw new FixtureError(`group member ${gm.id} has no member`)
      return {
        id: fixtureId('membershipEvent', i + 1),
        memberId: gm.memberId,
        groupId: gm.groupId,
        organizationId: FIXTURE_ORG_ID,
        action: 'ADDED' as const,
        actorId: FIXTURE_USER_ID,
        actorType: 'user',
        createdAt: gm.joinedAt,
      }
    }),
  })
}
