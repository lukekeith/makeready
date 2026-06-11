/**
 * Semantic Bible Search — unit tests
 *
 * Tests verse+window merging, similarity-threshold filtering, and
 * display-text resolution in the requested translation, with the embedding
 * model, database, and API.Bible chapter cache mocked. The real
 * model/pgvector path is covered by the manual smoke flow
 * (npm run model:prefetch + /api/search/smart).
 */

import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockEmbedQuery = vi.fn()
const mockEmbedQueries = vi.fn()
const mockExpandQuery = vi.fn()
const mockQueryRaw = vi.fn()
const mockTranslationFindUnique = vi.fn()
const mockVerseFindMany = vi.fn()
const mockResolveBibleId = vi.fn()
const mockGetChapterVerses = vi.fn()
const mockGetVerse = vi.fn()

vi.mock('../src/services/embeddings.js', () => ({
  embedQuery: mockEmbedQuery,
  embedQueries: mockEmbedQueries,
  embedPassages: vi.fn(),
  isEmbeddingsEnabled: () => true,
  EMBEDDING_MODEL: 'Xenova/bge-small-en-v1.5',
  EMBEDDING_DIMS: 384,
}))

vi.mock('../src/services/query-expansion.js', () => ({
  expandQuery: mockExpandQuery,
  isExpansionEnabled: () => true,
}))

