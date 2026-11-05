/** master-search §server: every C1 arm runs on a database whose ids are text, as dev and prod are. */
import { afterEach, describe, expect, it, vi } from 'vitest'
import { withTextIdSearchDb } from './helpers/master-search-db.js'
import { SEARCH_TYPES, parseRankedParams } from '../src/services/master-search-query.js'

const savedEnv = { DATABASE_URL: process.env.DATABASE_URL, DIRECT_URL: process.env.DIRECT_URL }
let close: (() => Promise<void>) | undefined

async function loadSearchAgainst(url: string) {
  process.env.DATABASE_URL = url
  process.env.DIRECT_URL = url
  delete (globalThis as { prisma?: unknown }).prisma
  vi.resetModules()
  const { prisma } = await import('../src/lib/prisma.js')
  const { searchRanked, recordRecentResult, listRecentResults } = await import('../src/services/master-search.js')
  const { seedMasterSearchWorld } = await import('./helpers/master-search-world.js')
  close = () => prisma.$disconnect()
  return { searchRanked, recordRecentResult, listRecentResults, world: await seedMasterSearchWorld(prisma) }
}

afterEach(() => {
  process.env.DATABASE_URL = savedEnv.DATABASE_URL
  process.env.DIRECT_URL = savedEnv.DIRECT_URL
  delete (globalThis as { prisma?: unknown }).prisma
})

describe.skipIf(!process.env.TEST_DATABASE_URL)('C1 on a text-id database', () => {
  it('every arm runs on a text-id database', async () => {
    await withTextIdSearchDb(async (url) => {
      try {
        const { searchRanked, world } = await loadSearchAgainst(url)
        for (const type of SEARCH_TYPES) {
          const { items } = await searchRanked(world.owner.id, parseRankedParams({ q: 'grace', types: type, ...(type === 'TEMPLATE' ? { q: 'video study' } : {}) }))
          expect(items.length, type).toBeGreaterThan(0)
        }

        // Every arm in one UNION ALL, and the cursor predicate, by following nextCursor to the end.
        const seen: string[] = []
        let cursor: string | undefined
        let pages = 0
        do {
          const page = await searchRanked(world.owner.id, parseRankedParams({ q: 'grace', limit: '5', ...(cursor ? { cursor } : {}) }))
          seen.push(...page.items.map((i) => `${i.type}:${i.id}`))
          cursor = page.nextCursor ?? undefined
          pages += 1
        } while (cursor)
        expect(pages).toBeGreaterThan(1)
        expect(new Set(seen).size).toBe(seen.length)
        expect(new Set(seen.map((key) => key.split(':')[0]))).toEqual(new Set(SEARCH_TYPES))
      } finally {
        await close?.()
      }
    })
  }, 180_000)

  it('recents work on a text-id database', async () => {
    await withTextIdSearchDb(async (url) => {
      try {
        const { recordRecentResult, listRecentResults, world } = await loadSearchAgainst(url)
        expect(await recordRecentResult(world.owner.id, 'GROUP', world.groupA)).toBe(true)
        expect((await listRecentResults(world.owner.id, {})).map((i: any) => i.id)).toEqual([world.groupA])
      } finally {
        await close?.()
      }
    })
  }, 180_000)
})
