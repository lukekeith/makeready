/**
 * Semantic Bible Search
 *
 * Concept search over locally-stored verses using pgvector cosine similarity.
 * Replaces the API.Bible keyword search for non-reference queries: "overcoming
 * fear" finds "do not be anxious" passages instead of only literal matches.
 *
 * Verses are embedded once by embed-bible.ts (WEB translation); queries are
 * embedded at request time. Result shape matches handleKeywordSearch in
 * routes/search.ts so consumers (iPhone, client) need no changes. Verse text
 * returned is always WEB (public domain — no FUMS token obligation);
 * sourceTranslation tells consumers which translation the text came from.
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

export interface SemanticSearchResult {
  type: 'semantic'
  query: string
  translation: string
  sourceTranslation: string
  results: Array<{
    verseId: string
    book: { bookNumber: number; name: string; abbrev: string }
    chapter: number
    verse: number
    text: string
    reference: string
    similarity: number
  }>
  total: number
  fumsToken: undefined
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

  const results = rows
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

  return {
    type: 'semantic',
    query,
    translation: translationCode,
    sourceTranslation: SOURCE_TRANSLATION,
    results,
    total: results.length,
    fumsToken: undefined,
  }
}