vi.mock('../src/lib/prisma.js', () => ({
  prisma: {
    $queryRaw: mockQueryRaw,
    translation: { findUnique: mockTranslationFindUnique },
    verse: { findMany: mockVerseFindMany },
  },
  Prisma: {
    sql: (strings: TemplateStringsArray, ...values: unknown[]) => ({ strings, values }),
    raw: (s: string) => s,
  },
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

type VerseRow = { bookNumber: number; chapter: number; verse: number; text: string; similarity: number }
type WindowRow = { bookNumber: number; chapter: number; verseStart: number; verseEnd: number; text: string; similarity: number }

type PassageRow = {
  bookNumber: number; chapter: number; verseStart: number; verseEnd: number;
  title: string; summary: string; openingText: string; similarity: number
}

/** Route the three pgvector queries (verses / verse_windows / bible_passages) to their fixtures. */
function setRows(verseRows: VerseRow[], windowRows: WindowRow[] = [], passageRows: PassageRow[] = []) {
  mockQueryRaw.mockImplementation(async (q: { strings: readonly string[] }) => {
    const sql = q.strings.join('')
    if (sql.includes('bible_passages')) return passageRows
    if (sql.includes('verse_windows')) return windowRows
    return verseRows
  })
}

function verseRow(overrides: Partial<VerseRow> = {}): VerseRow {
  return {
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
  mockEmbedQueries.mockResolvedValue([])
  mockExpandQuery.mockResolvedValue([])
  mockTranslationFindUnique.mockResolvedValue(null)
  mockResolveBibleId.mockResolvedValue(null)
})

describe('searchVersesSemantic', () => {
  it('maps single-verse rows to the smart-search result shape (WEB requested — no resolution)', async () => {
    setRows([verseRow()])

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
    expect(mockTranslationFindUnique).not.toHaveBeenCalled()
  })

  it('returns a window hit as a range result with verseEnd and range reference', async () => {
    setRows([], [{
      bookNumber: 19, chapter: 19, verseStart: 1, verseEnd: 3,
      text: 'The heavens declare the glory of God...', similarity: 0.79,
    }])

    const result = await searchVersesSemantic('God speaking through creation', 'WEB', 10)

    expect(result.results[0]).toMatchObject({
      verseId: 'PSA.19.1',
      verse: 1,
      verseEnd: 3,
      reference: 'Psalms 19:1-3',
      similarity: 0.79,
    })
  })

  it('returns pericope hits with title, summary, and snippet text', async () => {
    setRows([], [], [{
      bookNumber: 42, chapter: 15, verseStart: 11, verseEnd: 24,
      title: 'The Parable of the Prodigal Son',
      summary: 'A son squanders his inheritance, returns home, and is welcomed by his father.',
      openingText: 'He said, "A certain man had two sons. The younger of them said to his father..." …',
      similarity: 0.84,
    }])

    const result = await searchVersesSemantic('the prodigal son', 'WEB', 10)

    expect(result.results[0]).toMatchObject({
      verseId: 'LUK.15.11',
      verse: 11,
      verseEnd: 24,
      reference: 'Luke 15:11-24',
      title: 'The Parable of the Prodigal Son',
      summary: 'A son squanders his inheritance, returns home, and is welcomed by his father.',
      similarity: 0.84,
    })
    expect(result.results[0].text).toContain('A certain man had two sons')
  })

  it('suppresses a lower-scoring verse inside a winning pericope', async () => {
    setRows(
      [verseRow({ bookNumber: 42, chapter: 15, verse: 20, similarity: 0.7, text: 'he ran and fell on his neck' })],
      [],
      [{
        bookNumber: 42, chapter: 15, verseStart: 11, verseEnd: 24,
        title: 'The Parable of the Prodigal Son', summary: 's', openingText: 'opening …', similarity: 0.8,
      }]
    )

    const result = await searchVersesSemantic('a query', 'WEB', 10)

    expect(result.total).toBe(1)
    expect(result.results[0].title).toBe('The Parable of the Prodigal Son')
  })

  it('resolves pericope snippet text (first 2 verses + ellipsis) in the requested translation', async () => {
    setRows([], [], [{
      bookNumber: 42, chapter: 15, verseStart: 11, verseEnd: 24,
      title: 'The Parable of the Prodigal Son', summary: 's',
      openingText: 'WEB opening …', similarity: 0.8,
    }])
    mockResolveBibleId.mockResolvedValue('nasb-bible-id')
    mockGetChapterVerses.mockResolvedValue({
      verses: Array.from({ length: 32 }, (_, i) => ({ verse: i + 1, text: `NASB v${i + 1}.` })),
      copyright: 'NASB ©',
      fumsToken: 'tok',
    })

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    // Only the first two verses of the range, with ellipsis — not all 14 verses
    expect(result.results[0].text).toBe('NASB v11. NASB v12. …')
    expect(result.results[0].verseEnd).toBe(24)
  })

  it('merges verses and windows by similarity, suppressing overlaps', async () => {
    setRows(
      [
        verseRow({ bookNumber: 19, chapter: 19, verse: 1, similarity: 0.75, text: 'Psalm 19:1 alone' }),
        verseRow({ bookNumber: 45, chapter: 1, verse: 20, similarity: 0.72, text: 'Romans 1:20' }),
      ],
      [
        // Window overlapping Psalm 19:1 with HIGHER similarity — wins, verse dropped
        { bookNumber: 19, chapter: 19, verseStart: 1, verseEnd: 3, text: 'Psalm 19:1-3 window', similarity: 0.78 },
        // Window overlapping Romans 1:20 with LOWER similarity — dropped
        { bookNumber: 45, chapter: 1, verseStart: 19, verseEnd: 21, text: 'Romans 1:19-21 window', similarity: 0.70 },
      ]
    )

    const result = await searchVersesSemantic('a query', 'WEB', 10)

    expect(result.results.map(r => r.reference)).toEqual(['Psalms 19:1-3', 'Romans 1:20'])
    expect(result.results.map(r => r.similarity)).toEqual([0.78, 0.72])
  })

  it('filters out rows below the similarity threshold (default 0.6)', async () => {
    setRows(
      [verseRow({ similarity: 0.82 }), verseRow({ bookNumber: 1, chapter: 1, verse: 1, similarity: 0.41 })],
      [{ bookNumber: 2, chapter: 1, verseStart: 1, verseEnd: 3, text: 'low window', similarity: 0.5 }]
    )

    const result = await searchVersesSemantic('a query', 'WEB', 10)

    expect(result.total).toBe(1)
    expect(result.results.map(r => r.similarity)).toEqual([0.82])
  })

  it('returns empty results when nothing clears the threshold', async () => {
    setRows([verseRow({ similarity: 0.3 })], [])

    const result = await searchVersesSemantic('xyzzy nonsense', 'WEB', 10)

    expect(result.total).toBe(0)
  })

  it('resolves range text from the local verses table, joining the span', async () => {
    setRows([], [{
      bookNumber: 19, chapter: 19, verseStart: 1, verseEnd: 2,
      text: 'WEB window text', similarity: 0.8,
    }])
    mockTranslationFindUnique.mockResolvedValue({ id: 'kjv-id', code: 'KJV' })
    mockVerseFindMany.mockResolvedValue([
      { bookNumber: 19, chapter: 19, verse: 1, text: 'KJV v1.' },
      { bookNumber: 19, chapter: 19, verse: 2, text: 'KJV v2.' },
    ])

    const result = await searchVersesSemantic('a query', 'KJV', 10)

    expect(result.results[0].text).toBe('KJV v1. KJV v2.')
    expect(result.results[0].sourceTranslation).toBeUndefined()
  })

  it('falls back to WEB text when part of a range is missing in the target translation', async () => {
    setRows([], [{
      bookNumber: 19, chapter: 19, verseStart: 1, verseEnd: 2,
      text: 'WEB window text', similarity: 0.8,
    }])
    mockTranslationFindUnique.mockResolvedValue({ id: 'kjv-id', code: 'KJV' })
    mockVerseFindMany.mockResolvedValue([
      { bookNumber: 19, chapter: 19, verse: 1, text: 'KJV v1.' },
      // verse 2 missing
    ])

    const result = await searchVersesSemantic('a query', 'KJV', 10)

    expect(result.results[0].text).toBe('WEB window text')
    expect(result.results[0].sourceTranslation).toBe('WEB')
  })

  it('falls through to API.Bible when a local translation row has no verses (post-cleanup KJV)', async () => {
    setRows([verseRow()])
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

  it('resolves range text via cached API.Bible chapters and joins the span', async () => {
    setRows(
      [verseRow({ similarity: 0.81 })],
      [{ bookNumber: 19, chapter: 23, verseStart: 1, verseEnd: 3, text: 'WEB Psalm 23 window', similarity: 0.77 }]
    )
    mockResolveBibleId.mockResolvedValue('nasb-bible-id')
    mockGetChapterVerses.mockImplementation(async (_b: string, bookId: string) => {
      if (bookId === 'JHN') {
        return { verses: [{ verse: 16, text: 'NASB John 3:16' }], copyright: 'NASB ©', fumsToken: 'tok' }
      }
      return {
        verses: [
          { verse: 1, text: 'NASB Ps23 v1.' },
          { verse: 2, text: 'NASB Ps23 v2.' },
          { verse: 3, text: 'NASB Ps23 v3.' },
        ],
        copyright: 'NASB ©',
        fumsToken: null,
      }
    })

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    expect(mockGetChapterVerses).toHaveBeenCalledTimes(2)
    expect(result.results[0].text).toBe('NASB John 3:16')
    expect(result.results[1].text).toBe('NASB Ps23 v1. NASB Ps23 v2. NASB Ps23 v3.')
    expect(result.fumsToken).toBe('tok')
    expect(result.copyright).toBe('NASB ©')
    expect(mockGetVerse).not.toHaveBeenCalled()
  })

  it('fetches a single FUMS token when all chapters were cache hits', async () => {
    setRows([verseRow()])
    mockResolveBibleId.mockResolvedValue('nasb-bible-id')
    mockGetChapterVerses.mockResolvedValue({
      verses: [{ verse: 16, text: 'NASB John 3:16' }],
      copyright: 'NASB ©',
      fumsToken: null, // cache hit with skipFums
    })
    mockGetVerse.mockResolvedValue({ meta: { fumsToken: 'single-token' } })

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    expect(result.fumsToken).toBe('single-token')
    expect(mockGetVerse).toHaveBeenCalledTimes(1)
  })

  it('keeps WEB text per-verse when a chapter fetch fails', async () => {
    setRows([verseRow()])
    mockResolveBibleId.mockResolvedValue('nasb-bible-id')
    mockGetChapterVerses.mockRejectedValue(new Error('API.Bible down'))

    const result = await searchVersesSemantic('a query', 'NASB', 10)

    expect(result.results[0].text).toBe('WEB: For God so loved the world...')
    expect(result.results[0].sourceTranslation).toBe('WEB')
    expect(mockGetVerse).not.toHaveBeenCalled()
  })

  it('marks all verses as WEB when the translation cannot be resolved at all', async () => {
    setRows([verseRow()])
    mockResolveBibleId.mockResolvedValue(null)

    const result = await searchVersesSemantic('a query', 'NOPE', 10)

    expect(result.results[0].sourceTranslation).toBe('WEB')
  })

  it('propagates embedding failures (route falls back to keyword search)', async () => {
    mockEmbedQuery.mockRejectedValue(new Error('model load failed'))

    await expect(searchVersesSemantic('a query', 'NASB', 10)).rejects.toThrow('model load failed')
  })
})

describe('query expansion fusion', () => {
  /** Route retrieval fixtures by table AND query vector (baseline 0.05s vs variant 0.07s). */
  function setRowsByVector(fixtures: {
    baseline?: { verses?: VerseRow[]; windows?: WindowRow[]; passages?: PassageRow[] }
    variant?: { verses?: VerseRow[]; windows?: WindowRow[]; passages?: PassageRow[] }
  }) {
    mockQueryRaw.mockImplementation(async (q: { strings: readonly string[]; values: unknown[] }) => {
      const sql = q.strings.join('')
      const isVariant = String(q.values[0]).startsWith('[0.07')
      const set = (isVariant ? fixtures.variant : fixtures.baseline) ?? {}
      if (sql.includes('bible_passages')) return set.passages ?? []
      if (sql.includes('verse_windows')) return set.windows ?? []
      return set.verses ?? []
    })
  }

  it('keeps the best similarity across original and variant retrievals (max-sim fusion)', async () => {
    mockExpandQuery.mockResolvedValue(['the heavens declare the glory of God'])
    mockEmbedQueries.mockResolvedValue([new Array(384).fill(0.07)])
    setRowsByVector({
      baseline: {
        verses: [
          verseRow({ bookNumber: 1, chapter: 8, verse: 15, similarity: 0.78, text: 'God spoke to Noah' }),
          verseRow({ bookNumber: 19, chapter: 19, verse: 1, similarity: 0.62, text: 'The heavens declare' }),
        ],
      },
      variant: {
        verses: [verseRow({ bookNumber: 19, chapter: 19, verse: 1, similarity: 0.84, text: 'The heavens declare' })],
      },
    })

    const result = await searchVersesSemantic('God speaking through creation', 'WEB', 10)

    expect(result.results.map((r) => r.reference)).toEqual(['Psalms 19:1', 'Genesis 8:15'])
    expect(result.results[0].similarity).toBe(0.84)
  })

  it('surfaces candidates found only by a variant query', async () => {
    mockExpandQuery.mockResolvedValue(['perfect love casts out fear'])
    mockEmbedQueries.mockResolvedValue([new Array(384).fill(0.07)])
    setRowsByVector({
      baseline: { verses: [verseRow({ similarity: 0.65 })] },
      variant: {
        verses: [verseRow({ bookNumber: 62, chapter: 4, verse: 18, similarity: 0.8, text: 'There is no fear in love' })],
      },
    })

    const result = await searchVersesSemantic('overcoming fear', 'WEB', 10)

    expect(result.results.map((r) => r.reference)).toEqual(['1 John 4:18', 'John 3:16'])
  })

  it('skips variant embedding and retrieval entirely when expansion returns no variants', async () => {
    mockExpandQuery.mockResolvedValue([])
    setRows([verseRow()])

    const result = await searchVersesSemantic('a query', 'WEB', 10)

    expect(result.total).toBe(1)
    expect(mockEmbedQueries).not.toHaveBeenCalled()
    // 3 granularity queries for the baseline only
    expect(mockQueryRaw).toHaveBeenCalledTimes(3)
  })
})
