/**
 * image-framing-editor D8: the member avatar upload service. Prisma, R2 and sharp are mocked; the
 * service is real.
 */
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
const sharpCalls = vi.hoisted(() => [] as Array<{ input: Buffer; ops: Array<[string, unknown[]]> }>)
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../storage.js', () => storage)
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const call = { input, ops: [] as Array<[string, unknown[]]> }
    sharpCalls.push(call)
    const chain: Record<string, unknown> = {}
    for (const op of ['resize', 'jpeg', 'webp', 'rotate']) {
      chain[op] = vi.fn((...args: unknown[]) => { call.ops.push([op, args]); return chain })
    }
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from(`out:${input.toString()}`))
    chain.metadata = vi.fn(() =>
      input.toString() === 'bad' ? Promise.reject(new Error('unsupported image format')) : Promise.resolve({ format: 'jpeg', width: 10, height: 10 })
    )
    return chain
  }),
}))

import { ImageUploadError } from '../image-original.js'
import { MemberAvatarNotFoundError, parseFramingField, saveMemberAvatar } from '../member-avatar.js'

const FRAMING = { scale: 2, rotation: 10, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 1 }
const OLD_AVATAR = 'https://img.test/avatars/members/m1/100.webp'
const NEW_AVATAR = 'https://img.test/avatars/members/m1/200.webp'
const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'
const ORIGINAL_URL = /^https:\/\/img\.test\/avatars\/members\/m1\/\d+-original\.jpeg$/
const buf = (s: string) => Buffer.from(s)
const stored = (profilePictureOriginalUrl: string | null = OLD_ORIGINAL, profilePicture: string | null = OLD_AVATAR) => ({
  profilePicture,
  profilePictureOriginalUrl,
})
const written = () => prismaMock.member.update.mock.calls[0][0]
const opsFor = (input: string) => sharpCalls.find((c) => c.input.toString() === input && c.ops.length > 0)!.ops

beforeEach(() => {
  vi.clearAllMocks()
  sharpCalls.length = 0
  prismaMock.member.findUnique.mockResolvedValue(stored())
  prismaMock.member.update.mockResolvedValue({})
  storage.uploadMemberAvatar.mockResolvedValue({ success: true, url: NEW_AVATAR })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  storage.deleteMemberAvatar.mockResolvedValue(undefined)
})

describe('parseFramingField (D8)', () => {
  it('parses the JSON string and fills flipped / quarterTurns defaults', () => {
    expect(parseFramingField('{"scale":1,"rotation":0,"offsetX":0,"offsetY":0}')).toEqual({
      scale: 1, rotation: 0, offsetX: 0, offsetY: 0, flipped: false, quarterTurns: 0,
    })
    expect(parseFramingField(JSON.stringify(FRAMING))).toEqual(FRAMING)
  })

  it.each([
    ['not JSON', 'scale=2'],
    ['a JSON array', '[]'],
    ['an unknown key', JSON.stringify({ ...FRAMING, zoom: 2 })],
    ['a missing key', JSON.stringify({ scale: 1, rotation: 0, offsetX: 0 })],
    ['rotation beyond 45', JSON.stringify({ ...FRAMING, rotation: 46 })],
    ['quarterTurns 4', JSON.stringify({ ...FRAMING, quarterTurns: 4 })],
  ])('rejects %s with a 400', (_label, raw) => {
    const err = (() => { try { parseFramingField(raw) } catch (e) { return e } })()
    expect(err).toBeInstanceOf(ImageUploadError)
    expect((err as ImageUploadError).status).toBe(400)
  })
})

