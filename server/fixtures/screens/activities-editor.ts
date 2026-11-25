/**
 * activities-editor layer (text-activity Task 17): the lesson the iPhone editor opens. "Activity Editor Samples"
 * (program 210, unpublished) has one lesson holding a draft version with the sample activities — every kind, a
 * long page, a background image, an inline and a pinned action (activity-samples.ts). `ids.activitiesEditor` names it.
 * Reads only base ids, never touches ctx.rand, creates no org, user or group.
 */
import { lessonId } from '../base.js'
import type { FixtureContext } from '../context.js'
import { SAMPLE_POSTER_URL, SAMPLE_VIDEO_PLAYBACK_URL, sampleActivities, seedSampleMedia } from '../activity-samples.js'
import { ACTIVITIES_EDITOR_IDS as IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { videoDocument } from '../activity-documents.js'
import { type ActivitySeed, writeVersions } from '../lesson-content.js'

const MEDIA_BASE = 2_100_000
const ACTIVITY_BASE = 2_100_000
const VIDEO_2_BASE = 2_100_010
const VIDEO_2_KEY = 'fixture-editor-8'

/**
 * A second video in the draft with no poster: its page shows the video's still (D8), and the draft is its only use,
 * so both counts are 1 and Delete video everywhere is enabled (D11). The `ACTIVITY` usage row is keyed by the
 * activity key, as the app writes it.
 */
async function seedPosterlessVideo(ctx: FixtureContext): Promise<ActivitySeed> {
  const videoId = fixtureId('video', VIDEO_2_BASE)
  const mediaId = fixtureId('media', VIDEO_2_BASE + 3)
  await ctx.prisma.video.create({
    data: {
      id: videoId,
      title: 'Video 2',
      cloudflareUid: `fixture-video-samples-${VIDEO_2_BASE}`,
      playbackUrl: SAMPLE_VIDEO_PLAYBACK_URL,
      thumbnailUrl: SAMPLE_POSTER_URL,
      duration: 90,
      status: 'ready',
      userId: FIXTURE_USER_ID,
      createdAt: ctx.daysAgo(30),
    },
  })
  await ctx.prisma.media.create({
    data: {
      id: mediaId,
      title: 'Video 2',
      url: SAMPLE_VIDEO_PLAYBACK_URL,
      thumbnailUrl: SAMPLE_POSTER_URL,
      type: 'video',
      mimeType: 'video/mp4',
      videoId,
      organizationId: FIXTURE_ORG_ID,
      uploadedBy: FIXTURE_USER_ID,
    },
  })
  await ctx.prisma.mediaUsage.create({
    data: { id: fixtureId('mediaUsage', VIDEO_2_BASE + 3), mediaId, usageType: 'ACTIVITY', resourceId: VIDEO_2_KEY, resourceName: 'Video 2' },
  })
  return {
    id: fixtureId('contentActivity', ACTIVITY_BASE + 8),
    activityKey: VIDEO_2_KEY,
    kind: 'video',
    title: 'Video 2',
    document: videoDocument(videoId),
    estimatedSeconds: 90,
  }
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.studyProgram.create({
    data: {
      id: IDS.programId,
      name: 'Activity Editor Samples',
      days: 1,
      creatorId: FIXTURE_USER_ID,
      leaderId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: ctx.daysAgo(1),
    },
  })
  await prisma.lesson.create({ data: { id: lessonId(210, 1), programId: IDS.programId, position: 1 } })
  const media = await seedSampleMedia(ctx, MEDIA_BASE)
  const video2 = await seedPosterlessVideo(ctx)
  await writeVersions(
    ctx,
    [
      {
        id: IDS.lessonVersionId,
        lessonId: IDS.lessonId,
        number: 1,
        status: 'DRAFT',
        title: 'Day 1',
        estimatedSeconds: 600,
        activities: [...sampleActivities(media, ACTIVITY_BASE, 'fixture-editor'), video2],
      },
    ],
    ctx.daysAgo(1)
  )
}
