/**
 * Semantic Bible Search
 *
 * Concept search over locally-stored verses using pgvector cosine similarity.
 * Replaces the API.Bible keyword search for non-reference queries: "overcoming
 * fear" finds "do not be anxious" passages instead of only literal matches.
 *
 * Verses are embedded once by embed-bible.ts (WEB translation); queries are
 * embedded at request time. Result shape matches handleKeywordSearch in
 * routes/search.ts so consumers (iPhone, client) need no changes.
 *
 * Matching always runs against WEB embeddings, but display text is resolved
 * in the user's selected translation: from the local verses table when that
 * translation is stored locally, otherwise from API.Bible via the 14-day
 * chapter cache (one API call per uncached chapter). Verses that can't be
 * resolved (versification gaps, API errors) keep WEB text and are marked
 * with per-verse sourceTranslation: 'WEB'.
 */

import { prisma, Prisma } from '../lib/prisma.js'
import { embedQuery } from './embeddings.js'
import { getBookByNumber, buildVerseId } from '../utils/bible-id-map.js'

/** Minimum cosine similarity for a verse to count as a match.
 *  bge cosine scores compress into roughly 0.5–0.85; tune via env. */
const SIMILARITY_THRESHOLD = parseFloat(process.env.SEMANTIC_SIM_THRESHOLD ?? '0.6')

/** Hard cap on a single semantic search, model load included. */
const SEARCH_TIMEOUT_MS = parseInt(process.env.SEMANTIC_SEARCH_TIMEOUT_MS ?? '8000', 10)

const SOURCE_TRANSLATION = 'WEB'

interface SemanticRow {
  id: string
  bookNumber: number
  chapter: number
  verse: number
  text: string
  similarity: number
}

export interface SemanticVerseResult {
  verseId: string
  book: { bookNumber: number; name: string; abbrev: string }
  chapter: number
  verse: number
  text: string
  reference: string
  similarity: number
  /** Set to 'WEB' only when text could not be resolved in the requested translation */
  sourceTranslation?: string
}

export interface SemanticSearchResult {
  type: 'semantic'
  query: string
  translation: string
  results: SemanticVerseResult[]
  total: number
  fumsToken: string | undefined
  copyright?: string
}

export async function searchVersesSemantic(
  query: string,
  translationCode: string,
  limit: number
): Promise<SemanticSearchResult> {
  const result = searchInternal(query, translationCode, limit)
  const timeout = new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error(`Semantic search timed out after ${SEARCH_TIMEOUT_MS}ms`)), SEARCH_TIMEOUT_MS).unref()
  )
  return Promise.race([result, timeout])
}

async function searchInternal(
  query: string,
  translationCode: string,
  limit: number
): Promise<SemanticSearchResult> {
  const vector = await embedQuery(query)
  const vectorLiteral = `[${vector.join(',')}]`

  const rows = await prisma.$queryRaw<SemanticRow[]>(
    Prisma.sql`SELECT v.id, v."bookNumber", v.chapter, v.verse, v.text,
                      1 - (v."embedding" <=> ${vectorLiteral}::vector) AS similarity
               FROM verses v
               WHERE v."embedding" IS NOT NULL
               ORDER BY v."embedding" <=> ${vectorLiteral}::vector
               LIMIT ${limit}`
  )

  const results: SemanticVerseResult[] = rows
    .filter((row) => row.similarity >= SIMILARITY_THRESHOLD)
    .map((row) => {
      const book = getBookByNumber(row.bookNumber)
      return {
        verseId: buildVerseId(book.apiBibleId, row.chapter, row.verse),
        book: { bookNumber: book.bookNumber, name: book.name, abbrev: book.abbrev },
        chapter: row.chapter,
        verse: row.verse,
        text: row.text,
        reference: `${book.name} ${row.chapter}:${row.verse}`,
        similarity: Math.round(row.similarity * 1000) / 1000,
      }
    })

  const { fumsToken, copyright } = await resolveDisplayTexts(results, translationCode)

  return {
    type: 'semantic',
    query,
    translation: translationCode,
    results,
    total: results.length,
    fumsToken,
    copyright,
  }
}

