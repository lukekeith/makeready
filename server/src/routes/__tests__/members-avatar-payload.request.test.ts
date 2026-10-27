/**
 * image-framing-editor §Contract row 2: GET /api/members/:memberId carries the avatar's original
 * URL and its framing, the framing read through parseStoredFraming (null when absent or bad).
 * The real getScopedMember runs; Prisma is mocked; the caller is the member's own session.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn() },
  memberOrganization: { findMany: vi.fn() },
  group: { count: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))

import membersRoutes from '../members.js'

function appAsSelf() {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: 'm1' } })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const FRAMING = { scale: 2, rotation: 10, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 1 }
const row = (over: Record<string, unknown> = {}) => ({
  id: 'm1',
  firstName: 'James',
  userId: null,
  profilePicture: 'https://img.test/avatars/members/m1/1.webp',
  profilePictureOriginalUrl: null,
  profilePictureFraming: null,
  organizations: [],
  ...over,
})
const get = () => request(appAsSelf()).get('/api/members/m1')

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.memberOrganization.findMany.mockResolvedValue([])
})

describe('GET /api/members/:memberId — avatar original + framing (§Contract row 2)', () => {
  it('returns both as null for a member with no stored original', async () => {
    prismaMock.member.findUnique.mockResolvedValue(row())
    const res = await get()
    expect(res.status).toBe(200)
    expect(res.body.data).toMatchObject({ profilePictureOriginalUrl: null, profilePictureFraming: null })
  })

  it('returns the stored original and the parsed framing', async () => {
    prismaMock.member.findUnique.mockResolvedValue(
      row({ profilePictureOriginalUrl: 'https://img.test/avatars/members/m1/1-original.jpeg', profilePictureFraming: FRAMING })
    )
    const res = await get()
    expect(res.body.data.profilePictureOriginalUrl).toBe('https://img.test/avatars/members/m1/1-original.jpeg')
    expect(res.body.data.profilePictureFraming).toEqual(FRAMING)
  })

  it('fills flipped / quarterTurns defaults on a stored framing that lacks them', async () => {
    prismaMock.member.findUnique.mockResolvedValue(
      row({ profilePictureFraming: { scale: 1.5, rotation: 0, offsetX: 0, offsetY: 0 } })
    )
    const res = await get()
    expect(res.body.data.profilePictureFraming).toEqual({
      scale: 1.5, rotation: 0, offsetX: 0, offsetY: 0, flipped: false, quarterTurns: 0,
    })
  })

  it.each([
    ['out of range', { ...FRAMING, scale: 99 }],
    ['an unknown key', { ...FRAMING, zoom: 2 }],
    ['not an object', 'junk'],
  ])('returns null for a stored framing that is %s', async (_label, stored) => {
    prismaMock.member.findUnique.mockResolvedValue(row({ profilePictureFraming: stored }))
    const res = await get()
    expect(res.status).toBe(200)
    expect(res.body.data.profilePictureFraming).toBeNull()
  })
})
