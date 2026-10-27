import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findUnique: vi.fn() },
  member: { findUnique: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/invite.js', () => ({ sendGroupInvite: vi.fn(), getInviteByToken: vi.fn() }))
vi.mock('../../services/permission.js', () => ({ canManageOrgContent: vi.fn() }))
vi.mock('../../services/membership-event.js', () => ({ recordMembershipEvent: vi.fn() }))

import { sendGroupInvite } from '../../services/invite.js'
import { canManageOrgContent } from '../../services/permission.js'
import invitesRoutes from '../invites.js'

const GROUP_ID = '123e4567-e89b-12d3-a456-426614174000'

function appAs(userId: string) {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { user: { id: userId, name: 'Leader' }, isAuthenticated: () => true })
    next()
  })
  app.use('/api/invites', invitesRoutes)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.group.findUnique.mockResolvedValue({ id: GROUP_ID, name: 'Prayer Team', organizationId: 'org1', creatorId: 'u1' })
  prismaMock.member.findUnique.mockResolvedValue(null)
  vi.mocked(canManageOrgContent).mockResolvedValue(true)
  vi.mocked(sendGroupInvite).mockResolvedValue({ success: true, inviteId: 'inv1', inviteUrl: 'http://x/join' })
})

describe('POST /api/invites/send recipientName (D8)', () => {
  it('passes the trimmed name to the service', async () => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123', recipientName: '  Ada Test  ' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, inviteId: 'inv1', inviteUrl: 'http://x/join', message: 'Invite sent successfully' })
    expect(vi.mocked(sendGroupInvite).mock.calls[0][6]).toBe('Ada Test')
  })

  it('still accepts a body without a name', async () => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123' })
    expect(res.status).toBe(200)
    expect(vi.mocked(sendGroupInvite).mock.calls[0][6]).toBeUndefined()
  })

  it.each([['empty after trim', '   '], ['101 characters', 'a'.repeat(101)]])('rejects a name that is %s', async (_label, name) => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123', recipientName: name })
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(sendGroupInvite).not.toHaveBeenCalled()
  })

  it('accepts exactly 100 characters', async () => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123', recipientName: 'a'.repeat(100) })
    expect(res.status).toBe(200)
  })
})
