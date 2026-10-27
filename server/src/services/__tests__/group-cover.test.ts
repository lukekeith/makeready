/**
 * group-cover-image D9/D10/D17/D19: the cover upload service. Prisma, R2 and sharp are mocked; the
 * service is real.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ group: { update: vi.fn() } }))
const storage = vi.hoisted(() => ({
  uploadImageVariants: vi.fn(),
  uploadToR2: vi.fn(),
  deleteFromR2: vi.fn(),
  extractKeyFromUrl: vi.fn((url: string) => url.replace('https://img.test/', '')),
}))
const sharpCalls = vi.hoisted(() => [] as Array<{ input: Buffer; ops: Array<[string, unknown[]]> }>)
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock }))
vi.mock('../storage.js', () => storage)
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const call = { input, ops: [] as Array<[string, unknown[]]> }
    sharpCalls.push(call)
    const chain: Record<string, unknown> = {}
    for (const op of ['resize', 'jpeg', 'rotate']) {
      chain[op] = vi.fn((...args: unknown[]) => { call.ops.push([op, args]); return chain })
    }
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from(`out:${input.toString()}`))
    chain.metadata = vi.fn(() =>
      input.toString() === 'bad' ? Promise.reject(new Error('unsupported image format')) : Promise.resolve({ format: 'jpeg', width: 10, height: 10 })
    )
    return chain
  }),
}))

import { CoverUploadError, saveGroupCover } from '../group-cover.js'

const b64 = (s: string) => Buffer.from(s).toString('base64')
const FRAMING = { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2, flipped: false, quarterTurns: 0 }
const group = (coverOriginalUrl: string | null = null) => ({ id: 'g1', coverOriginalUrl })
const written = () => prismaMock.group.update.mock.calls[0][0].data

beforeEach(() => {
  vi.clearAllMocks()
  sharpCalls.length = 0
  storage.uploadImageVariants.mockResolvedValue({ url: 'https://img.test/groups/group-g1-1.jpeg' })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  prismaMock.group.update.mockResolvedValue({})
})

describe('saveGroupCover', () => {
  it('a new pick stores the rendered cover, the re-encoded original and the framing in ONE write', async () => {
    const r = await saveGroupCover({ group: group(), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(prismaMock.group.update).toHaveBeenCalledTimes(1)
    expect(written()).toEqual({
      coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg',
      coverOriginalUrl: expect.stringMatching(/^https:\/\/img\.test\/groups\/group-g1-\d+-original\.jpeg$/),
      coverFraming: FRAMING,
    })
    expect(r).toMatchObject({ coverFraming: FRAMING, isNewImage: true })
    expect(r.coverOriginalUrl).toBe(written().coverOriginalUrl)
  })

  it('re-encodes the original: EXIF rotate, ≤ 2400px inside, JPEG 90, own key, no WebP ladder (D10, F9)', async () => {
    await saveGroupCover({ group: group(), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    const orig = sharpCalls.find((c) => c.input.toString() === 'orig' && c.ops.length > 0)!
    expect(orig.ops).toEqual([
      ['rotate', []],
      ['resize', [2400, 2400, { fit: 'inside', withoutEnlargement: true }]],
      ['jpeg', [{ quality: 90 }]],
    ])
    expect(storage.uploadToR2).toHaveBeenCalledTimes(1)
    expect(storage.uploadToR2.mock.calls[0][0]).toMatch(/^groups\/group-g1-\d+-original\.jpeg$/)
    expect(storage.uploadToR2.mock.calls[0][2]).toBe('image/jpeg')
  })

  it('framing without an original keeps the stored original (a re-edit)', async () => {
    const r = await saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render'), framing: FRAMING })
    expect(written().coverOriginalUrl).toBe('https://img.test/old-original.jpeg')
    expect(storage.uploadToR2).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
    expect(r.isNewImage).toBe(false)
  })

  it('a legacy body (no framing) clears the original and the framing (D9) and deletes the old original (D19)', async () => {
    const r = await saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render') })
    expect(written()).toEqual({ coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg', coverOriginalUrl: null, coverFraming: Prisma.DbNull })
    expect(r).toMatchObject({ coverOriginalUrl: null, coverFraming: null, isNewImage: true })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('old-original.jpeg')
  })

  it('a new original replaces the old one, deleted after the write (D19)', async () => {
    await saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('old-original.jpeg')
    expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(prismaMock.group.update.mock.invocationCallOrder[0])
  })

  it('a failed old-original delete is logged, never thrown (D19)', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    await expect(
      saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render') })
    ).resolves.toBeTruthy()
  })

  it('an original without framing is a 400 and nothing is uploaded (D10)', async () => {
    await expect(saveGroupCover({ group: group(), imageData: b64('render'), originalData: b64('orig') })).rejects.toMatchObject({ status: 400 })
    expect(storage.uploadImageVariants).not.toHaveBeenCalled()
  })

  it.each([
    ['the rendered cover', { imageData: b64('bad') }],
    ['the original', { imageData: b64('render'), framing: FRAMING, originalData: b64('bad') }],
  ])('an undecodable %s is a 400 and nothing is uploaded (D10)', async (_l, body) => {
    const err = await saveGroupCover({ group: group(), ...body }).catch((e) => e)
    expect(err).toBeInstanceOf(CoverUploadError)
    expect(err.status).toBe(400)
    expect(storage.uploadImageVariants).not.toHaveBeenCalled()
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('an R2 failure propagates and leaves the row unchanged (D10)', async () => {
    storage.uploadToR2.mockRejectedValue(new Error('r2 down'))
    await expect(
      saveGroupCover({ group: group(), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    ).rejects.toThrow('r2 down')
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('strips a data-URL prefix from either image', async () => {
    await saveGroupCover({ group: group(), imageData: `data:image/jpeg;base64,${b64('render')}`, framing: FRAMING, originalData: `data:image/jpeg;base64,${b64('orig')}` })
    expect(sharpCalls.some((c) => c.input.toString() === 'orig')).toBe(true)
    expect(sharpCalls.some((c) => c.input.toString() === 'render')).toBe(true)
  })
})
