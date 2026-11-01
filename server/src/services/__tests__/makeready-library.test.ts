/** media-library D6: the MakeReady org and its system owner. Prisma is stubbed. */
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  user: { upsert: vi.fn() },
  organization: { upsert: vi.fn(), findUnique: vi.fn(), findMany: vi.fn() },
  userRole: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import {
  MAKEREADY_ORG_ID,
  MAKEREADY_SYSTEM_USER_ID,
  ensureMakeReadyOrg,
  isMakeReadyOrg,
  resetMakeReadyOrgCache,
} from '../makeready-library.js'
import { getUserOrganizations } from '../organization.js'

beforeEach(() => {
  vi.clearAllMocks()
  resetMakeReadyOrgCache()
})

describe('ensureMakeReadyOrg', () => {
  it('upserts a disabled system owner, then the flagged org it owns, by fixed ids', async () => {
    const out = await ensureMakeReadyOrg()
    expect(out).toEqual({ orgId: MAKEREADY_ORG_ID, userId: MAKEREADY_SYSTEM_USER_ID })
    const userCall = prismaMock.user.upsert.mock.calls[0][0]
    expect(userCall.where).toEqual({ id: MAKEREADY_SYSTEM_USER_ID })
    expect(userCall.create).toMatchObject({ isActive: false, name: 'MakeReady' })
    expect(userCall.update).toEqual({ isActive: false })
    const orgCall = prismaMock.organization.upsert.mock.calls[0][0]
    expect(orgCall.where).toEqual({ id: MAKEREADY_ORG_ID })
    expect(orgCall.create).toMatchObject({ isMakeReady: true, ownerId: MAKEREADY_SYSTEM_USER_ID, name: 'MakeReady' })
    expect(prismaMock.user.upsert.mock.invocationCallOrder[0]).toBeLessThan(
      prismaMock.organization.upsert.mock.invocationCallOrder[0],
    )
  })
})

describe('isMakeReadyOrg', () => {
  it('is true for the fixed id without a query, false for null', async () => {
    expect(await isMakeReadyOrg(MAKEREADY_ORG_ID)).toBe(true)
    expect(await isMakeReadyOrg(null)).toBe(false)
    expect(prismaMock.organization.findUnique).not.toHaveBeenCalled()
  })
  it('reads the flag once per org and memoizes it', async () => {
    prismaMock.organization.findUnique.mockResolvedValue({ isMakeReady: false })
    expect(await isMakeReadyOrg('org-a')).toBe(false)
    expect(await isMakeReadyOrg('org-a')).toBe(false)
    expect(prismaMock.organization.findUnique).toHaveBeenCalledTimes(1)
  })
})

describe('getUserOrganizations', () => {
  it('excludes the MakeReady org from owned and role-held lists', async () => {
    prismaMock.organization.findMany.mockResolvedValue([])
    prismaMock.userRole.findMany.mockResolvedValue([{ organizationId: 'org-b' }])
    await getUserOrganizations('u1')
    for (const [args] of prismaMock.organization.findMany.mock.calls) {
      expect(args.where.isMakeReady).toBe(false)
    }
  })
})
