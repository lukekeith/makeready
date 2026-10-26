import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  enrollment: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
  memberVideoProgress: { findMany: vi.fn() },
  clientEvent: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../member-access.js', () => ({ visibleMemberOrgIds: vi.fn() }))

import { visibleMemberOrgIds } from '../member-access.js'
import { enrollmentSeconds, getMemberEngagement, summarizeEnrollment } from '../member-engagement.js'

const at = (iso: string) => new Date(iso)
const CHI = 'America/Chicago'
const NOW = at('2026-10-25T15:00:00Z') // 10:00 CDT → today = 2026-10-25 in Chicago

describe('summarizeEnrollment (D11, D14)', () => {
  const schedules = [
    { id: 's1', date: '2026-10-23' },
    { id: 's2', date: '2026-10-24' },
    { id: 's3', date: '2026-10-25' }, // today: not yet due
    { id: 's4', date: '2026-10-26' },
  ]

  it('counts completions on the listed lessons against the lessons due before today', () => {
    expect(summarizeEnrollment(schedules, new Set(['s1', 's3', 'removed-lesson']), 4260, '2026-10-25')).toEqual({
      completedCount: 2,
      totalCount: 4,
      hours: 1,
      percent: 100,
    })
  })

  it('caps percent at 100 when the member is ahead of the schedule', () => {
    expect(summarizeEnrollment(schedules, new Set(['s1', 's3', 's4']), 0, '2026-10-25').percent).toBe(100)
  })

  it('rounds percent and reads 0 when nothing is due yet', () => {
    expect(summarizeEnrollment(schedules, new Set(['s1']), 0, '2026-10-26').percent).toBe(33) // 1 of 3
    expect(summarizeEnrollment(schedules, new Set(['s1']), 0, '2026-10-01').percent).toBe(0)
    expect(summarizeEnrollment([], new Set(), 0, '2026-10-25')).toEqual({ completedCount: 0, totalCount: 0, hours: 0, percent: 0 })
  })

  it('rounds hours to whole hours (1 h 29 m → 1, 1 h 30 m → 2)', () => {
    expect(summarizeEnrollment([], new Set(), 5340, '2026-10-25').hours).toBe(1)
    expect(summarizeEnrollment([], new Set(), 5400, '2026-10-25').hours).toBe(2)
  })
})

describe('enrollmentSeconds (D17)', () => {
  it('sessionizes each enrollment on its own, so interleaved moments never merge', () => {
    const totals = enrollmentSeconds([
      { enrollmentId: 'e1', at: at('2026-10-23T15:00:00Z') },
      { enrollmentId: 'e1', at: at('2026-10-23T15:25:00Z') },
      { enrollmentId: 'e2', at: at('2026-10-23T15:05:00Z') },
      { enrollmentId: 'e1', at: at('2026-10-23T15:50:00Z') },
      { enrollmentId: 'e1', at: at('2026-10-23T16:10:00Z') }, // e1: one 70-min session = 4200 s
      { enrollmentId: 'e2', at: at('2026-10-23T16:50:00Z') }, // e2: 105 min after its last → two 60 s floors
      { enrollmentId: 'e1', at: at('2026-10-24T15:00:00Z') }, // e1: a lone moment = 60 s
    ])
    expect(totals.get('e1')).toBe(4260)
    expect(totals.get('e2')).toBe(120)
  })
})

