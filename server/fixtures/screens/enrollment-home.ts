/**
 * enrollment-home layer (ui2-enrollments-browse D22): the enrollment detail page's walk enrollment.
 *  - enrollment n 950 on the Prayer Team (base group 4, created by Nathan Hughes — the feed's second
 *    group creator): "Foundations of Faith" (21 lessons, one a day from −10 to +10, so active today),
 *    invite 07:30 Chicago, one lesson at a time. Its 3 members come from members-home.ts.
 *  - days 1–3 each carry a YOUTUBE (youtubeThumbnailUrl) and a READ (read-block image) activity, so
 *    the lesson rows show slide thumbnails.
 * No member progress or client events (home-dashboard's totals stay exact); base enrollment 4 carries
 * the progress spread over days. Never touches ctx.rand. Creates no org, user or group; wipe.ts removes
 * all of it with the Prayer Team (group cascade).
 */
import { lessonId } from '../base.js'
import { FIXTURE_TZ, type FixtureContext } from '../context.js'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_LEADER_USER_ID, FIXTURE_PROGRAM_IDS, fixtureId } from '../ids.js'
import { seedScheduledContent } from '../scheduled-content.js'
import { READ_IMAGE_URL, YOUTUBE_THUMBNAIL_URL } from './groups-detail.js'

export const HOME_ENROLLMENT_ID = fixtureId('enrollment', 950)
export const HOME_LESSON_COUNT = 21
export const HOME_START_OFFSET = -10
export const HOME_SMS_TIME = '07:30'
const PROGRAM_INDEX = 1 // base PROGRAMS: days21 = index 1 "Foundations of Faith"

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const days = Array.from({ length: HOME_LESSON_COUNT }, (_, i) => i + 1)
  const offsetOf = (day: number) => HOME_START_OFFSET + day - 1
  await prisma.enrollment.create({
    data: {
      id: HOME_ENROLLMENT_ID,
      groupId: FIXTURE_LEADER_GROUP_ID,
      studyProgramId: FIXTURE_PROGRAM_IDS.days21,
      startDate: ctx.at(offsetOf(1), 12),
      endDate: ctx.at(offsetOf(HOME_LESSON_COUNT), 12),
      enabledDays: JSON.stringify(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
      smsTime: HOME_SMS_TIME,
      timezone: FIXTURE_TZ,
      lessonAccess: 'ONE_AT_A_TIME',
      createdById: FIXTURE_LEADER_USER_ID,
      createdAt: ctx.daysAgo(12),
    },
  })
  // 1.0 rows, kept only until home-dashboard's engagement read (still on LessonSchedule) moves to the new model; the
  // enrollment-home reads use the ScheduledLesson rows below. Task 17 deletes these with the table.
  await prisma.lessonSchedule.createMany({
    data: days.map((day) => ({
      id: fixtureId('schedule', 950_000 + day),
      enrollmentId: HOME_ENROLLMENT_ID,
      lessonId: lessonId(PROGRAM_INDEX, day),
      scheduledDate: ctx.at(offsetOf(day), 12),
      title: `Day ${day}`,
      estimatedMinutes: 25,
    })),
  })
  await seedScheduledContent(ctx, {
    seed: 950,
    programId: FIXTURE_PROGRAM_IDS.days21,
    enrollmentId: HOME_ENROLLMENT_ID,
    lessons: days.map((day) => ({ lessonId: lessonId(PROGRAM_INDEX, day), scheduledDate: ctx.at(offsetOf(day), 12), title: `Day ${day}` })),
    // days 1–3: a YouTube-style slide (its thumbnail) and a read slide (its image), as the 1.0 rows had.
    slides: Object.fromEntries(
      [1, 2, 3].map((day) => [
        day,
        [
          { kind: 'youtube', title: 'Watch: Overview', imageUrl: YOUTUBE_THUMBNAIL_URL },
          { kind: 'text', title: `Read John ${day}`, imageUrl: READ_IMAGE_URL },
        ],
      ]),
    ),
  })
}
