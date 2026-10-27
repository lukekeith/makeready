/**
 * image-framing-editor D11/D15: syncProfilePictureFromUrl (OAuth link, user link, the sync script)
 * copies the Google picture into R2 as the avatar and clears the stored original + framing.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
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
vi.mock('../storage.js', () => storage)

import { syncProfilePictureFromUrl } from '../account-linking.js'

const COPY = 'https://img.test/avatars/members/m1/300.jpg'
const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'

beforeEach(() => {
  vi.clearAllMocks()
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue(new Response(Buffer.from('img'), { status: 200, headers: { 'content-type': 'image/jpeg' } }))
  )
  storage.uploadMemberAvatar.mockResolvedValue({ success: true, url: COPY })
  storage.deleteFromR2.mockResolvedValue(undefined)
  prismaMock.member.findUnique.mockResolvedValue({ profilePictureOriginalUrl: OLD_ORIGINAL })
  prismaMock.member.update.mockResolvedValue({})
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('syncProfilePictureFromUrl (D11)', () => {
  it('writes the R2 copy and clears the original + framing, then deletes the old original', async () => {
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(true)
    expect(prismaMock.member.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: { profilePicture: COPY, profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull },
    })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
    expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(prismaMock.member.update.mock.invocationCallOrder[0])
  })

  it('no stored original: deletes nothing', async () => {
    prismaMock.member.findUnique.mockResolvedValue({ profilePictureOriginalUrl: null })
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(true)
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('a failed delete still returns true', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(true)
  })

  it('a failed download writes nothing', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('nope', { status: 404 })))
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(false)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
