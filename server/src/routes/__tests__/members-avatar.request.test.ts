/**
 * image-framing-editor D8/D14/D16 + F4: POST /api/members/:memberId/avatar over HTTP — the real
 * requireMemberOrOrgOwner, the real D16 gate, the real multer instance and the real member-avatar
 * service. Prisma, R2, sharp, the permission lookups and canViewMember are mocked.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ member: { findUnique: vi.fn(), update: vi.fn() } }))
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
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  isSuperAdmin: vi.fn(),
  getManageableOrgIds: vi.fn(),
}))
vi.mock('../../services/member-access.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-access.js')>()),
  canViewMember: vi.fn(),
}))
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const chain: Record<string, unknown> = {}
    for (const op of ['resize', 'jpeg', 'webp', 'rotate']) chain[op] = vi.fn(() => chain)
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from(`out:${input.toString()}`))
    chain.metadata = vi.fn(() =>
      input.toString() === 'bad' ? Promise.reject(new Error('unsupported image format')) : Promise.resolve({ format: 'jpeg', width: 10, height: 10 })
    )
    return chain
  }),
}))

import { getManageableOrgIds, isSuperAdmin } from '../../services/permission.js'
import { canViewMember } from '../../services/member-access.js'
import membersRoutes from '../members.js'

type Who = { userId?: string; memberId?: string }
function appAs(who: Who) {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const SELF: Who = { memberId: 'm1' }
const LEADER: Who = { userId: 'gl' }
const STRANGER: Who = { userId: 'other' }
const FRAMING = { scale: 2, rotation: 10, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 1 }
const OLD_AVATAR = 'https://img.test/avatars/members/m1/100.webp'
const NEW_AVATAR = 'https://img.test/avatars/members/m1/200.webp'
const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'
const JPEG = { filename: 'avatar.jpg', contentType: 'image/jpeg' }
const member = (over: Record<string, unknown> = {}) => ({
  id: 'm1',
  profilePicture: OLD_AVATAR,
  profilePictureOriginalUrl: OLD_ORIGINAL,
  organizations: [{ organizationId: 'o1', organization: { ownerId: 'owner-1' } }],
  ...over,
})
const post = (who: Who = SELF) => request(appAs(who)).post('/api/members/m1/avatar')
const written = () => prismaMock.member.update.mock.calls[0][0].data

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.member.findUnique.mockResolvedValue(member())
  prismaMock.member.update.mockResolvedValue({})
  storage.uploadMemberAvatar.mockResolvedValue({ success: true, url: NEW_AVATAR })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  storage.deleteMemberAvatar.mockResolvedValue(undefined)
  vi.mocked(isSuperAdmin).mockResolvedValue(false)
  vi.mocked(getManageableOrgIds).mockResolvedValue(['o1'])
  vi.mocked(canViewMember).mockResolvedValue(true)
})

describe('POST /api/members/:memberId/avatar — bodies (D8, D14)', () => {
  it('file + framing + original: stores both and answers {success, data: {url, originalUrl, framing}}', async () => {
    const res = await post()
      .attach('file', Buffer.from('render'), JPEG)
      .field('framing', JSON.stringify(FRAMING))
      .attach('original', Buffer.from('orig'), { filename: 'original.jpg', contentType: 'image/jpeg' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({
      success: true,
      data: { url: NEW_AVATAR, originalUrl: expect.stringMatching(/^https:\/\/img\.test\/avatars\/members\/m1\/\d+-original\.jpeg$/), framing: FRAMING },
    })
    expect(written()).toMatchObject({ profilePicture: NEW_AVATAR, profilePictureFraming: FRAMING })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
    expect(storage.deleteMemberAvatar).toHaveBeenCalledWith(OLD_AVATAR)
  })

  it('framing alone keeps the stored original (a re-edit)', async () => {
    const res = await post().attach('file', Buffer.from('render'), JPEG).field('framing', JSON.stringify(FRAMING))
    expect(res.status).toBe(200)
    expect(res.body.data).toEqual({ url: NEW_AVATAR, originalUrl: OLD_ORIGINAL, framing: FRAMING })
    expect(written()).not.toHaveProperty('profilePictureOriginalUrl')
    expect(storage.uploadToR2).not.toHaveBeenCalled()
  })

  it('file alone (the web path) clears the original and the framing; data.url is kept', async () => {
    const res = await post().attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: { url: NEW_AVATAR, originalUrl: null, framing: null } })
    expect(written()).toEqual({ profilePicture: NEW_AVATAR, profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull })
  })

  it('D14: the web field name `avatar` uploads the same way', async () => {
    const res = await post().attach('avatar', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(res.body.data.url).toBe(NEW_AVATAR)
    expect(storage.uploadMemberAvatar).toHaveBeenCalledWith('m1', Buffer.from('out:render'), 'image/webp')
  })

  it('a failed old-original delete still answers 200', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    const res = await post().attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
  })
})

describe('400s — nothing written', () => {
  it.each([
    ['no file', () => post().field('framing', JSON.stringify(FRAMING))],
    ['an original without framing', () => post().attach('file', Buffer.from('r'), JPEG).attach('original', Buffer.from('o'), JPEG)],
    ['framing that is not JSON', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', 'scale=2')],
    ['framing with an unknown key', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify({ ...FRAMING, zoom: 2 }))],
    ['framing out of range', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify({ ...FRAMING, scale: 9 }))],
    ['framing sent twice', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify(FRAMING)).field('framing', JSON.stringify(FRAMING))],
    ['an unexpected text field', () => post().attach('file', Buffer.from('r'), JPEG).field('caption', 'hi')],
    ['an unexpected file field', () => post().attach('photo', Buffer.from('r'), JPEG)],
    ['a second file part', () => post().attach('file', Buffer.from('r'), JPEG).attach('file', Buffer.from('r2'), JPEG)],
    ['a non-image file type', () => post().attach('file', Buffer.from('r'), { filename: 'a.pdf', contentType: 'application/pdf' })],
    ['an undecodable avatar', () => post().attach('file', Buffer.from('bad'), JPEG)],
    ['an undecodable original', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify(FRAMING)).attach('original', Buffer.from('bad'), JPEG)],
  ])('%s', async (_label, send) => {
    const res = await send()
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(typeof res.body.error).toBe('string')
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('framing alone with no stored original', async () => {
    prismaMock.member.findUnique.mockResolvedValue(member({ profilePictureOriginalUrl: null }))
    const res = await post().attach('file', Buffer.from('render'), JPEG).field('framing', JSON.stringify(FRAMING))
    expect(res.status).toBe(400)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})

describe('413 over 10MB per file, as JSON (F4)', () => {
  const big = Buffer.alloc(10 * 1024 * 1024 + 1, 1)

  it('the rendered avatar', async () => {
    const res = await post().attach('file', big, JPEG)
    expect(res.status).toBe(413)
    expect(res.headers['content-type']).toMatch(/application\/json/)
    expect(res.body.success).toBe(false)
  })

  it('the original', async () => {
    const res = await post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify(FRAMING)).attach('original', big, JPEG)
    expect(res.status).toBe(413)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a 6MB original (over the old 5MB limit) is accepted', async () => {
    const res = await post()
      .attach('file', Buffer.from('render'), JPEG)
      .field('framing', JSON.stringify(FRAMING))
      .attach('original', Buffer.alloc(6 * 1024 * 1024, 1), JPEG)
    expect(res.status).toBe(200)
  })
})

describe('who may replace an avatar (D6, D16)', () => {
  it('the member themself — no visibility check', async () => {
    const res = await post(SELF).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(canViewMember).not.toHaveBeenCalled()
  })

  it('a role-holder who can view the member', async () => {
    const res = await post(LEADER).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(canViewMember).toHaveBeenCalledWith('gl', 'm1')
  })

  it('a role-holder WITHOUT visibility gets 404 and nothing is uploaded (D16)', async () => {
    vi.mocked(canViewMember).mockResolvedValue(false)
    const res = await post(LEADER).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a non-manager gets 403', async () => {
    vi.mocked(getManageableOrgIds).mockResolvedValue([])
    const res = await post(STRANGER).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(403)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a member in no org can be changed only by themself', async () => {
    prismaMock.member.findUnique.mockResolvedValue(member({ organizations: [] }))
    expect((await post(LEADER).attach('file', Buffer.from('render'), JPEG)).status).toBe(403)
    expect((await post(SELF).attach('file', Buffer.from('render'), JPEG)).status).toBe(200)
  })
})

describe('500 — R2 failures leave the row unchanged', () => {
  it('the original upload fails', async () => {
    storage.uploadToR2.mockRejectedValue(new Error('r2 down'))
    const res = await post().attach('file', Buffer.from('render'), JPEG).field('framing', JSON.stringify(FRAMING)).attach('original', Buffer.from('orig'), JPEG)
    expect(res.status).toBe(500)
    expect(res.body.success).toBe(false)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('the avatar upload fails', async () => {
    storage.uploadMemberAvatar.mockResolvedValue({ success: false, error: 'Internal error uploading avatar' })
    const res = await post().attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(500)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
