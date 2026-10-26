import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../home-sessions.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../home-sessions.js')>()),
  loadSessions: vi.fn(),
}))

import { loadSessions, type Session } from '../home-sessions.js'
import {
  activeMembers,
  activeWindow,
  bucketDays,
  computeEngagement,
  getHomeDays,
  getHomeEngagement,
  getHomeSessions,
  summarizeSessions,
  sessionLengthAxis,
  validateDayRange,
  zonedMidnight,
} from '../home-dashboard.js'

const CHI = 'America/Chicago'
const at = (iso: string) => new Date(iso)
const session = (memberId: string, iso: string, seconds: number): Session => ({
  memberId,
  start: at(iso),
  end: new Date(at(iso).getTime() + seconds * 1000),
  seconds,
})
const SCOPE = { all: false as const, orgIds: ['o1'], groupIds: [] as string[] }
const NOW = at('2026-10-25T15:00:00Z') // 10:00 CDT, today = 2026-10-25 in Chicago

beforeEach(() => vi.clearAllMocks())

describe('zonedMidnight', () => {
  it('finds local midnight on both sides of the 2026-11-01 DST change', () => {
    expect(zonedMidnight('2026-11-01', CHI)).toEqual(at('2026-11-01T05:00:00Z'))
    expect(zonedMidnight('2026-11-02', CHI)).toEqual(at('2026-11-02T06:00:00Z'))
    expect(zonedMidnight('2026-10-25', 'UTC')).toEqual(at('2026-10-25T00:00:00Z'))
  })
})

describe('validateDayRange (≤ 62 days)', () => {
  it('accepts 1 and 62 days, rejects 63, reversed and malformed', () => {
    expect(validateDayRange('2026-10-01', '2026-10-01')).toBeNull()
    expect(validateDayRange('2026-10-01', '2026-12-01')).toBeNull() // 62 days
    expect(validateDayRange('2026-10-01', '2026-12-02')).toBe('At most 62 days')
    expect(validateDayRange('2026-10-02', '2026-10-01')).toBe('to must not be before from')
    expect(validateDayRange('2026-10-1', '2026-10-02')).toBe('from/to must be YYYY-MM-DD')
    expect(validateDayRange('2026-02-30', '2026-03-01')).toBe('from/to must be YYYY-MM-DD')
  })
})

describe('bucketDays (D6, SC7)', () => {
  it('zero-fills every day with 12 blocks summing to sessionSeconds and no last activity', () => {
    const days = bucketDays([], '2026-10-30', '2026-11-02', CHI)
    expect(days.map((d) => d.day)).toEqual(['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02'])
    for (const d of days) {
      expect(d.blocks).toEqual(Array(12).fill(0))
      expect(d.sessionSeconds).toBe(0)
      expect(d.lastActivityAt).toBeNull()
    }
  })

  it('puts sessions in the caller-tz block they start in across the DST boundary, and ends each day at its last session', () => {
    const days = bucketDays(
      [
        session('a', '2026-11-01T05:30:00Z', 600), // 00:30 CDT → Nov 1 block 0
        session('b', '2026-11-01T07:30:00Z', 300), // 01:30 CST (the repeated hour) → block 0
        session('c', '2026-11-01T08:30:00Z', 120), // 02:30 CST → block 1
        session('d', '2026-11-02T05:30:00Z', 60), // 23:30 CST, still Nov 1 → block 11, ends 05:31Z
        session('e', '2026-11-02T06:30:00Z', 90), // 00:30 CST Nov 2 → block 0, ends 06:31:30Z
      ],
      '2026-11-01',
      '2026-11-02',
      CHI
    )
    expect(days[0]).toEqual({
      day: '2026-11-01',
      sessionSeconds: 1080,
      blocks: [900, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 60],
      lastActivityAt: '2026-11-02T05:31:00.000Z',
    })
    expect(days[1]).toEqual({
      day: '2026-11-02',
      sessionSeconds: 90,
      blocks: [90, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      lastActivityAt: '2026-11-02T06:31:30.000Z',
    })
  })

  it('F8 (accepted): a session crossing local midnight stays on its start day and reports the next day’s end time', () => {
    // 23:50 CDT Oct 24 → 00:20 CDT Oct 25
    const days = bucketDays([session('a', '2026-10-25T04:50:00Z', 1800)], '2026-10-24', '2026-10-25', CHI)
    expect(days[0]).toEqual({
      day: '2026-10-24',
      sessionSeconds: 1800,
      blocks: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1800],
      lastActivityAt: '2026-10-25T05:20:00.000Z',
    })
    expect(days[1]).toMatchObject({ day: '2026-10-25', sessionSeconds: 0, lastActivityAt: null })
  })
})

