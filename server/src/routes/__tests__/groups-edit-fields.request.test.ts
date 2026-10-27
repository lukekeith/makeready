/**
 * ui2-groups-edit SC1–SC3 (D7, D8, D12): PATCH /api/groups/:id directory access + age range. Prisma and
 * every side-effecting service are stubbed; the router is real.
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

import { groupManageFilter } from '../../services/permission.js'

const patch = (body: Record<string, unknown>) => request(app()).patch('/api/groups/g1').send(body)
const updateData = () => prismaMock.group.update.mock.calls[0][0].data

describe('PATCH memberDirectoryAccess (SC1, D7)', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it.each([
    ['ALLOWED', true],
    ['NAMES_ONLY', false],
    ['NOT_ALLOWED', false],
  ])('%s writes the enum and the Boolean %s', async (access, enabled) => {
    const res = await patch({ memberDirectoryAccess: access })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ memberDirectoryAccess: access, memberDirectoryEnabled: enabled })
    expect(res.body.group).toMatchObject({ memberDirectoryAccess: access, memberDirectory: enabled })
  })

  it('rejects an unknown value with 400 and writes nothing', async () => {
    const res = await patch({ memberDirectoryAccess: 'SOMETIMES' })
    expect(res.status).toBe(400)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('400s when memberDirectory disagrees with memberDirectoryAccess', async () => {
    const res = await patch({ memberDirectory: true, memberDirectoryAccess: 'NAMES_ONLY' })
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'memberDirectory conflicts with memberDirectoryAccess' })
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('accepts both when they agree', async () => {
    const res = await patch({ memberDirectory: false, memberDirectoryAccess: 'NOT_ALLOWED' })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ memberDirectoryAccess: 'NOT_ALLOWED', memberDirectoryEnabled: false })
  })
})

describe('PATCH memberDirectory alone (SC3, D12)', () => {
  beforeEach(() => {
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it('false keeps a stored NAMES_ONLY', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NAMES_ONLY' }))
    const res = await patch({ name: 'Renamed', memberDirectory: false })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ name: 'Renamed', memberDirectoryEnabled: false, memberDirectoryAccess: 'NAMES_ONLY' })
  })

  it('false on a stored ALLOWED → NOT_ALLOWED', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    await patch({ memberDirectory: false })
    expect(updateData()).toMatchObject({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' })
  })

  it('true → ALLOWED, even from NAMES_ONLY', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NAMES_ONLY' }))
    await patch({ memberDirectory: true })
    expect(updateData()).toMatchObject({ memberDirectoryEnabled: true, memberDirectoryAccess: 'ALLOWED' })
  })

  it('leaves both columns alone when neither key is sent', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    await patch({ name: 'Renamed' })
    expect(updateData()).not.toHaveProperty('memberDirectoryAccess')
    expect(updateData()).not.toHaveProperty('memberDirectoryEnabled')
  })
})

describe('PATCH ageRange (SC2, D8)', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it('400s on min > max and writes nothing', async () => {
    const res = await patch({ ageRange: { min: 30, max: 20 } })
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'Minimum age must not exceed maximum age' })
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('accepts equal bounds', async () => {
    const res = await patch({ ageRange: { min: 30, max: 30 } })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ ageRangeMin: 30, ageRangeMax: 30 })
  })

  it('accepts a partial range (one bound null)', async () => {
    const res = await patch({ ageRange: { min: 30, max: null } })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ ageRangeMin: 30, ageRangeMax: null })
  })

  it('clears both bounds with ageRange: null', async () => {
    const res = await patch({ ageRange: null })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ ageRangeMin: null, ageRangeMax: null })
  })

  it('clears maxMembers and description with null', async () => {
    const res = await patch({ maxMembers: null })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ maxMembers: null })
    prismaMock.group.update.mockClear()
    await patch({ description: null })
    expect(updateData()).toMatchObject({ description: null })
  })
})

describe('PATCH scope', () => {
  it('404s for a caller who cannot manage the group (groupManageFilter finds nothing)', async () => {
    vi.mocked(groupManageFilter).mockResolvedValueOnce({ id: '__none__' } as never)
    prismaMock.group.findFirst.mockResolvedValue(null)
    const res = await patch({ memberDirectoryAccess: 'NAMES_ONLY' })
    expect(res.status).toBe(404)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })
})
