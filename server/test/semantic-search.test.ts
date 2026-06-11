/**
 * Semantic Bible Search — unit tests
 *
 * Tests result shaping, similarity-threshold filtering, and display-text
 * resolution in the requested translation, with the embedding model,
 * database, and API.Bible chapter cache mocked. The real model/pgvector
 * path is covered by the manual smoke flow (npm run model:prefetch +
 * /api/search/smart).
 */

import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockEmbedQuery = vi.fn()
const mockQueryRaw = vi.fn()
const mockTranslationFindUnique = vi.fn()
const mockVerseFindMany = vi.fn()
const mockResolveBibleId = vi.fn()
const mockGetChapterVerses = vi.fn()
const mockGetVerse = vi.fn()

vi.mock('../src/services/embeddings.js', () => ({
  embedQuery: mockEmbedQuery,
  embedPassages: vi.fn(),
  isEmbeddingsEnabled: () => true,
  EMBEDDING_MODEL: 'Xenova/bge-small-en-v1.5',
  EMBEDDING_DIMS: 384,
}))

vi.mock('../src/lib/prisma.js', () => ({
  prisma: {
    $queryRaw: mockQueryRaw,
    translation: { findUnique: mockTranslationFindUnique },
    verse: { findMany: mockVerseFindMany },
  },
  Prisma: { sql: (strings: TemplateStringsArray, ...values: unknown[]) => ({ strings, values }) },
}))

vi.mock('../src/services/bible-metadata.js', () => ({
  resolveBibleId: mockResolveBibleId,
}))

vi.mock('../src/services/bible-chapter.js', () => ({
  getChapterVerses: mockGetChapterVerses,
}))

vi.mock('../src/services/api-bible.js', () => ({
  getVerse: mockGetVerse,
  extractFumsToken: (meta: any) => meta?.fumsToken,
}))

const { searchVersesSemantic } = await import('../src/services/semantic-search.js')

function row(overrides: Partial<{ bookNumber: number; chapter: number; verse: number; text: string; similarity: number }> = {}) {
  return {
    id: 'uuid-1',
    bookNumber: 43,
    chapter: 3,
    verse: 16,
    text: 'WEB: For God so loved the world...',
    similarity: 0.8,
    ...overrides,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
  mockEmbedQuery.mockResolvedValue(new Array(384).fill(0.05))
  mockTranslationFindUnique.mockResolvedValue(null)
  mockResolveBibleId.mockResolvedValue(null)
})

