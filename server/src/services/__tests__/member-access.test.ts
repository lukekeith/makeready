import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  organization: { findUnique: vi.fn() },
  userRole: { findFirst: vi.fn() },
  group: { findMany: vi.fn() },
  groupMember: { count: vi.fn() },
  memberOrganization: { count: vi.fn(), findMany: vi.fn() },
}))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import {
  ALL_MEMBERS_SYSTEM_ROLES,
  canAccessMember,
  canViewMember,
  memberAccessScope,
  visibleMemberOrgIds,
} from '../member-access.js'

/** o1 is owned by 'owner-1'; o2 by 'owner-2'. 'gl' created g-led in o1; 'gl2' created g-other in o1. */
const OWNER_OF: Record<string, string> = { o1: 'owner-1', o2: 'owner-2' }
const CREATED: Record<string, Record<string, string[]>> = { gl: { o1: ['g-led'] }, gl2: { o1: ['g-other'] } }

beforeEach(() => {
  vi.clearAllMocks()
  permissionMock.isSuperAdmin.mockResolvedValue(false)
  prismaMock.organization.findUnique.mockImplementation(async ({ where }: any) =>
    OWNER_OF[where.id] ? { ownerId: OWNER_OF[where.id] } : null
  )
  prismaMock.userRole.findFirst.mockResolvedValue(null)
  prismaMock.group.findMany.mockImplementation(async ({ where }: any) =>
    (CREATED[where.creatorId]?.[where.organizationId] ?? []).map((id) => ({ id }))
  )
  // m1 is active in g-led only.
  prismaMock.groupMember.count.mockImplementation(async ({ where }: any) =>
    where.memberId === 'm1' && where.groupId.in.includes('g-led') ? 1 : 0
  )
  prismaMock.memberOrganization.count.mockResolvedValue(1)
  prismaMock.memberOrganization.findMany.mockResolvedValue([{ organizationId: 'o1' }, { organizationId: 'o2' }])
})

describe('memberAccessScope (D7, F6)', () => {
  it('gives a super admin every member, without reading the org', async () => {
    permissionMock.isSuperAdmin.mockResolvedValue(true)
    expect(await memberAccessScope('anyone', 'o1')).toEqual({ all: true })
    expect(prismaMock.organization.findUnique).not.toHaveBeenCalled()
  })

  it('gives the org owner (Organization.ownerId) every member', async () => {
    expect(await memberAccessScope('owner-1', 'o1')).toEqual({ all: true })
    expect(prismaMock.userRole.findFirst).not.toHaveBeenCalled()
  })

  it('gives a holder of the SYSTEM Owner or Admin role every member', async () => {
    prismaMock.userRole.findFirst.mockResolvedValue({ id: 'ur-1' })
    expect(await memberAccessScope('admin-1', 'o1')).toEqual({ all: true })
    expect(prismaMock.userRole.findFirst).toHaveBeenCalledWith({
      where: { userId: 'admin-1', organizationId: 'o1', role: { isSystem: true, name: { in: ['Owner', 'Admin'] } } },
      select: { id: true },
    })
    expect([...ALL_MEMBERS_SYSTEM_ROLES]).toEqual(['Owner', 'Admin'])
  })

  it('narrows every other role — Group Leader, Contributor, custom — to the active groups they created in that org', async () => {
    expect(await memberAccessScope('gl', 'o1')).toEqual({ all: false, groupIds: ['g-led'] })
    expect(prismaMock.group.findMany).toHaveBeenCalledWith({
      where: { creatorId: 'gl', organizationId: 'o1', isActive: true },
      select: { id: true },
      orderBy: { id: 'asc' },
    })
  })

  it('gives a leader with no groups in that org an empty group list', async () => {
    expect(await memberAccessScope('gl', 'o2')).toEqual({ all: false, groupIds: [] })
  })
})

describe('canAccessMember', () => {
  it('all: the member belongs to the org', async () => {
    expect(await canAccessMember({ all: true }, 'm1', 'o1')).toBe(true)
    expect(prismaMock.memberOrganization.count).toHaveBeenCalledWith({ where: { memberId: 'm1', organizationId: 'o1' } })
    prismaMock.memberOrganization.count.mockResolvedValue(0)
    expect(await canAccessMember({ all: true }, 'm-foreign', 'o1')).toBe(false)
  })

  it('groups: an active membership in one of the scope groups, active and in the org', async () => {
    expect(await canAccessMember({ all: false, groupIds: ['g-led'] }, 'm1', 'o1')).toBe(true)
    expect(prismaMock.groupMember.count).toHaveBeenCalledWith({
      where: { memberId: 'm1', isActive: true, groupId: { in: ['g-led'] }, group: { isActive: true, organizationId: 'o1' } },
    })
    expect(await canAccessMember({ all: false, groupIds: ['g-other'] }, 'm1', 'o1')).toBe(false)
  })

  it('groups: no groups means no members, without a query', async () => {
    expect(await canAccessMember({ all: false, groupIds: [] }, 'm1', 'o1')).toBe(false)
    expect(prismaMock.groupMember.count).not.toHaveBeenCalled()
  })
})

describe('visibleMemberOrgIds — a member in two orgs', () => {
  it('self sees every org the member belongs to', async () => {
    expect(await visibleMemberOrgIds({ kind: 'self' }, 'm1')).toEqual(['o1', 'o2'])
    expect(prismaMock.memberOrganization.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1' },
      select: { organizationId: true },
      orderBy: { organizationId: 'asc' },
    })
  })

  it('an owner of one org sees the member only in that org', async () => {
    expect(await visibleMemberOrgIds({ kind: 'user', userId: 'owner-1' }, 'm1')).toEqual(['o1'])
  })

  it('a Group Leader sees the member in the org of the group they lead', async () => {
    expect(await visibleMemberOrgIds({ kind: 'user', userId: 'gl' }, 'm1')).toEqual(['o1'])
  })

  it('a Group Leader whose groups do not hold the member sees no org', async () => {
    expect(await visibleMemberOrgIds({ kind: 'user', userId: 'gl2' }, 'm1')).toEqual([])
  })
})

describe('canViewMember', () => {
  it('checks the named org, or any org when none is named', async () => {
    expect(await canViewMember('gl', 'm1', 'o1')).toBe(true)
    expect(await canViewMember('gl', 'm1', 'o2')).toBe(false)
    expect(await canViewMember('gl', 'm1')).toBe(true)
    expect(await canViewMember('gl2', 'm1')).toBe(false)
  })
})
