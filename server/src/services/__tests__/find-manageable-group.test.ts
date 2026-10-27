import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  user: { findUnique: vi.fn() },
  organization: { findMany: vi.fn() },
  userRole: { findMany: vi.fn() },
  group: { findFirst: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { findManageableGroup } from '../permission.js'

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.user.findUnique.mockResolvedValue({ isSuperAdmin: false })
  prismaMock.organization.findMany.mockResolvedValue([{ id: 'o1' }])
  prismaMock.userRole.findMany.mockResolvedValue([])
  prismaMock.group.findFirst.mockResolvedValue({ id: 'g1', organizationId: 'o1' })
})

describe('findManageableGroup (ui2-groups-browse D9, D14, D15)', () => {
  it('resolves the active group through groupManageFilter', async () => {
    expect(await findManageableGroup('u1', 'g1')).toEqual({ id: 'g1', organizationId: 'o1' })
    expect(prismaMock.group.findFirst).toHaveBeenCalledWith({
      where: { id: 'g1', OR: [{ creatorId: 'u1' }, { organizationId: { in: ['o1'] } }], isActive: true },
      select: { id: true, organizationId: true },
    })
  })

  it('gives a super admin every active group', async () => {
    prismaMock.user.findUnique.mockResolvedValue({ isSuperAdmin: true })
    await findManageableGroup('admin', 'g9')
    expect(prismaMock.group.findFirst).toHaveBeenCalledWith({
      where: { id: 'g9', isActive: true },
      select: { id: true, organizationId: true },
    })
  })

  it('returns null outside the caller’s scope', async () => {
    prismaMock.group.findFirst.mockResolvedValue(null)
    expect(await findManageableGroup('u1', 'g-other')).toBeNull()
  })
})
