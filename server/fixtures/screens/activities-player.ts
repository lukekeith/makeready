/**
 * activities-player layer (text-activity Task 17): the lesson the iPhone viewer plays. "Activity Player Samples"
 * (program 211, published) has one lesson with a published version 1 (`ids.activitiesPlayer.lessonVersionId`) holding
 * the sample activities — every kind, a long page, a background image, an inline and a pinned action — and a draft
 * version 2 on the same keys, so the draft read (D22) and the published read both have data.
 * Reads only base ids, never touches ctx.rand, creates no org, user or group.
 */
import { lessonId } from '../base.js'
import type { FixtureContext } from '../context.js'
import { sampleActivities, seedSampleMedia } from '../activity-samples.js'
import { ACTIVITIES_PLAYER_IDS as IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { publishProgramVersion, writeVersions } from '../lesson-content.js'

const MEDIA_BASE = 2_110_000
const PUBLISHED_ACTIVITY_BASE = 2_110_000
const DRAFT_ACTIVITY_BASE = 2_110_100

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.studyProgram.create({
    data: {
      id: IDS.programId,
      name: 'Activity Player Samples',
      days: 1,
      creatorId: FIXTURE_USER_ID,
      leaderId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      isPublished: true,
      publishedAt: ctx.daysAgo(3),
      createdAt: ctx.daysAgo(3),
    },
  })
  await prisma.lesson.create({ data: { id: lessonId(211, 1), programId: IDS.programId, position: 1 } })
  const media = await seedSampleMedia(ctx, MEDIA_BASE)
  await publishProgramVersion(ctx, {
    programId: IDS.programId,
    programVersionId: fixtureId('programVersion', 211),
    publishedAt: ctx.daysAgo(3),
    versions: [
      {
        id: IDS.lessonVersionId,
        lessonId: IDS.lessonId,
        number: 1,
        title: 'Day 1',
        estimatedSeconds: 600,
        activities: sampleActivities(media, PUBLISHED_ACTIVITY_BASE, 'fixture-player'),
      },
    ],
  })
  // The draft keeps the published keys, with a changed first page.
  await writeVersions(
    ctx,
    [
      {
        id: IDS.draftVersionId,
        lessonId: IDS.lessonId,
        number: 2,
        status: 'DRAFT',
        title: 'Day 1',
        estimatedSeconds: 600,
        basedOnVersionId: IDS.lessonVersionId,
        activities: sampleActivities(media, DRAFT_ACTIVITY_BASE, 'fixture-player', ' (draft)'),
      },
    ],
    ctx.daysAgo(1)
  )
}
