/**
 * image-framing-editor D11: every profilePicture write other than the avatar upload clears the
 * stored original + framing and deletes the old original after the write, best-effort. The real
 * routes and the real updateMember / syncGoogleProfile run; Prisma and R2 are mocked.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn(), update: vi.fn() },
  user: { findUnique: vi.fn() },
}))
const storage = vi.hoisted(() => ({
  uploadMemberAvatar: vi.fn(),
  deleteMemberAvatar: vi.fn(),
  uploadToR2: vi.fn(),
  uploadImageVariants: vi.fn(),
  deleteFromR2: vi.fn(),
  extractKeyFromUrl: vi.fn((url: string) => url.replace('https://img.test/', '')),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => storage)
vi.mock('../../lib/activity-log.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../lib/activity-log.js')>()),
  logSuccess: vi.fn(),
}))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member-access.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-access.js')>()),
  canViewMember: vi.fn(),
}))

import { canViewMember } from '../../services/member-access.js'
import membersRoutes from '../members.js'

function appAsLeader() {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: {}, user: { id: 'gl', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'
const GOOGLE_PICTURE = 'https://lh3.googleusercontent.com/a/photo=s96-c'
const CLEARED = { profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull }
const memberRow = (over: Record<string, unknown> = {}) => ({
  id: 'm1',
  email: 'james.carter@example.org',
  profilePicture: 'https://img.test/avatars/members/m1/100.webp',
  profilePictureOriginalUrl: OLD_ORIGINAL,
  profilePictureFraming: { scale: 2, rotation: 0, offsetX: 0, offsetY: 0, flipped: false, quarterTurns: 0 },
  googleId: 'g-1',
  googlePicture: GOOGLE_PICTURE,
  organizations: [],
  ...over,
})
const written = () => prismaMock.member.update.mock.calls[0][0].data
const deletedAfterWrite = () => {
  expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
  expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(prismaMock.member.update.mock.invocationCallOrder[0])
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.member.findUnique.mockResolvedValue(memberRow())
  prismaMock.member.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => memberRow(data))
  prismaMock.user.findUnique.mockResolvedValue({ id: 'u1', picture: GOOGLE_PICTURE, googleId: 'g-1' })
  storage.deleteFromR2.mockResolvedValue(undefined)
  vi.mocked(canViewMember).mockResolvedValue(true)
})

describe('PATCH /api/members/:memberId with the profilePicture key (D11)', () => {
  it.each([['a URL', 'https://img.test/elsewhere.jpeg'], ['null', null]])('profilePicture = %s clears both', async (_l, value) => {
    const res = await request(appAsLeader()).patch('/api/members/m1').send({ profilePicture: value })
    expect(res.status).toBe(200)
    expect(written()).toMatchObject({ profilePicture: value, ...CLEARED })
    deletedAfterWrite()
  })

  it('a PATCH without the key leaves them alone and reads nothing extra', async () => {
    await request(appAsLeader()).patch('/api/members/m1').send({ firstName: 'Ann' })
    expect(written()).not.toHaveProperty('profilePictureOriginalUrl')
    expect(written()).not.toHaveProperty('profilePictureFraming')
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it.each([['profilePictureOriginalUrl', 'https://img.test/x.jpeg'], ['profilePictureFraming', { scale: 1 }]])(
    'a client cannot write %s (the PATCH zod stays strict)',
    async (key, value) => {
      const res = await request(appAsLeader()).patch('/api/members/m1').send({ [key]: value })
      expect(res.status).toBe(400)
      expect(prismaMock.member.update).not.toHaveBeenCalled()
    }
  )

  it('no stored original: clears, deletes nothing', async () => {
    prismaMock.member.findUnique.mockResolvedValue(memberRow({ profilePictureOriginalUrl: null }))
    await request(appAsLeader()).patch('/api/members/m1').send({ profilePicture: null })
    expect(written()).toMatchObject(CLEARED)
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('a failed delete is logged, the PATCH still answers 200', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    const res = await request(appAsLeader()).patch('/api/members/m1').send({ profilePicture: null })
    expect(res.status).toBe(200)
  })
})

describe('POST /api/members/:memberId/avatar/sync-google (D11)', () => {
  it('writes the Google picture and clears both', async () => {
    const res = await request(appAsLeader()).post('/api/members/m1/avatar/sync-google')
    expect(res.status).toBe(200)
    expect(written()).toMatchObject({ profilePicture: GOOGLE_PICTURE, ...CLEARED })
    deletedAfterWrite()
  })
})

describe('POST /api/members/:memberId/sync-google-profile (D11)', () => {
  it('writes the linked googlePicture and clears both', async () => {
    const res = await request(appAsLeader()).post('/api/members/m1/sync-google-profile')
    expect(res.status).toBe(200)
    expect(res.body.data.profilePicture).toBe(GOOGLE_PICTURE)
    expect(prismaMock.member.update.mock.calls[0][0]).toEqual({
      where: { id: 'm1' },
      data: { profilePicture: GOOGLE_PICTURE, ...CLEARED },
    })
    deletedAfterWrite()
  })
})
