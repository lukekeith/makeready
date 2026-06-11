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
 * Three granularities are searched and merged (higher similarity wins,
 * overlapping candidates suppressed):
 *  - single verses (verses.embedding) — precise punchy matches
 *  - 3-verse sliding windows (verse_windows) — concepts that span verses,
 *    e.g. "the heavens declare the glory of God..." across Psalm 19:1-3.
 *    Range results carry verseEnd; `verse` stays the range start.
 *  - pericope concept cards (bible_passages) — narrative/thematic queries.
 *    The embedding is of an LLM-generated title + summary + themes, so
 *    "the prodigal son" matches Luke 15:11-24 even though the word
 *    "prodigal" never appears in the text. These results carry title and
 *    summary, and their text is an opening-verses snippet.
 *
 * Abstract concept queries are additionally expanded into biblical-vocabulary
 * variants (query-expansion.ts, Claude Haiku): all variants are embedded and
 * retrieved, and each candidate keeps its best similarity across variants
 * (max-sim fusion). This is what lets "God speaking to humanity through
 * creation" rank Psalm 19:1 and Romans 1:19-20 above literal "God spoke"
 * matches. Expansion runs concurrently with baseline retrieval and fails
 * open — on timeout or error the original-query results stand alone.
 *
 * Matching always runs against WEB embeddings, but display text is resolved
 * in the user's selected translation: from the local verses table when that
 * translation is stored locally, otherwise from API.Bible via the 14-day
 * chapter cache (one API call per uncached chapter). Verses that can't be
 * resolved (versification gaps, API errors) keep WEB text and are marked
 * with per-verse sourceTranslation: 'WEB'.
 */

import { prisma, Prisma } from '../lib/prisma.js'
import { embedQuery, embedQueries } from './embeddings.js'
import { expandQuery } from './query-expansion.js'
import { getBookByNumber, buildVerseId } from '../utils/bible-id-map.js'

/** Minimum cosine similarity for a verse to count as a match.
 *  bge cosine scores compress into roughly 0.5–0.85; tune via env. */
const SIMILARITY_THRESHOLD = parseFloat(process.env.SEMANTIC_SIM_THRESHOLD ?? '0.6')

/** Hard cap on a single semantic search, model load included. */
const SEARCH_TIMEOUT_MS = parseInt(process.env.SEMANTIC_SEARCH_TIMEOUT_MS ?? '8000', 10)

const SOURCE_TRANSLATION = 'WEB'

interface Candidate {
  bookNumber: number
  chapter: number
  verseStart: number
  verseEnd: number
  text: string
  similarity: number
  /** Pericope results only */
  title?: string
  summary?: string
}

export interface SemanticVerseResult {
  verseId: string
  book: { bookNumber: number; name: string; abbrev: string }
  chapter: number
  verse: number
  /** Present only for multi-verse range results (verse = range start) */
  verseEnd?: number
  text: string
  reference: string
  similarity: number
  /** Pericope (named passage) results only, e.g. "The Parable of the Prodigal Son".
   *  For these, text is an opening-verses snippet rather than the full passage. */
  title?: string
  summary?: string
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
  // Expansion (LLM) runs concurrently with the baseline embed+retrieval so
  // its latency overlaps instead of adding to it.
  const variantsPromise = expandQuery(query)
  const vector = await embedQuery(query)
  const baseline = await retrieveCandidates(vector, limit)

  const variants = await variantsPromise
  const fused = new Map<string, Candidate>(baseline)
  if (variants.length > 0) {
    const variantVectors = await embedQueries(variants)
    const variantResults = await Promise.all(variantVectors.map((v) => retrieveCandidates(v, limit)))
    // Max-sim fusion: a candidate keeps its best similarity across the
    // original query and all variants.
    for (const result of variantResults) {
      for (const [key, c] of result) {
        const prev = fused.get(key)
        if (!prev || c.similarity > prev.similarity) fused.set(key, c)
      }
    }
  }

  const candidates = [...fused.values()]
    .filter((c) => c.similarity >= SIMILARITY_THRESHOLD)
    .sort((a, b) => b.similarity - a.similarity)

  // Greedy merge: best similarity wins, overlapping candidates are dropped
  // (a verse inside an already-taken window, a window covering a taken verse)
  const taken: Candidate[] = []
  for (const c of candidates) {
    if (taken.length >= limit) break
    const overlaps = taken.some(
      (t) =>
        t.bookNumber === c.bookNumber &&
        t.chapter === c.chapter &&
        !(c.verseEnd < t.verseStart || c.verseStart > t.verseEnd)
    )
    if (!overlaps) taken.push(c)
  }

