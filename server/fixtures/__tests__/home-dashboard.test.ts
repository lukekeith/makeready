import { describe, expect, it } from 'vitest'
import { addDays, createPrng, weekdayOf } from '../context.js'
import { FIXTURES_DIR, availableScenarios, loadLayers } from '../runner.js'
import { apportion, dailyCompletionCounts } from '../screens/home-dashboard.js'

const TODAY = '2026-10-25'
// Member × schedule pairs per day under the D11 stagger (8 members per group).
const capacity = (o: number) => (o <= -30 ? 8 : o <= -21 ? 16 : o <= -19 ? 24 : o <= -14 ? 16 : 24)

function sum(counts: Map<number, number>, from: number, to: number): number {
  let total = 0
  for (let o = from; o <= to; o++) total += counts.get(o) ?? 0
  return total
}

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

describe('dailyCompletionCounts (D11, F16)', () => {
  const counts = dailyCompletionCounts(TODAY, createPrng(), capacity)

  it('covers exactly days −48 … −1, each non-empty and within capacity', () => {
    expect([...counts.keys()].sort((a, b) => a - b)).toEqual(Array.from({ length: 48 }, (_, i) => i - 48))
    for (const [o, n] of counts) {
      expect(n).toBeGreaterThanOrEqual(1)
      expect(n).toBeLessThanOrEqual(capacity(o))
    }
  })

  it('makes the last 24 days 115% (±3%) of the 24 before, with ≥ 18 non-empty days', () => {
    const current = sum(counts, -23, 0)
    const previous = sum(counts, -47, -24)
    expect(current / previous).toBeGreaterThanOrEqual(1.12)
    expect(current / previous).toBeLessThanOrEqual(1.18)
    let nonEmpty = 0
    for (let o = -23; o <= 0; o++) if ((counts.get(o) ?? 0) > 0) nonEmpty++
    expect(nonEmpty).toBeGreaterThanOrEqual(18)
  })

  it('keeps weekends near 40% of weekdays', () => {
    const weekend: number[] = []
    const weekday: number[] = []
    for (const [o, n] of counts) {
      const day = weekdayOf(addDays(TODAY, o))
      ;(day === 0 || day === 6 ? weekend : weekday).push(n)
    }
    const avg = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length
    const ratio = avg(weekend) / avg(weekday)
    expect(ratio).toBeGreaterThanOrEqual(0.3)
    expect(ratio).toBeLessThanOrEqual(0.55)
  })

  it('is identical across runs (fixed seed)', () => {
    expect(dailyCompletionCounts(TODAY, createPrng(), capacity)).toEqual(counts)
  })
})

describe('layer discovery (D2, D6)', () => {
  it('finds base plus the home-dashboard layer, which offers full only', async () => {
    const layers = await loadLayers(FIXTURES_DIR)
    expect(layers.screens.map((s) => s.name)).toEqual(['home-dashboard'])
    expect(availableScenarios(layers.screens)).toEqual(['full', 'empty'])
  })
})
