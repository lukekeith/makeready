import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findMany: vi.fn() },
  organization: { findMany: vi.fn().mockResolvedValue([]) },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  groupManageFilter: vi.fn().mockResolvedValue({ organizationId: 'org1' }),
}))

import groupsRoutes from '../groups.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api/groups', groupsRoutes)
  return a
}

const base = {
  code: 'ABC123', description: null, coverImageUrl: null, isPrivate: false, allowInvites: true,
  memberDirectoryEnabled: true, welcomeMessage: null, ageRangeMin: null, ageRangeMax: null,
  maxMembers: null, _count: { members: 3 }, createdAt: new Date(), updatedAt: new Date(),
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.group.findMany.mockResolvedValue([
    { ...base, id: 'g1', name: 'Prayer Team', creatorId: 'u1', creator: { name: 'Tony Stark' } },
    { ...base, id: 'g2', name: 'Youth', creatorId: 'u2', creator: null },
  ])
})

describe('GET /api/groups creatorName (D9)', () => {
  it('returns the creator name, or null', async () => {
    const res = await request(app()).get('/api/groups')
    expect(res.status).toBe(200)
    expect(res.body.groups.map((g: { creatorName: string | null }) => g.creatorName)).toEqual(['Tony Stark', null])
    expect(res.body.groups[0].creatorId).toBe('u1')
    expect(res.body.groups[0].memberCount).toBe(3)
  })

  it('asks Prisma for the creator name only', async () => {
    await request(app()).get('/api/groups')
    expect(prismaMock.group.findMany.mock.calls[0][0].include.creator).toEqual({ select: { name: true } })
  })
})
