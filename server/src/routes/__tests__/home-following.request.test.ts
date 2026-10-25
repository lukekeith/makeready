/**
 * /api/home/following end to end through the router with the REAL scope and
 * following services: only Prisma, preferences and the permission helpers are
 * stubbed. The enrollment stub evaluates the `where` the service sends against
 * an in-memory table, so an unknown id and a foreign-org id drop out because
 * of the query itself, not because the stub returns a canned row.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  enrollment: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
  group: { findMany: vi.fn() },
}))
const preferencesMock = vi.hoisted(() => ({ getPreference: vi.fn() }))
const permissionMock = vi.hoisted(() => ({
  enrollmentManageFilter: vi.fn(),
  getManageableOrgIds: vi.fn(),
  isSuperAdmin: vi.fn(),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/preferences.js', () => preferencesMock)
vi.mock('../../services/permission.js', () => permissionMock)

import homeRoutes from '../home.js'

type Row = { id: string; orgId: string; name: string }
const TABLE: Row[] = [
  { id: 'e-mine', orgId: 'org-1', name: 'Mine' },
  { id: 'e-foreign', orgId: 'org-9', name: 'Foreign' },
]
const rowFor = (r: Row) => ({
  id: r.id,
  syncMode: 'OFF',
  group: { name: r.name, coverImageUrl: null, members: [] },
  studyProgram: { id: `p-${r.id}`, name: `Program ${r.name}`, createdAt: new Date('2026-08-01T00:00:00Z'), creator: null },
  lessonSchedules: [],
})

function app() {
  const a = express()
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, isAuthenticated: () => true })
    next()
  })
  a.use('/api/home', homeRoutes)
  return a
}

beforeEach(() => {
  vi.clearAllMocks()
  permissionMock.isSuperAdmin.mockResolvedValue(false)
  permissionMock.getManageableOrgIds.mockResolvedValue(['org-1'])
  permissionMock.enrollmentManageFilter.mockResolvedValue({})
  prismaMock.group.findMany.mockResolvedValue([])
  prismaMock.memberLessonProgress.findMany.mockResolvedValue([])
  prismaMock.enrollment.findMany.mockImplementation(async ({ where }: any) => {
    const wanted: string[] = where.AND[0].id.in
    const orgs: string[] = where.AND[3].group.OR[0].organizationId.in
    return TABLE.filter((r) => wanted.includes(r.id) && orgs.includes(r.orgId)).map(rowFor)
  })
})

describe('GET /api/home/following (real services)', () => {
  it('drops an unknown id and a foreign-org id end to end', async () => {
    preferencesMock.getPreference.mockResolvedValue(JSON.stringify(['e-mine', 'ghost', 'e-foreign']))
    const res = await request(app()).get('/api/home/following')
    expect(res.status).toBe(200)
    expect(res.body.programs.flatMap((p: any) => p.groups.map((g: any) => g.enrollmentId))).toEqual(['e-mine'])
  })

  it('answers the empty state when nothing is followed', async () => {
    preferencesMock.getPreference.mockResolvedValue('')
    const res = await request(app()).get('/api/home/following')
    expect(res.body).toEqual({ programs: [] })
  })

  it('404s when organizationId is outside the caller scope', async () => {
    const res = await request(app()).get('/api/home/following?organizationId=org-9')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Not found' })
  })
})
