import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  clientEvent: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
  memberVideoProgress: { findMany: vi.fn() },
  member: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { loadSessions, scopeGroupWhere, sessionize, type Moment } from '../home-sessions.js'

const at = (iso: string) => new Date(iso)
const m = (memberId: string, iso: string): Moment => ({ memberId, at: at(iso) })

describe('sessionize (D2)', () => {
  it('splits at a gap of exactly 30:00', () => {
    const s = sessionize([m('a', '2026-10-20T10:00:00Z'), m('a', '2026-10-20T10:30:00Z')])
    expect(s).toHaveLength(2)
    expect(s.map((x) => x.seconds)).toEqual([60, 60])
  })

  it('joins a gap of 29:59', () => {
    const s = sessionize([m('a', '2026-10-20T10:00:00Z'), m('a', '2026-10-20T10:29:59Z')])
    expect(s).toEqual([{ memberId: 'a', start: at('2026-10-20T10:00:00Z'), end: at('2026-10-20T10:29:59Z'), seconds: 1799 }])
  })

  it('floors a single moment at 60 s', () => {
    expect(sessionize([m('a', '2026-10-20T10:00:00Z')])).toEqual([
      { memberId: 'a', start: at('2026-10-20T10:00:00Z'), end: at('2026-10-20T10:00:00Z'), seconds: 60 },
    ])
  })

  it('keeps members separate even when their moments interleave', () => {
    const s = sessionize([
      m('b', '2026-10-20T10:05:00Z'),
      m('a', '2026-10-20T10:00:00Z'),
      m('a', '2026-10-20T10:10:00Z'),
      m('b', '2026-10-20T10:20:00Z'),
    ])
    expect(s).toEqual([
      { memberId: 'a', start: at('2026-10-20T10:00:00Z'), end: at('2026-10-20T10:10:00Z'), seconds: 600 },
      { memberId: 'b', start: at('2026-10-20T10:05:00Z'), end: at('2026-10-20T10:20:00Z'), seconds: 900 },
    ])
  })

  it('sorts unsorted input and chains moments each under 30 min apart', () => {
    const s = sessionize([m('a', '2026-10-20T10:50:00Z'), m('a', '2026-10-20T10:00:00Z'), m('a', '2026-10-20T10:25:00Z')])
    expect(s).toHaveLength(1)
    expect(s[0].seconds).toBe(3000)
  })
})

describe('scopeGroupWhere', () => {
  it('is unconstrained for all, else orgs OR created groups', () => {
    expect(scopeGroupWhere({ all: true })).toEqual({})
    expect(scopeGroupWhere({ all: false, orgIds: ['o1'], groupIds: ['g1'] })).toEqual({
      OR: [{ organizationId: { in: ['o1'] } }, { id: { in: ['g1'] } }],
    })
  })
})

describe('loadSessions (D2 sources)', () => {
  const scope = { all: false as const, orgIds: ['o1'], groupIds: [] as string[] }
  const window = { from: at('2026-10-20T10:00:00Z'), to: at('2026-10-20T12:00:00Z') }

  beforeEach(() => {
    vi.clearAllMocks()
    prismaMock.clientEvent.findMany.mockResolvedValue([
      { memberId: 'm1', occurredAt: at('2026-10-20T10:05:00Z') },
      { memberId: 'ghost', occurredAt: at('2026-10-20T10:10:00Z') }, // deleted member: erased
    ])
    prismaMock.member.findMany.mockResolvedValue([{ id: 'm1' }])
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([
      { memberId: 'm1', completedAt: at('2026-10-20T10:20:00Z') },
      { memberId: 'm2', completedAt: at('2026-10-20T09:00:00Z') }, // starts before the window → dropped
    ])
    prismaMock.memberVideoProgress.findMany.mockResolvedValue([
      { memberId: 'm1', startedAt: at('2026-10-20T10:06:00Z'), lastWatchedAt: at('2026-10-20T10:15:00Z') },
    ])
  })

  it('merges every source per member and keeps sessions starting in the window', async () => {
    expect(await loadSessions(scope, window)).toEqual([
      { memberId: 'm1', start: at('2026-10-20T10:05:00Z'), end: at('2026-10-20T10:20:00Z'), seconds: 900 },
    ])
  })

  it('scopes client events by org/group and the progress tables through schedule → enrollment → group', async () => {
    await loadSessions(scope, window)
    const padded = { gte: at('2026-10-20T04:00:00Z'), lt: at('2026-10-20T18:00:00Z') }
    expect(prismaMock.clientEvent.findMany).toHaveBeenCalledWith({
      where: {
        memberId: { not: null },
        occurredAt: padded,
        OR: [{ organizationId: { in: ['o1'] } }, { groupId: { in: [] } }],
      },
      select: { memberId: true, occurredAt: true },
    })
    const scheduleWhere = { enrollment: { group: { OR: [{ organizationId: { in: ['o1'] } }, { id: { in: [] } }] } } }
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: padded, lessonSchedule: scheduleWhere },
      select: { memberId: true, completedAt: true },
    })
    expect(prismaMock.memberVideoProgress.findMany).toHaveBeenCalledWith({
      where: { OR: [{ startedAt: padded }, { lastWatchedAt: padded }], lessonSchedule: scheduleWhere },
      select: { memberId: true, startedAt: true, lastWatchedAt: true },
    })
    expect(prismaMock.member.findMany).toHaveBeenCalledWith({
      where: { id: { in: ['m1', 'ghost'] } },
      select: { id: true },
    })
  })

  it('narrows every source to one member when memberId is set (ui2-members-browse D12)', async () => {
    await loadSessions(scope, window, { memberId: 'm1' })
    const padded = { gte: at('2026-10-20T04:00:00Z'), lt: at('2026-10-20T18:00:00Z') }
    const scheduleWhere = { enrollment: { group: { OR: [{ organizationId: { in: ['o1'] } }, { id: { in: [] } }] } } }
    expect(prismaMock.clientEvent.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', occurredAt: padded, OR: [{ organizationId: { in: ['o1'] } }, { groupId: { in: [] } }] },
      select: { memberId: true, occurredAt: true },
    })
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: padded, lessonSchedule: scheduleWhere, memberId: 'm1' },
      select: { memberId: true, completedAt: true },
    })
    expect(prismaMock.memberVideoProgress.findMany).toHaveBeenCalledWith({
      where: { OR: [{ startedAt: padded }, { lastWatchedAt: padded }], lessonSchedule: scheduleWhere, memberId: 'm1' },
      select: { memberId: true, startedAt: true, lastWatchedAt: true },
    })
  })
})
