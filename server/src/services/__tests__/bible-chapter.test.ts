import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockGetCached = vi.hoisted(() => vi.fn())
const mockSetCache = vi.hoisted(() => vi.fn())
const mockClearCacheEntry = vi.hoisted(() => vi.fn())
const mockGetChapter = vi.hoisted(() => vi.fn())

vi.mock('../bible-cache.js', () => ({
  getCached: mockGetCached,
  setCache: mockSetCache,
  clearCacheEntry: mockClearCacheEntry,
}))
vi.mock('../api-bible.js', () => ({
  getChapter: mockGetChapter,
  getVerse: vi.fn(),
  extractFumsToken: () => null,
}))

import { getChapterVerses } from '../bible-chapter.js'

describe('getChapterVerses', () => {
  beforeEach(() => vi.clearAllMocks())

  it('getChapterVerses normalizes a cached chapter and reads the v2 key', async () => {
    mockGetCached.mockResolvedValue({ responseJson: JSON.stringify([{ verse: 1, text: '¶ In the\nbeginning' }]), copyright: 'PD' })
    const r = await getChapterVerses('bib', 'GEN', 1, { skipFums: true })
    expect(mockGetCached).toHaveBeenCalledWith('chapter:v2:bib:GEN.1')
    expect(r.verses[0].text).toBe('In the beginning')
  })

  it('getChapterVerses normalizes and caches a fetched chapter', async () => {
    mockGetCached.mockResolvedValue(null)
    mockGetChapter.mockResolvedValue({ data: { content: '[1] ¶ In the  beginning\\n', copyright: 'PD' }, meta: {} })
    const r = await getChapterVerses('bib', 'GEN', 1)
    expect(r.verses[0].text).toBe('In the beginning')
    expect(mockSetCache.mock.calls[0][0]).toBe('chapter:v2:bib:GEN.1')
    expect(mockSetCache.mock.calls[0][3][0].text).toBe('In the beginning')
  })
})
