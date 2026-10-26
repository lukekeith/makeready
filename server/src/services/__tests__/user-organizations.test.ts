import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  organization: { findMany: vi.fn() },
  userRole: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { getUserOrganizations } from '../organization.js'

const org = (id: string, name: string, ownerId: string) => ({
  id,
  name,
  ownerId,
  isActive: true,
  twilioVerifyServiceSid: null,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
})

beforeEach(() => vi.clearAllMocks())

describe('getUserOrganizations (ui2-members-browse D18)', () => {
  it('lists the owned org first, then role-held orgs by name, without duplicates', async () => {
    prismaMock.organization.findMany
      .mockResolvedValueOnce([org('o-owned', 'Zion Church', 'u1')])
      .mockResolvedValueOnce([org('o-a', 'Alpha', 'x'), org('o-b', 'Beta', 'y')])
    prismaMock.userRole.findMany.mockResolvedValue([
      { organizationId: 'o-owned' },
      { organizationId: 'o-b' },
      { organizationId: 'o-a' },
      { organizationId: 'o-b' },
    ])

    const result = await getUserOrganizations('u1')

    expect(result.success).toBe(true)
    expect(result.data?.map((o) => o.id)).toEqual(['o-owned', 'o-a', 'o-b'])
    expect(prismaMock.organization.findMany).toHaveBeenNthCalledWith(1, {
      where: { ownerId: 'u1', isActive: true },
    })
    expect(prismaMock.userRole.findMany).toHaveBeenCalledWith({ where: { userId: 'u1' }, select: { organizationId: true } })
    expect(prismaMock.organization.findMany).toHaveBeenNthCalledWith(2, {
      where: { id: { in: ['o-b', 'o-a'] }, isActive: true },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
    })
  })

  it('serves a role-only leader (no owned org) — the D18 case', async () => {
    prismaMock.organization.findMany.mockResolvedValueOnce([]).mockResolvedValueOnce([org('o-a', 'Alpha', 'x')])
    prismaMock.userRole.findMany.mockResolvedValue([{ organizationId: 'o-a' }])
    expect((await getUserOrganizations('gl')).data?.map((o) => o.id)).toEqual(['o-a'])
  })

  it('returns an empty list, with no second org query, for a user in no org', async () => {
    prismaMock.organization.findMany.mockResolvedValueOnce([])
    prismaMock.userRole.findMany.mockResolvedValue([])
    expect(await getUserOrganizations('nobody')).toEqual({ success: true, data: [] })
    expect(prismaMock.organization.findMany).toHaveBeenCalledTimes(1)
  })

  it('reports a failure instead of throwing', async () => {
    prismaMock.organization.findMany.mockRejectedValue(new Error('db down'))
    prismaMock.userRole.findMany.mockResolvedValue([])
    expect(await getUserOrganizations('u1')).toEqual({ success: false, error: 'Failed to fetch organizations' })
  })
})