  const results: SemanticVerseResult[] = taken.map((c) => {
    const book = getBookByNumber(c.bookNumber)
    const isRange = c.verseEnd > c.verseStart
    return {
      verseId: buildVerseId(book.apiBibleId, c.chapter, c.verseStart),
      book: { bookNumber: book.bookNumber, name: book.name, abbrev: book.abbrev },
      chapter: c.chapter,
      verse: c.verseStart,
      ...(isRange ? { verseEnd: c.verseEnd } : {}),
      text: c.text,
      reference: isRange
        ? `${book.name} ${c.chapter}:${c.verseStart}-${c.verseEnd}`
        : `${book.name} ${c.chapter}:${c.verseStart}`,
      similarity: Math.round(c.similarity * 1000) / 1000,
      ...(c.title ? { title: c.title, summary: c.summary } : {}),
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
 * Top candidates from all three granularities for one query vector, keyed by
 * granularity + span so results for different query variants can be fused.
 */
async function retrieveCandidates(vector: number[], limit: number): Promise<Map<string, Candidate>> {
  const vectorLiteral = `[${vector.join(',')}]`

  const [verseRows, windowRows, passageRows] = await Promise.all([
    prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verse: number; text: string; similarity: number }>>(
      Prisma.sql`SELECT v."bookNumber", v.chapter, v.verse, v.text,
                        1 - (v."embedding" <=> ${vectorLiteral}::vector) AS similarity
                 FROM verses v
                 WHERE v."embedding" IS NOT NULL
                 ORDER BY v."embedding" <=> ${vectorLiteral}::vector
                 LIMIT ${limit * 2}`
    ),
    prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verseStart: number; verseEnd: number; text: string; similarity: number }>>(
      Prisma.sql`SELECT w."bookNumber", w.chapter, w."verseStart", w."verseEnd", w.text,
                        1 - (w."embedding" <=> ${vectorLiteral}::vector) AS similarity
                 FROM verse_windows w
                 WHERE w."embedding" IS NOT NULL
                 ORDER BY w."embedding" <=> ${vectorLiteral}::vector
                 LIMIT ${limit * 2}`
    ),
    prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verseStart: number; verseEnd: number; title: string; summary: string; openingText: string; similarity: number }>>(
      Prisma.sql`SELECT p."bookNumber", p.chapter, p."verseStart", p."verseEnd", p.title, p.summary, p."openingText",
                        1 - (p."embedding" <=> ${vectorLiteral}::vector) AS similarity
                 FROM bible_passages p
                 WHERE p."embedding" IS NOT NULL
                 ORDER BY p."embedding" <=> ${vectorLiteral}::vector
                 LIMIT ${limit * 2}`
    ),
  ])

  const candidates = new Map<string, Candidate>()
  const add = (src: string, c: Candidate) =>
    candidates.set(`${src}:${c.bookNumber}:${c.chapter}:${c.verseStart}:${c.verseEnd}`, c)

  verseRows.forEach((r) => add('verse', { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verse, verseEnd: r.verse, text: r.text, similarity: r.similarity }))
  windowRows.forEach((r) => add('window', { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verseStart, verseEnd: r.verseEnd, text: r.text, similarity: r.similarity }))
  passageRows.forEach((r) => add('pericope', { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verseStart, verseEnd: r.verseEnd, text: r.openingText, similarity: r.similarity, title: r.title, summary: r.summary }))
  return candidates
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
          verse: { gte: r.verse, lte: textSpanEnd(r) },
        })),
      },
      select: { bookNumber: true, chapter: true, verse: true, text: true },
    })
    if (rows.length > 0) {
      const texts = new Map(rows.map((r) => [`${r.bookNumber}:${r.chapter}:${r.verse}`, r.text]))
      for (const r of results) {
        const text = joinRangeText(
          (v) => texts.get(`${r.book.bookNumber}:${r.chapter}:${v}`),
          r.verse,
          textSpanEnd(r)
        )
        if (text) r.text = withEllipsis(text, r)
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
    const chapterMap = chapterTexts.get(`${r.book.bookNumber}:${r.chapter}`)
    const text = chapterMap
      ? joinRangeText((v) => chapterMap.get(v), r.verse, textSpanEnd(r))
      : undefined
    if (text) r.text = withEllipsis(text, r)
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

/**
 * The verse span whose TEXT is returned for a result. Verse and window
 * results return their full range; pericope results (title set) return only
 * the first two verses as a snippet — a 30-verse parable doesn't belong in a
 * search-result list, and tapping through opens the full passage anyway.
 */
function textSpanEnd(r: SemanticVerseResult): number {
  const end = r.verseEnd ?? r.verse
  return r.title ? Math.min(r.verse + 1, end) : end
}

/** Append an ellipsis when the resolved text is a truncated snippet. */
function withEllipsis(text: string, r: SemanticVerseResult): string {
  return textSpanEnd(r) < (r.verseEnd ?? r.verse) ? `${text} …` : text
}

/**
 * Join verse texts for a range; returns undefined if ANY verse in the range
 * is missing (versification gaps) so the caller falls back to WEB text
 * rather than serving a silently-truncated passage.
 */
function joinRangeText(
  lookup: (verse: number) => string | undefined,
  verseStart: number,
  verseEnd: number
): string | undefined {
  const parts: string[] = []
  for (let v = verseStart; v <= verseEnd; v++) {
    const text = lookup(v)
    if (!text) return undefined
    parts.push(text)
  }
  return parts.join(' ')
}
