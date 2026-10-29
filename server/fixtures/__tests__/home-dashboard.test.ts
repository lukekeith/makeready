import { describe, expect, it } from 'vitest'
import { FIXTURES_DIR, availableScenarios, loadLayers } from '../runner.js'
import {
  BAD_WEEK_FACTOR,
  FATIGUE_AT_END,
  FOLLOWED_ENROLLMENT_IDS,
  HABITS,
  HISTORY_CADENCE,
  POP_CURVE,
  apportion,
  badWeekFactor,
  behindBy,
  fatigue,
  habitOf,
  memberRate,
} from '../screens/home-dashboard.js'
import { FIXTURE_ENROLLMENT_IDS } from '../ids.js'

describe('apportion', () => {
  it('splits a total exactly, at least one per slot, within caps', () => {
    const out = apportion(100, [1, 2, 3, 4], [50, 50, 50, 20])
    expect(out.reduce((a, b) => a + b, 0)).toBe(100)
    expect(out[3]).toBeLessThanOrEqual(20)
    for (const n of out) expect(n).toBeGreaterThanOrEqual(1)
  })

  it('throws when the caps cannot hold the total', () => {
    expect(() => apportion(10, [1, 1], [3, 3])).toThrow('capacity')
  })
})

describe('behindBy (home-dashboard-data D12, D17)', () => {
  const indices = Array.from({ length: 24 }, (_, i) => i)

  it('keeps 10 of 24 members caught up — 42%, the D7 yellow band', () => {
    const caughtUp = indices.filter((i) => behindBy(i) === 0)
    expect(caughtUp).toHaveLength(10)
    expect(Math.round((caughtUp.length / 24) * 100)).toBe(42)
  })

  it('puts every other member 1–5 lessons behind', () => {
    for (const i of indices.filter((n) => behindBy(n) !== 0)) {
      expect(behindBy(i)).toBeGreaterThanOrEqual(1)
      expect(behindBy(i)).toBeLessThanOrEqual(5)
    }
  })

  it('has caught-up members in each of the three groups', () => {
    for (const g of [0, 1, 2]) {
      expect(indices.slice(g * 8, g * 8 + 8).some((i) => behindBy(i) === 0)).toBe(true)
    }
  })
})

describe('realistic usage model (home-dashboard-data D21)', () => {
  const indices = Array.from({ length: 24 }, (_, i) => i)

  it('gives 9 early, 3 lunch, 9 evening and 3 night-owl habits', () => {
    const count = (h: string) => indices.filter((i) => habitOf(i) === h).length
    expect([count('early'), count('lunch'), count('evening'), count('night')]).toEqual([9, 3, 9, 3])
  })

  it('opens every habit window before midnight', () => {
    for (const w of Object.values(HABITS)) expect(w.end).toBeLessThan(24)
  })

  it('keeps off-habit opens near zero between 1 and 5 AM', () => {
    const total = POP_CURVE.reduce((s, v) => s + v, 0)
    const night = POP_CURVE.slice(1, 5).reduce((s, v) => s + v, 0)
    expect(POP_CURVE).toHaveLength(24)
    expect(night / total).toBeLessThan(0.01)
  })

  it('rates members 55–90% (caught-up 100%), fading to 55% of that by the last lesson', () => {
    for (const i of indices) {
      const r = memberRate(i)
      if (behindBy(i) === 0) expect(r).toBe(1)
      else {
        expect(r).toBeGreaterThanOrEqual(0.55)
        expect(r).toBeLessThanOrEqual(0.9)
      }
    }
    expect(fatigue(1, 30)).toBe(1)
    expect(fatigue(30, 30)).toBeCloseTo(FATIGUE_AT_END)
  })

  it('cuts the three bad weeks to 30%', () => {
    expect(badWeekFactor(-121)).toBe(BAD_WEEK_FACTOR)
    expect(badWeekFactor(-22)).toBe(BAD_WEEK_FACTOR)
    expect(badWeekFactor(-50)).toBe(1)
  })

  it("meets Men's Mon/Wed/Fri, Young Adults daily, Women's Mon–Fri", () => {
    expect(HISTORY_CADENCE.map((c) => c.length)).toEqual([3, 7, 5])
  })
})

describe('followed enrollments (D12)', () => {
  it('follows enrollments 2, 3 and 4', () => {
    expect(FOLLOWED_ENROLLMENT_IDS).toEqual([FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]])
  })
})

describe('layer discovery (D2, D6)', () => {
  it('finds base plus the groups, groups-enroll-program, home-dashboard, invite-member, members and shared-edit-field layers; only shared-edit-field adds a scenario (sparse)', async () => {
    const layers = await loadLayers(FIXTURES_DIR)
    expect(layers.screens.map((s) => s.name)).toEqual([
      'create-group',
      'create-study-program',
      'groups-detail',
      'groups-enroll-program',
      'groups-home',
      'home-dashboard',
      'invite-member',
      'members-home',
      'members-profile',
      'shared-edit-field',
      'study-program-home',
      'study-programs',
    ])
    expect(availableScenarios(layers.screens)).toEqual(['full', 'sparse', 'empty'])
  })
})
