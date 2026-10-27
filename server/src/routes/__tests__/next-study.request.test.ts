import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ group: { findFirst: vi.fn() }, lessonSchedule: { findFirst: vi.fn() } }))
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

const act = (over: Record<string, unknown>) => ({
  id: 'a',
  type: 'READ',
  orderNumber: 1,
  title: 'Activity',
  videoUrl: null,
  sourceReferences: [],
  versionId: null,
  youtubeThumbnailUrl: null,
  video: null,
  readBlocks: [],
  ...over,
})

const schedule = (over: Record<string, unknown> = {}) => ({
  id: 's1',
  code: 'XYZ123',
  title: 'Love one another',
  currentVersionId: 'v2',
  scheduledDate: new Date('2026-10-27T17:00:00Z'),
  lesson: {
    dayNumber: 14,
    studyProgram: { id: 'p1', name: 'Foundations of Faith', description: null, days: 21, coverImageUrl: null, requireResponse: false },
  },
  enrollment: { id: 'e1', requireResponse: false, startDate: new Date('2026-10-14T17:00:00Z'), endDate: new Date('2026-11-03T17:00:00Z') },
  scheduledActivities: [
    act({ id: 'a-old', versionId: 'v1', type: 'YOUTUBE', youtubeThumbnailUrl: 'https://img.test/old.jpg' }),
    act({ id: 'a1', versionId: 'v2', orderNumber: 1, type: 'YOUTUBE', youtubeThumbnailUrl: 'https://i.ytimg.com/vi/x/hqdefault.jpg' }),
    act({ id: 'a2', versionId: 'v2', orderNumber: 2, type: 'VIDEO', video: { thumbnailUrl: 'https://img.test/video.jpg' } }),
    act({ id: 'a3', versionId: 'v2', orderNumber: 3, type: 'READ', readBlocks: [{ backgroundImageUrl: 'https://img.test/read.jpg' }] }),
    act({ id: 'a4', versionId: 'v2', orderNumber: 4, type: 'USER_INPUT' }),
  ],
  ...over,
})

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.group.findFirst.mockResolvedValue({ id: 'g1' })
  prismaMock.lessonSchedule.findFirst.mockResolvedValue(schedule())
})

describe('GET /api/groups/:groupId/next-study (D17, SC5)', () => {
  it('adds study.title and per-activity thumbnailUrl, current version only', async () => {
    const res = await request(app()).get('/api/groups/g1/next-study')
    expect(res.status).toBe(200)
    expect(res.body.study.title).toBe('Love one another')
    expect(res.body.study.dayNumber).toBe(14)
    expect(res.body.study.activities.map((a: { id: string; thumbnailUrl: string | null }) => [a.id, a.thumbnailUrl])).toEqual([
      ['a1', 'https://i.ytimg.com/vi/x/hqdefault.jpg'],
      ['a2', 'https://img.test/video.jpg'],
      ['a3', 'https://img.test/read.jpg'],
      ['a4', null],
    ])
  })

  it('keeps the wire free of the thumbnail source fields', async () => {
    const res = await request(app()).get('/api/groups/g1/next-study')
    const first = res.body.study.activities[0]
    expect(first).not.toHaveProperty('youtubeThumbnailUrl')
    expect(first).not.toHaveProperty('video')
    expect(first).not.toHaveProperty('readBlocks')
    expect(first).toMatchObject({ id: 'a1', type: 'YOUTUBE', orderNumber: 1, title: 'Activity', videoUrl: null, versionId: 'v2' })
  })

  it('selects versionId and the three thumbnail sources', async () => {
    await request(app()).get('/api/groups/g1/next-study')
    const select = prismaMock.lessonSchedule.findFirst.mock.calls[0][0].include.scheduledActivities.select
    expect(select).toMatchObject({
      versionId: true,
      youtubeThumbnailUrl: true,
      video: { select: { thumbnailUrl: true } },
      readBlocks: {
        where: { backgroundImageUrl: { not: null } },
        orderBy: { orderNumber: 'asc' },
        take: 1,
        select: { backgroundImageUrl: true },
      },
    })
  })

  it('reads title null when the schedule has none', async () => {
    prismaMock.lessonSchedule.findFirst.mockResolvedValue(schedule({ title: null }))
    expect((await request(app()).get('/api/groups/g1/next-study')).body.study.title).toBeNull()
  })

  it('still answers 204 with nothing upcoming and 404 outside scope', async () => {
    prismaMock.lessonSchedule.findFirst.mockResolvedValue(null)
    expect((await request(app()).get('/api/groups/g1/next-study')).status).toBe(204)
    prismaMock.group.findFirst.mockResolvedValue(null)
    expect((await request(app()).get('/api/groups/g-other/next-study')).status).toBe(404)
  })
})
