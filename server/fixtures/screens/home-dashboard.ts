/**
 * home-dashboard layer (SPEC ui2-fixtures D1, D9, D11; home-dashboard-data D1, D12, D17, D21): fills
 * every number Home reads — Overview's sparkline and trend, total video time, Activity's
 * scheduled/completed columns and day cards, Sessions, Engagement and Following. `full` only.
 *
 * Engagement (D17): the 10 members in CAUGHT_UP_INDICES finish every lesson scheduled before today
 * (some late); the other 14 always leave their last 1–5 due base lessons undone — 10 of 24 caught
 * up (D3 → 42%, the D7 yellow band). Caught-up members also finish today's lesson when the clock
 * allows. Video seconds over the base sittings are apportioned to exactly 40 h. The fixture user
 * follows enrollments 2–4 through the `dashboard.followedEnrollments` preference (D4, D12).
 *
 * History (owner 2026-10-25): before each group's first base enrollment, back-to-back past
 * enrollments reach today−182, each group on its own cadence (D21: Men's Mon/Wed/Fri, Young Adults
 * daily, Women's Mon–Fri) with a 3–10-day break before each one, so ~6 months of Activity shows
 * real gaps. History sittings are LESSON_OPENED + completion only — no video, so the 40 h holds.
 *
 * Realism (D21, owner 2026-10-25):
 * - Completion: a member's rate (55–90%) × program fatigue (day 1 → 55% of it on the last day)
 *   × weekend (Sat 0.6, Sun 0.7) × three bad weeks (0.3) × 2–3 lapse streaks of 4–9 days (0.05).
 *   15% of completions land 1–4 days late, on a weekday whose completions are still below its
 *   scheduled member-lessons, so completed never exceeds scheduled (D10). A caught-up member's
 *   late lesson holds its own day's slot until it lands, so it always gets done (D3).
 * - Time of day: each member has a habit (HABITS) — 9 early, 3 lunch, 9 evening, 3 night — opened
 *   with ±20 min jitter (early risers 1.5 h later on weekends); 15% of sittings follow POP_CURVE
 *   instead, which is near zero 1–4 AM. Every sitting ends before local midnight.
 * - Length: log-normal, median 13 min × a per-member pace, clipped 5–60; 6% are 2–4 min
 *   check-ins. A sitting longer than 25 min re-opens every 20 min so it stays one session (the
 *   sessionizer splits at a 30-min gap).
 *
 * Ids: base sittings n = 1…; history enrollment n 10…, schedule (n)*1000+day, history progress and
 * opens n ≥ 1_000_000, resume opens n ≥ 2_000_000.
 */
import type { Prisma } from '../../src/generated/prisma/index.js'
import { PROGRAMS, VIDEO_SECONDS, WEEKDAYS, lessonId } from '../base.js'
import { FIXTURE_TZ, type FixtureContext, FixtureError, addDays, localDate, weekdayOf, zonedTime } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_GROUP_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const VIDEO_TOTAL_SECONDS = 40 * 3600
/** Member indices (into FIXTURE_MEMBER_IDS) who are caught up: 5 + 3 + 2 across the three groups. */
export const CAUGHT_UP_INDICES: ReadonlySet<number> = new Set([0, 1, 2, 3, 4, 8, 9, 10, 16, 17])
export const SITTING_MIN_MINUTES = 5
export const SITTING_MAX_MINUTES = 60
export const CHECK_IN_MINUTES = { min: 2, max: 4 } as const
export const FOLLOWED_ENROLLMENTS_PREFERENCE = 'dashboard.followedEnrollments'
/** Enrollments 2, 3, 4: Walking Through John (Young Adults) + Foundations of Faith (Women's, Tuesday Men's). */
export const FOLLOWED_ENROLLMENT_IDS = [FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]]
/** How many days back the history reaches (inclusive). */
export const HISTORY_DAYS = 182

/** D21: each group's history cadence, by group index. */
export const HISTORY_CADENCE: readonly (readonly string[])[] = [['Mon', 'Wed', 'Fri'], ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], WEEKDAYS]
export const BREAK_DAYS = { min: 3, max: 10 } as const

