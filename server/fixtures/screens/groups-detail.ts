/**
 * groups-detail layer (ui2-groups-browse D19, T9): what the group page reads beyond base, on the rich
 * group — base group 1, Tuesday Men's Group.
 *  - Lessons up next: enrollment 4's day 14 (today) and day 15 (tomorrow) each get three
 *    ScheduledLessonActivity rows — YOUTUBE (youtubeThumbnailUrl), VIDEO (a Video with a thumbnail)
 *    and READ (a read block image) — so next-study has three thumbnails whichever of the two the
 *    server's midnight picks.
 *  - Requests: members 20 and 21 (Women's Bible Study) have pending join requests + REQUESTED events.
 *  - Timeline: member 12 joined (APPROVED, −20) and left (REMOVED_GROUP, −6); the group was created
 *    (−75), its settings (−10) and cover (−3) updated (Activity rows, resourceType GROUP); a breakfast
 *    was held (−5). A future social and a past LESSON event exist and must not show (D15). Base's
 *    joins come from home-dashboard's ADDED events; joins by invite write none (D26).
 *  - Activity rail + chart: base + home-dashboard already schedule, complete and sessionize group 1.
 * Never touches ctx.rand: this file runs before home-dashboard.ts, and one draw would shift its numbers.
 * Creates no org, user or group.
 */
import { scheduleId } from '../base.js'
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const RICH_GROUP_ID = FIXTURE_GROUP_IDS[0]
/** Enrollment 4 (group 1) runs daily from today−13: day 14 is today, day 15 tomorrow. */
export const NEXT_LESSON_SCHEDULE_IDS: readonly string[] = [scheduleId(4, 14), scheduleId(4, 15)]
/** Ruth Hamilton (20) and Esther Graham (21), newest request last in this list. */
export const REQUESTER_INDICES: readonly number[] = [20, 21]
/** Sophia Powell (12) joined group 1 and left it. */
export const LEFT_MEMBER_INDEX = 12
export const GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS: string[] = [101, 102, 103, 104].map((n) => fixtureId('membershipEvent', n))

