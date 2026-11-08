import { describe, expect, it, vi } from 'vitest'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { lessonId } from '../base.js'
import { LESSON_RAIL_PROGRAM_ID, SINGLE_LESSON_PROGRAM_ID, full } from '../screens/activity-new.js'

function fakeCtx() {
  const prisma = {
    studyProgram: { createMany: vi.fn() },
    lesson: { createMany: vi.fn() },
    lessonVersion: { createMany: vi.fn() },
    contentActivity: { createMany: vi.fn() },
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

  it('gives the lessons the D18 minutes, as draft versions', async () => {
    const { prisma, ctx } = fakeCtx()
    await full(ctx)
    const lessons = prisma.lesson.createMany.mock.calls[0][0].data
    expect(lessons.map((l: { id: string; position: number }) => [l.id, l.position])).toEqual([
      [lessonId(200, 1), 1],
      [lessonId(200, 2), 2],
      [lessonId(200, 3), 3],
      [lessonId(201, 1), 1],
    ])
    const versions = prisma.lessonVersion.createMany.mock.calls[0][0].data
    expect(versions.map((v: { lessonId: string; status: string; estimatedSeconds: number | null }) => [v.lessonId, v.status, v.estimatedSeconds])).toEqual([
      [lessonId(200, 1), 'DRAFT', 180],
      [lessonId(200, 2), 'DRAFT', 300],
      [lessonId(200, 3), 'DRAFT', null],
      [lessonId(201, 1), 'DRAFT', null],
    ])
  })

  it('gives lessons 2, 1 and 0 activities, and the single lesson none', async () => {
    const { prisma, ctx } = fakeCtx()
    await full(ctx)
    const versions = prisma.lessonVersion.createMany.mock.calls[0][0].data
    const versionOf = (id: string) => versions.find((v: { lessonId: string }) => v.lessonId === id).id
    const rows = prisma.contentActivity.createMany.mock.calls[0][0].data
    const count = (id: string) => rows.filter((a: { lessonVersionId: string }) => a.lessonVersionId === versionOf(id)).length
    expect([count(lessonId(200, 1)), count(lessonId(200, 2)), count(lessonId(200, 3)), count(lessonId(201, 1))]).toEqual([2, 1, 0, 0])
    expect(new Set(rows.map((a: { id: string }) => a.id)).size).toBe(rows.length)
    expect(rows.map((a: { kind: string }) => a.kind)).toEqual(['text', 'write', 'text'])
  })
})
