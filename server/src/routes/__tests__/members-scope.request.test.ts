import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => ({ uploadMemberAvatar: vi.fn(), deleteMemberAvatar: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  // 401/403 stay the middleware's (unchanged); these tests are about D7 in the service.
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member.js')>()),
  getScopedMember: vi.fn(),
  getScopedMemberGroups: vi.fn(),
}))

import { getScopedMember, getScopedMemberGroups } from '../../services/member.js'
import membersRoutes from '../members.js'

function appAs(who: { userId?: string; memberId?: string }) {
  const app = express()
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const DATA = {
  id: 'm1',
  firstName: 'James',
  address: '100 Maple Ave\nChicago, IL 60614',
  emergencyContactName: 'Sophia Carter',
  emergencyContactPhone: '+15550200001',
  organizations: [],
  isGroupLeader: false,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getScopedMember).mockResolvedValue({ success: true, data: DATA as never })
  vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: true, data: [] })
})

describe('GET /api/members/:memberId (D7)', () => {
  it('scopes a user caller and returns the member with the new keys', async () => {
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1')
    expect(res.status).toBe(200)
    expect(getScopedMember).toHaveBeenCalledWith('m1', { kind: 'user', userId: 'gl' })
    expect(res.body).toEqual({ success: true, data: DATA })
  })

  it('404s a member outside the caller’s scope', async () => {
    vi.mocked(getScopedMember).mockResolvedValue({ success: false, error: 'Member not found' })
    const res = await request(appAs({ userId: 'gl2' })).get('/api/members/m1')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
  })

  it('reads a member session’s own record unscoped', async () => {
    await request(appAs({ memberId: 'm1' })).get('/api/members/m1')
    expect(getScopedMember).toHaveBeenCalledWith('m1', { kind: 'self' })
  })

  it('403s a caller that is neither the member nor a user', async () => {
    const res = await request(appAs({ memberId: 'm-other' })).get('/api/members/m1')
    expect(res.status).toBe(403)
    expect(getScopedMember).not.toHaveBeenCalled()
  })
})

describe('GET /api/members/:memberId/groups (D7, D16)', () => {
  it('scopes a user caller and keeps the existing body', async () => {
    vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: true, data: [{ id: 'g-led' } as never] })
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1/groups?includeInactive=true')
    expect(res.status).toBe(200)
    expect(getScopedMemberGroups).toHaveBeenCalledWith('m1', { kind: 'user', userId: 'gl' }, true)
    expect(res.body).toEqual({ success: true, data: [{ id: 'g-led' }], count: 1 })
  })

  it('404s outside the scope, 500s any other failure', async () => {
    vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: false, error: 'Member not found', notFound: true })
    expect((await request(appAs({ userId: 'gl2' })).get('/api/members/m1/groups')).status).toBe(404)
    vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: false, error: 'Failed to fetch groups' })
    expect((await request(appAs({ userId: 'gl' })).get('/api/members/m1/groups')).status).toBe(500)
  })

  it('reads a member session’s own groups unscoped', async () => {
    await request(appAs({ memberId: 'm1' })).get('/api/members/m1/groups')
    expect(getScopedMemberGroups).toHaveBeenCalledWith('m1', { kind: 'self' }, false)
  })
})
