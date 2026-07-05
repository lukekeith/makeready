// Leader Bible store — web port of the iPhone's BibleCacheManager +
// BibleSearchService (the data layer behind the passage picker / Bible
// reader). All endpoints are session-optional on the server; the leader
// session reaches them through the /admin/api proxy.
//
//   GET  /api/bible/translations                      → { translations }
//   GET  /api/bible/{code}/{bookNumber}/{chapter}     → { verses: [{verse,text,…}] }
//   POST /api/search/smart {query, translation, limit} → direct|semantic|grouped
//   GET  /api/search/recent?limit=10&type=bible        → { searches }

import axios from 'axios'
import { defineStore } from 'pinia'
import { ref } from 'vue'
import {
  knownBibleVersions,
  sortVersionsPopularFirst,
  type BibleVersionInfo,
} from '../../../utils/bible-data'

/** iOS VerseCompact — {v, t}. */
export interface VerseCompact {
  v: number
  t: string
}

export interface BibleSearchResultItem {
  reference: string
  text: string
  bookNumber: number
  chapter: number
  verse: number
  verseEnd: number | null
  title: string | null
  summary: string | null
}

export interface BibleMatchedBook {
  bookNumber: number
  bookName: string
  chapters: number
  testament: string
}

interface ApiSemanticResult {
  book: { bookNumber: number; name: string; abbrev?: string }
  chapter: number
  verse: number
  verseEnd?: number | null
  text: string
  reference: string
  title?: string | null
  summary?: string | null
}

export const useLeaderBible = defineStore('leader-bible', () => {
  // iOS AppState.selectedBibleTranslation — default WEB.
  const selectedCode = ref('WEB')
  const translations = ref<BibleVersionInfo[]>(sortVersionsPopularFirst(knownBibleVersions))
  let translationsLoaded = false

  const chapterCache = new Map<string, VerseCompact[]>()

  async function loadTranslations(): Promise<void> {
    if (translationsLoaded) return
    try {
      const res = await axios.get('/admin/api/bible/translations')
      const raw: Array<{ id: string; code: string; name: string }> = res.data?.translations ?? []
      if (raw.length > 0) {
        translations.value = sortVersionsPopularFirst(
          raw.map((t) => ({ id: t.id, code: t.code, name: t.name })),
        )
      }
      translationsLoaded = true
    } catch {
      // Fall back to the static known list (iOS knownBibleVersions).
    }
  }

  function setTranslation(code: string): void {
    if (code === selectedCode.value) return
    selectedCode.value = code
    chapterCache.clear()
  }

  /** iOS BibleCacheManager.getChapterVerses — per-chapter cached. */
  async function getChapterVerses(bookNumber: number, chapter: number): Promise<VerseCompact[] | null> {
    const key = `${selectedCode.value}-${bookNumber}-${chapter}`
    const cached = chapterCache.get(key)
    if (cached) return cached
    try {
      const res = await axios.get(`/admin/api/bible/${selectedCode.value}/${bookNumber}/${chapter}`)
      const raw: Array<{ verse: number; text: string }> = res.data?.verses ?? []
      const verses = raw.map((v) => ({ v: v.verse, t: v.text })).sort((a, b) => a.v - b.v)
      if (verses.length > 0) chapterCache.set(key, verses)
      return verses
    } catch {
      return null
    }
  }

  /** iOS BibleSearchService.smartSearch — flattened to UI rows. */
  async function smartSearch(
    query: string,
  ): Promise<{ results: BibleSearchResultItem[]; books: BibleMatchedBook[] }> {
    const res = await axios.post('/admin/api/search/smart', {
      query,
      translation: selectedCode.value,
      limit: 10,
    })
    const data = res.data ?? {}
    const type: string = data.type ?? ''

    const fromSemantic = (r: ApiSemanticResult): BibleSearchResultItem => ({
      reference: r.reference,
      text: r.text,
      bookNumber: r.book.bookNumber,
      chapter: r.chapter,
      verse: r.verse,
      verseEnd: r.verseEnd ?? null,
      title: r.title ?? null,
      summary: r.summary ?? null,
    })

    if (type === 'direct') {
      const book = data.book as { bookNumber: number; name: string }
      const chapter: number = data.chapter
      const verses: Array<{ verse: number; text: string; reference: string }> = data.verses ?? []
      return {
        results: verses.map((v) => ({
          reference: v.reference,
          text: v.text,
          bookNumber: book.bookNumber,
          chapter,
          verse: v.verse,
          verseEnd: null,
          title: null,
          summary: null,
        })),
        books: [],
      }
    }
    if (type === 'semantic') {
      return { results: ((data.results ?? []) as ApiSemanticResult[]).map(fromSemantic), books: [] }
    }
    if (type === 'grouped') {
      return {
        results: ((data.verses ?? []) as ApiSemanticResult[]).map(fromSemantic),
        books: (data.books ?? []) as BibleMatchedBook[],
      }
    }
    return { results: [], books: [] }
  }

  /** iOS BibleSearchService.getRecentSearches. */
  async function recentSearches(): Promise<string[]> {
    try {
      const res = await axios.get('/admin/api/search/recent', {
        params: { limit: 10, type: 'bible' },
      })
      const raw: Array<{ query: string }> = res.data?.searches ?? []
      return raw.map((s) => s.query)
    } catch {
      return []
    }
  }

  return {
    selectedCode,
    translations,
    loadTranslations,
    setTranslation,
    getChapterVerses,
    smartSearch,
    recentSearches,
  }
})