describe('getHomeDays', () => {
  it('loads exactly the local days [from 00:00, to + 1 00:00) — Home’s call, two arguments', async () => {
    vi.mocked(loadSessions).mockResolvedValue([session('a', '2026-11-01T05:30:00Z', 600)])
    const result = await getHomeDays(SCOPE, '2026-11-01', '2026-11-02', CHI)
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at('2026-11-01T05:00:00Z'), to: at('2026-11-03T06:00:00Z') })
    expect(vi.mocked(loadSessions).mock.calls[0]).toHaveLength(2)
    expect(result.days).toHaveLength(2)
    expect(result.days[0].sessionSeconds).toBe(600)
    expect(result.days[0].lastActivityAt).toBe('2026-11-01T05:40:00.000Z')
  })

  it('passes memberId through to loadSessions (ui2-members-browse D12)', async () => {
    vi.mocked(loadSessions).mockResolvedValue([])
    await getHomeDays(SCOPE, '2026-11-01', '2026-11-02', CHI, { memberId: 'm1' })
    expect(loadSessions).toHaveBeenCalledWith(
      SCOPE,
      { from: at('2026-11-01T05:00:00Z'), to: at('2026-11-03T06:00:00Z') },
      { memberId: 'm1' }
    )
  })
})

describe('summarizeSessions (D8, D18)', () => {
  const window = { from: at('2026-10-19T05:00:00Z'), to: NOW } // 154 h → 1.75 h per bin
  const sessions = [
    session('a', '2026-10-20T14:00:00Z', 600), // 09:00 CDT, bin 18
    session('b', '2026-10-20T14:30:00Z', 1200), // 09:30 CDT, bin 19
    session('c', '2026-10-24T23:00:00Z', 300), // 18:00 CDT, bin 78
    session('x', '2026-10-19T04:00:00Z', 9999), // before the window: ignored
  ]

  it('averages and counts sessions', () => {
    const s = summarizeSessions(sessions, window, CHI)
    expect(s.averageSeconds).toBe(700)
    expect(s.sessionCount).toBe(3)
  })

  it('makes the dial activity concentration: sessions active during each local hour (D23)', () => {
    const s = summarizeSessions(sessions, window, CHI)
    expect(s.hourly).toHaveLength(24)
    expect(s.hourly[9]).toBe(2) // a 09:00–09:10 and b 09:30–09:50
    expect(s.hourly[18]).toBe(1)
    expect(s.hourly.filter((v) => v > 0)).toHaveLength(2)
  })

  it('counts a session in every hour it overlaps (D23)', () => {
    // 06:50–07:20 CDT
    const s = summarizeSessions([session('d', '2026-10-21T11:50:00Z', 1800)], window, CHI)
    expect(s.hourly[6]).toBe(1)
    expect(s.hourly[7]).toBe(1)
    expect(s.hourly.reduce((a, b) => a + b, 0)).toBe(2)
  })

  it('histograms session LENGTH into 88 bands over a readable 0 … longest axis (D18)', () => {
    const s = summarizeSessions(sessions, window, CHI)
    // Lengths 10, 20 and 5 min → longest 20 → axis 0·10·20.
    expect(s.axisMinutes).toBe(20)
    expect(s.ticks).toEqual([0, 10, 20])
    expect(s.bins).toHaveLength(88)
    expect(s.bins[22]).toBe(1) // 5 min
    expect(s.bins[44]).toBe(1) // 10 min
    expect(s.bins[87]).toBe(1) // 20 min — the longest lands in the last band
    expect(s.bins.filter((v) => v > 0)).toHaveLength(3)
  })

  it('counts sessions, not seconds, per band and normalises to the busiest band', () => {
    const many = [
      session('a', '2026-10-20T14:00:00Z', 600),
      session('b', '2026-10-20T16:00:00Z', 610),
      session('c', '2026-10-21T14:00:00Z', 1800),
    ]
    const s = summarizeSessions(many, window, CHI)
    expect(s.ticks).toEqual([0, 10, 20, 30]) // 30 fits 10 and 15 equally; the finer, 4-tick axis wins
    expect(s.bins[29]).toBe(1)   // 10:00 and 10:10 share a band → 2 sessions, the busiest
    expect(s.bins[87]).toBe(0.5) // the one 30-min session
  })

  it('is all zeros with no sessions', () => {
    const s = summarizeSessions([], window, CHI)
    expect(s).toMatchObject({ averageSeconds: 0, sessionCount: 0 })
    expect(s.hourly).toEqual(Array(24).fill(0))
    expect(s.bins).toEqual(Array(88).fill(0))
    expect(s.ticks).toEqual([0])
    expect(s.axisMinutes).toBe(0)
  })
})

