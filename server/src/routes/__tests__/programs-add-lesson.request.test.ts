/**
 * ui2-programs D9: the Lessons `+` on a blank program (no template, no lessons) creates day 1 and
 * syncs `days` to the lesson count.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const tx = vi.hoisted(() => ({
  lesson: {
    aggregate: vi.fn(),
    create: vi.fn(),
    count: vi.fn(),
    findUnique: vi.fn(),
  },
  lessonActivity: { createMany: vi.fn(), findMany: vi.fn() },
  activityReadBlock: { createMany: vi.fn() },
  studyProgram: { update: vi.fn() },
}))
const prismaMock = vi.hoisted(() => ({
  studyProgram: { findFirst: vi.fn() },
  $transaction: vi.fn(),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  programManageFilter: vi.fn().mockResolvedValue({}),
}))
vi.mock('../../services/activity.js', () => ({ trackActivity: vi.fn() }))
vi.mock('../../services/lesson-estimate.service.js', () => ({ recalculateLessonEstimate: vi.fn() }))

import programsRoutes from '../programs.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key', isAuthenticated: () => true })
    next()
  })
  a.use('/api', programsRoutes)
  return a
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.studyProgram.findFirst.mockResolvedValue({ id: 'p1', name: 'Blank', days: 0, template: null })
  prismaMock.$transaction.mockImplementation((fn: (t: typeof tx) => unknown) => fn(tx))
  tx.lesson.aggregate.mockResolvedValue({ _max: { dayNumber: null } })
  tx.lesson.create.mockResolvedValue({ id: 'l1', dayNumber: 1 })
  tx.lesson.count.mockResolvedValue(1)
  tx.lesson.findUnique.mockResolvedValue({ id: 'l1', dayNumber: 1, activities: [] })
})

describe('POST /api/programs/:id/lessons on a blank program (D9)', () => {
  it('creates day 1 with no activities and sets days to 1', async () => {
    const res = await request(app()).post('/api/programs/p1/lessons').send({})
    expect(res.status).toBeLessThan(300)
    expect(tx.lesson.create.mock.calls[0][0].data).toMatchObject({ studyProgramId: 'p1', dayNumber: 1, title: null })
    expect(tx.lessonActivity.createMany).not.toHaveBeenCalled()
    expect(tx.studyProgram.update).toHaveBeenCalledWith({ where: { id: 'p1' }, data: { days: 1 } })
  })
})
