/**
 * Chapter-first cached Bible content retrieval.
 *
 * Any request for a verse, verse range, or chapter fetches and caches the
 * entire chapter in a single API.Bible call. Subsequent requests for any
 * verse in that chapter are served from cache with zero API calls.
 *
 * API.Bible rules:
 *   - Max 500 consecutive verses per request (a chapter is always < 200)
 *   - Cache must be refreshed every 14 days
 *   - FUMS token must be reported for every *view* (even cache hits)
 */

import * as apiBible from './api-bible.js'
import * as bibleCache from './bible-cache.js'
import { buildChapterId, buildVerseId } from '../utils/bible-id-map.js'
import { parseChapterContent } from '../utils/bible-content-parser.js'

export interface ChapterCacheResult {
  verses: { verse: number; text: string }[]
  copyright: string | null
  fumsToken: string | null
}

/**
 * Get all verses for a chapter, using cache-first strategy.
 * On cache miss: fetches the full chapter from API.Bible (1 API call),
 * caches it for 14 days, and returns parsed verses.
 * On cache hit: returns cached verses and fetches a fresh fumsToken —
 * unless skipFums is set (callers that batch multiple chapters and only
 * need one token per response, e.g. semantic search).
 */
export async function getChapterVerses(
  bibleId: string,
  bookId: string,
  chapter: number,
  options?: { skipCache?: boolean; skipFums?: boolean }
): Promise<ChapterCacheResult> {
  const chapterId = buildChapterId(bookId, chapter)
  const cacheKey = `chapter:${bibleId}:${chapterId}`

  if (!options?.skipCache) {
    const cached = await bibleCache.getCached(cacheKey)
    if (cached) {
      // Cache hit — still need a fresh fumsToken for FUMS compliance
      let fumsToken: string | null = null
      if (!options?.skipFums) {
        try {
          const verseId = buildVerseId(bookId, chapter, 1)
          const fumsResponse = await apiBible.getVerse(bibleId, verseId)
          fumsToken = apiBible.extractFumsToken(fumsResponse.meta)
        } catch {
          // fumsToken fetch failed — content still valid
        }
      }

      return {
        verses: JSON.parse(cached.responseJson),
        copyright: cached.copyright,
        fumsToken,
      }
    }
  } else {
    // skipCache: clear existing entry so fresh data replaces it
    await bibleCache.clearCacheEntry(cacheKey)
  }

  // Cache miss or refresh — fetch full chapter (1 API call covers all verses)
  const response = await apiBible.getChapter(bibleId, chapterId)
  const verses = parseChapterContent(response.data.content)
  const copyright = response.data.copyright
  const fumsToken = apiBible.extractFumsToken(response.meta)

  // Cache for 14 days
  if (verses.length > 0) {
    await bibleCache.setCache(cacheKey, bibleId, 'chapter', verses, copyright, verses.length)
  }

  return { verses, copyright, fumsToken }
}