describe('getMemberEngagement', () => {
  const sched = (id: string, iso: string) => ({ id, scheduledDate: at(iso) })
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(visibleMemberOrgIds).mockResolvedValue(['o1'])
    prismaMock.enrollment.findMany.mockResolvedValue([
      {
        id: 'e1',
        studyProgramId: 'p-john',
        studyProgram: { name: 'Walking Through John', coverImageUrl: 'http://img/john.jpg' },
        lessonSchedules: [
          sched('s1', '2026-10-23T17:00:00Z'),
          sched('s2', '2026-10-24T17:00:00Z'),
          sched('s3', '2026-10-25T17:00:00Z'),
          sched('s4', '2026-10-26T17:00:00Z'),
        ],
      },
      {
        id: 'e2',
        studyProgramId: 'p-faith',
        studyProgram: { name: 'Foundations of Faith', coverImageUrl: null },
        lessonSchedules: [sched('t1', '2026-11-02T17:00:00Z')],
      },
    ])
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([
      { lessonScheduleId: 's1', completedAt: at('2026-10-24T15:00:00Z'), lessonSchedule: { enrollmentId: 'e1' } },
      { lessonScheduleId: 's3', completedAt: at('2026-10-23T16:10:00Z'), lessonSchedule: { enrollmentId: 'e1' } },
      { lessonScheduleId: 's2', completedAt: null, lessonSchedule: { enrollmentId: 'e1' } },
    ])
    prismaMock.memberVideoProgress.findMany.mockResolvedValue([
      { startedAt: at('2026-10-23T15:05:00Z'), lastWatchedAt: at('2026-10-23T16:50:00Z'), lessonSchedule: { enrollmentId: 'e2' } },
    ])
    prismaMock.clientEvent.findMany.mockResolvedValue([
      { enrollmentId: 'e1', occurredAt: at('2026-10-23T15:00:00Z') },
      { enrollmentId: 'e1', occurredAt: at('2026-10-23T15:25:00Z') },
      { enrollmentId: 'e1', occurredAt: at('2026-10-23T15:50:00Z') },
    ])
  })

  it('returns one row per enrollment with the D11/D14 keys verbatim', async () => {
    expect(await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, NOW)).toEqual({
      programs: [
        {
          enrollmentId: 'e1',
          programId: 'p-john',
          title: 'Walking Through John',
          coverImageUrl: 'http://img/john.jpg',
          completedCount: 2,
          totalCount: 4,
          hours: 1, // 4200 + 60 s
          percent: 100, // 2 completed ÷ 2 due (s1, s2)
        },
        {
          enrollmentId: 'e2',
          programId: 'p-faith',
          title: 'Foundations of Faith',
          coverImageUrl: null,
          completedCount: 0,
          totalCount: 1,
          hours: 0,
          percent: 0, // nothing due yet
        },
      ],
    })
  })

  it('reads enrollments of active groups the member is active in, inside the visible orgs (D16)', async () => {
    await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, NOW)
    expect(prismaMock.enrollment.findMany).toHaveBeenCalledWith({
      where: {
        group: { isActive: true, organizationId: { in: ['o1'] }, members: { some: { memberId: 'm1', isActive: true } } },
      },
      select: {
        id: true,
        studyProgramId: true,
        studyProgram: { select: { name: true, coverImageUrl: true } },
        lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } },
      },
      orderBy: [{ startDate: 'desc' }, { id: 'asc' }],
    })
    const tied = { lessonSchedule: { enrollmentId: { in: ['e1', 'e2'] } } }
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', ...tied },
      select: { lessonScheduleId: true, completedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    })
    expect(prismaMock.memberVideoProgress.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', ...tied },
      select: { startedAt: true, lastWatchedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    })
    expect(prismaMock.clientEvent.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', enrollmentId: { in: ['e1', 'e2'] } },
      select: { enrollmentId: true, occurredAt: true },
    })
  })

  it('is null for a user who sees the member in no org (the route answers 404)', async () => {
    vi.mocked(visibleMemberOrgIds).mockResolvedValue([])
    expect(await getMemberEngagement('m1', { kind: 'user', userId: 'gl2' }, CHI, NOW)).toBeNull()
    expect(prismaMock.enrollment.findMany).not.toHaveBeenCalled()
  })

  it('reads every org for a member reading itself, with no scope lookup', async () => {
    await getMemberEngagement('m1', { kind: 'self' }, 'UTC', NOW)
    expect(visibleMemberOrgIds).not.toHaveBeenCalled()
    expect(prismaMock.enrollment.findMany.mock.calls[0][0].where).toEqual({
      group: { isActive: true, members: { some: { memberId: 'm1', isActive: true } } },
    })
  })

  it('answers no enrollments with an empty list and no progress queries', async () => {
    prismaMock.enrollment.findMany.mockResolvedValue([])
    expect(await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, NOW)).toEqual({ programs: [] })
    expect(prismaMock.memberLessonProgress.findMany).not.toHaveBeenCalled()
  })

  it('takes "today" in the caller’s tz', async () => {
    // 2026-10-26T03:00Z is still 2026-10-25 in Chicago but already 2026-10-26 in UTC.
    const late = at('2026-10-26T03:00:00Z')
    const chicago = await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, late)
    const utc = await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, 'UTC', late)
    expect(chicago?.programs[0].percent).toBe(100) // 2 of 2 due
    expect(utc?.programs[0].percent).toBe(67) // 2 of 3 due (s3 now due)
  })
})
