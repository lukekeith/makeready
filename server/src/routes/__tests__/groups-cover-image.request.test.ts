/**
 * group-cover-image D9/D10/D11/D18: POST /api/groups/:id/cover-image and the PATCH clearing. Prisma and
 * every side-effecting service are stubbed; the router and the group-cover service are real.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findMany: vi.fn(), findFirst: vi.fn(), create: vi.fn(), update: vi.fn() },
  organization: { findMany: vi.fn(), findUnique: vi.fn() },
  userRole: { findFirst: vi.fn() },
}))
const trackActivity = vi.hoisted(() => vi.fn())
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  groupManageFilter: vi.fn().mockResolvedValue({ organizationId: 'org1' }),
  isSuperAdmin: vi.fn().mockResolvedValue(false),
}))
vi.mock('../../services/activity.js', () => ({ trackActivity }))
vi.mock('../../services/organization.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/organization.js')>()),
  resolveUserOrganizationId: vi.fn().mockResolvedValue('org1'),
}))
vi.mock('../../lib/group-code.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../lib/group-code.js')>()),
  generateUniqueGroupCode: vi.fn().mockResolvedValue('ABC123'),
}))
const storage = vi.hoisted(() => ({
  uploadImageVariants: vi.fn(),
  uploadToR2: vi.fn(),
  deleteFromR2: vi.fn(),
}))
vi.mock('../../services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/storage.js')>()),
  ...storage,
  extractKeyFromUrl: (url: string) => url.replace('https://img.test/', ''),
}))
vi.mock('../../services/media-library.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/media-library.js')>()),
  captureToLibrary: vi.fn(),
}))
vi.mock('../../services/media-metadata.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/media-metadata.js')>()),
  extractImageMetadata: vi
    .fn()
    .mockResolvedValue({ width: 1, height: 1, aspectRatio: 1, dominantColor: null, fileHash: 'h', exifData: null }),
}))
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const chain: Record<string, any> = {}
    for (const op of ['resize', 'jpeg', 'rotate']) chain[op] = vi.fn(() => chain)
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from('jpeg'))
    chain.metadata = vi.fn(() =>
      input?.toString() === 'bad' ? Promise.reject(new Error('bad')) : Promise.resolve({ format: 'jpeg', width: 1, height: 1 })
    )
    return chain
  }),
}))

import groupsRoutes from '../groups.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api/groups', groupsRoutes)
  return a
}

const row = (over: Record<string, unknown> = {}) => ({
  id: 'g1',
  code: 'ABC123',
  name: 'Prayer Team',
  description: null,
  coverImageUrl: null,
  isPrivate: false,
  allowInvites: true,
  memberDirectoryEnabled: true,
  memberDirectoryAccess: 'ALLOWED',
  welcomeMessage: null,
  ageRangeMin: null,
  ageRangeMax: null,
  maxMembers: null,
  creatorId: 'u1',
  organizationId: 'org1',
  isActive: true,
  createdAt: new Date('2026-10-01T00:00:00Z'),
  updatedAt: new Date('2026-10-02T00:00:00Z'),
  _count: { members: 3 },
  creator: { name: 'Tony Stark' },
  ...over,
})

import { captureToLibrary } from '../../services/media-library.js'
import { Prisma } from '../../generated/prisma/index.js'

const b64 = (s: string) => Buffer.from(s).toString('base64')
const FRAMING = { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 }
const upload = (body: Record<string, unknown>) => request(app()).post('/api/groups/g1/cover-image').send(body)
const written = () => prismaMock.group.update.mock.calls[0][0].data

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.organization.findMany.mockResolvedValue([])
  storage.uploadImageVariants.mockResolvedValue({ url: 'https://img.test/groups/group-g1-1.jpeg' })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  prismaMock.group.findFirst.mockResolvedValue(row({ coverOriginalUrl: 'https://img.test/old-original.jpeg', coverFraming: FRAMING }))
  prismaMock.group.update.mockResolvedValue(row())
})

describe('POST /api/groups/:id/cover-image (D10)', () => {
  it('framing + original: stores both and answers flat', async () => {
    const res = await upload({ imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({
      success: true,
      coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg',
      coverOriginalUrl: expect.stringMatching(/-original\.jpeg$/),
      coverFraming: FRAMING,
    })
    expect(res.body).not.toHaveProperty('data')
  })

  it('framing only keeps the stored original', async () => {
    const res = await upload({ imageData: b64('render'), framing: FRAMING })
    expect(res.body.coverOriginalUrl).toBe('https://img.test/old-original.jpeg')
  })

  it('the legacy body (imageData + contentType) clears both and still answers coverImageUrl top-level (D9)', async () => {
    const res = await upload({ imageData: b64('render'), contentType: 'image/jpeg' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg', coverOriginalUrl: null, coverFraming: null })
    expect(written()).toMatchObject({ coverOriginalUrl: null, coverFraming: Prisma.DbNull })
  })

  it.each([
    ['originalData without framing', { imageData: b64('r'), originalData: b64('o') }],
    ['a framing out of range', { imageData: b64('r'), framing: { ...FRAMING, scale: 9 } }],
    ['a framing with an unknown key', { imageData: b64('r'), framing: { ...FRAMING, flip: true } }],
    ['a framing missing a key', { imageData: b64('r'), framing: { scale: 1, rotation: 0, offsetX: 0 } }],
    ['an undecodable image', { imageData: b64('bad') }],
    ['no imageData', { framing: FRAMING }],
  ])('400 on %s, nothing written', async (_l, body) => {
    const res = await upload(body)
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('404 for a non-manager (groupManageFilter finds nothing, D14)', async () => {
    prismaMock.group.findFirst.mockResolvedValue(null)
    const res = await upload({ imageData: b64('render'), framing: FRAMING })
    expect(res.status).toBe(404)
  })

  it('500 on an R2 failure, row unchanged', async () => {
    storage.uploadImageVariants.mockRejectedValue(new Error('r2 down'))
    const res = await upload({ imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(res.status).toBe(500)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('D18: a new pick and a legacy upload capture the rendered cover; a re-edit captures nothing', async () => {
    await upload({ imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    await upload({ imageData: b64('render') })
    expect(captureToLibrary).toHaveBeenCalledTimes(2)
    expect(vi.mocked(captureToLibrary).mock.calls[0][0]).toMatchObject({ url: 'https://img.test/groups/group-g1-1.jpeg', usageType: 'GROUP_COVER' })
    vi.mocked(captureToLibrary).mockClear()
    await upload({ imageData: b64('render'), framing: FRAMING })
    expect(captureToLibrary).not.toHaveBeenCalled()
  })

  it('records the cover history row on every save', async () => {
    await upload({ imageData: b64('render'), framing: FRAMING })
    expect(trackActivity).toHaveBeenCalledWith(expect.objectContaining({ metadata: { field: 'cover' } }))
  })
})

describe('PATCH clears the original and framing with the coverImageUrl key (D9)', () => {
  beforeEach(() => {
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it.each([['a URL', 'https://img.test/other.jpeg'], ['null', null]])('coverImageUrl = %s', async (_l, value) => {
    await request(app()).patch('/api/groups/g1').send({ coverImageUrl: value })
    expect(written()).toMatchObject({ coverImageUrl: value, coverOriginalUrl: null, coverFraming: Prisma.DbNull })
  })

  it('a PATCH without the key leaves them alone', async () => {
    await request(app()).patch('/api/groups/g1').send({ name: 'Renamed' })
    expect(written()).not.toHaveProperty('coverOriginalUrl')
    expect(written()).not.toHaveProperty('coverFraming')
  })
})
