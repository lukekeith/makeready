/**
 * ui2-programs D8 (SC4, SC6): POST /api/programs without a template creates a blank program; with a
 * template it is unchanged. Prisma and side-effecting services are stubbed; the router is real.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  studyProgram: { create: vi.fn() },
  lessonTemplate: { findFirst: vi.fn() },
  lesson: { createMany: vi.fn() },
  $transaction: vi.fn(),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/activity.js', () => ({ trackActivity: vi.fn() }))
vi.mock('../../services/media-library.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/media-library.js')>()),
  getUserOrgId: vi.fn().mockResolvedValue('org1'),
}))

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

beforeEach(() => vi.clearAllMocks())

describe('POST /api/programs without a template (D8)', () => {
  it('creates a blank program: trimmed name, days 0, unpublished, led by the caller', async () => {
    prismaMock.studyProgram.create.mockResolvedValue({
      id: 'p9',
      name: 'Walk',
      days: 0,
      creator: { name: 'Luke Keith' },
      leader: { name: 'Luke Keith' },
    })
    const res = await request(app()).post('/api/programs').send({ name: '  Walk  ', days: 30, isPublished: true })
    expect(res.status).toBe(200)
    expect(prismaMock.studyProgram.create.mock.calls[0][0].data).toMatchObject({
      name: 'Walk',
      days: 0,
      isPublished: false,
      creatorId: 'u1',
      leaderId: 'u1',
      organizationId: 'org1',
    })
    expect(prismaMock.$transaction).not.toHaveBeenCalled()
    expect(prismaMock.lessonTemplate.findFirst).not.toHaveBeenCalled()
    expect(res.body.program).toEqual({
      id: 'p9',
      name: 'Walk',
      days: 0,
      creatorName: 'Luke Keith',
      leaderName: 'Luke Keith',
    })
  })

  it('400s on a blank name', async () => {
    expect((await request(app()).post('/api/programs').send({ name: '   ' })).status).toBe(400)
    expect(prismaMock.studyProgram.create).not.toHaveBeenCalled()
  })

  it('still 404s when a templateId is sent and the template is missing', async () => {
    prismaMock.lessonTemplate.findFirst.mockResolvedValue(null)
    const res = await request(app())
      .post('/api/programs')
      .send({ name: 'X', templateId: '00000000-0000-4000-8000-000000000000' })
    expect(res.status).toBe(404)
    expect(prismaMock.studyProgram.create).not.toHaveBeenCalled()
  })
})
