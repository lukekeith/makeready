import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ group: { findMany: vi.fn() } }))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn(), getManageableOrgIds: vi.fn() }))

vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import { deriveAnalyticsScope, isEmptyScope } from '../analytics-scope.js'

beforeEach(() => {
  vi.clearAllMocks()
  permissionMock.isSuperAdmin.mockResolvedValue(false)
  permissionMock.getManageableOrgIds.mockResolvedValue(['org-1', 'org-2'])
  prismaMock.group.findMany.mockResolvedValue([{ id: 'own-group' }])
})

describe('deriveAnalyticsScope — unchanged analytics behaviour', () => {
  it('gives an API key the whole platform', async () => {
    expect(await deriveAnalyticsScope({ apiKeyId: 'key-1', userId: 'u1' })).toEqual({ all: true })
    expect(permissionMock.isSuperAdmin).not.toHaveBeenCalled()
  })

  it('returns null with no user', async () => {
    expect(await deriveAnalyticsScope({})).toBeNull()
  })

  it('gives a super admin the whole platform', async () => {
    permissionMock.isSuperAdmin.mockResolvedValue(true)
    expect(await deriveAnalyticsScope({ userId: 'u1' })).toEqual({ all: true })
  })

  it('gives anyone else their manageable orgs plus the active groups they created', async () => {
    expect(await deriveAnalyticsScope({ userId: 'u1' })).toEqual({
      all: false,
      orgIds: ['org-1', 'org-2'],
      groupIds: ['own-group'],
    })
    expect(prismaMock.group.findMany).toHaveBeenCalledWith({
      where: { creatorId: 'u1', isActive: true },
      select: { id: true },
    })
  })
})

describe('deriveAnalyticsScope — organizationId only narrows (D9)', () => {
  it('narrows an all-scope to the one org', async () => {
    expect(await deriveAnalyticsScope({ apiKeyId: 'k' }, { organizationId: 'org-9' })).toEqual({
      all: false,
      orgIds: ['org-9'],
      groupIds: [],
    })
  })

  it('narrows to an org the caller manages', async () => {
    expect(await deriveAnalyticsScope({ userId: 'u1' }, { organizationId: 'org-2' })).toEqual({
      all: false,
      orgIds: ['org-2'],
      groupIds: [],
    })
  })

  it('keeps only the created groups inside a foreign org', async () => {
    prismaMock.group.findMany
      .mockResolvedValueOnce([{ id: 'own-group' }, { id: 'other-own' }])
      .mockResolvedValueOnce([{ id: 'other-own' }])
    expect(await deriveAnalyticsScope({ userId: 'u1' }, { organizationId: 'org-x' })).toEqual({
      all: false,
      orgIds: [],
      groupIds: ['other-own'],
    })
    expect(prismaMock.group.findMany).toHaveBeenLastCalledWith({
      where: { id: { in: ['own-group', 'other-own'] }, organizationId: 'org-x' },
      select: { id: true },
    })
  })

  it('reads as an empty scope for an org wholly outside the caller', async () => {
    prismaMock.group.findMany.mockResolvedValueOnce([{ id: 'own-group' }]).mockResolvedValueOnce([])
    const scope = await deriveAnalyticsScope({ userId: 'u1' }, { organizationId: 'org-x' })
    expect(scope).not.toBeNull()
    expect(isEmptyScope(scope!)).toBe(true)
  })
})

describe('isEmptyScope', () => {
  it('is false for all, true for no orgs and no groups', () => {
    expect(isEmptyScope({ all: true })).toBe(false)
    expect(isEmptyScope({ all: false, orgIds: [], groupIds: [] })).toBe(true)
    expect(isEmptyScope({ all: false, orgIds: [], groupIds: ['g'] })).toBe(false)
  })
})
