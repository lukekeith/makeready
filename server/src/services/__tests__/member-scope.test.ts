import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn() },
  memberOrganization: { findMany: vi.fn(), count: vi.fn() },
  organization: { findUnique: vi.fn() },
  userRole: { findFirst: vi.fn() },
  group: { findMany: vi.fn(), count: vi.fn() },
  groupMember: { count: vi.fn(), findMany: vi.fn() },
}))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import { getScopedMember, getScopedMemberGroups } from '../member.js'

/** m1 belongs to o1 (owner-1) and o2 (owner-2); it is active in g-led (o1), which 'gl' created. */
const OWNER_OF: Record<string, string> = { o1: 'owner-1', o2: 'owner-2' }
const CREATED: Record<string, Record<string, string[]>> = { gl: { o1: ['g-led'] }, gl2: { o1: ['g-other'] } }
const orgRow = (id: string, name: string) => ({
  id: `mo-${id}`,
  memberId: 'm1',
  organizationId: id,
  joinedAt: new Date('2026-08-24T15:00:00Z'),
  createdAt: new Date('2026-08-24T15:00:00Z'),
  updatedAt: new Date('2026-08-24T15:00:00Z'),
  organization: { id, name, ownerId: OWNER_OF[id] },
})
const MEMBER = {
  id: 'm1',
  firstName: 'James',
  lastName: 'Carter',
  userId: 'u-linked',
  address: '100 Maple Ave\nChicago, IL 60614',
  emergencyContactName: 'Sophia Carter',
  emergencyContactPhone: '+15550200001',
  organizations: [orgRow('o1', 'Grace Church'), orgRow('o2', 'Hope Chapel')],
}
const MEMBERSHIP = {
  joinedAt: new Date('2026-09-01T15:00:00Z'),
  group: { id: 'g-led', name: 'Prayer Team', organizationId: 'o1', creator: { id: 'gl', name: 'Nathan Hughes', email: null, picture: null }, _count: { members: 3 } },
}

beforeEach(() => {
  vi.clearAllMocks()
  permissionMock.isSuperAdmin.mockResolvedValue(false)
  prismaMock.member.findUnique.mockResolvedValue(MEMBER)
  prismaMock.memberOrganization.findMany.mockResolvedValue([{ organizationId: 'o1' }, { organizationId: 'o2' }])
  prismaMock.memberOrganization.count.mockResolvedValue(1)
  prismaMock.organization.findUnique.mockImplementation(async ({ where }: any) => ({ ownerId: OWNER_OF[where.id] }))
  prismaMock.userRole.findFirst.mockResolvedValue(null)
  prismaMock.group.findMany.mockImplementation(async ({ where }: any) =>
    (CREATED[where.creatorId]?.[where.organizationId] ?? []).map((id) => ({ id }))
  )
  prismaMock.groupMember.count.mockImplementation(async ({ where }: any) =>
    where.memberId === 'm1' && where.groupId.in.includes('g-led') ? 1 : 0
  )
  prismaMock.group.count.mockResolvedValue(1)
  prismaMock.groupMember.findMany.mockResolvedValue([MEMBERSHIP])
})

