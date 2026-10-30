/**
 * enrollments-home layer (ui2-enrollments-browse D22): what the Enrollments list adds beyond base,
 * home-dashboard's history, groups-enroll-program's ended enrollment and enrollment-home.ts.
 *  - Upcoming: enrollment n 960 on the Prayer Team — "Walking Through John" (30 lessons, one a day from
 *    +5), created yesterday by Nathan Hughes. Base and every other layer have no upcoming enrollment.
 *  - Draft · 2/6: draft n 1 — Women's Bible Study + "Walking Through John", group and program only,
 *    started by Fixture Leader, last touched yesterday.
 *  - Draft · 6/6 read as 5/6 (D9 stale start): draft n 2 — Young Adults + "Foundations of Faith", every
 *    row set, its 21 lesson dates from 3 days ago, started by Nathan Hughes.
 *  (The Prayer Team's draft is groups-enroll-program.ts's: its program is that layer's.)
 * Never touches ctx.rand. Creates no org, user or group; wipe.ts removes the drafts and the enrollment
 * with their groups (cascade).
 */
import { lessonId } from '../base.js'
import { FIXTURE_TZ, type FixtureContext } from '../context.js'
import {
  FIXTURE_GROUP_IDS,
  FIXTURE_LEADER_GROUP_ID,
  FIXTURE_LEADER_USER_ID,
  FIXTURE_PROGRAM_IDS,
  FIXTURE_USER_ID,
  fixtureId,
} from '../ids.js'

export const UPCOMING_ENROLLMENT_ID = fixtureId('enrollment', 960)
export const UPCOMING_START_OFFSET = 5
const UPCOMING_LESSONS = 30
const UPCOMING_PROGRAM_INDEX = 2 // base PROGRAMS: days30 = index 2 "Walking Through John"
export const DRAFT_PARTIAL_ID = fixtureId('enrollmentDraft', 1)
export const DRAFT_STALE_ID = fixtureId('enrollmentDraft', 2)
export const DRAFT_STALE_START_OFFSET = -3
const DRAFT_STALE_LESSONS = 21
const ALL_WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const days = Array.from({ length: UPCOMING_LESSONS }, (_, i) => i + 1)
  const offsetOf = (day: number) => UPCOMING_START_OFFSET + day - 1
  await prisma.enrollment.create({
    data: {
      id: UPCOMING_ENROLLMENT_ID,
      groupId: FIXTURE_LEADER_GROUP_ID,
      studyProgramId: FIXTURE_PROGRAM_IDS.days30,
      startDate: ctx.at(offsetOf(1), 12),
      endDate: ctx.at(offsetOf(UPCOMING_LESSONS), 12),
      enabledDays: JSON.stringify(ALL_WEEKDAYS),
      smsTime: '08:00',
      timezone: FIXTURE_TZ,
      createdById: FIXTURE_LEADER_USER_ID,
      createdAt: ctx.daysAgo(1),
    },
  })
  await prisma.lessonSchedule.createMany({
    data: days.map((day) => ({
      id: fixtureId('schedule', 960_000 + day),
      enrollmentId: UPCOMING_ENROLLMENT_ID,
      lessonId: lessonId(UPCOMING_PROGRAM_INDEX, day),
      scheduledDate: ctx.at(offsetOf(day), 12),
      title: `Day ${day}`,
      estimatedMinutes: 25,
    })),
  })

  const staleDates = Array.from({ length: DRAFT_STALE_LESSONS }, (_, i) => ctx.dateOf(DRAFT_STALE_START_OFFSET + i))
  await prisma.enrollmentDraft.create({
    data: {
      id: DRAFT_PARTIAL_ID,
      groupId: FIXTURE_GROUP_IDS[2],
      studyProgramId: FIXTURE_PROGRAM_IDS.days30,
      createdById: FIXTURE_USER_ID,
      updatedById: FIXTURE_USER_ID,
      createdAt: ctx.at(-2, 10),
      updatedAt: ctx.at(-1, 15),
    },
  })
  await prisma.enrollmentDraft.create({
    data: {
      id: DRAFT_STALE_ID,
      groupId: FIXTURE_GROUP_IDS[1],
      studyProgramId: FIXTURE_PROGRAM_IDS.days21,
      startDate: staleDates[0],
      enabledDays: ALL_WEEKDAYS,
      overriddenDates: [],
      scheduleDates: staleDates,
      smsTime: '08:00',
      timezone: FIXTURE_TZ,
      syncMode: 'AUTO',
      lessonAccess: 'ONE_AT_A_TIME',
      createdById: FIXTURE_LEADER_USER_ID,
      updatedById: FIXTURE_LEADER_USER_ID,
      createdAt: ctx.at(-6, 9),
      updatedAt: ctx.at(-4, 18),
    },
  })
}
