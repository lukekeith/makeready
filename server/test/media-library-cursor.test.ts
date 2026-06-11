/**
 * Media library keyset pagination — unit tests (media plan M1.2/M1.6)
 *
 * Tests the cursor codec, the keyset predicate (incl. the redundant
 * createdAt upper bound that makes the index condition pushable), mode
 * selection (page vs cursor), hasMore/nextCursor derivation, and filter
 * composition — with Prisma mocked. The real index-scan path was verified
 * by EXPLAIN against the live schema (Index Only Scan Backward using
 * idx_media_organizationId_createdAt_id) and by full walk-equivalence
 * against a seeded org (cursor walk byte-identical to page walk).
 */

import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockFindMany = vi.fn()
const mockCount = vi.fn()

vi.mock('../src/lib/prisma.js', () => ({
  prisma: {
    media: {
      findMany: (...args: unknown[]) => mockFindMany(...args),
      count: (...args: unknown[]) => mockCount(...args),
    },
  },
}))

vi.mock('../src/services/claude.js', () => ({
  analyzeImage: vi.fn(),
}))

const { listLibrary, encodeLibraryCursor, decodeLibraryCursor } = await import(
  '../src/services/media-library.js'
)

function row(id: string, createdAt: Date) {
  return {
    id,
    createdAt,
    tags: [],
    _count: { usages: 0 },
  }
}

describe('cursor codec', () => {
  it('round-trips createdAt + id', () => {
    const createdAt = new Date('2026-06-11T12:34:56.789Z')
    const decoded = decodeLibraryCursor(encodeLibraryCursor(createdAt, 'abc-123'))
    expect(decoded).not.toBeNull()
    expect(decoded!.createdAt.toISOString()).toBe(createdAt.toISOString())
    expect(decoded!.id).toBe('abc-123')
  })

  it('rejects garbage and malformed payloads', () => {
    expect(decodeLibraryCursor('garbage!!!')).toBeNull()
    expect(decodeLibraryCursor(Buffer.from('no-separator').toString('base64url'))).toBeNull()
    expect(decodeLibraryCursor(Buffer.from('not-a-date|id').toString('base64url'))).toBeNull()
  })
})

describe('listLibrary modes', () => {
  beforeEach(() => {
    mockFindMany.mockReset()
    mockCount.mockReset()
  })

  it('page mode: exact total, plus nextCursor/hasMore for cursor-capable clients', async () => {
    const t = new Date('2026-06-11T10:00:00.000Z')
    mockFindMany.mockResolvedValue([row('a', t), row('b', t)])
    mockCount.mockResolvedValue(5)

    const result = await listLibrary({ organizationId: 'org', limit: 2, page: 1 })

    expect(result.total).toBe(5)
    expect(result.totalPages).toBe(3)
    expect(result.hasMore).toBe(true)
    expect(result.nextCursor).toBe(encodeLibraryCursor(t, 'b'))

    const args = mockFindMany.mock.calls[0][0]
    expect(args.skip).toBe(0)
    expect(args.take).toBe(2)
    // id tiebreaker makes ordering deterministic in both modes
    expect(args.orderBy).toEqual([{ createdAt: 'desc' }, { id: 'desc' }])
  })

  it('cursor mode: limit+1 probe, exact hasMore, no count query, total omitted', async () => {
    const t1 = new Date('2026-06-11T10:00:00.000Z')
    const t2 = new Date('2026-06-11T09:00:00.000Z')
    mockFindMany.mockResolvedValue([row('a', t1), row('b', t1), row('c', t2)])

    const cursor = encodeLibraryCursor(new Date('2026-06-11T11:00:00.000Z'), 'z')
    const result = await listLibrary({ organizationId: 'org', limit: 2, cursor })

    expect(mockCount).not.toHaveBeenCalled()
    expect('total' in result).toBe(false)
    expect(result.data).toHaveLength(2)
    expect(result.hasMore).toBe(true)
    expect(result.nextCursor).toBe(encodeLibraryCursor(t1, 'b'))

    const args = mockFindMany.mock.calls[0][0]
    expect(args.take).toBe(3) // limit + 1 probe
    expect(args.skip).toBeUndefined()
  })

  it('cursor mode: final page reports hasMore=false and nextCursor=null', async () => {
    mockFindMany.mockResolvedValue([row('a', new Date())])

    const cursor = encodeLibraryCursor(new Date(), 'z')
    const result = await listLibrary({ organizationId: 'org', limit: 2, cursor })

    expect(result.hasMore).toBe(false)
    expect(result.nextCursor).toBeNull()
  })

  it('keyset predicate carries the pushable createdAt bound AND the strict tiebreak', async () => {
    mockFindMany.mockResolvedValue([])
    const at = new Date('2026-06-11T11:00:00.000Z')
    await listLibrary({ organizationId: 'org', limit: 2, cursor: encodeLibraryCursor(at, 'cid') })

    const where = mockFindMany.mock.calls[0][0].where
    expect(where.AND).toEqual([
      // index-condition-pushable upper bound (keeps deep pages flat)
      { createdAt: { lte: at } },
      // strict keyset boundary
      {
        OR: [
          { createdAt: { lt: at } },
          { createdAt: at, id: { lt: 'cid' } },
        ],
      },
    ])
  })

  it('keyset predicate composes with q-search OR instead of clobbering it', async () => {
    mockFindMany.mockResolvedValue([])
    await listLibrary({
      organizationId: 'org',
      limit: 2,
      q: 'sunset',
      cursor: encodeLibraryCursor(new Date(), 'cid'),
    })

    const where = mockFindMany.mock.calls[0][0].where
    expect(where.OR).toBeDefined() // q-search clause intact at top level
    expect(where.AND).toHaveLength(2) // keyset lives under AND
  })

  it('invalid cursor falls back to page mode (exact total, count runs)', async () => {
    mockFindMany.mockResolvedValue([])
    mockCount.mockResolvedValue(0)

    const result = await listLibrary({ organizationId: 'org', limit: 2, cursor: 'garbage!!!' })

    expect(mockCount).toHaveBeenCalled()
    expect(result.total).toBe(0)
    expect(mockFindMany.mock.calls[0][0].where.AND).toBeUndefined()
  })
})