describe('getScopedMember (D7, D8, SC8)', () => {
  it('Owner of one org: sees the member, organizations[] keeps only that org, Role from the linked user', async () => {
    const result = await getScopedMember('m1', { kind: 'user', userId: 'owner-1' })
    expect(result.success).toBe(true)
    expect(result.data?.organizations.map((o) => o.organization.name)).toEqual(['Grace Church'])
    expect(result.data).toMatchObject({
      address: MEMBER.address,
      emergencyContactName: 'Sophia Carter',
      emergencyContactPhone: '+15550200001',
      isGroupLeader: true,
    })
    expect(prismaMock.group.count).toHaveBeenCalledWith({
      where: { creatorId: 'u-linked', isActive: true, organizationId: { in: ['o1'] } },
    })
  })

  it('super admin: every org of a multi-org member', async () => {
    permissionMock.isSuperAdmin.mockResolvedValue(true)
    const result = await getScopedMember('m1', { kind: 'user', userId: 'sa' })
    expect(result.data?.organizations.map((o) => o.organizationId)).toEqual(['o1', 'o2'])
  })

  it('Group Leader whose group holds the member: sees it in that org', async () => {
    const result = await getScopedMember('m1', { kind: 'user', userId: 'gl' })
    expect(result.success).toBe(true)
    expect(result.data?.organizations.map((o) => o.organizationId)).toEqual(['o1'])
  })

  it('Group Leader whose groups do not hold the member: not found (the route answers 404)', async () => {
    expect(await getScopedMember('m1', { kind: 'user', userId: 'gl2' })).toEqual({ success: false, error: 'Member not found' })
    expect(prismaMock.group.count).not.toHaveBeenCalled()
  })

  it('isGroupLeader is false, without a query, when no user is linked', async () => {
    prismaMock.member.findUnique.mockResolvedValue({ ...MEMBER, userId: null })
    const result = await getScopedMember('m1', { kind: 'user', userId: 'owner-1' })
    expect(result.data?.isGroupLeader).toBe(false)
    expect(prismaMock.group.count).not.toHaveBeenCalled()
  })

  it('isGroupLeader is false when the linked user created no active group in a visible org', async () => {
    prismaMock.group.count.mockResolvedValue(0)
    expect((await getScopedMember('m1', { kind: 'user', userId: 'owner-1' })).data?.isGroupLeader).toBe(false)
  })

  it('a member reading itself is unscoped: every org', async () => {
    const result = await getScopedMember('m1', { kind: 'self' })
    expect(result.data?.organizations.map((o) => o.organizationId)).toEqual(['o1', 'o2'])
    expect(prismaMock.organization.findUnique).not.toHaveBeenCalled()
  })

  it('a member with no org can still read itself', async () => {
    prismaMock.member.findUnique.mockResolvedValue({ ...MEMBER, organizations: [] })
    prismaMock.memberOrganization.findMany.mockResolvedValue([])
    const result = await getScopedMember('m1', { kind: 'self' })
    expect(result).toMatchObject({ success: true, data: { organizations: [], isGroupLeader: false } })
  })

  it('an unknown member is not found', async () => {
    prismaMock.member.findUnique.mockResolvedValue(null)
    expect(await getScopedMember('nope', { kind: 'user', userId: 'owner-1' })).toEqual({ success: false, error: 'Member not found' })
  })
})

describe('getScopedMemberGroups (D16)', () => {
  it('limits a user to groups in the orgs they see the member in — every such group, not only their own', async () => {
    const result = await getScopedMemberGroups('m1', { kind: 'user', userId: 'gl' })
    expect(prismaMock.groupMember.findMany.mock.calls[0][0].where).toEqual({
      memberId: 'm1',
      isActive: true,
      group: { isActive: true, organizationId: { in: ['o1'] } },
    })
    expect(result).toMatchObject({ success: true, data: [{ id: 'g-led', memberCount: 3 }] })
  })

  it('keeps the org filter with includeInactive', async () => {
    await getScopedMemberGroups('m1', { kind: 'user', userId: 'gl' }, true)
    expect(prismaMock.groupMember.findMany.mock.calls[0][0].where).toEqual({
      memberId: 'm1',
      group: { organizationId: { in: ['o1'] } },
    })
  })

  it('is not found outside the caller’s scope, without reading groups', async () => {
    expect(await getScopedMemberGroups('m1', { kind: 'user', userId: 'gl2' })).toEqual({
      success: false,
      error: 'Member not found',
      notFound: true,
    })
    expect(prismaMock.groupMember.findMany).not.toHaveBeenCalled()
  })

  it('a member reading itself is unchanged: no org filter', async () => {
    await getScopedMemberGroups('m1', { kind: 'self' })
    expect(prismaMock.groupMember.findMany.mock.calls[0][0].where).toEqual({
      memberId: 'm1',
      isActive: true,
      group: { isActive: true },
    })
  })
})
