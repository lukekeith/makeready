/**
 * home-dashboard layer (SPEC ui2-fixtures D1, D9, D11; home-dashboard-data D1, D12, D17): fills
 * every number Home reads — Overview's sparkline and trend, total video time, Activity's
 * scheduled/completed columns and day cards, Sessions, Engagement and Following. `full` only.
 *
 * Construction (D17): every member completes each of their group's due lessons ON its scheduled
 * Chicago day, except that the 14 members outside CAUGHT_UP_INDICES stop 1–5 lessons short of
 * today — 10 of 24 caught up (D3 → 42%, the D7 yellow band). The previous 24-day Overview window
 * holds only the early enrollments, so the current window is larger (a positive trend). Each
 * completion is one sitting, 5–40 min: LESSON_OPENED → video start (+10%) → last watch (+60%) →
 * completion (+100%), opened in a morning, midday or evening band inside 07:00–21:00 Chicago.
 * Caught-up members also finish today's lesson in a sitting ending ≥ 5 min before ctx.now (skipped
 * before ~07:15 Chicago). Video seconds are apportioned to exactly 40 h. The fixture user follows
 * enrollments 2–4 through the `dashboard.followedEnrollments` preference (D4, D12).
 */
import type { LessonSchedule } from '../../src/generated/prisma/index.js'
import { VIDEO_SECONDS } from '../base.js'
import { type FixtureContext, FixtureError, localDate, zonedTime } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const VIDEO_TOTAL_SECONDS = 40 * 3600
/** Member indices (into FIXTURE_MEMBER_IDS) who are caught up: 5 + 3 + 2 across the three groups. */
export const CAUGHT_UP_INDICES: ReadonlySet<number> = new Set([0, 1, 2, 3, 4, 8, 9, 10, 16, 17])
export const SITTING_MIN_MINUTES = 5
export const SITTING_MAX_MINUTES = 40
/** Opening-hour bands (Chicago). The latest open + the longest sitting ends by 21:00. */
export const DAY_PARTS = [
  { start: 7, end: 9.5 },
  { start: 11.5, end: 13.5 },
  { start: 18, end: 20.3 },
] as const
export const FOLLOWED_ENROLLMENTS_PREFERENCE = 'dashboard.followedEnrollments'
/** Enrollments 2, 3, 4: Walking Through John (Young Adults) + Foundations of Faith (Women's, Tuesday Men's). */
export const FOLLOWED_ENROLLMENT_IDS = [FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]]
const TODAY_MARGIN_MS = 5 * 60_000
const TODAY_MIN_WINDOW_MS = 10 * 60_000

/** How many due lessons a member leaves undone: 0 when caught up, else 1–5. */
export function behindBy(memberIndex: number): number {
  return CAUGHT_UP_INDICES.has(memberIndex) ? 0 : 1 + (memberIndex % 5)
}

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

interface Pair {
  memberId: string
  groupId: string
  enrollmentId: string
  studyProgramId: string
  schedule: LessonSchedule
}