describe('sessionLengthAxis (D18)', () => {
  it.each([
    [45, 45, [0, 15, 30, 45]],
    [40, 40, [0, 20, 40]],
    [37, 40, [0, 20, 40]],
    [8, 10, [0, 5, 10]],
    [1, 1, [0, 1]],
    [130, 135, [0, 45, 90, 135]],
  ] as [number, number, number[]][])('longest %d min → axis %d, ticks %j', (longest, axis, ticks) => {
    const a = sessionLengthAxis(longest)
    expect(a.axisMinutes).toBe(axis)
    expect(a.ticks).toEqual(ticks)
    expect(a.ticks.length).toBeLessThanOrEqual(4)
  })
})

describe('getHomeSessions windows (D8)', () => {
  it.each([
    ['week', '2026-10-19T05:00:00Z'],
    ['month', '2026-09-26T05:00:00Z'],
    ['year', '2025-10-26T05:00:00Z'],
  ] as const)('%s starts at local midnight N−1 days ago and ends now', async (range, from) => {
    vi.mocked(loadSessions).mockResolvedValue([])
    await getHomeSessions(SCOPE, range, CHI, NOW)
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at(from), to: NOW })
  })

  it('all loads the 730-day cap and histograms every session in it (D18)', async () => {
    vi.mocked(loadSessions).mockResolvedValue([session('a', '2025-01-10T15:00:00Z', 600), session('a', '2026-10-20T15:00:00Z', 300)])
    const s = await getHomeSessions(SCOPE, 'all', CHI, NOW)
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at('2024-10-26T05:00:00Z'), to: NOW })
    expect(s.ticks).toEqual([0, 5, 10]) // longest 10 min
    expect(s.bins[44]).toBe(1)          // the 5-min session
    expect(s.bins[87]).toBe(1)          // the 10-min session
    expect(s.sessionCount).toBe(2)
  })
})

