import { describe, expect, it } from 'vitest'
import { FIXTURES_DIR, availableScenarios, loadLayers } from '../runner.js'
import {
  DAY_PARTS,
  FOLLOWED_ENROLLMENT_IDS,
  SITTING_MAX_MINUTES,
  apportion,
  behindBy,
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

describe('sittings stay in the 07:00–21:00 band (D11 of ui2-fixtures)', () => {
  it('opens no earlier than 07:00 and finishes by 21:00 even at the longest length', () => {
    for (const part of DAY_PARTS) {
      expect(part.start).toBeGreaterThanOrEqual(7)
      expect(part.end + SITTING_MAX_MINUTES / 60).toBeLessThanOrEqual(21)
    }
  })
})

describe('followed enrollments (D12)', () => {
  it('follows enrollments 2, 3 and 4', () => {
    expect(FOLLOWED_ENROLLMENT_IDS).toEqual([FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]])
  })
})

describe('layer discovery (D2, D6)', () => {
  it('finds base plus the home-dashboard layer, which offers full only', async () => {
    const layers = await loadLayers(FIXTURES_DIR)
    expect(layers.screens.map((s) => s.name)).toEqual(['home-dashboard'])
    expect(availableScenarios(layers.screens)).toEqual(['full', 'empty'])
  })
})