/** D21: opening windows (local hours) per habit. */
export const HABITS = {
  early: { start: 6, end: 7.5 },
  lunch: { start: 11.75, end: 13 },
  evening: { start: 19, end: 21 },
  night: { start: 21.5, end: 23 },
} as const
export type Habit = keyof typeof HABITS
/** By member index within its group (8 per group): 3 early, 1 lunch, 3 evening, 1 night. */
const HABIT_PATTERN: readonly Habit[] = ['early', 'evening', 'early', 'night', 'evening', 'lunch', 'evening', 'early']
export const habitOf = (memberIndex: number): Habit => HABIT_PATTERN[memberIndex % HABIT_PATTERN.length]
/** D21: the share of sittings opened off-habit, from POP_CURVE. */
export const OFF_HABIT_SHARE = 0.15
/** D21: relative opens per local hour 0–23 for off-habit sittings — near zero 1–4 AM. */
export const POP_CURVE = [0.3, 0.1, 0.05, 0.05, 0.1, 0.6, 3, 6, 5, 3, 2, 2.5, 3.5, 2.5, 1.5, 1.5, 2, 2.5, 4, 6, 6.5, 5, 3, 1] as const

/** D21 completion model. */
export const WEEKEND_FACTOR: Readonly<Record<number, number>> = { 0: 0.7, 6: 0.6 }
export const FATIGUE_AT_END = 0.55
/** Day-offset ranges (inclusive) of the three bad weeks. */
export const BAD_WEEKS: readonly (readonly [number, number])[] = [[-124, -118], [-79, -73], [-23, -20]]
export const BAD_WEEK_FACTOR = 0.3
export const LAPSE_FACTOR = 0.05
export const LATE_SHARE = 0.15
export const LATE_DAYS = { min: 1, max: 4 } as const

const HISTORY_ID_BASE = 1_000_000
const RESUME_ID_BASE = 2_000_000
const RESUME_EVERY_MINUTES = 20
const RESUME_AFTER_MINUTES = 25
const TODAY_MARGIN_MS = 5 * 60_000
const TODAY_MIN_WINDOW_MS = 10 * 60_000
const LAST_LOCAL_HOUR = 23.95

/** How many due base lessons a member leaves undone: 0 when caught up, else 1–5. */
export function behindBy(memberIndex: number): number {
  return CAUGHT_UP_INDICES.has(memberIndex) ? 0 : 1 + (memberIndex % 5)
}

/** D21: a member's own completion rate before fatigue, weekends, bad weeks and lapses. */
export function memberRate(memberIndex: number): number {
  return CAUGHT_UP_INDICES.has(memberIndex) ? 1 : 0.55 + 0.35 * (((memberIndex * 5) % 14) / 13)
}

/** D21: day 1 of a program at full rate, its last day at FATIGUE_AT_END of it. */
export function fatigue(dayNumber: number, programDays: number): number {
  if (programDays <= 1) return 1
  return 1 - (1 - FATIGUE_AT_END) * ((dayNumber - 1) / (programDays - 1))
}