interface Sitting {
  pair: Pair
  openedAt: Date
  minutes: number
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma, created } = ctx

  // Every member's lessons (member × schedule pairs), oldest first.
  const enrollmentById = new Map(created.enrollments.map((e) => [e.id, e]))
  const pairsByMember = new Map<string, Pair[]>()
  for (const schedule of created.schedules) {
    const enrollment = enrollmentById.get(schedule.enrollmentId)
    if (!enrollment) throw new FixtureError(`schedule ${schedule.id} has no base enrollment`)
    for (const gm of created.groupMembers) {
      if (gm.groupId !== enrollment.groupId || !gm.memberId) continue
      const list = pairsByMember.get(gm.memberId) ?? []
      list.push({
        memberId: gm.memberId,
        groupId: enrollment.groupId,
        enrollmentId: enrollment.id,
        studyProgramId: enrollment.studyProgramId,
        schedule,
      })
      pairsByMember.set(gm.memberId, list)
    }
  }

  const sittingMinutes = () => SITTING_MIN_MINUTES + (SITTING_MAX_MINUTES - SITTING_MIN_MINUTES) * ctx.rand.next()
  const todayStart = ctx.at(0, 7).getTime()
  const todayEnd = Math.min(ctx.at(0, 21).getTime(), ctx.now.getTime() - TODAY_MARGIN_MS)

  const sittings: Sitting[] = []
  FIXTURE_MEMBER_IDS.forEach((memberId, index) => {
    const pairs = (pairsByMember.get(memberId) ?? [])
      .slice()
      .sort((a, b) => a.schedule.scheduledDate.getTime() - b.schedule.scheduledDate.getTime())
    const due = pairs.filter((p) => localDate(p.schedule.scheduledDate) < ctx.today)
    for (const pair of due.slice(0, Math.max(0, due.length - behindBy(index)))) {
      const date = localDate(pair.schedule.scheduledDate)
      const part = DAY_PARTS[ctx.rand.int(0, DAY_PARTS.length - 1)]
      const openedHour = part.start + (part.end - part.start) * ctx.rand.next()
      sittings.push({ pair, openedAt: zonedTime(date, openedHour), minutes: sittingMinutes() })
    }
    // D1: today's day card — caught-up members also finish today's lesson, before ctx.now.
    const todays = pairs.find((p) => localDate(p.schedule.scheduledDate) === ctx.today)
    if (behindBy(index) === 0 && todays && todayEnd - todayStart >= TODAY_MIN_WINDOW_MS) {
      const minutes = Math.min(sittingMinutes(), (todayEnd - todayStart) / 60_000)
      const openedAt = new Date(todayStart + (todayEnd - todayStart - minutes * 60_000) * ctx.rand.next())
      sittings.push({ pair: todays, openedAt, minutes })
    }
  })

  const along = (s: Sitting, fraction: number) => new Date(s.openedAt.getTime() + Math.round(s.minutes * 60_000 * fraction))

  const watched = apportion(
    VIDEO_TOTAL_SECONDS,
    sittings.map(() => 0.7 + 0.3 * ctx.rand.next()),
    sittings.map(() => VIDEO_SECONDS)
  )

  const lessonById = new Map(created.lessons.map((l) => [l.id, l]))
  const videoActivityByLesson = new Map(
    created.activities.filter((a) => a.activityType === 'VIDEO').map((a) => [a.lessonId, a.id])
  )

  await prisma.memberLessonProgress.createMany({
    data: sittings.map((s, i) => ({
      id: fixtureId('lessonProgress', i + 1),
      memberId: s.pair.memberId,
      lessonScheduleId: s.pair.schedule.id,
      startedAt: s.openedAt,
      completedAt: along(s, 1),
      lastUpdatedAt: along(s, 1),
    })),
  })

  await prisma.memberVideoProgress.createMany({
    data: sittings.map((s, i) => {
      const lessonId = s.pair.schedule.lessonId
      const lessonActivityId = lessonId ? videoActivityByLesson.get(lessonId) : undefined
      if (!lessonActivityId) throw new FixtureError(`schedule ${s.pair.schedule.id} has no VIDEO activity`)
      return {
        id: fixtureId('videoProgress', i + 1),
        memberId: s.pair.memberId,
        lessonScheduleId: s.pair.schedule.id,
        lessonActivityId,
        watchedSeconds: watched[i],
        totalDuration: VIDEO_SECONDS,
        watchPercentage: Math.round((watched[i] / VIDEO_SECONDS) * 1000) / 10,
        startedAt: along(s, 0.1),
        lastWatchedAt: along(s, 0.6),
        completedAt: null,
      }
    }),
  })

  await prisma.clientEvent.createMany({
    data: sittings.map((s, i) => {
      const lesson = s.pair.schedule.lessonId ? lessonById.get(s.pair.schedule.lessonId) : undefined
      return {
        id: fixtureId('clientEvent', i + 1),
        eventType: 'LESSON_OPENED',
        occurredAt: s.openedAt,
        receivedAt: s.openedAt,
        memberId: s.pair.memberId,
        organizationId: FIXTURE_ORG_ID,
        groupId: s.pair.groupId,
        enrollmentId: s.pair.enrollmentId,
        studyProgramId: s.pair.studyProgramId,
        lessonScheduleId: s.pair.schedule.id,
        lessonId: s.pair.schedule.lessonId,
        dayNumber: lesson?.dayNumber ?? null,
        scheduledDate: s.pair.schedule.scheduledDate,
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

  // D4/D12: the preference column is a string — store the JSON-encoded id array.
  await prisma.userPreference.create({
    data: {
      id: fixtureId('userPreference', 1),
      userId: FIXTURE_USER_ID,
      key: FOLLOWED_ENROLLMENTS_PREFERENCE,
      value: JSON.stringify(FOLLOWED_ENROLLMENT_IDS),
      createdAt: ctx.now,
    },
  })
}
