/**
 * activities-editor layer (text-activity Task 17): the lesson the iPhone editor opens. "Activity Editor Samples"
 * (program 210, unpublished) has one lesson holding a draft version with the sample activities — every kind, a
 * long page, a background image, an inline and a pinned action (activity-samples.ts). `ids.activitiesEditor` names it.
 * Reads only base ids, never touches ctx.rand, creates no org, user or group.
 */
import { lessonId } from '../base.js'
import type { FixtureContext } from '../context.js'
import { sampleActivities, seedSampleMedia } from '../activity-samples.js'
import { ACTIVITIES_EDITOR_IDS as IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { writeVersions } from '../lesson-content.js'

const MEDIA_BASE = 2_100_000
const ACTIVITY_BASE = 2_100_000

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
        activities: sampleActivities(media, ACTIVITY_BASE, 'fixture-editor'),
      },
    ],
    ctx.daysAgo(1)
  )
}