export const YOUTUBE_THUMBNAIL_URL = 'https://picsum.photos/seed/makeready-fixture-youtube/640/360'
export const VIDEO_THUMBNAIL_URL = 'https://picsum.photos/seed/makeready-fixture-video/640/360'
export const READ_IMAGE_URL = 'https://picsum.photos/seed/makeready-fixture-read/640/360'
const VIDEO_ID = fixtureId('video', 1)
const VIDEO_PLAYBACK_URL = 'https://videodelivery.net/fixture-video-1/manifest/video.m3u8'

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const groupName = ctx.created.groups[0]?.name ?? "Tuesday Men's Group"
  const member = (i: number) => FIXTURE_MEMBER_IDS[i]
  const [ruth, esther] = REQUESTER_INDICES
  const requestedAt = [ctx.at(-2, 15), ctx.at(-1, 9)]

  // Requests section (D18) + their history rows.
  await prisma.groupJoinRequest.createMany({
    data: REQUESTER_INDICES.map((i, n) => ({
      id: fixtureId('joinRequest', n + 1),
      groupId: RICH_GROUP_ID,
      memberId: member(i),
      status: 'pending',
      message: 'I’d love to join this group.',
      createdAt: requestedAt[n],
    })),
  })
  const membership = (n: number, memberIndex: number, action: 'APPROVED' | 'REMOVED_GROUP' | 'REQUESTED', createdAt: Date) => ({
    id: fixtureId('membershipEvent', n),
    memberId: member(memberIndex),
    groupId: RICH_GROUP_ID,
    organizationId: FIXTURE_ORG_ID,
    action,
    actorId: action === 'REQUESTED' ? member(memberIndex) : FIXTURE_USER_ID,
    actorType: action === 'REQUESTED' ? 'member' : 'user',
    createdAt,
  })
  await prisma.membershipEvent.createMany({
    data: [
      membership(101, LEFT_MEMBER_INDEX, 'APPROVED', ctx.at(-20, 10)),
      membership(102, LEFT_MEMBER_INDEX, 'REMOVED_GROUP', ctx.at(-6, 18)),
      membership(103, ruth, 'REQUESTED', requestedAt[0]),
      membership(104, esther, 'REQUESTED', requestedAt[1]),
    ],
  })

  // Timeline: the Activity ledger's GROUP rows (D15 — resourceType + resourceId, F6).
  const groupActivity = (n: number, action: 'CREATED' | 'UPDATED', createdAt: Date, metadata?: { field: string }) => ({
    id: fixtureId('feedActivity', n),
    actorId: FIXTURE_USER_ID,
    action,
    resourceType: 'GROUP',
    resourceId: RICH_GROUP_ID,
    resourceName: groupName,
    organizationId: FIXTURE_ORG_ID,
    groupId: RICH_GROUP_ID,
    ...(metadata ? { metadata } : {}),
    createdAt,
  })
  await prisma.activity.createMany({
    data: [
      groupActivity(1, 'CREATED', ctx.daysAgo(75)),
      groupActivity(2, 'UPDATED', ctx.at(-10, 14)),
      groupActivity(3, 'UPDATED', ctx.at(-3, 11), { field: 'cover' }),
    ],
  })

  // Timeline: one past meeting is shown; a future social and a past LESSON event are not (D15).
  await prisma.event.createMany({
    data: [
      { id: fixtureId('event', 1), groupId: RICH_GROUP_ID, type: 'MEETING', title: 'Monthly Breakfast', locationName: 'Corner Bakery', date: ctx.at(-5, 8), createdById: FIXTURE_USER_ID },
      { id: fixtureId('event', 2), groupId: RICH_GROUP_ID, type: 'SOCIAL', title: 'Summer Cookout', date: ctx.at(12, 17), createdById: FIXTURE_USER_ID },
      { id: fixtureId('event', 3), groupId: RICH_GROUP_ID, type: 'LESSON', title: 'Day 10', date: ctx.at(-4, 12), createdById: FIXTURE_USER_ID },
    ],
  })

  // Lessons up next (D17): a YouTube, an uploaded video and a READ block image on today's and tomorrow's lesson.
  await prisma.video.create({
    data: {
      id: VIDEO_ID,
      title: 'A welcome from your leader',
      cloudflareUid: 'fixture-video-1',
      playbackUrl: VIDEO_PLAYBACK_URL,
      thumbnailUrl: VIDEO_THUMBNAIL_URL,
      duration: 180,
      status: 'ready',
      userId: FIXTURE_USER_ID,
      createdAt: ctx.daysAgo(30),
    },
  })
  for (const [k, lessonScheduleId] of NEXT_LESSON_SCHEDULE_IDS.entries()) {
    const id = (order: number) => fixtureId('scheduledActivity', (k + 1) * 10 + order)
    await prisma.scheduledLessonActivity.createMany({
      data: [
        {
          id: id(1),
          lessonScheduleId,
          type: 'YOUTUBE',
          orderNumber: 1,
          title: 'Watch: Overview of John',
          youtubeUrl: 'https://www.youtube.com/watch?v=G-2e9mMf7E8',
          youtubeVideoId: 'G-2e9mMf7E8',
          youtubeThumbnailUrl: YOUTUBE_THUMBNAIL_URL,
        },
        { id: id(2), lessonScheduleId, type: 'VIDEO', orderNumber: 2, title: 'A welcome from your leader', videoId: VIDEO_ID, videoUrl: VIDEO_PLAYBACK_URL },
        { id: id(3), lessonScheduleId, type: 'READ', orderNumber: 3, title: 'Read John 3', referenceTitle: 'John 3', readContent: 'Read John 3 slowly, twice.' },
      ],
    })
    await prisma.activityReadBlock.create({
      data: {
        id: fixtureId('readBlock', k + 1),
        scheduledActivityId: id(3),
        orderNumber: 1,
        title: 'John 3',
        content: 'For God so loved the world…',
        backgroundImageUrl: READ_IMAGE_URL,
      },
    })
  }
}
