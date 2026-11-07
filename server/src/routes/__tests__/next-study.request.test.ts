import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findFirst: vi.fn() },
  scheduledLesson: { findFirst: vi.fn() },
  media: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  groupManageFilter: vi.fn().mockResolvedValue({ organizationId: 'org1' }),
}))

import enrollmentsRoutes from '../enrollments.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api', enrollmentsRoutes)
  return a
}

const doc = (background: object, content: object = { type: 'canvas' }) => ({ schemaVersion: 1, kind: 'text', background, content })

const act = (over: Record<string, unknown>) => ({
  id: 'a',
  kind: 'text',
  position: 1,
  title: 'Activity',
  document: doc({ color: '#000' }),
  ...over,
})

const schedule = (over: Record<string, unknown> = {}) => ({
  id: 's1',
  code: 'XYZ123',
  currentVersionId: 'v2',
  scheduledDate: new Date('2026-10-27T17:00:00Z'),
  lesson: { position: 14 },
  currentVersion: {
    title: 'Love one another',
    activities: [
      act({ id: 'a1', position: 1, document: doc({ image: { mediaId: 'm-bg' } }) }),
      act({ id: 'a2', position: 2, kind: 'video', document: doc({ color: '#000' }, { type: 'video', videoId: 'v', posterMediaId: 'm-poster' }) }),
      act({ id: 'a3', position: 3, kind: 'write' }),
    ],
  },
  enrollment: {
    id: 'e1',
    requireResponse: false,
    startDate: new Date('2026-10-14T17:00:00Z'),
    endDate: new Date('2026-11-03T17:00:00Z'),
    studyProgram: { id: 'p1', name: 'Foundations of Faith', description: null, days: 21, coverImageUrl: null, requireResponse: false },
  },
  ...over,
})

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.group.findFirst.mockResolvedValue({ id: 'g1' })
  prismaMock.scheduledLesson.findFirst.mockResolvedValue(schedule())
  prismaMock.media.findMany.mockResolvedValue([
    { id: 'm-bg', url: 'https://img.test/bg.jpg', type: 'photo', width: null, height: null, thumbnailUrl: null, duration: null, uploader: null, video: null },
    { id: 'm-poster', url: 'https://img.test/poster.jpg', type: 'photo', width: null, height: null, thumbnailUrl: null, duration: null, uploader: null, video: null },
  ])
})

describe('GET /api/groups/:groupId/next-study (§Contract)', () => {
  it('adds study.title and per-activity thumbnailUrl from the documents', async () => {
    const res = await request(app()).get('/api/groups/g1/next-study')
    expect(res.status).toBe(200)
    expect(res.body.study.title).toBe('Love one another')
    expect(res.body.study.dayNumber).toBe(14)
    expect(res.body.study.studyProgram).toMatchObject({ id: 'p1', name: 'Foundations of Faith' })
    expect(res.body.study.enrollment).toMatchObject({ id: 'e1', requireResponse: false })
    expect(res.body.study.activities.map((a: { id: string; thumbnailUrl: string | null }) => [a.id, a.thumbnailUrl])).toEqual([
      ['a1', 'https://img.test/bg.jpg'],
      ['a2', 'https://img.test/poster.jpg'],
      ['a3', null],
    ])
  })

  it('keeps today\'s activity keys with kind as type and position as orderNumber', async () => {
    const res = await request(app()).get('/api/groups/g1/next-study')
    expect(res.body.study.activities[0]).toEqual({
      id: 'a1', type: 'text', orderNumber: 1, title: 'Activity', videoUrl: null, sourceReferences: [], thumbnailUrl: 'https://img.test/bg.jpg',
    })
  })

  it('asks only for lessons that are not removed and are today or later', async () => {
    await request(app()).get('/api/groups/g1/next-study')
    const where = prismaMock.scheduledLesson.findFirst.mock.calls[0][0].where
    expect(where).toMatchObject({ enrollment: { groupId: 'g1' }, removedAt: null })
    expect(where.scheduledDate.gte).toBeInstanceOf(Date)
  })

  it('reads title null when the version has none', async () => {
    prismaMock.scheduledLesson.findFirst.mockResolvedValue(schedule({ currentVersion: { title: null, activities: [] } }))
    expect((await request(app()).get('/api/groups/g1/next-study')).body.study.title).toBeNull()
  })

  it('still answers 204 with nothing upcoming and 404 outside scope', async () => {
    prismaMock.scheduledLesson.findFirst.mockResolvedValue(null)
    expect((await request(app()).get('/api/groups/g1/next-study')).status).toBe(204)
    prismaMock.group.findFirst.mockResolvedValue(null)
    expect((await request(app()).get('/api/groups/g-other/next-study')).status).toBe(404)
  })
})
