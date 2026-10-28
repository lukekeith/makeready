/**
 * ui2-programs D8/D13/D14/D15: the program service — template-less create, the list query and the
 * payload mapper. Prisma is stubbed.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  studyProgram: { create: vi.fn() },
  organization: { findMany: vi.fn() },
  userRole: { findMany: vi.fn() },
  user: { findUnique: vi.fn() },
}))
const permission = vi.hoisted(() => ({
  isSuperAdmin: vi.fn(),
  getManageableOrgIds: vi.fn(),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permission)

import {
  buildProgramListWhere,
  createBlankProgram,
  privateProgramVisibility,
  programListScope,
  toProgramPayload,
} from '../study-program.service.js'

beforeEach(() => {
  vi.clearAllMocks()
  permission.isSuperAdmin.mockResolvedValue(false)
  permission.getManageableOrgIds.mockResolvedValue([])
  prismaMock.organization.findMany.mockResolvedValue([])
  prismaMock.userRole.findMany.mockResolvedValue([])
  prismaMock.user.findUnique.mockResolvedValue({ organizationId: null })
})

describe('toProgramPayload (D15)', () => {
  it('maps creator and leader names and drops the relations', () => {
    const program = { id: 'p1', creator: { name: 'Luke Keith' }, leader: null }
    expect(toProgramPayload(program)).toEqual({
      id: 'p1',
      creatorName: 'Luke Keith',
      leaderName: null,
    })
  })

  it('reads missing relations as null names', () => {
    const program: { id: string; creator?: null } = { id: 'p1' }
    expect(toProgramPayload(program)).toEqual({ id: 'p1', creatorName: null, leaderName: null })
  })
})

describe('createBlankProgram (D8)', () => {
  it('creates an empty, unpublished program led by its creator', async () => {
    prismaMock.studyProgram.create.mockResolvedValue({ id: 'p9' })
    await createBlankProgram({ name: 'Walk', description: null, userId: 'u1', organizationId: 'o1' })
    const { data } = prismaMock.studyProgram.create.mock.calls[0][0]
    expect(data).toMatchObject({
      name: 'Walk',
      days: 0,
      isPublished: false,
      publishedAt: null,
      creatorId: 'u1',
      leaderId: 'u1',
      updatedById: 'u1',
      organizationId: 'o1',
    })
    expect(data.templateId).toBeUndefined()
  })
})

describe('programListScope (D14)', () => {
  it('is every manageable org plus the user\'s own org, de-duplicated', async () => {
    permission.getManageableOrgIds.mockResolvedValue(['o1', 'o2'])
    prismaMock.user.findUnique.mockResolvedValue({ organizationId: 'o2' })
    expect(await programListScope('u1')).toEqual(['o1', 'o2'])
  })

  it('adds the user\'s own org when they manage none', async () => {
    prismaMock.user.findUnique.mockResolvedValue({ organizationId: 'o3' })
    expect(await programListScope('u1')).toEqual(['o3'])
  })
})

describe('privateProgramVisibility (D13)', () => {
  it('lets a super admin see every private program', async () => {
    permission.isSuperAdmin.mockResolvedValue(true)
    expect(await privateProgramVisibility('u1')).toEqual({})
  })

  it('shows private programs only to creator, leader, org owner and Admin role-holders', async () => {
    prismaMock.organization.findMany.mockResolvedValue([{ id: 'own1' }])
    prismaMock.userRole.findMany.mockResolvedValue([{ organizationId: 'adm1' }])
    expect(await privateProgramVisibility('u1')).toEqual({
      OR: [
        { isPrivate: false },
        { creatorId: 'u1' },
        { leaderId: 'u1' },
        { organizationId: { in: ['own1', 'adm1'] } },
      ],
    })
    expect(prismaMock.userRole.findMany.mock.calls[0][0].where).toMatchObject({
      userId: 'u1',
      role: { name: { in: ['Owner', 'Admin'] } },
    })
  })

  it('a Group Leader with no owned or Admin org sees only their own private programs', async () => {
    expect(await privateProgramVisibility('u2')).toEqual({
      OR: [{ isPrivate: false }, { creatorId: 'u2' }, { leaderId: 'u2' }],
    })
  })
})

describe('buildProgramListWhere (D13/D14)', () => {
  it('scopes to the orgs plus own programs and composes privacy and filters with AND', () => {
    const where = buildProgramListWhere({
      userId: 'u1',
      orgIds: ['o1', 'o2'],
      privacy: { OR: [{ isPrivate: false }] },
      leaders: ['l1'],
    })
    expect(where).toEqual({
      AND: [
        { isActive: true },
        { OR: [{ organizationId: { in: ['o1', 'o2'] } }, { creatorId: 'u1' }] },
        { OR: [{ isPrivate: false }] },
        { OR: [{ leaderId: { in: ['l1'] } }, { creatorId: { in: ['l1'] } }] },
      ],
    })
  })

  it('narrows to one org and passes the other filters through', () => {
    const where = buildProgramListWhere({
      userId: 'u1',
      orgIds: ['o1', 'o2'],
      privacy: {},
      orgId: 'o2',
      tags: ['lent'],
      isPublished: true,
      groupId: 'g1',
    })
    expect(where.AND).toEqual(
      expect.arrayContaining([
        { organizationId: 'o2' },
        { tags: { some: { tag: { in: ['lent'] } } } },
        { isPublished: true },
        { enrollments: { some: { groupId: 'g1' } } },
      ]),
    )
    expect(where.AND).not.toContainEqual({})
  })

  it('leaves a super admin unscoped (orgIds null) and can include inactive programs', () => {
    const where = buildProgramListWhere({ userId: 'u1', orgIds: null, privacy: {}, includeInactive: true })
    expect(where).toEqual({ AND: [] })
  })

  it('keeps the single creatorId filter', () => {
    const where = buildProgramListWhere({ userId: 'u1', orgIds: ['o1'], privacy: {}, creatorId: 'c1' })
    expect(where.AND).toContainEqual({ creatorId: 'c1' })
  })

  it('scopes to own programs only when the user has no org', () => {
    const where = buildProgramListWhere({ userId: 'u1', orgIds: [], privacy: {} })
    expect(where.AND).toContainEqual({ creatorId: 'u1' })
  })
})
