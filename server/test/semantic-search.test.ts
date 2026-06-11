/**
 * Semantic Bible Search — unit tests
 *
 * Tests result shaping and similarity-threshold filtering with the embedding
 * model and database mocked. The real model/pgvector path is covered by the
 * manual smoke flow (npm run model:prefetch + /api/search/smart).
 */

import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockEmbedQuery = vi.fn()
const mockQueryRaw = vi.fn()

vi.mock('../src/services/embeddings.js', () => ({
  embedQuery: mockEmbedQuery,
  embedPassages: vi.fn(),
  isEmbeddingsEnabled: () => true,
  EMBEDDING_MODEL: 'Xenova/bge-small-en-v1.5',
  EMBEDDING_DIMS: 384,
}))

vi.mock('../src/lib/prisma.js', () => ({
  prisma: { $queryRaw: mockQueryRaw },
  Prisma: { sql: (strings: TemplateStringsArray, ...values: unknown[]) => ({ strings, values }) },
}))

const { searchVersesSemantic } = await import('../src/services/semantic-search.js')

function row(overrides: Partial<{ bookNumber: number; chapter: number; verse: number; text: string; similarity: number }> = {}) {
  return {
    id: 'uuid-1',
    bookNumber: 43,
    chapter: 3,
    verse: 16,
    text: 'For God so loved the world...',
    similarity: 0.8,
    ...overrides,
  }
}

beforeEach(() => {
  mockEmbedQuery.mockReset()
  mockQueryRaw.mockReset()
  mockEmbedQuery.mockResolvedValue(new Array(384).fill(0.05))
})

describe('searchVersesSemantic', () => {
  it('maps rows to the smart-search verse result shape', async () => {
    mockQueryRaw.mockResolvedValue([row()])

    const result = await searchVersesSemantic('god so loved the world', 'NASB', 10)

    expect(result.type).toBe('semantic')
    expect(result.translation).toBe('NASB')
    expect(result.sourceTranslation).toBe('WEB')
    expect(result.fumsToken).toBeUndefined()
    expect(result.total).toBe(1)
    expect(result.results[0]).toEqual({
      verseId: 'JHN.3.16',
      book: { bookNumber: 43, name: 'John', abbrev: 'John' },
      chapter: 3,
      verse: 16,
      text: 'For God so loved the world...',
      reference: 'John 3:16',
      similarity: 0.8,
    })
  })

  it('filters out rows below the similarity threshold (default 0.6)', async () => {
    mockQueryRaw.mockResolvedValue([
      row({ similarity: 0.82 }),
      row({ bookNumber: 1, chapter: 1, verse: 1, similarity: 0.41 }),
    ])

    const result = await searchVersesSemantic('a query', 'KJV', 10)

    expect(result.total).toBe(1)
    expect(result.results.map(r => r.similarity)).toEqual([0.82])
  })

  it('returns empty results when nothing clears the threshold', async () => {
    mockQueryRaw.mockResolvedValue([row({ similarity: 0.3 }), row({ similarity: 0.2 })])

    const result = await searchVersesSemantic('xyzzy nonsense', 'NASB', 10)

    expect(result.total).toBe(0)
    expect(result.results).toEqual([])
  })

  it('rounds similarity to 3 decimal places', async () => {
    mockQueryRaw.mockResolvedValue([row({ similarity: 0.7654321 })])

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    expect(result.results[0].similarity).toBe(0.765)
  })

  it('propagates embedding failures (route falls back to keyword search)', async () => {
    mockEmbedQuery.mockRejectedValue(new Error('model load failed'))

    await expect(searchVersesSemantic('a query', 'NASB', 10)).rejects.toThrow('model load failed')
  })
})
