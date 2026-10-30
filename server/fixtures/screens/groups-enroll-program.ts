/**
 * groups-enroll-program layer (ui2-enrollment-create D12): one layer for the New-enrollment checklist
 * and its six pickers. Base already gives the walk the 0-member group (FIXTURE_EMPTY_GROUP_ID, hidden
 * by the group picker), group 1 with its active enrollment 4 (the already-enrolled warning) and the
 * study-program-home layer's unpublished 0-lesson program 4 (hidden). This layer adds:
 *  - program n 5 "Romans in 12 Days" — published, 12 lessons — with one enrollment on base group 2
 *    that ended before ctx.now (the program picker's completed count reads 1);
 *  - program n 6 "Coming Soon Study" — published with days 0 and no lessons (hidden by the picker);
 *  - draft n 3 (owner 2026-10-30): the Prayer Team + "Romans in 12 Days", group and program only, started
 *    by Nathan Hughes — the one program the Prayer Team has no current enrollment in.
 * Ids from a fresh n 900+ range. Creates no org, user or group; wipe.ts removes the programs (and
 * their lessons, enrollments and schedules by cascade) with the fixture org.
 */
import type { FixtureContext } from '../context.js'
import { placeProgramCovers } from '../images.js'
import {
  FIXTURE_GROUP_IDS,
  FIXTURE_LEADER_GROUP_ID,
  FIXTURE_LEADER_USER_ID,
  FIXTURE_ORG_ID,
  FIXTURE_USER_ID,
  fixtureId,
} from '../ids.js'

export const ENROLL_PROGRAM_ID = fixtureId('program', 5)
export const ENROLL_PROGRAM_NAME = 'Romans in 12 Days'
export const ENROLL_EMPTY_PROGRAM_ID = fixtureId('program', 6)
export const ENROLL_PROGRAM_DAYS = 12
export const ENROLL_ENDED_ENROLLMENT_ID = fixtureId('enrollment', 900)
export const DRAFT_PRAYER_TEAM_ID = fixtureId('enrollmentDraft', 3)
const lessonIdFor = (day: number) => fixtureId('lesson', 900_000 + day)
const scheduleIdFor = (day: number) => fixtureId('schedule', 900_000 + day)

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.studyProgram.createMany({
    data: [
      {
        id: ENROLL_PROGRAM_ID,
        name: ENROLL_PROGRAM_NAME,
        description: "Twelve short readings through Paul's letter to the Romans.",
        days: ENROLL_PROGRAM_DAYS,
        creatorId: FIXTURE_USER_ID,
        leaderId: FIXTURE_USER_ID,
        organizationId: FIXTURE_ORG_ID,
        isPublished: true,
        publishedAt: ctx.daysAgo(60),
        createdAt: ctx.daysAgo(60),
      },
      {
        id: ENROLL_EMPTY_PROGRAM_ID,
        name: 'Coming Soon Study',
        days: 0,
        creatorId: FIXTURE_USER_ID,
        leaderId: FIXTURE_USER_ID,
        organizationId: FIXTURE_ORG_ID,
        isPublished: true,
        publishedAt: ctx.daysAgo(2),
        createdAt: ctx.daysAgo(2),
      },
    ],
  })
  await placeProgramCovers(ctx, [ENROLL_PROGRAM_ID])
  const days = Array.from({ length: ENROLL_PROGRAM_DAYS }, (_, i) => i + 1)
  await prisma.lesson.createMany({
    data: days.map((day) => ({ id: lessonIdFor(day), studyProgramId: ENROLL_PROGRAM_ID, dayNumber: day, title: `Day ${day}` })),
  })
  // Ran days −40 … −29: ended before today, so it counts as completed (D8/D17).
  await prisma.enrollment.create({
    data: {
      id: ENROLL_ENDED_ENROLLMENT_ID,
      groupId: FIXTURE_GROUP_IDS[1],
      studyProgramId: ENROLL_PROGRAM_ID,
      startDate: ctx.at(-40, 12),
      endDate: ctx.at(-29, 12),
      enabledDays: JSON.stringify(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
      smsTime: '08:00',
      timezone: 'America/Chicago',
      createdById: FIXTURE_USER_ID,
      createdAt: ctx.daysAgo(41),
    },
  })
  await prisma.lessonSchedule.createMany({
    data: days.map((day) => ({
      id: scheduleIdFor(day),
      enrollmentId: ENROLL_ENDED_ENROLLMENT_ID,
      lessonId: lessonIdFor(day),
      scheduledDate: ctx.at(-41 + day, 12),
      title: `Day ${day}`,
    })),
  })
  await prisma.enrollmentDraft.create({
    data: {
      id: DRAFT_PRAYER_TEAM_ID,
      groupId: FIXTURE_LEADER_GROUP_ID,
      studyProgramId: ENROLL_PROGRAM_ID,
      createdById: FIXTURE_LEADER_USER_ID,
      updatedById: FIXTURE_LEADER_USER_ID,
      createdAt: ctx.at(-1, 9),
      updatedAt: ctx.at(-1, 9),
    },
  })
}
