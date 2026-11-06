/**
 * activity-new layer (program-lesson-add-activity D18): the program page's lesson rail and the
 * activity picker's strip. "Lesson Rail Samples" has three lessons with 2, 1 and 0 activities
 * (3, 5 and no estimated minutes) so the rail shows a full row, a short row and the "+" card
 * alone; "Single Lesson Study" has one empty lesson, where the lesson menu omits Delete lesson.
 * Reads only base ids and runs first among the screens (filename order); program indexes 200
 * and 201 are clear of base (1–2), search-home (lesson 7000) and groups-enroll-program (900,000+).
 */
import type { FixtureContext } from '../context.js'
import { activityId, lessonId } from '../base.js'
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
      { id: lessonId(RAIL_INDEX, 1), studyProgramId: LESSON_RAIL_PROGRAM_ID, dayNumber: 1, title: 'Day 1', estimatedMinutes: 3 },
      { id: lessonId(RAIL_INDEX, 2), studyProgramId: LESSON_RAIL_PROGRAM_ID, dayNumber: 2, title: 'Day 2', estimatedMinutes: 5 },
      { id: lessonId(RAIL_INDEX, 3), studyProgramId: LESSON_RAIL_PROGRAM_ID, dayNumber: 3, title: 'Day 3' },
      { id: lessonId(SINGLE_INDEX, 1), studyProgramId: SINGLE_LESSON_PROGRAM_ID, dayNumber: 1, title: 'Day 1' },
    ],
  })
  const read = (day: number, order: number) => ({
    id: activityId(RAIL_INDEX, day, order),
    lessonId: lessonId(RAIL_INDEX, day),
    activityType: 'READ' as const,
    orderNumber: order,
    title: 'Read',
    referenceTitle: `John ${day}`,
    readContent: `Read John ${day} slowly, twice.`,
  })
  await prisma.lessonActivity.createMany({
    data: [
      read(1, 1),
      {
        id: activityId(RAIL_INDEX, 1, 2),
        lessonId: lessonId(RAIL_INDEX, 1),
        activityType: 'USER_INPUT' as const,
        orderNumber: 2,
        title: 'Reflect',
        placeholder: 'What stood out to you today?',
      },
      read(2, 1),
    ],
  })
}
