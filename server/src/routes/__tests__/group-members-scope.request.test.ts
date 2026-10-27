import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ groupMember: { findMany: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  findManageableGroup: vi.fn(),
}))
vi.mock('../../services/membership-event.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/membership-event.js')>()),
  getMembershipHistory: vi.fn(),
}))

import { findManageableGroup } from '../../services/permission.js'
import { getMembershipHistory } from '../../services/membership-event.js'
import groupMembersRoutes from '../group-members.js'

function appAs(user: { id?: string; isActive: boolean }) {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api/groups', groupMembersRoutes)
  return a
}
const leader = () => appAs({ id: 'u1', isActive: true })

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(findManageableGroup).mockResolvedValue({ id: 'g1', organizationId: 'org1' })
  prismaMock.groupMember.findMany.mockResolvedValue([
    {
      id: 'gm1',
      memberId: 'm1',
      groupId: 'g1',
      role: 'member',
      joinedAt: new Date('2026-10-01T15:00:00Z'),
      member: { firstName: 'James', lastName: 'Carter', profilePicture: null },
    },
  ])
  vi.mocked(getMembershipHistory).mockResolvedValue([{ id: 'me1' }] as never)
})

describe('GET /api/groups/:groupId/members (D9)', () => {
  it('lists members of a group the caller manages, shape unchanged', async () => {
    const res = await request(leader()).get('/api/groups/g1/members')
    expect(res.status).toBe(200)
    expect(findManageableGroup).toHaveBeenCalledWith('u1', 'g1')
    expect(res.body).toEqual({
      success: true,
      members: [
        { id: 'gm1', userId: 'm1', groupId: 'g1', role: 'MEMBER', name: 'James Carter', avatarUrl: null, joinedAt: '2026-10-01T15:00:00.000Z' },
      ],
    })
  })

  it('404s outside the caller’s manage scope, before reading members', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(leader()).get('/api/groups/g-other/members')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Group not found' })
    expect(prismaMock.groupMember.findMany).not.toHaveBeenCalled()
  })

  it('404s a caller with no user id', async () => {
    const res = await request(appAs({ isActive: true })).get('/api/groups/g1/members')
    expect(res.status).toBe(404)
    expect(findManageableGroup).not.toHaveBeenCalled()
  })
})

describe('GET /api/groups/:groupId/membership-history (D9)', () => {
  it('returns history for a group the caller manages', async () => {
    const res = await request(leader()).get('/api/groups/g1/membership-history?limit=10')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, events: [{ id: 'me1' }] })
    expect(getMembershipHistory).toHaveBeenCalledWith({ groupId: 'g1', search: undefined, action: undefined, limit: 10 })
  })

  it('404s outside the caller’s manage scope, before reading history', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(leader()).get('/api/groups/g-other/membership-history')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Group not found' })
    expect(getMembershipHistory).not.toHaveBeenCalled()
  })
})