describe('saveMemberAvatar (D8)', () => {
  it('a new pick stores the avatar, the re-encoded original and the framing in ONE write', async () => {
    const r = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    expect(prismaMock.member.update).toHaveBeenCalledTimes(1)
    expect(written()).toEqual({
      where: { id: 'm1' },
      data: { profilePicture: NEW_AVATAR, profilePictureOriginalUrl: expect.stringMatching(ORIGINAL_URL), profilePictureFraming: FRAMING },
    })
    expect(r).toEqual({ url: NEW_AVATAR, originalUrl: written().data.profilePictureOriginalUrl, framing: FRAMING })
  })

  it('keeps the 512px WebP re-encode for the rendered avatar (D7)', async () => {
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })
    expect(opsFor('render')).toEqual([
      ['resize', [512, 512, { fit: 'cover', withoutEnlargement: true }]],
      ['webp', [{ quality: 85 }]],
    ])
    expect(storage.uploadMemberAvatar).toHaveBeenCalledWith('m1', buf('out:render'), 'image/webp')
  })

  it('re-encodes the original: EXIF rotate, ≤ 2400px inside, JPEG 90, under avatars/members/{id}/{ts}-original.jpeg', async () => {
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    expect(opsFor('orig')).toEqual([
      ['rotate', []],
      ['resize', [2400, 2400, { fit: 'inside', withoutEnlargement: true }]],
      ['jpeg', [{ quality: 90 }]],
    ])
    expect(storage.uploadToR2).toHaveBeenCalledTimes(1)
    expect(storage.uploadToR2.mock.calls[0][0]).toMatch(/^avatars\/members\/m1\/\d+-original\.jpeg$/)
    expect(storage.uploadToR2.mock.calls[0][1]).toEqual(buf('out:orig'))
    expect(storage.uploadToR2.mock.calls[0][2]).toBe('image/jpeg')
  })

  it('framing alone is a re-edit: profilePictureOriginalUrl stays out of the write, the stored one is returned', async () => {
    const r = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING) })
    expect(written().data).toEqual({ profilePicture: NEW_AVATAR, profilePictureFraming: FRAMING })
    expect(r).toEqual({ url: NEW_AVATAR, originalUrl: OLD_ORIGINAL, framing: FRAMING })
    expect(storage.uploadToR2).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('framing alone with no stored original is a 400 and nothing is uploaded', async () => {
    prismaMock.member.findUnique.mockResolvedValue(stored(null))
    await expect(
      saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING) })
    ).rejects.toMatchObject({ status: 400 })
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('no framing (the web, 1.0-era callers) clears the original and the framing and deletes the old original', async () => {
    const r = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })
    expect(written().data).toEqual({ profilePicture: NEW_AVATAR, profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull })
    expect(r).toEqual({ url: NEW_AVATAR, originalUrl: null, framing: null })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
  })

  it('a new original replaces the old one, deleted after the write; the old avatar is deleted too', async () => {
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    const writeOrder = prismaMock.member.update.mock.invocationCallOrder[0]
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
    expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(writeOrder)
    expect(storage.deleteMemberAvatar).toHaveBeenCalledWith(OLD_AVATAR)
    expect(storage.deleteMemberAvatar.mock.invocationCallOrder[0]).toBeGreaterThan(writeOrder)
  })

  it('a member with no avatar yet deletes nothing', async () => {
    prismaMock.member.findUnique.mockResolvedValue(stored(null, null))
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    expect(storage.deleteMemberAvatar).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('a failed old-original delete is logged, never thrown', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })).resolves.toMatchObject({ url: NEW_AVATAR })
  })

  it('an original without framing is a 400 before anything is read or uploaded', async () => {
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), original: buf('orig') })).rejects.toMatchObject({ status: 400 })
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
  })

  it('a bad framing string is a 400 and nothing is uploaded', async () => {
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: '{nope' })).rejects.toBeInstanceOf(ImageUploadError)
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
  })

  it.each([
    ['the rendered avatar', { rendered: buf('bad') }],
    ['the original', { rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('bad') }],
  ])('an undecodable %s is a 400 and nothing is uploaded', async (_l, body) => {
    const err = await saveMemberAvatar({ memberId: 'm1', ...body }).catch((e) => e)
    expect(err).toBeInstanceOf(ImageUploadError)
    expect(err.status).toBe(400)
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a missing member is a 404', async () => {
    prismaMock.member.findUnique.mockResolvedValue(null)
    const err = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render') }).catch((e) => e)
    expect(err).toBeInstanceOf(MemberAvatarNotFoundError)
    expect(err.status).toBe(404)
  })

  it('an R2 failure on the original propagates and leaves the row unchanged', async () => {
    storage.uploadToR2.mockRejectedValue(new Error('r2 down'))
    await expect(
      saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    ).rejects.toThrow('r2 down')
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a failed avatar upload propagates and leaves the row unchanged', async () => {
    storage.uploadMemberAvatar.mockResolvedValue({ success: false, error: 'Internal error uploading avatar' })
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })).rejects.toThrow('Internal error uploading avatar')
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
