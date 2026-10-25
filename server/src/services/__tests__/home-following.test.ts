import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  enrollment: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
}))
const preferencesMock = vi.hoisted(() => ({ getPreference: vi.fn() }))
const permissionMock = vi.hoisted(() => ({ enrollmentManageFilter: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../preferences.js', () => preferencesMock)
vi.mock('../permission.js', () => permissionMock)

import {
  FOLLOWED_ENROLLMENTS_KEY,
  assembleFollowing,
  getHomeFollowing,
  parseFollowedEnrollments,
  type FollowedEnrollmentRow,
} from '../home-following.js'

const at = (iso: string) => new Date(iso)
const row = (over: Partial<FollowedEnrollmentRow> & { id: string }): FollowedEnrollmentRow => ({
  syncMode: 'OFF',
  group: { name: 'Group', coverImageUrl: null, members: [] },
  studyProgram: { id: 'p', name: 'Program', createdAt: at('2026-08-01T10:00:00.123Z'), creator: null },
  lessonSchedules: [],
  ...over,
})

const r1 = row({
  id: 'e1',
  syncMode: 'AUTO',
  group: { name: 'Young Adults', coverImageUrl: 'https://img/ya.jpg', members: [{ memberId: 'm1' }, { memberId: 'm2' }] },
  studyProgram: { id: 'p2', name: 'Walking Through John', createdAt: at('2026-08-01T10:00:00.123Z'), creator: { name: 'Fixture Leader' } },
  lessonSchedules: [
    { id: 's1', scheduledDate: at('2026-10-20T17:00:00Z') },
    { id: 's2', scheduledDate: at('2026-10-24T17:00:00Z') },
    { id: 's3', scheduledDate: at('2026-10-30T17:00:00Z') }, // not yet due
  ],
})
const r2 = row({
  id: 'e2',
  group: { name: "Women's Bible Study", coverImageUrl: null, members: [{ memberId: 'm3' }] },
  studyProgram: { id: 'p1', name: 'Foundations of Faith', createdAt: at('2026-07-01T00:00:00Z'), creator: null },
  lessonSchedules: [{ id: 's4', scheduledDate: at('2026-10-22T17:00:00Z') }],
})
const r3 = row({
  id: 'e3',
  syncMode: 'APPROVAL',
  group: { name: "Tuesday Men's Group", coverImageUrl: null, members: [{ memberId: 'm4' }, { memberId: 'm5' }, { memberId: null }] },
  studyProgram: { id: 'p1', name: 'Foundations of Faith', createdAt: at('2026-07-01T00:00:00Z'), creator: null },
  lessonSchedules: [{ id: 's5', scheduledDate: at('2026-10-23T17:00:00Z') }],
})
const completed = new Set(['m1|s1', 'm1|s2', 'm2|s1', 'm3|s4', 'm4|s5'])

describe('parseFollowedEnrollments (D4)', () => {
  it.each([[null], [undefined], [''], ['not json'], ['{"a":1}'], ['"e1"'], ['42'], ['[]']])('reads %j as nothing followed', (value) => {
    expect(parseFollowedEnrollments(value)).toEqual([])
  })

  it('keeps non-empty strings in order, deduped', () => {
    expect(parseFollowedEnrollments('["e1", 2, null, "", {"id":"x"}, "e2", "e1"]')).toEqual(['e1', 'e2'])
  })

  it('caps at 50', () => {
    const ids = Array.from({ length: 60 }, (_, i) => `e${i}`)
    expect(parseFollowedEnrollments(JSON.stringify(ids))).toEqual(ids.slice(0, 50))
  })
})

describe('assembleFollowing (D11)', () => {
  it('groups by program, orders programs by title and groups by name, and computes each card', () => {
    expect(assembleFollowing([r1, r2, r3], completed, ['e1', 'e3', 'e2'], '2026-10-25')).toEqual({
      programs: [
        {
          id: 'p1',
          title: 'Foundations of Faith',
          author: '',
          createdAt: '2026-07-01T00:00:00.000Z',
          groups: [
            { enrollmentId: 'e3', groupName: "Tuesday Men's Group", photoUrl: null, memberCount: 2, percent: 50, synced: true },
            { enrollmentId: 'e2', groupName: "Women's Bible Study", photoUrl: null, memberCount: 1, percent: 100, synced: false },
          ],
        },
        {
          id: 'p2',
          title: 'Walking Through John',
          author: 'Fixture Leader',
          createdAt: '2026-08-01T10:00:00.123Z',
          groups: [
            { enrollmentId: 'e1', groupName: 'Young Adults', photoUrl: 'https://img/ya.jpg', memberCount: 2, percent: 75, synced: true },
          ],
        },
      ],
    })
  })

  it('breaks title/name ties by the preference order', () => {
    const a = row({ id: 'ea', group: { name: 'Alpha', coverImageUrl: null, members: [] } })
    const b = row({ id: 'eb', group: { name: 'Alpha', coverImageUrl: null, members: [] } })
    const out = assembleFollowing([a, b], new Set(), ['eb', 'ea'], '2026-10-25')
    expect(out.programs[0].groups.map((g) => g.enrollmentId)).toEqual(['eb', 'ea'])
  })

  it('is 0% when nothing is due or nobody is in the group', () => {
    const out = assembleFollowing([row({ id: 'e9' })], new Set(), ['e9'], '2026-10-25')
    expect(out.programs[0].groups[0].percent).toBe(0)
  })
})

describe('getHomeFollowing', () => {
  const scope = { all: false as const, orgIds: ['org-1'], groupIds: [] as string[] }
  const manage = { OR: [{ createdById: 'u1' }, { group: { OR: [{ creatorId: 'u1' }, { organizationId: { in: ['org-1'] } }] } }] }
  const NOW = at('2026-10-25T15:00:00Z')

  beforeEach(() => {
    vi.clearAllMocks()
    permissionMock.enrollmentManageFilter.mockResolvedValue(manage)
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([
      { memberId: 'm1', lessonScheduleId: 's1' },
      { memberId: 'm1', lessonScheduleId: 's2' },
      { memberId: 'm2', lessonScheduleId: 's1' },
    ])
  })

  it('returns the empty state without querying when nothing is followed', async () => {
    preferencesMock.getPreference.mockResolvedValue(null)
    expect(await getHomeFollowing(scope, 'u1', NOW)).toEqual({ programs: [] })
    expect(preferencesMock.getPreference).toHaveBeenCalledWith({ userId: 'u1' }, FOLLOWED_ENROLLMENTS_KEY)
    expect(prismaMock.enrollment.findMany).not.toHaveBeenCalled()
  })

  it('drops an unknown id and a foreign-org id through the manage filter AND the scope', async () => {
    preferencesMock.getPreference.mockResolvedValue(JSON.stringify(['e1', 'ghost', 'foreign']))
    prismaMock.enrollment.findMany.mockResolvedValue([r1]) // the database returns only what passes the where
    const out = await getHomeFollowing(scope, 'u1', NOW)
    expect(out.programs.flatMap((p) => p.groups.map((g) => g.enrollmentId))).toEqual(['e1'])
    expect(permissionMock.enrollmentManageFilter).toHaveBeenCalledWith('u1')
    expect(prismaMock.enrollment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: [
            { id: { in: ['e1', 'ghost', 'foreign'] } },
            manage,
            { studyProgram: { isActive: true } },
            { group: { isActive: true, OR: [{ organizationId: { in: ['org-1'] } }, { id: { in: [] } }] } },
          ],
        },
      })
    )
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: { not: null }, lessonScheduleId: { in: ['s1', 's2'] }, memberId: { in: ['m1', 'm2'] } },
      select: { memberId: true, lessonScheduleId: true },
    })
    expect(out.programs[0].groups[0].percent).toBe(75)
  })
})
