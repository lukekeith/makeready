/**
 * ui2-programs D13/D14/D15 (SC5): GET /api/programs scopes to every managed org, hides other leaders'
 * private programs, narrows by orgId, and carries org, names and the D12 settings per program.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  studyProgram: { findMany: vi.fn() },
  organization: { findMany: vi.fn() },
  userRole: { findMany: vi.fn() },
  user: { findUnique: vi.fn() },
  enrollment: { groupBy: vi.fn() },
}))
const permission = vi.hoisted(() => ({ isSuperAdmin: vi.fn(), getManageableOrgIds: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  ...permission,
}))

import programsRoutes from '../programs.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key', isAuthenticated: () => true })
    next()
  })
  a.use('/api', programsRoutes)
  return a
}

const row = {
  id: 'p1',
  name: 'Foundations',
  organizationId: 'o2',
  leaderId: 'l1',
  isPrivate: false,
  ageRangeMin: 18,
  ageRangeMax: 35,
  maxMembers: null,
  memberDirectoryAccess: 'ALLOWED',
  coverOriginalUrl: null,
  coverFraming: null,
  tags: [{ tag: 'lent' }],
  creator: { name: 'Luke Keith' },
  leader: { name: 'Nathan Reed' },
  _count: { enrollments: 3 },
}

beforeEach(() => {
  vi.clearAllMocks()
  permission.isSuperAdmin.mockResolvedValue(false)
  permission.getManageableOrgIds.mockResolvedValue(['o1', 'o2'])
  prismaMock.user.findUnique.mockResolvedValue({ organizationId: 'o1' })
  prismaMock.organization.findMany.mockImplementation(({ where }: any) =>
    where?.ownerId ? [] : [{ id: 'o2', name: 'Grace Church' }],
  )
  prismaMock.userRole.findMany.mockResolvedValue([])
  prismaMock.studyProgram.findMany.mockResolvedValue([row])
  prismaMock.enrollment.groupBy.mockResolvedValue([{ studyProgramId: 'p1', _count: { _all: 2 } }])
})

describe('GET /api/programs (D13/D14/D15)', () => {
  it('scopes to every managed org and hides private programs the caller neither created nor leads', async () => {
    const res = await request(app()).get('/api/programs')
    expect(res.status).toBe(200)
    const { where } = prismaMock.studyProgram.findMany.mock.calls[0][0]
    expect(where.AND).toContainEqual({ OR: [{ organizationId: { in: ['o1', 'o2'] } }, { creatorId: 'u1' }] })
    expect(where.AND).toContainEqual({ OR: [{ isPrivate: false }, { creatorId: 'u1' }, { leaderId: 'u1' }] })
  })

  it('returns org name, creator and leader names and the settings per program', async () => {
    const res = await request(app()).get('/api/programs')
    expect(res.body.programs[0]).toMatchObject({
      id: 'p1',
      organizationId: 'o2',
      organizationName: 'Grace Church',
      creatorName: 'Luke Keith',
      leaderName: 'Nathan Reed',
      leaderId: 'l1',
      isPrivate: false,
      ageRangeMin: 18,
      memberDirectoryAccess: 'ALLOWED',
      tags: ['lent'],
      _count: { enrollments: 3 },
    })
    expect(res.body.programs[0].creator).toBeUndefined()
  })

  it('narrows to one org of the scope with orgId', async () => {
    await request(app()).get('/api/programs?orgId=o2')
    expect(prismaMock.studyProgram.findMany.mock.calls[0][0].where.AND).toContainEqual({ organizationId: 'o2' })
  })

  it('400s an orgId outside the scope', async () => {
    const res = await request(app()).get('/api/programs?orgId=zz')
    expect(res.status).toBe(400)
    expect(prismaMock.studyProgram.findMany).not.toHaveBeenCalled()
  })

  it('matches leaders on leader or creator', async () => {
    await request(app()).get('/api/programs?leaders=l1,l2')
    expect(prismaMock.studyProgram.findMany.mock.calls[0][0].where.AND).toContainEqual({
      OR: [{ leaderId: { in: ['l1', 'l2'] } }, { creatorId: { in: ['l1', 'l2'] } }],
    })
  })

  it('leaves a super admin unscoped', async () => {
    permission.isSuperAdmin.mockResolvedValue(true)
    await request(app()).get('/api/programs')
    expect(prismaMock.studyProgram.findMany.mock.calls[0][0].where).toEqual({ AND: [{ isActive: true }] })
  })

  it('adds completedEnrollmentCount from one grouped query over ended enrollments (D8)', async () => {
    const res = await request(app()).get('/api/programs')
    expect(res.body.programs[0].completedEnrollmentCount).toBe(2)
    expect(prismaMock.enrollment.groupBy).toHaveBeenCalledTimes(1)
    const arg = prismaMock.enrollment.groupBy.mock.calls[0][0]
    expect(arg.by).toEqual(['studyProgramId'])
    expect(arg.where.studyProgramId).toEqual({ in: ['p1'] })
    const startOfTodayUtc = new Date(); startOfTodayUtc.setUTCHours(0, 0, 0, 0)
    expect(arg.where.endDate.lt.toISOString()).toBe(startOfTodayUtc.toISOString())
  })

  it('reads 0 for a program with no ended enrollment', async () => {
    prismaMock.enrollment.groupBy.mockResolvedValue([])
    const res = await request(app()).get('/api/programs')
    expect(res.body.programs[0].completedEnrollmentCount).toBe(0)
  })
})
