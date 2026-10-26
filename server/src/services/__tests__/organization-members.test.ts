import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ memberOrganization: { findMany: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../member-access.js', () => ({ memberAccessScope: vi.fn() }))

import { memberAccessScope } from '../member-access.js'
import { getOrganizationMembers, searchTokens } from '../organization.js'

const ORG = 'org-1'
const row = (id: string, joinedAt: string, groupCount: number) => ({
  joinedAt: new Date(joinedAt),
  member: {
    id,
    firstName: `F-${id}`,
    lastName: `L-${id}`,
    profilePicture: null,
    googlePicture: `https://g/${id}`,
    _count: { groupMemberships: groupCount },
  },
})
const activeIn = (group: Record<string, unknown>) => ({
  groupMemberships: { some: { isActive: true, group: { isActive: true, organizationId: ORG, ...group } } },
})
const tokenMatch = (t: string) => ({
  OR: [
    { firstName: { contains: t, mode: 'insensitive' } },
    { lastName: { contains: t, mode: 'insensitive' } },
    { email: { contains: t, mode: 'insensitive' } },
    { phoneNumber: { contains: t } },
  ],
})
const SELECT = {
  joinedAt: true,
  member: {
    select: {
      id: true,
      firstName: true,
      lastName: true,
      profilePicture: true,
      googlePicture: true,
      _count: {
        select: { groupMemberships: { where: { isActive: true, group: { isActive: true, organizationId: ORG } } } },
      },
    },
  },
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(memberAccessScope).mockResolvedValue({ all: true })
  prismaMock.memberOrganization.findMany.mockResolvedValue([
    row('m2', '2026-10-25T15:00:00Z', 2),
    row('m1', '2026-09-01T15:00:00Z', 1),
  ])
})

describe('searchTokens (D6 search)', () => {
  it('splits on any whitespace and drops empties', () => {
    expect(searchTokens('  jo   sm\tx ')).toEqual(['jo', 'sm', 'x'])
    expect(searchTokens('')).toEqual([])
    expect(searchTokens(undefined)).toEqual([])
  })
})

describe('getOrganizationMembers — Owner/Admin (all)', () => {
  it('queries member_organizations by joinedAt desc with an explicit select and maps the contract keys', async () => {
    const result = await getOrganizationMembers(ORG, 'owner-1')
    expect(memberAccessScope).toHaveBeenCalledWith('owner-1', ORG)
    expect(prismaMock.memberOrganization.findMany).toHaveBeenCalledWith({
      where: { organizationId: ORG, member: { AND: [{ isActive: true }] } },
      orderBy: [{ joinedAt: 'desc' }, { memberId: 'asc' }],
      select: SELECT,
    })
    expect(result).toEqual({
      success: true,
      viewerScope: { all: true, groupIds: [] },
      data: [
        { id: 'm2', firstName: 'F-m2', lastName: 'L-m2', profilePicture: null, googlePicture: 'https://g/m2', joinedAt: new Date('2026-10-25T15:00:00Z'), groupCount: 2 },
        { id: 'm1', firstName: 'F-m1', lastName: 'L-m1', profilePicture: null, googlePicture: 'https://g/m1', joinedAt: new Date('2026-09-01T15:00:00Z'), groupCount: 1 },
      ],
    })
  })

  it('AND-combines every search token with groupId and leaderId', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { search: 'jo sm', groupId: 'g1', leaderId: 'leader-9' })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({
      organizationId: ORG,
      member: {
        AND: [{ isActive: true }, tokenMatch('jo'), tokenMatch('sm'), activeIn({ id: 'g1' }), activeIn({ creatorId: 'leader-9' })],
      },
    })
  })

  it('drops the isActive filter with includeInactive', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { includeInactive: true })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({ organizationId: ORG, member: { AND: [] } })
  })

  it('lets the org constraint empty a foreign groupId (no special case needed)', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { groupId: 'g-other-org' })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where.member.AND).toContainEqual(activeIn({ id: 'g-other-org' }))
  })
})

describe('getOrganizationMembers — narrowed leader (D7, D15)', () => {
  beforeEach(() => {
    vi.mocked(memberAccessScope).mockResolvedValue({ all: false, groupIds: ['g-led'] })
  })

  it('limits the list to members of the caller’s groups and reports viewerScope', async () => {
    const result = await getOrganizationMembers(ORG, 'gl')
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({
      organizationId: ORG,
      member: { AND: [{ isActive: true }, activeIn({ id: { in: ['g-led'] } })] },
    })
    expect(result.viewerScope).toEqual({ all: false, groupIds: ['g-led'] })
  })

  it('accepts its own group and itself as leader', async () => {
    await getOrganizationMembers(ORG, 'gl', { groupId: 'g-led', leaderId: 'gl' })
    expect(prismaMock.memberOrganization.findMany).toHaveBeenCalledTimes(1)
  })

  it.each([
    ['a groupId outside its scope', { groupId: 'g-someone-else' }],
    ['a leaderId other than itself', { leaderId: 'other-leader' }],
  ])('answers %s with an empty list, without querying', async (_label, options) => {
    const result = await getOrganizationMembers(ORG, 'gl', options)
    expect(result).toEqual({ success: true, data: [], viewerScope: { all: false, groupIds: ['g-led'] } })
    expect(prismaMock.memberOrganization.findMany).not.toHaveBeenCalled()
  })

  it('answers a leader with no groups with an empty list', async () => {
    vi.mocked(memberAccessScope).mockResolvedValue({ all: false, groupIds: [] })
    const result = await getOrganizationMembers(ORG, 'gl')
    expect(result).toEqual({ success: true, data: [], viewerScope: { all: false, groupIds: [] } })
    expect(prismaMock.memberOrganization.findMany).not.toHaveBeenCalled()
  })
})

describe('getOrganizationMembers — failure', () => {
  it('reports instead of throwing', async () => {
    prismaMock.memberOrganization.findMany.mockRejectedValue(new Error('db down'))
    expect(await getOrganizationMembers(ORG, 'owner-1')).toEqual({ success: false, error: 'Failed to fetch members' })
  })
})
