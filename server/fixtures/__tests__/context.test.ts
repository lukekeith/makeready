import { describe, expect, it } from 'vitest'
import type { PrismaClient } from '../../src/generated/prisma/index.js'
import {
  FIXTURE_ENROLLMENT_IDS,
  FIXTURE_GROUP_IDS,
  FIXTURE_IDS,
  FIXTURE_MEMBER_IDS,
  FIXTURE_ORG_ID,
  FIXTURE_USER_ID,
  fixtureId,
} from '../ids.js'
import {
  addDays,
  atLocalHour,
  createContext,
  createPrng,
  daysAgo,
  localDate,
  weekdayOf,
  zonedTime,
} from '../context.js'

const UUID = /^f1f1f1f1-[0-9a-f]{4}-4000-8000-[0-9a-f]{12}$/

describe('fixture ids (D15)', () => {
  it('builds valid f1f1f1f1-prefixed UUIDs with the kind in the second group', () => {
    expect(fixtureId('group', 1)).toBe('f1f1f1f1-0003-4000-8000-000000000001')
    expect(fixtureId('schedule', 4021)).toBe('f1f1f1f1-0009-4000-8000-000000000fb5')
    expect(() => fixtureId('member', -1)).toThrow(RangeError)
    expect(() => fixtureId('member', 1.5)).toThrow(RangeError)
  })

  it('fixes every base identity, all distinct and well-formed', () => {
    expect(FIXTURE_GROUP_IDS).toHaveLength(3)
    expect(FIXTURE_MEMBER_IDS).toHaveLength(24)
    expect(FIXTURE_ENROLLMENT_IDS).toHaveLength(4)
    const all = [
      FIXTURE_USER_ID,
      FIXTURE_ORG_ID,
      ...FIXTURE_GROUP_IDS,
      ...FIXTURE_MEMBER_IDS,
      FIXTURE_IDS.programs.days21,
      FIXTURE_IDS.programs.days30,
      ...FIXTURE_ENROLLMENT_IDS,
    ]
    for (const id of all) expect(id).toMatch(UUID)
    expect(new Set(all).size).toBe(all.length)
  })
})

describe('seeded PRNG', () => {
  it('is deterministic for a seed and stays in [0, 1)', () => {
    const a = createPrng()
    const b = createPrng()
    const xs = Array.from({ length: 50 }, () => a.next())
    const ys = Array.from({ length: 50 }, () => b.next())
    expect(xs).toEqual(ys)
    for (const x of xs) {
      expect(x).toBeGreaterThanOrEqual(0)
      expect(x).toBeLessThan(1)
    }
    expect(createPrng(7).next()).not.toBe(createPrng(8).next())
  })

  it('shuffles deterministically without losing items', () => {
    const items = Array.from({ length: 20 }, (_, i) => i)
    const s1 = createPrng().shuffle(items)
    const s2 = createPrng().shuffle(items)
    expect(s1).toEqual(s2)
    expect([...s1].sort((x, y) => x - y)).toEqual(items)
    expect(items[0]).toBe(0) // input untouched
  })

  it('int() stays inside its inclusive bounds', () => {
    const r = createPrng()
    for (let i = 0; i < 200; i++) {
      const n = r.int(7, 9)
      expect(n).toBeGreaterThanOrEqual(7)
      expect(n).toBeLessThanOrEqual(9)
    }
  })
})

describe('America/Chicago date helpers (D9, D11)', () => {
  it('converts Chicago wall time to UTC across both offsets and DST', () => {
    expect(zonedTime('2026-07-01', 7).toISOString()).toBe('2026-07-01T12:00:00.000Z') // CDT −5
    expect(zonedTime('2026-07-01', 13.5).toISOString()).toBe('2026-07-01T18:30:00.000Z')
    expect(zonedTime('2026-01-15', 21).toISOString()).toBe('2026-01-16T03:00:00.000Z') // CST −6
    expect(zonedTime('2026-03-08', 12).toISOString()).toBe('2026-03-08T17:00:00.000Z') // DST-start day
  })

  it('reads the Chicago calendar date of an instant', () => {
    expect(localDate(new Date('2026-01-16T03:00:00.000Z'))).toBe('2026-01-15')
    expect(localDate(new Date('2026-07-01T05:30:00.000Z'))).toBe('2026-07-01')
  })

  it('anchors daysAgo at Chicago noon and atLocalHour on the instant’s Chicago date', () => {
    const now = new Date('2026-07-10T15:00:00.000Z') // 10:00 CDT
    expect(daysAgo(now, 3).toISOString()).toBe('2026-07-07T17:00:00.000Z')
    expect(atLocalHour(new Date('2026-01-16T03:30:00.000Z'), 9).toISOString()).toBe('2026-01-15T15:00:00.000Z')
  })

  it('does date-only arithmetic and weekday lookup', () => {
    expect(addDays('2026-02-28', 1)).toBe('2026-03-01')
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28')
    expect(weekdayOf('2026-10-25')).toBe(0) // Sunday
    expect(weekdayOf('2026-10-31')).toBe(6) // Saturday
  })
})

describe('createContext', () => {
  it('derives today and the day-offset helpers from now', () => {
    const now = new Date('2026-10-25T20:00:00.000Z') // 15:00 CDT, Sunday
    const ctx = createContext({} as PrismaClient, now)
    expect(ctx.today).toBe('2026-10-25')
    expect(ctx.dateOf(-1)).toBe('2026-10-24')
    expect(ctx.at(-1, 7).toISOString()).toBe('2026-10-24T12:00:00.000Z')
    expect(ctx.daysAgo(2).toISOString()).toBe('2026-10-23T17:00:00.000Z')
    expect(ctx.ids.user).toBe(FIXTURE_USER_ID)
    expect(ctx.created.groups).toEqual([])
  })
})
