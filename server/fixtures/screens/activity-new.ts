/**
 * activity-new layer (program-lesson-add-activity D18): the program page's lesson rail and the
 * activity picker's strip. "Lesson Rail Samples" has three lessons with 2, 1 and 0 activities
 * (3, 5 and no estimated minutes) so the rail shows a full row, a short row and the "+" card
 * alone; "Single Lesson Study" has one empty lesson, where the lesson menu omits Delete lesson.
 * Reads only base ids and runs first among the screens (filename order); program indexes 200
 * and 201 are clear of base (1–2), search-home (lesson 7000) and groups-enroll-program (900,000+).
 */
import type { FixtureContext } from '../context.js'
import { textDocument, textObject, writeDocument } from '../activity-documents.js'
import { activityId, lessonId, lessonVersionId } from '../base.js'
import { type ActivitySeed, writeVersions } from '../lesson-content.js'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const LESSON_RAIL_PROGRAM_ID = fixtureId('program', 200)
export const SINGLE_LESSON_PROGRAM_ID = fixtureId('program', 201)

const RAIL_INDEX = 200
const SINGLE_INDEX = 201

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.studyProgram.createMany({
    data: [
      { id: LESSON_RAIL_PROGRAM_ID, name: 'Lesson Rail Samples', days: 3, createdAt: ctx.daysAgo(2) },
      { id: SINGLE_LESSON_PROGRAM_ID, name: 'Single Lesson Study', days: 1, createdAt: ctx.daysAgo(1) },
    ].map((p) => ({ ...p, creatorId: FIXTURE_USER_ID, leaderId: FIXTURE_USER_ID, organizationId: FIXTURE_ORG_ID })),
  })
  await prisma.lesson.createMany({
    data: [
      { id: lessonId(RAIL_INDEX, 1), programId: LESSON_RAIL_PROGRAM_ID, position: 1 },
      { id: lessonId(RAIL_INDEX, 2), programId: LESSON_RAIL_PROGRAM_ID, position: 2 },
      { id: lessonId(RAIL_INDEX, 3), programId: LESSON_RAIL_PROGRAM_ID, position: 3 },
      { id: lessonId(SINGLE_INDEX, 1), programId: SINGLE_LESSON_PROGRAM_ID, position: 1 },
    ],
  })
  const read = (day: number, order: number) => ({
    id: fixtureId('contentActivity', (RAIL_INDEX * 1000 + day) * 10 + order),
    activityKey: activityId(RAIL_INDEX, day, order),
    kind: 'text',
    title: 'Read',
    document: textDocument([textObject({ id: 'o1', text: `Read John ${day} slowly, twice.` })]),
  })
  const draft = (index: number, day: number, estimatedSeconds: number | null, activities: ActivitySeed[]) => ({
    id: lessonVersionId(index, day),
    lessonId: lessonId(index, day),
    number: 1,
    status: 'DRAFT' as const,
    title: 'Day ' + day,
    estimatedSeconds,
    activities,
  })
  // Drafts only: neither program is published, so the program page and the picker read the drafts.
  await writeVersions(
    ctx,
    [
      draft(RAIL_INDEX, 1, 180, [
        read(1, 1),
        {
          id: fixtureId('contentActivity', (RAIL_INDEX * 1000 + 1) * 10 + 2),
          activityKey: activityId(RAIL_INDEX, 1, 2),
          kind: 'write',
          title: 'Reflect',
          document: writeDocument('What stood out to you today?'),
        },
      ]),
      draft(RAIL_INDEX, 2, 300, [read(2, 1)]),
      draft(RAIL_INDEX, 3, null, []),
      draft(SINGLE_INDEX, 1, null, []),
    ],
    ctx.daysAgo(2)
  )
}
