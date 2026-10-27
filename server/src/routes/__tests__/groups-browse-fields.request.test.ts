/**
 * ui2-groups-browse D10, D11, SC1–SC3, SC7: the additive group payload fields, the D11 enum sync on
 * create / Boolean-only PATCH, and the cover upload's history row. Prisma and every side-effecting
 * service are stubbed; the router is real.
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
    const chain: Record<string, any> = {}
    for (const op of ['resize', 'jpeg', 'rotate']) chain[op] = vi.fn(() => chain)
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from('jpeg'))
    chain.metadata = vi.fn().mockResolvedValue({ format: 'jpeg', width: 1, height: 1 })
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

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.organization.findMany.mockResolvedValue([])
})

describe('GET /api/groups — org fields + memberDirectoryAccess (D10, D11)', () => {
  it('adds organizationId, organizationName and memberDirectoryAccess per group', async () => {
    prismaMock.group.findMany.mockResolvedValue([
      row(),
      row({ id: 'g2', organizationId: 'org2', memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' }),
      row({ id: 'g3', memberDirectoryAccess: 'NAMES_ONLY' }),
    ])
    prismaMock.organization.findMany.mockResolvedValue([
      { id: 'org1', name: 'Grace Church' },
      { id: 'org2', name: 'Hope Chapel' },
    ])
    const res = await request(app()).get('/api/groups')
    expect(res.status).toBe(200)
    expect(
      res.body.groups.map((g: Record<string, unknown>) => [g.organizationId, g.organizationName, g.memberDirectoryAccess])
    ).toEqual([
      ['org1', 'Grace Church', 'ALLOWED'],
      ['org2', 'Hope Chapel', 'NOT_ALLOWED'],
      ['org1', 'Grace Church', 'NAMES_ONLY'],
    ])
    expect(res.body.groups[0].creatorName).toBe('Tony Stark')
    expect(res.body.groups[1].memberDirectory).toBe(false)
  })

  it('reads org names in ONE batched query over the distinct ids', async () => {
    prismaMock.group.findMany.mockResolvedValue([row(), row({ id: 'g2', organizationId: 'org2' }), row({ id: 'g3' })])
    await request(app()).get('/api/groups')
    expect(prismaMock.organization.findMany).toHaveBeenCalledTimes(1)
    expect(prismaMock.organization.findMany).toHaveBeenCalledWith({
      where: { id: { in: ['org1', 'org2'] } },
      select: { id: true, name: true },
    })
  })

  it('reads organizationName null for an org that no longer exists, and skips the query for no groups', async () => {
    prismaMock.group.findMany.mockResolvedValue([row({ organizationId: 'gone' })])
    expect((await request(app()).get('/api/groups')).body.groups[0].organizationName).toBeNull()
    vi.clearAllMocks()
    prismaMock.group.findMany.mockResolvedValue([])
    expect((await request(app()).get('/api/groups')).body.groups).toEqual([])
    expect(prismaMock.organization.findMany).not.toHaveBeenCalled()
  })
})

describe('GET /api/groups/:id — creatorName + memberDirectoryAccess (D10, D11)', () => {
  it('returns the creator name and the enum, asking Prisma for the name only', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ memberDirectoryAccess: 'NAMES_ONLY' }))
    const res = await request(app()).get('/api/groups/g1')
    expect(res.status).toBe(200)
    expect(res.body.group.creatorName).toBe('Tony Stark')
    expect(res.body.group.memberDirectoryAccess).toBe('NAMES_ONLY')
    expect(prismaMock.group.findFirst.mock.calls[0][0].include.creator).toEqual({ select: { name: true } })
  })

  it('reads creatorName null when the creator row is gone', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ creator: null }))
    expect((await request(app()).get('/api/groups/g1')).body.group.creatorName).toBeNull()
  })
})

describe('POST /api/groups — D11 write + payload', () => {
  it('writes ALLOWED by default and returns creatorName + memberDirectoryAccess', async () => {
    prismaMock.group.create.mockResolvedValue(row({ name: 'Walk Test Group' }))
    const res = await request(app()).post('/api/groups').send({ name: 'Walk Test Group' })
    expect(res.status).toBe(200)
    const args = prismaMock.group.create.mock.calls[0][0]
    expect(args.data).toMatchObject({ memberDirectoryEnabled: true, memberDirectoryAccess: 'ALLOWED' })
    expect(args.include.creator).toEqual({ select: { name: true } })
    expect(res.body.group).toMatchObject({ creatorName: 'Tony Stark', memberDirectoryAccess: 'ALLOWED' })
  })

  it('writes NOT_ALLOWED when memberDirectory is false', async () => {
    prismaMock.group.create.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' }))
    await request(app()).post('/api/groups').send({ name: 'Quiet Group', memberDirectory: false })
    expect(prismaMock.group.create.mock.calls[0][0].data).toMatchObject({
      memberDirectoryEnabled: false,
      memberDirectoryAccess: 'NOT_ALLOWED',
    })
  })
})

describe('PATCH /api/groups/:id — D11 Boolean-only sync + payload', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
  })

  it('memberDirectory false → NOT_ALLOWED', async () => {
    prismaMock.group.update.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' }))
    const res = await request(app()).patch('/api/groups/g1').send({ memberDirectory: false })
    expect(res.status).toBe(200)
    const args = prismaMock.group.update.mock.calls[0][0]
    expect(args.data).toMatchObject({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' })
    expect(args.include.creator).toEqual({ select: { name: true } })
    expect(res.body.group).toMatchObject({ creatorName: 'Tony Stark', memberDirectoryAccess: 'NOT_ALLOWED' })
  })

  it('memberDirectory true → ALLOWED', async () => {
    prismaMock.group.update.mockResolvedValue(row())
    await request(app()).patch('/api/groups/g1').send({ memberDirectory: true })
    expect(prismaMock.group.update.mock.calls[0][0].data).toMatchObject({
      memberDirectoryEnabled: true,
      memberDirectoryAccess: 'ALLOWED',
    })
  })

  it('leaves the enum alone when memberDirectory is absent', async () => {
    prismaMock.group.update.mockResolvedValue(row({ name: 'Renamed' }))
    await request(app()).patch('/api/groups/g1').send({ name: 'Renamed' })
    expect(prismaMock.group.update.mock.calls[0][0].data).not.toHaveProperty('memberDirectoryAccess')
  })
})

describe('POST /api/groups/:id/cover-image — history row (SC7, D15)', () => {
  it('tracks UPDATED GROUP with metadata.field = "cover"', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.update.mockResolvedValue(row())
    const res = await request(app()).post('/api/groups/g1/cover-image').send({ imageData: 'aGVsbG8=' })
    expect(res.status).toBe(200)
    expect(res.body.coverImageUrl).toBe('https://img.test/groups/group-g1.jpeg')
    expect(trackActivity).toHaveBeenCalledWith({
      actorId: 'u1',
      action: 'UPDATED',
      resourceType: 'GROUP',
      resourceId: 'g1',
      resourceName: 'Prayer Team',
      organizationId: 'org1',
      groupId: 'g1',
      metadata: { field: 'cover' },
    })
  })
})