describe('computeEngagement (D3, D14, D15)', () => {
  const today = '2026-10-25'
  const g1 = {
    id: 'g1',
    memberIds: ['m1', 'm2'],
    schedules: [
      { id: 's1', date: '2026-10-23' },
      { id: 's2', date: '2026-10-24' },
      { id: 's3', date: '2026-10-25' }, // today: not yet due
      { id: 's4', date: '2026-10-27' },
    ],
  }
  const future = { id: 'g2', memberIds: ['m3'], schedules: [{ id: 's9', date: '2026-10-26' }] }
  const g3 = { id: 'g3', memberIds: ['m4'], schedules: [{ id: 's5', date: '2026-10-20' }] }

  it('a member with one overdue lesson is not current; future-only groups are not enrolled', () => {
    const completed = new Set(['m1|s1', 'm1|s2', 'm2|s1', 'm4|s5'])
    expect(computeEngagement([g1, future, g3], completed, new Set(['m1', 'm9']), today)).toEqual({
      currentCount: 2, // m1, m4 — m2 still owes s2
      enrolledCount: 3, // m1, m2, m4 — m3's group has nothing due
      groupCount: 2,
      percent: 67,
      activeCount: 2,
    })
  })

  it('needs a member caught up in every in-scope group they belong to', () => {
    const shared = { id: 'g4', memberIds: ['m1'], schedules: [{ id: 's7', date: '2026-10-21' }] }
    const result = computeEngagement([g1, shared], new Set(['m1|s1', 'm1|s2']), new Set(), today)
    expect(result.currentCount).toBe(0)
    expect(result.enrolledCount).toBe(2)
  })

  it('is 0% with nobody enrolled', () => {
    expect(computeEngagement([future], new Set(), new Set(), today)).toEqual({
      currentCount: 0, enrolledCount: 0, groupCount: 0, percent: 0, activeCount: 0,
    })
  })
})

describe('active window (D3: last 7 days, today included)', () => {
  it('starts at local midnight six days ago', () => {
    expect(activeWindow(NOW, CHI)).toEqual({ from: at('2026-10-19T05:00:00Z'), to: NOW })
  })

  it('counts a session at the window start and drops one a second earlier', () => {
    const window = activeWindow(NOW, CHI)
    const active = activeMembers(
      [session('in', '2026-10-19T05:00:00Z', 60), session('out', '2026-10-19T04:59:59Z', 60), session('in', '2026-10-24T15:00:00Z', 60)],
      window
    )
    expect([...active]).toEqual(['in'])
  })
})

describe('getHomeEngagement', () => {
  it('reads stored dates (D14): a UTC-midnight schedule dated today is not overdue in Chicago', async () => {
    prismaMock.group.findMany.mockResolvedValue([
      {
        id: 'g1',
        members: [{ memberId: 'm1' }, { memberId: 'm2' }],
        enrollments: [
          {
            lessonSchedules: [
              { id: 's1', scheduledDate: at('2026-10-24T17:00:00Z') },
              { id: 's2', scheduledDate: at('2026-10-25T00:00:00Z') }, // = Oct 24 19:00 CDT, but stored date is today
            ],
          },
        ],
      },
    ])
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([{ memberId: 'm1', lessonScheduleId: 's1' }])
    vi.mocked(loadSessions).mockResolvedValue([session('m1', '2026-10-24T15:00:00Z', 600)])

    expect(await getHomeEngagement(SCOPE, CHI, NOW)).toEqual({
      currentCount: 1, enrolledCount: 2, groupCount: 1, percent: 50, activeCount: 1,
    })
    expect(prismaMock.group.findMany).toHaveBeenCalledWith({
      where: { isActive: true, OR: [{ organizationId: { in: ['o1'] } }, { id: { in: [] } }] },
      select: {
        id: true,
        members: { where: { isActive: true, memberId: { not: null } }, select: { memberId: true } },
        enrollments: {
          select: { lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } } },
        },
      },
    })
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: { not: null }, lessonScheduleId: { in: ['s1'] }, memberId: { in: ['m1', 'm2'] } },
      select: { memberId: true, lessonScheduleId: true },
    })
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at('2026-10-19T05:00:00Z'), to: NOW })
  })
})
