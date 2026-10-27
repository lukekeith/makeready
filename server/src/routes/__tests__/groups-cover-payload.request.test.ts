/**
 * group-cover-image D17: every groups payload (POST, GET list, GET /:id, PATCH) carries coverOriginalUrl +
 * coverFraming. Prisma and every side-effecting service are stubbed; the router is real.
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
vi.mock('../../services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/storage.js')>()),
  uploadImageVariants: vi.fn().mockResolvedValue({ url: 'https://img.test/groups/group-g1.jpeg' }),
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
  default: vi.fn(() => {
    const chain = { resize: vi.fn(), jpeg: vi.fn(), toBuffer: vi.fn().mockResolvedValue(Buffer.from('jpeg')) }
    chain.resize.mockReturnValue(chain)
    chain.jpeg.mockReturnValue(chain)
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
  coverOriginalUrl: 'https://img.test/o.jpeg',
  coverFraming: { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2, flipped: false, quarterTurns: 0 },
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

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.organization.findMany.mockResolvedValue([])
})

const COVER = { coverOriginalUrl: 'https://img.test/o.jpeg', coverFraming: { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2, flipped: false, quarterTurns: 0 } }

describe('group payloads carry the cover fields (§Contract row 2)', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.findMany.mockResolvedValue([row()])
    prismaMock.group.create.mockResolvedValue(row())
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
    prismaMock.organization.findMany.mockResolvedValue([{ id: 'org1', name: 'Grace' }])
  })

  it('GET /api/groups', async () => {
    const res = await request(app()).get('/api/groups')
    expect(res.status).toBe(200)
    expect(res.body.groups[0]).toMatchObject({ ...COVER, organizationName: 'Grace' })
  })

  it('GET /api/groups/:id', async () => {
    const res = await request(app()).get('/api/groups/g1')
    expect(res.body.group).toMatchObject(COVER)
  })

  it('PATCH /api/groups/:id', async () => {
    const res = await request(app()).patch('/api/groups/g1').send({ name: 'Renamed' })
    expect(res.body.group).toMatchObject({ ...COVER, name: 'Renamed' })
  })

  it('POST /api/groups', async () => {
    const res = await request(app()).post('/api/groups').send({ name: 'Prayer Team' })
    expect(res.status).toBe(200)
    expect(res.body.group).toMatchObject(COVER)
  })
})