describe('searchVersesSemantic', () => {
  it('maps rows to the smart-search verse result shape (WEB requested — no resolution)', async () => {
    mockQueryRaw.mockResolvedValue([row()])

    const result = await searchVersesSemantic('god so loved the world', 'WEB', 10)

    expect(result.type).toBe('semantic')
    expect(result.translation).toBe('WEB')
    expect(result.fumsToken).toBeUndefined()
    expect(result.total).toBe(1)
    expect(result.results[0]).toEqual({
      verseId: 'JHN.3.16',
      book: { bookNumber: 43, name: 'John', abbrev: 'John' },
      chapter: 3,
      verse: 16,
      text: 'WEB: For God so loved the world...',
      reference: 'John 3:16',
      similarity: 0.8,
    })
    // WEB is the embedding source — no lookup should happen
    expect(mockTranslationFindUnique).not.toHaveBeenCalled()
  })

  it('filters out rows below the similarity threshold (default 0.6)', async () => {
    mockQueryRaw.mockResolvedValue([
      row({ similarity: 0.82 }),
      row({ bookNumber: 1, chapter: 1, verse: 1, similarity: 0.41 }),
    ])

    const result = await searchVersesSemantic('a query', 'WEB', 10)

    expect(result.total).toBe(1)
    expect(result.results.map(r => r.similarity)).toEqual([0.82])
  })

  it('returns empty results when nothing clears the threshold', async () => {
    mockQueryRaw.mockResolvedValue([row({ similarity: 0.3 }), row({ similarity: 0.2 })])

    const result = await searchVersesSemantic('xyzzy nonsense', 'WEB', 10)

    expect(result.total).toBe(0)
    expect(result.results).toEqual([])
  })

  it('resolves text from the local verses table for locally-stored translations', async () => {
    mockQueryRaw.mockResolvedValue([row(), row({ bookNumber: 1, chapter: 1, verse: 1, text: 'WEB: In the beginning...' })])
    mockTranslationFindUnique.mockResolvedValue({ id: 'kjv-id', code: 'KJV' })
    mockVerseFindMany.mockResolvedValue([
      { bookNumber: 43, chapter: 3, verse: 16, text: 'KJV: For God so loved the world...' },
      // Genesis 1:1 intentionally missing — falls back to WEB
    ])

    const result = await searchVersesSemantic('a query', 'KJV', 10)

    expect(result.results[0].text).toBe('KJV: For God so loved the world...')
    expect(result.results[0].sourceTranslation).toBeUndefined()
    expect(result.results[1].text).toBe('WEB: In the beginning...')
    expect(result.results[1].sourceTranslation).toBe('WEB')
    expect(result.fumsToken).toBeUndefined()
  })

  it('falls through to API.Bible when a local translation row has no verses (post-cleanup KJV)', async () => {
    mockQueryRaw.mockResolvedValue([row()])
    // KJV translation row still exists (highlight FKs) but its verses were cleaned up
    mockTranslationFindUnique.mockResolvedValue({ id: 'kjv-id', code: 'KJV' })
    mockVerseFindMany.mockResolvedValue([])
    mockResolveBibleId.mockResolvedValue('kjv-bible-id')
    mockGetChapterVerses.mockResolvedValue({
      verses: [{ verse: 16, text: 'KJV via API.Bible' }],
      copyright: null,
      fumsToken: 'tok',
    })

    const result = await searchVersesSemantic('a query', 'KJV', 10)

    expect(result.results[0].text).toBe('KJV via API.Bible')
    expect(result.results[0].sourceTranslation).toBeUndefined()
    expect(mockGetChapterVerses).toHaveBeenCalledWith('kjv-bible-id', 'JHN', 3, { skipFums: true })
  })

  it('resolves text via cached API.Bible chapters for remote translations', async () => {
    mockQueryRaw.mockResolvedValue([
      row(),
      row({ bookNumber: 43, chapter: 3, verse: 17, text: 'WEB: For God did not send...' }),
      row({ bookNumber: 19, chapter: 23, verse: 1, text: 'WEB: Yahweh is my shepherd...' }),
    ])
    mockResolveBibleId.mockResolvedValue('nasb-bible-id')
    mockGetChapterVerses.mockImplementation(async (_bibleId: string, bookId: string) => {
      if (bookId === 'JHN') {
        return {
          verses: [{ verse: 16, text: 'NASB: John 3:16 text' }, { verse: 17, text: 'NASB: John 3:17 text' }],
          copyright: 'NASB copyright',
          fumsToken: 'token-from-miss',
        }
      }
      return { verses: [{ verse: 1, text: 'NASB: Psalm 23:1 text' }], copyright: 'NASB copyright', fumsToken: null }
    })

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    // One chapter fetch per distinct chapter (John 3 shared by two results)
    expect(mockGetChapterVerses).toHaveBeenCalledTimes(2)
    expect(mockGetChapterVerses).toHaveBeenCalledWith('nasb-bible-id', 'JHN', 3, { skipFums: true })
    expect(result.results.map(r => r.text)).toEqual([
      'NASB: John 3:16 text',
      'NASB: John 3:17 text',
      'NASB: Psalm 23:1 text',
    ])
    expect(result.results.every(r => r.sourceTranslation === undefined)).toBe(true)
    expect(result.fumsToken).toBe('token-from-miss')
    expect(result.copyright).toBe('NASB copyright')
    // Token came from the chapter fetch — no extra getVerse call
    expect(mockGetVerse).not.toHaveBeenCalled()
  })

  it('fetches a single FUMS token when all chapters were cache hits', async () => {
    mockQueryRaw.mockResolvedValue([row()])
    mockResolveBibleId.mockResolvedValue('nasb-bible-id')
    mockGetChapterVerses.mockResolvedValue({
      verses: [{ verse: 16, text: 'NASB: John 3:16 text' }],
      copyright: 'NASB copyright',
      fumsToken: null, // cache hit with skipFums
    })
    mockGetVerse.mockResolvedValue({ meta: { fumsToken: 'single-token' } })

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    expect(result.fumsToken).toBe('single-token')
    expect(mockGetVerse).toHaveBeenCalledTimes(1)
  })

  it('keeps WEB text per-verse when a chapter fetch fails', async () => {
    mockQueryRaw.mockResolvedValue([row()])
    mockResolveBibleId.mockResolvedValue('nasb-bible-id')
    mockGetChapterVerses.mockRejectedValue(new Error('API.Bible down'))

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    expect(result.results[0].text).toBe('WEB: For God so loved the world...')
    expect(result.results[0].sourceTranslation).toBe('WEB')
    // No API.Bible text served — no FUMS token needed
    expect(mockGetVerse).not.toHaveBeenCalled()
  })

  it('marks all verses as WEB when the translation cannot be resolved at all', async () => {
    mockQueryRaw.mockResolvedValue([row()])
    mockResolveBibleId.mockResolvedValue(null)

    const result = await searchVersesSemantic('a query', 'NOPE', 10)

    expect(result.results[0].sourceTranslation).toBe('WEB')
    expect(result.results[0].text).toBe('WEB: For God so loved the world...')
  })

  it('propagates embedding failures (route falls back to keyword search)', async () => {
    mockEmbedQuery.mockRejectedValue(new Error('model load failed'))

    await expect(searchVersesSemantic('a query', 'NASB', 10)).rejects.toThrow('model load failed')
  })
})
