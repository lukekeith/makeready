import { describe, expect, it, vi } from 'vitest'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { lessonId } from '../base.js'
import { LESSON_RAIL_PROGRAM_ID, SINGLE_LESSON_PROGRAM_ID, full } from '../screens/activity-new.js'

function fakeCtx() {
  const prisma = {
    studyProgram: { createMany: vi.fn() },
    lesson: { createMany: vi.fn() },
    lessonActivity: { createMany: vi.fn() },
  }
  const ctx = { prisma, daysAgo: (n: number) => new Date(Date.UTC(2026, 10, 6 - n)) }
  return { prisma, ctx: ctx as unknown as Parameters<typeof full>[0] }
}

describe('activity-new fixture layer (program-lesson-add-activity D18)', () => {
  it('uses fixed program ids clear of the other layers', () => {
    expect(LESSON_RAIL_PROGRAM_ID).toBe(fixtureId('program', 200))
    expect(SINGLE_LESSON_PROGRAM_ID).toBe(fixtureId('program', 201))
  })

  it('creates both programs in the fixture org with the D18 day counts', async () => {
    const { prisma, ctx } = fakeCtx()
    await full(ctx)
    const rows = prisma.studyProgram.createMany.mock.calls[0][0].data
    expect(rows).toEqual([
      expect.objectContaining({ id: LESSON_RAIL_PROGRAM_ID, name: 'Lesson Rail Samples', days: 3, organizationId: FIXTURE_ORG_ID, creatorId: FIXTURE_USER_ID }),
      expect.objectContaining({ id: SINGLE_LESSON_PROGRAM_ID, name: 'Single Lesson Study', days: 1, organizationId: FIXTURE_ORG_ID, creatorId: FIXTURE_USER_ID }),
    ])
    expect(rows.every((r: { leaderId: string }) => r.leaderId === FIXTURE_USER_ID)).toBe(true)
  })

  it('gives the lessons the D18 minutes', async () => {
    const { prisma, ctx } = fakeCtx()
    await full(ctx)
    const rows = prisma.lesson.createMany.mock.calls[0][0].data
    expect(rows.map((l: { id: string; estimatedMinutes: number | null }) => [l.id, l.estimatedMinutes ?? null])).toEqual([
      [lessonId(200, 1), 3],
      [lessonId(200, 2), 5],
      [lessonId(200, 3), null],
      [lessonId(201, 1), null],
    ])
  })

  it('gives lessons 2, 1 and 0 activities, and the single lesson none', async () => {
    const { prisma, ctx } = fakeCtx()
    await full(ctx)
    const rows = prisma.lessonActivity.createMany.mock.calls[0][0].data
    const count = (id: string) => rows.filter((a: { lessonId: string }) => a.lessonId === id).length
    expect([count(lessonId(200, 1)), count(lessonId(200, 2)), count(lessonId(200, 3)), count(lessonId(201, 1))]).toEqual([2, 1, 0, 0])
    expect(new Set(rows.map((a: { id: string }) => a.id)).size).toBe(rows.length)
  })
})
