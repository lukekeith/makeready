/**
 * ui2-programs D15/D18/D20 (SC6): GET /api/programs/:id carries names + settings; PATCH takes the
 * settings, the nested age range, the leader and an org move under the same checks as groups.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  studyProgram: { findFirst: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
  organization: { findUnique: vi.fn(), findFirst: vi.fn() },
  userRole: { findFirst: vi.fn() },
  user: { findUnique: vi.fn() },
  $transaction: vi.fn(),
}))
const permission = vi.hoisted(() => ({
  isSuperAdmin: vi.fn(),
  getManageableOrgIds: vi.fn(),
  programManageFilter: vi.fn(),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: { DbNull: 'DbNull' } }))
vi.mock('../../generated/prisma/index.js', () => ({ Prisma: { DbNull: 'DbNull' } }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  ...permission,
}))
vi.mock('../../services/activity.js', () => ({ trackActivity: vi.fn() }))

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

const stored = {
  id: 'p1',
  name: 'Foundations',
  organizationId: 'o1',
  creatorId: 'u1',
  isPublished: false,
  days: 3,
  templateId: null,
  ageRangeMin: 18,
  ageRangeMax: 35,
}

beforeEach(() => {
  vi.clearAllMocks()
  permission.isSuperAdmin.mockResolvedValue(false)
  permission.getManageableOrgIds.mockResolvedValue(['o1'])
  permission.programManageFilter.mockResolvedValue({ organizationId: 'o1' })
  prismaMock.user.findUnique.mockResolvedValue({ organizationId: 'o1' })
  prismaMock.studyProgram.findFirst.mockResolvedValue(stored)
  prismaMock.studyProgram.update.mockResolvedValue(stored)
  prismaMock.studyProgram.findUnique.mockResolvedValue({
    ...stored,
    creator: { name: 'Luke Keith' },
    leader: { name: 'Nathan Reed' },
  })
  prismaMock.organization.findFirst.mockResolvedValue(null)
  prismaMock.userRole.findFirst.mockResolvedValue({ id: 'r1' })
})

const patch = (body: object) => request(app()).patch('/api/programs/p1').send(body)
const data = () => prismaMock.studyProgram.update.mock.calls[0][0].data

describe('GET /api/programs/:id (D15)', () => {
  it('returns the names and settings and drops the relations', async () => {
    prismaMock.studyProgram.findFirst.mockResolvedValue({
      ...stored,
      isPrivate: true,
      maxMembers: 40,
      memberDirectoryAccess: 'NAMES_ONLY',
      leaderId: 'l1',
      coverOriginalUrl: null,
      coverFraming: null,
      creator: { name: 'Luke Keith' },
      leader: { name: 'Nathan Reed' },
      tags: [],
      _count: { lessons: 0, enrollments: 0 },
    })
    const res = await request(app()).get('/api/programs/p1')
    expect(res.status).toBe(200)
    expect(res.body.program).toMatchObject({
      creatorName: 'Luke Keith',
      leaderName: 'Nathan Reed',
      isPrivate: true,
      maxMembers: 40,
      memberDirectoryAccess: 'NAMES_ONLY',
    })
    expect(res.body.program.creator).toBeUndefined()
    expect(res.body.pagination).toMatchObject({ totalLessons: 0, hasMore: false })
  })

  it('reads across every org the caller manages', async () => {
    permission.getManageableOrgIds.mockResolvedValue(['o1', 'o2'])
    prismaMock.studyProgram.findFirst.mockResolvedValue(null)
    await request(app()).get('/api/programs/p1')
    expect(prismaMock.studyProgram.findFirst.mock.calls[0][0].where).toMatchObject({
      id: 'p1',
      OR: [{ organizationId: { in: ['o1', 'o2'] } }, { creatorId: 'u1' }],
    })
  })
})

describe('PATCH /api/programs/:id (D15)', () => {
  it('writes the settings and returns the names', async () => {
    const res = await patch({ isPrivate: true, maxMembers: 40, memberDirectoryAccess: 'NAMES_ONLY' })
    expect(res.status).toBe(200)
    expect(data()).toMatchObject({ isPrivate: true, maxMembers: 40, memberDirectoryAccess: 'NAMES_ONLY' })
    expect(res.body.program).toMatchObject({ creatorName: 'Luke Keith', leaderName: 'Nathan Reed' })
  })

  it('clears with explicit nulls', async () => {
    await patch({ description: null, maxMembers: null, ageRange: null })
    expect(data()).toMatchObject({ description: null, maxMembers: null, ageRangeMin: null, ageRangeMax: null })
    expect(data().ageRange).toBeUndefined()
  })

  it('maps the nested age range to the two columns', async () => {
    await patch({ ageRange: { min: 20, max: 30 } })
    expect(data()).toMatchObject({ ageRangeMin: 20, ageRangeMax: 30 })
  })

  it('400s an inverted range', async () => {
    expect((await patch({ ageRange: { min: 40, max: 30 } })).status).toBe(400)
    expect(prismaMock.studyProgram.update).not.toHaveBeenCalled()
  })

  it('400s a one-bound update that inverts against the stored bound', async () => {
    expect((await patch({ ageRange: { min: 40 } })).status).toBe(400)
  })

  it('accepts a leader who holds a role in the program org', async () => {
    expect((await patch({ leaderId: '00000000-0000-4000-8000-000000000001' })).status).toBe(200)
    expect(data()).toMatchObject({ leaderId: '00000000-0000-4000-8000-000000000001' })
  })

  it('400s a leader outside the program org', async () => {
    prismaMock.userRole.findFirst.mockResolvedValue(null)
    expect((await patch({ leaderId: '00000000-0000-4000-8000-000000000002' })).status).toBe(400)
    expect(prismaMock.studyProgram.update).not.toHaveBeenCalled()
  })

  it('setting coverImageUrl drops the stored original and framing', async () => {
    await patch({ coverImageUrl: 'https://img.test/programs/p1.jpeg' })
    expect(data()).toMatchObject({ coverOriginalUrl: null, coverFraming: 'DbNull' })
  })
})

describe('PATCH organizationId (D18)', () => {
  it('403s a move into an org the caller neither owns nor holds a role in', async () => {
    prismaMock.organization.findUnique.mockResolvedValue({ id: 'zz', ownerId: 'someone' })
    prismaMock.userRole.findFirst.mockResolvedValue(null)
    const res = await patch({ organizationId: '00000000-0000-4000-8000-0000000000aa' })
    expect(res.status).toBe(403)
    expect(prismaMock.studyProgram.update).not.toHaveBeenCalled()
  })

  it('400s a move into an org that does not exist', async () => {
    prismaMock.organization.findUnique.mockResolvedValue(null)
    expect((await patch({ organizationId: '00000000-0000-4000-8000-0000000000aa' })).status).toBe(400)
  })
})
