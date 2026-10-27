import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  invite: { findMany: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/invite.js', () => ({ sendGroupInvite: vi.fn(), getInviteByToken: vi.fn() }))
vi.mock('../../services/permission.js', () => ({ canManageOrgContent: vi.fn().mockResolvedValue(true) }))
vi.mock('../../services/membership-event.js', () => ({ recordMembershipEvent: vi.fn() }))

import { getInviteByToken } from '../../services/invite.js'
import invitesRoutes from '../invites.js'

function app(authenticated: boolean) {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: authenticated ? { id: 'u1' } : undefined, isAuthenticated: () => authenticated })
    next()
  })
  a.use('/api/invites', invitesRoutes)
  return a
}

const created = new Date('2026-10-26T12:00:00Z')
const row = {
  id: 'inv1', token: 'TOK1', groupId: 'g1', inviterId: 'u1', recipientPhone: '+15555550123',
  recipientName: 'Tony Stark', status: 'pending', createdAt: created, expiresAt: null,
  group: { id: 'g1', name: 'Prayer Team', organizationId: 'org1', creatorId: 'u1' },
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.invite.findMany.mockResolvedValue([row])
  prismaMock.invite.findUnique.mockResolvedValue(row)
  prismaMock.invite.update.mockResolvedValue(row)
})

describe('recipientName on leader reads (D6)', () => {
  it('GET /api/invites returns it', async () => {
    const res = await request(app(true)).get('/api/invites')
    expect(res.status).toBe(200)
    expect(res.body.invites[0].recipientName).toBe('Tony Stark')
  })

  it('PATCH /api/invites/:id returns it', async () => {
    const res = await request(app(true)).patch('/api/invites/inv1').send({ status: 'expired' })
    expect(res.status).toBe(200)
    expect(res.body.invite.recipientName).toBe('Tony Stark')
  })

  it('GET /api/invites/:token never returns it', async () => {
    vi.mocked(getInviteByToken).mockResolvedValue({ success: true, invite: { ...row } } as never)
    const res = await request(app(false)).get('/api/invites/TOK1')
    expect(JSON.stringify(res.body)).not.toContain('recipientName')
    expect(JSON.stringify(res.body)).not.toContain('Tony Stark')
  })
})
