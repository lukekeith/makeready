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
import { youtubeDocument, textDocument, textObject } from '../activity-documents.js'
import { lessonId, lessonVersionId, programVersionId, scheduleId } from '../base.js'
import { FIXTURE_TZ, type FixtureContext } from '../context.js'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_LEADER_USER_ID, FIXTURE_PROGRAM_IDS, fixtureId } from '../ids.js'
import { customizeLessons, scheduleLessons, seedImageMedia } from '../lesson-content.js'
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
  await scheduleLessons(ctx, {
    enrollmentId: HOME_ENROLLMENT_ID,
    programVersionId: programVersionId(PROGRAM_INDEX),
    schedules: days.map((day) => ({
      id: scheduleId(950, day),
      lessonId: lessonId(PROGRAM_INDEX, day),
      currentVersionId: lessonVersionId(PROGRAM_INDEX, day),
      scheduledDate: ctx.at(offsetOf(day), 12),
    })),
  })
  // days 1–3: this group's own version of the lesson — a YouTube page (its thumbnail as the background) and a read
  // page (its image), so the lesson rows show slide thumbnails.
  const items = []
  for (const day of [1, 2, 3]) {
    const youtubeMedia = await seedImageMedia(ctx, 950_000 + day * 2 - 1, 'Watch: Overview', YOUTUBE_THUMBNAIL_URL)
    const readMedia = await seedImageMedia(ctx, 950_000 + day * 2, `Read John ${day}`, READ_IMAGE_URL)
    const base = lessonVersionId(PROGRAM_INDEX, day)
    items.push({
      scheduledLessonId: scheduleId(950, day),
      version: {
        id: fixtureId('lessonVersion', 950_000 + day),
        lessonId: lessonId(PROGRAM_INDEX, day),
        number: 1,
        title: `Day ${day}`,
        basedOnVersionId: base,
        activities: [
          { id: fixtureId('contentActivity', 950_000 + day * 2 - 1), activityKey: `fixture-950-${day}-1`, kind: 'youtube', title: 'Watch: Overview', document: youtubeDocument('G-2e9mMf7E8', { imageMediaId: youtubeMedia }) },
          { id: fixtureId('contentActivity', 950_000 + day * 2), activityKey: `fixture-950-${day}-2`, kind: 'text', title: `Read John ${day}`, document: textDocument([textObject({ id: 'o1', text: `Read John ${day} slowly, twice.` })], { imageMediaId: readMedia }) },
        ],
      },
    })
  }
  await customizeLessons(ctx, HOME_ENROLLMENT_ID, items)
}