export function badWeekFactor(offset: number): number {
  return BAD_WEEKS.some(([a, b]) => offset >= a && offset <= b) ? BAD_WEEK_FACTOR : 1
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

/** One member × one lesson schedule, base or history. */
interface MemberLesson {
  memberId: string
  memberIndex: number
  groupId: string
  enrollmentId: string
  studyProgramId: string
  scheduleId: string
  lessonId: string
  dayNumber: number
  programDays: number
  /** Scheduled local date, and its offset from today. */
  date: string
  offset: number
  base: boolean
}

interface Sitting {
  ml: MemberLesson
  openedAt: Date
  minutes: number
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma, created } = ctx
  const rand = ctx.rand
  const offsetOf = (date: string) =>
    Math.round((Date.parse(`${date}T12:00:00Z`) - Date.parse(`${ctx.today}T12:00:00Z`)) / 86_400_000)

  // ── Member-lessons: base, then the generated history ──────────────────────
  const enrollmentById = new Map(created.enrollments.map((e) => [e.id, e]))
  const lessonById = new Map(created.lessons.map((l) => [l.id, l]))
  const programDays = new Map<string, number>(PROGRAMS.map((p) => [p.id, p.days]))
  const membersOf = (groupId: string) =>
    created.groupMembers.filter((gm) => gm.groupId === groupId && gm.memberId).map((gm) => gm.memberId!)

  const lessons: MemberLesson[] = []
  for (const schedule of created.schedules) {
    const enrollment = enrollmentById.get(schedule.enrollmentId)
    if (!enrollment) throw new FixtureError(`schedule ${schedule.id} has no base enrollment`)
    const lesson = schedule.lessonId ? lessonById.get(schedule.lessonId) : undefined
    if (!lesson) throw new FixtureError(`schedule ${schedule.id} has no lesson`)
    const date = localDate(schedule.scheduledDate)
    for (const memberId of membersOf(enrollment.groupId)) {
      lessons.push({
        memberId,
        memberIndex: FIXTURE_MEMBER_IDS.indexOf(memberId),
        groupId: enrollment.groupId,
        enrollmentId: enrollment.id,
        studyProgramId: enrollment.studyProgramId,
        scheduleId: schedule.id,
        lessonId: lesson.id,
        dayNumber: lesson.dayNumber,
        programDays: programDays.get(enrollment.studyProgramId) ?? lesson.dayNumber,
        date,
        offset: offsetOf(date),
        base: true,
      })
    }
  }
  const history = await seedHistorySchedules(ctx, offsetOf)
  for (const h of history) {
    for (const memberId of membersOf(h.groupId)) {
      lessons.push({ ...h, memberId, memberIndex: FIXTURE_MEMBER_IDS.indexOf(memberId), base: false })
    }
  }
  lessons.sort((a, b) => a.offset - b.offset || a.memberIndex - b.memberIndex || a.scheduleId.localeCompare(b.scheduleId))

  // ── Which lessons get done, and on which day (D17, D21) ───────────────────
  // Lapse streaks: 2–3 per member who is not caught up, 4–9 days each.
  const lapses = new Map<number, Array<[number, number]>>()
  FIXTURE_MEMBER_IDS.forEach((_, i) => {
    if (CAUGHT_UP_INDICES.has(i)) return
    const streaks: Array<[number, number]> = []
    const count = 2 + (rand.next() < 0.5 ? 1 : 0)
    for (let k = 0; k < count; k++) {
      const start = rand.int(-HISTORY_DAYS, -8)
      streaks.push([start, start + rand.int(4, 9) - 1])
    }
    lapses.set(i, streaks)
  })
  const inLapse = (i: number, offset: number) => (lapses.get(i) ?? []).some(([a, b]) => offset >= a && offset <= b)
  const chance = (ml: MemberLesson) =>
    memberRate(ml.memberIndex) *
    fatigue(ml.dayNumber, ml.programDays) *
    (WEEKEND_FACTOR[weekdayOf(ml.date)] ?? 1) *
    badWeekFactor(ml.offset) *
    (inLapse(ml.memberIndex, ml.offset) ? LAPSE_FACTOR : 1)

  // The base lessons each not-caught-up member always leaves undone (their last 1–5 due).
  const leftUndone = new Set<MemberLesson>()
  FIXTURE_MEMBER_IDS.forEach((memberId, i) => {
    const due = lessons.filter((ml) => ml.memberId === memberId && ml.base && ml.offset < 0)
    for (const ml of due.slice(Math.max(0, due.length - behindBy(i)))) leftUndone.add(ml)
  })

  // Scheduled member-lessons per day: completions on a day never exceed it (D10).
  const capacity = new Map<number, number>()
  for (const ml of lessons) capacity.set(ml.offset, (capacity.get(ml.offset) ?? 0) + 1)
  const used = new Map<number, number>()
  const take = (offset: number) => used.set(offset, (used.get(offset) ?? 0) + 1)
  const room = (offset: number) => (used.get(offset) ?? 0) < (capacity.get(offset) ?? 0)

  const done: Array<{ ml: MemberLesson; day: number }> = []
  const late: MemberLesson[] = []
  for (const ml of lessons) {
    if (ml.offset > 0 || leftUndone.has(ml)) continue
    const caughtUp = CAUGHT_UP_INDICES.has(ml.memberIndex)
    if (ml.offset === 0) {
      // Today: caught-up members finish it (D1); others sometimes, already.
      if (caughtUp || rand.next() < 0.5 * chance(ml)) done.push({ ml, day: 0 })
      continue
    }
    const p = chance(ml)
    if (caughtUp) {
      // Every due lesson gets done; the less likely it was on the day, the likelier it ran late.
      if (ml.offset <= -3 && rand.next() > Math.max(p, 1 - LATE_SHARE * 3)) late.push(ml)
      else done.push({ ml, day: ml.offset })
    } else if (rand.next() < p) {
      if (rand.next() < LATE_SHARE && ml.offset <= -2) late.push(ml)
      else done.push({ ml, day: ml.offset })
    }
  }
  for (const d of done) take(d.day)
  // A caught-up member's late lesson keeps its own day's slot until it lands later (D3: it is done).
  for (const ml of late) if (CAUGHT_UP_INDICES.has(ml.memberIndex)) take(ml.offset)
  const weekday = (offset: number) => ![0, 6].includes(weekdayOf(addDays(ctx.today, offset)))
  for (const ml of late) {
    const caughtUp = CAUGHT_UP_INDICES.has(ml.memberIndex)
    let day: number | null = null
    for (let k = rand.int(LATE_DAYS.min, LATE_DAYS.max); k >= 1; k--) {
      const candidate = ml.offset + k
      if (candidate < 0 && weekday(candidate) && room(candidate)) {
        day = candidate
        break
      }
    }
    if (day === null) {
      // No room later: a caught-up member did it on the day (its slot is held); anyone else let it go.
      if (caughtUp) done.push({ ml, day: ml.offset })
      continue
    }
    if (caughtUp) used.set(ml.offset, (used.get(ml.offset) ?? 1) - 1)
    take(day)
    done.push({ ml, day })
  }

  // ── When, and for how long (D21) ──────────────────────────────────────────
  const pace = FIXTURE_MEMBER_IDS.map(() => 0.75 + 0.55 * rand.next())
  const gaussian = () => {
    const u = Math.max(rand.next(), 1e-9)
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * rand.next())
  }
  const sittingMinutes = (memberIndex: number) => {
    if (rand.next() < 0.06) return CHECK_IN_MINUTES.min + (CHECK_IN_MINUTES.max - CHECK_IN_MINUTES.min) * rand.next()
    const m = 13 * pace[memberIndex] * Math.exp(0.55 * gaussian())
    return Math.min(SITTING_MAX_MINUTES, Math.max(SITTING_MIN_MINUTES, m))
  }
  const curveTotal = POP_CURVE.reduce((s, v) => s + v, 0)
  const offHabitHour = () => {
    let r = rand.next() * curveTotal
    for (let h = 0; h < 24; h++) {
      r -= POP_CURVE[h]
      if (r <= 0) return h + rand.next()
    }
    return 20 + rand.next()
  }
  const openHour = (memberIndex: number, date: string) => {
    if (rand.next() < OFF_HABIT_SHARE) return offHabitHour()
    const habit = habitOf(memberIndex)
    const w = HABITS[habit]
    const weekend = weekdayOf(date) === 0 || weekdayOf(date) === 6
    const shift = habit === 'early' && weekend ? 1.5 : 0
    return w.start + shift + (w.end - w.start) * rand.next() + gaussian() / 3
  }
  const todayFloor = ctx.at(0, 5).getTime()
  const todayEnd = ctx.now.getTime() - TODAY_MARGIN_MS

  const sittings: Sitting[] = []
  for (const { ml, day } of done) {
    const date = addDays(ctx.today, day)
    let minutes = sittingMinutes(ml.memberIndex)
    const hour = Math.min(Math.max(openHour(ml.memberIndex, date), 0), LAST_LOCAL_HOUR - SITTING_MIN_MINUTES / 60)
    minutes = Math.min(minutes, (LAST_LOCAL_HOUR - hour) * 60)
    let openedAt = zonedTime(date, hour)
    if (day === 0) {
      // Today's sittings end before ctx.now; too early in the day for one → none.
      if (todayEnd - todayFloor < TODAY_MIN_WINDOW_MS) continue
      if (openedAt.getTime() + minutes * 60_000 > todayEnd) {
        minutes = Math.min(minutes, (todayEnd - todayFloor) / 60_000)
        openedAt = new Date(todayFloor + (todayEnd - todayFloor - minutes * 60_000) * rand.next())
      }
    }
    sittings.push({ ml, openedAt, minutes })
  }
  const along = (s: Sitting, fraction: number) => new Date(s.openedAt.getTime() + Math.round(s.minutes * 60_000 * fraction))

  // ── Rows ──────────────────────────────────────────────────────────────────
  const baseSittings = sittings.filter((s) => s.ml.base)
  const historySittings = sittings.filter((s) => !s.ml.base)

  // Video seconds go to base sittings only, never more than a sitting's own length (40 h total).
  const watched = apportion(
    VIDEO_TOTAL_SECONDS,
    baseSittings.map((s) => s.minutes),
    baseSittings.map((s) => Math.max(1, Math.min(VIDEO_SECONDS, Math.floor(s.minutes * 60 * 0.9))))
  )
  const videoActivityByLesson = new Map(
    created.activities.filter((a) => a.activityType === 'VIDEO').map((a) => [a.lessonId, a.id])
  )

  const progressRow = (s: Sitting, n: number) => ({
    id: fixtureId('lessonProgress', n),
    memberId: s.ml.memberId,
    lessonScheduleId: s.ml.scheduleId,
    startedAt: s.openedAt,
    completedAt: along(s, 1),
    lastUpdatedAt: along(s, 1),
  })
  const openRow = (s: Sitting, n: number, at: Date) => ({
    id: fixtureId('clientEvent', n),
    eventType: 'LESSON_OPENED',
    occurredAt: at,
    receivedAt: at,
    memberId: s.ml.memberId,
    organizationId: FIXTURE_ORG_ID,
    groupId: s.ml.groupId,
    enrollmentId: s.ml.enrollmentId,
    studyProgramId: s.ml.studyProgramId,
    lessonScheduleId: s.ml.scheduleId,
    lessonId: s.ml.lessonId,
    dayNumber: s.ml.dayNumber,
    scheduledDate: zonedTime(s.ml.date, 12),
  })

  await prisma.memberLessonProgress.createMany({ data: baseSittings.map((s, i) => progressRow(s, i + 1)) })
  await prisma.memberVideoProgress.createMany({
    data: baseSittings.map((s, i) => {
      const lessonActivityId = videoActivityByLesson.get(s.ml.lessonId)
      if (!lessonActivityId) throw new FixtureError(`schedule ${s.ml.scheduleId} has no VIDEO activity`)
      return {
        id: fixtureId('videoProgress', i + 1),
        memberId: s.ml.memberId,
        lessonScheduleId: s.ml.scheduleId,
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
  await prisma.clientEvent.createMany({ data: baseSittings.map((s, i) => openRow(s, i + 1, s.openedAt)) })

  const CHUNK = 5000
  for (let i = 0; i < historySittings.length; i += CHUNK) {
    const part = historySittings.slice(i, i + CHUNK)
    await prisma.memberLessonProgress.createMany({ data: part.map((s, j) => progressRow(s, HISTORY_ID_BASE + i + j + 1)) })
    await prisma.clientEvent.createMany({ data: part.map((s, j) => openRow(s, HISTORY_ID_BASE + i + j + 1, s.openedAt)) })
  }

  // A long sitting re-opens every 20 min so the 30-min sessionizer keeps it one session.
  const resumes: Array<{ s: Sitting; at: Date }> = []
  for (const s of sittings) {
    if (s.minutes <= RESUME_AFTER_MINUTES) continue
    for (let m = RESUME_EVERY_MINUTES; m < s.minutes; m += RESUME_EVERY_MINUTES) {
      resumes.push({ s, at: new Date(s.openedAt.getTime() + m * 60_000) })
    }
  }
  for (let i = 0; i < resumes.length; i += CHUNK) {
    await prisma.clientEvent.createMany({
      data: resumes.slice(i, i + CHUNK).map(({ s, at }, j) => openRow(s, RESUME_ID_BASE + i + j + 1, at)),
    })
  }

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

type HistoryLesson = Omit<MemberLesson, 'memberId' | 'memberIndex' | 'base'>

/**
 * Past enrollments + schedules for every group, back from a break before its first base lesson to
 * today−182 (D21 cadence and breaks). Returns one entry per schedule; members are added by the caller.
 */
async function seedHistorySchedules(ctx: FixtureContext, offsetOf: (date: string) => number): Promise<HistoryLesson[]> {
  const { prisma, created, rand } = ctx
  const enrollments: Prisma.EnrollmentCreateManyInput[] = []
  const schedules: Prisma.LessonScheduleCreateManyInput[] = []
  const out: HistoryLesson[] = []
  const firstBase = new Map<string, number>()
  for (const s of created.schedules) {
    const groupId = created.enrollments.find((e) => e.id === s.enrollmentId)?.groupId
    if (!groupId) continue
    const o = offsetOf(localDate(s.scheduledDate))
    firstBase.set(groupId, Math.min(firstBase.get(groupId) ?? 0, o))
  }
  let counter = 0

  FIXTURE_GROUP_IDS.forEach((groupId, groupIndex) => {
    const cadence = HISTORY_CADENCE[groupIndex]
    const meets = (o: number) => cadence.includes(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][weekdayOf(addDays(ctx.today, o))])
    let end = (firstBase.get(groupId) ?? 0) - rand.int(BREAK_DAYS.min, BREAK_DAYS.max)
    let turn = groupIndex
    while (end >= -HISTORY_DAYS) {
      const program = PROGRAMS[turn++ % PROGRAMS.length]
      // Walk back from `end` collecting meeting days until the program is full or the history ends.
      const offsets: number[] = []
      for (let o = end; o >= -HISTORY_DAYS && offsets.length < program.days; o--) if (meets(o)) offsets.unshift(o)
      if (offsets.length === 0) break
      const firstDay = program.days - offsets.length + 1 // an enrollment clipped at −182 keeps its last lessons
      counter += 1
      const enrollmentId = fixtureId('enrollment', 9 + counter)
      enrollments.push({
        id: enrollmentId,
        groupId,
        studyProgramId: program.id,
        startDate: ctx.at(offsets[0], 12),
        endDate: ctx.at(offsets[offsets.length - 1], 12),
        enabledDays: JSON.stringify(cadence),
        smsTime: '08:00',
        timezone: FIXTURE_TZ,
        createdById: FIXTURE_USER_ID,
        createdAt: ctx.daysAgo(3 - offsets[0]),
      })
      offsets.forEach((offset, k) => {
        const day = firstDay + k
        const scheduleId = fixtureId('schedule', (9 + counter) * 1000 + day)
        schedules.push({
          id: scheduleId,
          enrollmentId,
          lessonId: lessonId(program.index, day),
          scheduledDate: ctx.at(offset, 12),
          title: `Day ${day}`,
          estimatedMinutes: 25,
        })
        out.push({
          groupId,
          enrollmentId,
          studyProgramId: program.id,
          scheduleId,
          lessonId: lessonId(program.index, day),
          dayNumber: day,
          programDays: program.days,
          date: ctx.dateOf(offset),
          offset,
        })
      })
      end = offsets[0] - 1 - rand.int(BREAK_DAYS.min, BREAK_DAYS.max)
    }
  })

  await prisma.enrollment.createMany({ data: enrollments })
  await prisma.lessonSchedule.createMany({ data: schedules })
  return out
}
