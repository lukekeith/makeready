/**
 * What the enrollment layers need on the lesson-version model (text-activity Task 11): a published
 * ProgramVersion over a program's existing lessons, one PUBLISHED LessonVersion per lesson, optional
 * ContentActivity documents, and the ScheduledLesson rows an enroll writes (one per lesson, current version
 * = that lesson's version). Task 17 moves the rest of the fixtures; these helpers serve only the layers that
 * the Task 11 reads (enrollment home, feed) cover. Creates no org, user or group; wipe.ts removes it all
 * (group cascade → scheduled lessons, program cascade → versions, user cascade → media).
 */
import type { FixtureContext } from './context.js'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from './ids.js'

export interface ScheduledContentInput {
  /** Distinct per call: seeds every id this call creates. */
  seed: number
  programId: string
  enrollmentId: string
  /** The program's lessons, in position order, with the date each is scheduled. */
  lessons: Array<{ lessonId: string; scheduledDate: Date; title: string; estimatedSeconds?: number }>
  /** A slide per entry for the lesson at that 1-based position: `imageUrl` becomes the page's background image. */
  slides?: Record<number, Array<{ kind: string; title: string; imageUrl: string }>>
}

/** Publishes version 1 of `programId`, points the enrollment at it, and writes the scheduled lessons. */
export async function seedScheduledContent(ctx: FixtureContext, input: ScheduledContentInput): Promise<void> {
  const { prisma } = ctx
  const { seed } = input
  const programVersionId = fixtureId('programVersion', seed)
  const versionIdFor = (position: number) => fixtureId('lessonVersion', seed * 1000 + position)
  const publishedAt = ctx.daysAgo(30)

  await prisma.lessonVersion.createMany({
    data: input.lessons.map((l, i) => ({
      id: versionIdFor(i + 1),
      lessonId: l.lessonId,
      number: 1,
      status: 'PUBLISHED' as const,
      title: l.title,
      estimatedSeconds: l.estimatedSeconds ?? 1500,
      publishedAt,
    })),
  })
  await prisma.programVersion.create({
    data: {
      id: programVersionId,
      programId: input.programId,
      number: 1,
      publishedAt,
      lessons: { create: input.lessons.map((l, i) => ({ lessonId: l.lessonId, lessonVersionId: versionIdFor(i + 1), position: i + 1 })) },
    },
  })
  await prisma.studyProgram.update({ where: { id: input.programId }, data: { currentVersionId: programVersionId } })
  await prisma.enrollment.update({ where: { id: input.enrollmentId }, data: { programVersionId } })
  await prisma.scheduledLesson.createMany({
    data: input.lessons.map((l, i) => ({
      id: fixtureId('schedule', seed * 1000 + i + 1),
      enrollmentId: input.enrollmentId,
      lessonId: l.lessonId,
      currentVersionId: versionIdFor(i + 1),
      scheduledDate: l.scheduledDate,
    })),
  })

  let mediaN = 0
  for (const [position, slides] of Object.entries(input.slides ?? {})) {
    for (const [k, slide] of slides.entries()) {
      mediaN += 1
      const mediaId = fixtureId('media', seed * 1000 + mediaN)
      await prisma.media.create({
        data: { id: mediaId, title: slide.title, url: slide.imageUrl, type: 'photo', mimeType: 'image/jpeg', organizationId: FIXTURE_ORG_ID, uploadedBy: FIXTURE_USER_ID },
      })
      await prisma.contentActivity.create({
        data: {
          id: fixtureId('contentActivity', seed * 1000 + mediaN),
          lessonVersionId: versionIdFor(Number(position)),
          activityKey: `fixture-${seed}-${position}-${k + 1}`,
          position: k + 1,
          kind: slide.kind,
          title: slide.title,
          document: { schemaVersion: 1, background: { image: { mediaId } }, content: { type: slide.kind, objects: [] } },
        },
      })
    }
  }
}