/**
 * Replace WEB match text with the requested translation's text, in place.
 * Local translations cost one SQL query; API.Bible translations cost one
 * cached chapter fetch per distinct chapter (zero API calls once warm).
 */
async function resolveDisplayTexts(
  results: SemanticVerseResult[],
  translationCode: string
): Promise<{ fumsToken: string | undefined; copyright?: string }> {
  const code = translationCode.toUpperCase()
  if (results.length === 0 || code === SOURCE_TRANSLATION) {
    return { fumsToken: undefined }
  }

  // 1. Translation stored locally — one SQL query. Only WEB verses are kept
  //    locally these days, but translation rows for removed translations
  //    still exist (highlight/note FKs), so an empty result falls through to
  //    API.Bible rather than treating the translation as local.
  const local = await prisma.translation.findUnique({ where: { code } })
  if (local) {
    const rows = await prisma.verse.findMany({
      where: {
        translationId: local.id,
        OR: results.map((r) => ({
          bookNumber: r.book.bookNumber,
          chapter: r.chapter,
          verse: r.verse,
        })),
      },
      select: { bookNumber: true, chapter: true, verse: true, text: true },
    })
    if (rows.length > 0) {
      const texts = new Map(rows.map((r) => [`${r.bookNumber}:${r.chapter}:${r.verse}`, r.text]))
      for (const r of results) {
        const text = texts.get(`${r.book.bookNumber}:${r.chapter}:${r.verse}`)
        if (text) r.text = text
        else r.sourceTranslation = SOURCE_TRANSLATION
      }
      return { fumsToken: undefined }
    }
  }

  // 2. API.Bible translation (NASB, ESV, ...) — cached chapter fetches
  const { resolveBibleId } = await import('./bible-metadata.js')
  const bibleId = await resolveBibleId(code)
  if (!bibleId) {
    results.forEach((r) => { r.sourceTranslation = SOURCE_TRANSLATION })
    return { fumsToken: undefined }
  }

  const { getChapterVerses } = await import('./bible-chapter.js')
  const chapterKeys = [...new Set(results.map((r) => `${r.book.bookNumber}:${r.chapter}`))]
  const chapterTexts = new Map<string, Map<number, string>>()
  let fumsToken: string | undefined
  let copyright: string | undefined

  await Promise.all(chapterKeys.map(async (key) => {
    const [bookNumber, chapter] = key.split(':').map(Number)
    try {
      const book = getBookByNumber(bookNumber)
      // skipFums: one token per response is enough — fetched below if needed
      const result = await getChapterVerses(bibleId, book.apiBibleId, chapter, { skipFums: true })
      chapterTexts.set(key, new Map(result.verses.map((v) => [v.verse, v.text])))
      if (result.fumsToken) fumsToken = result.fumsToken
      if (result.copyright) copyright = result.copyright
    } catch (err) {
      console.error(`Semantic search: failed to fetch ${code} chapter for ${key}:`, err)
    }
  }))

  for (const r of results) {
    const text = chapterTexts.get(`${r.book.bookNumber}:${r.chapter}`)?.get(r.verse)
    if (text) r.text = text
    else r.sourceTranslation = SOURCE_TRANSLATION
  }

  // FUMS compliance: copyrighted text views need a token. Cache misses above
  // already produced one; on all-cache-hit fetch a single token.
  const servedApiBibleText = results.some((r) => !r.sourceTranslation)
  if (servedApiBibleText && !fumsToken) {
    try {
      const { getVerse, extractFumsToken } = await import('./api-bible.js')
      const first = results.find((r) => !r.sourceTranslation)!
      const response = await getVerse(bibleId, first.verseId)
      fumsToken = extractFumsToken(response.meta) ?? undefined
    } catch {
      // token fetch failed — results still valid
    }
  }

  return { fumsToken, copyright }
}
