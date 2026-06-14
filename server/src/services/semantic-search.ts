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
import { rerank } from './reranker.js'
import { getBookByNumber, buildVerseId } from '../utils/bible-id-map.js'

/** Minimum cosine similarity for a verse to count as a match.
 *  bge cosine scores compress into roughly 0.5–0.85; tune via env. */
const SIMILARITY_THRESHOLD = parseFloat(process.env.SEMANTIC_SIM_THRESHOLD ?? '0.6')

/** Reciprocal Rank Fusion constant. Standard 60; larger = flatter weighting
 *  across arms (top-rank dominance softened). */
const RRF_K = parseInt(process.env.SEMANTIC_RRF_K ?? '60', 10)

/** How many top fused candidates the cross-encoder reranks. Bounded so rerank
 *  stays within the search budget on CPU. */
const RERANK_POOL = parseInt(process.env.SEMANTIC_RERANK_POOL ?? '25', 10)

/** doc2query retrieval arm (generated questions → pericope). Toggle off to fall
 *  back to dense + lexical only. */
const DOC2QUERY_ENABLED = process.env.SEMANTIC_DOC2QUERY_ENABLED !== 'false'

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

  // The user's actual query contributes dense (verse/window/pericope) AND
  // lexical arms; variants contribute dense arms only (lexical matching on a
  // paraphrase the user never typed adds noise, not recall).
  const arms: Arm[] = await retrieveArms(vector, limit, query)

  const variants = await variantsPromise
  if (variants.length > 0) {
    const variantVectors = await embedQueries(variants)
    const variantArms = await Promise.all(variantVectors.map((v) => retrieveArms(v, limit)))
    for (const set of variantArms) arms.push(...set)
  }

  // Reciprocal Rank Fusion across every arm: a candidate's score is the sum of
  // 1/(K+rank) over each ranked list it appears in — robust to the fact that
  // cosine similarity and ts_rank live on different scales. Dense cosine is
  // retained (max across arms) as the displayed score and the dense relevance
  // gate; lexical-only hits (exact names/quotes that dense embeddings miss)
  // bypass that gate so they can surface.
  const fused = fuseArms(arms)

  const candidates = [...fused.values()]
    .filter((e) => e.sim >= SIMILARITY_THRESHOLD || e.lexical)
    // RRF score first; break ties by cosine similarity so that when two
    // candidates are tied on fused rank (e.g. a verse and the window covering
    // it, each rank-1 in its own arm) the higher-cosine one wins.
    .sort((a, b) => b.rrf - a.rrf || b.sim - a.sim)
    .map((e) => ({ ...e.cand, similarity: e.sim }))

  // Second stage: re-order the top fused candidates by a cross-encoder's true
  // query↔passage relevance — fixes RRF's tendency to float a multiply-retrieved
  // mediocre verse above the single best passage. Fail-open: on disable/timeout
  // the RRF order stands.
  const ranked = await rerankCandidates(query, candidates)

  // Greedy merge: best-ranked wins, overlapping candidates are dropped
  // (a verse inside an already-taken window, a window covering a taken verse)
  const taken: Candidate[] = []
  for (const c of ranked) {
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

/** One ranked retrieval arm: candidates in the arm's native order (best first),
 *  each tagged with whether the arm is the lexical (full-text) one. */
type Arm = Array<{ key: string; cand: Candidate; lexical: boolean }>

// Fuse key is a span ("book:chapter:start:end"), granularity-agnostic, so the
// SAME verse found by the dense and lexical arms fuses into one entry (and
// accumulates RRF from both), while a verse and a window/pericope covering it
// stay distinct (de-overlap resolves those later).

/**
 * Run all retrieval arms for one query vector and return each as an ORDERED
 * list (preserving the arm's native ranking) so Reciprocal Rank Fusion can use
 * positions. Dense arms: single verses, 3-verse windows, pericope cards. When
 * `lexicalQuery` is provided, a Postgres full-text arm over verses is added —
 * it carries each hit's cosine similarity too, so lexical-only candidates still
 * get a real displayed score.
 */
async function retrieveArms(vector: number[], limit: number, lexicalQuery?: string): Promise<Arm[]> {
  const vectorLiteral = `[${vector.join(',')}]`
  const k = limit * 4 // wider pool than the old limit*2 so fusion has signal to combine

  const dense = Promise.all([
    prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verse: number; text: string; similarity: number }>>(
      Prisma.sql`SELECT v."bookNumber", v.chapter, v.verse, v.text,
                        1 - (v."embedding" <=> ${vectorLiteral}::vector) AS similarity
                 FROM verses v
                 WHERE v."embedding" IS NOT NULL
                 ORDER BY v."embedding" <=> ${vectorLiteral}::vector
                 LIMIT ${k}`
    ),
    prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verseStart: number; verseEnd: number; text: string; similarity: number }>>(
      Prisma.sql`SELECT w."bookNumber", w.chapter, w."verseStart", w."verseEnd", w.text,
                        1 - (w."embedding" <=> ${vectorLiteral}::vector) AS similarity
                 FROM verse_windows w
                 WHERE w."embedding" IS NOT NULL
                 ORDER BY w."embedding" <=> ${vectorLiteral}::vector
                 LIMIT ${k}`
    ),
    prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verseStart: number; verseEnd: number; title: string; summary: string; openingText: string; similarity: number }>>(
      Prisma.sql`SELECT p."bookNumber", p.chapter, p."verseStart", p."verseEnd", p.title, p.summary, p."openingText",
                        1 - (p."embedding" <=> ${vectorLiteral}::vector) AS similarity
                 FROM bible_passages p
                 WHERE p."embedding" IS NOT NULL
                 ORDER BY p."embedding" <=> ${vectorLiteral}::vector
                 LIMIT ${k}`
    ),
  ])

  // Lexical full-text arm (verses only). `websearch_to_tsquery` handles plain
  // user input ("david goliath", quoted phrases) safely; ranking by ts_rank_cd
  // but also returning cosine so the result still shows a meaningful score.
  const lexical = lexicalQuery
    ? prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verse: number; text: string; similarity: number }>>(
        Prisma.sql`SELECT v."bookNumber", v.chapter, v.verse, v.text,
                          1 - (v."embedding" <=> ${vectorLiteral}::vector) AS similarity
                   FROM verses v, websearch_to_tsquery('english', ${lexicalQuery}) AS q
                   WHERE v."searchVector" @@ q
                   ORDER BY ts_rank_cd(v."searchVector", q) DESC
                   LIMIT ${k}`
      )
    : Promise.resolve([])

  // doc2query arm: nearest generated questions (passage_queries) → the pericope
  // they index. This bridges how people ASK to where the answer lives, even
  // when the passage's own wording shares nothing with the query. Pull extra
  // and dedupe to the best question per passage (HNSW-friendly: ORDER BY
  // distance alone). Empty until the embeddings are backfilled; toggleable.
  const doc2query = DOC2QUERY_ENABLED
    ? prisma.$queryRaw<Array<{ bookNumber: number; chapter: number; verseStart: number; verseEnd: number; title: string; summary: string; openingText: string; similarity: number }>>(
        Prisma.sql`SELECT p."bookNumber", p.chapter, p."verseStart", p."verseEnd", p.title, p.summary, p."openingText",
                          1 - (q."embedding" <=> ${vectorLiteral}::vector) AS similarity
                   FROM passage_queries q
                   JOIN bible_passages p ON p.id = q."biblePassageId"
                   WHERE q."embedding" IS NOT NULL
                   ORDER BY q."embedding" <=> ${vectorLiteral}::vector
                   LIMIT ${k * 3}`
      )
    : Promise.resolve([])

  const [verseRows, windowRows, passageRows] = await dense
  const lexRows = await lexical
  const dqRows = await doc2query

  const arms: Arm[] = [
    verseRows.map((r) => ({ key: `${r.bookNumber}:${r.chapter}:${r.verse}:${r.verse}`, lexical: false, cand: { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verse, verseEnd: r.verse, text: r.text, similarity: r.similarity } })),
    windowRows.map((r) => ({ key: `${r.bookNumber}:${r.chapter}:${r.verseStart}:${r.verseEnd}`, lexical: false, cand: { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verseStart, verseEnd: r.verseEnd, text: r.text, similarity: r.similarity } })),
    passageRows.map((r) => ({ key: `${r.bookNumber}:${r.chapter}:${r.verseStart}:${r.verseEnd}`, lexical: false, cand: { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verseStart, verseEnd: r.verseEnd, text: r.openingText, similarity: r.similarity, title: r.title, summary: r.summary } })),
  ]
  if (lexRows.length > 0) {
    arms.push(lexRows.map((r) => ({ key: `${r.bookNumber}:${r.chapter}:${r.verse}:${r.verse}`, lexical: true, cand: { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verse, verseEnd: r.verse, text: r.text, similarity: r.similarity } })))
  }
  if (dqRows.length > 0) {
    // Dedupe to best (first = nearest) question per passage span, preserving order.
    const seen = new Set<string>()
    const dqArm: Arm = []
    for (const r of dqRows) {
      const key = `${r.bookNumber}:${r.chapter}:${r.verseStart}:${r.verseEnd}`
      if (seen.has(key)) continue
      seen.add(key)
      dqArm.push({ key, lexical: false, cand: { bookNumber: r.bookNumber, chapter: r.chapter, verseStart: r.verseStart, verseEnd: r.verseEnd, text: r.openingText, similarity: r.similarity, title: r.title, summary: r.summary } })
      if (dqArm.length >= limit * 4) break
    }
    arms.push(dqArm)
  }
  return arms
}

interface FusedEntry { rrf: number; sim: number; cand: Candidate; lexical: boolean }

/** Reciprocal Rank Fusion over every arm. Accumulates RRF score, tracks the max
 *  cosine similarity (for display + the dense gate), flags whether any lexical
 *  arm contributed, and prefers a pericope card as the representative candidate
 *  when one collides on the same span. */
function fuseArms(arms: Arm[]): Map<string, FusedEntry> {
  const fused = new Map<string, FusedEntry>()
  for (const arm of arms) {
    arm.forEach(({ key, cand, lexical }, i) => {
      const contribution = 1 / (RRF_K + i + 1)
      const prev = fused.get(key)
      if (!prev) {
        fused.set(key, { rrf: contribution, sim: cand.similarity, cand, lexical })
      } else {
        prev.rrf += contribution
        if (cand.similarity > prev.sim) prev.sim = cand.similarity
        if (lexical) prev.lexical = true
        if (cand.title && !prev.cand.title) prev.cand = cand
      }
    })
  }
  return fused
}

/**
 * Reorder the top `RERANK_POOL` candidates by cross-encoder relevance to the
 * original query, leaving the long tail in its RRF order. A pericope is
 * represented to the reranker by its concept card (title + summary); verses and
 * windows by their text. Returns the input unchanged when reranking is
 * disabled, times out, or fails.
 */
async function rerankCandidates(query: string, candidates: Candidate[]): Promise<Candidate[]> {
  const pool = candidates.slice(0, RERANK_POOL)
  if (pool.length <= 1) return candidates

  const docs = pool.map((c) => (c.title ? `${c.title}. ${c.summary ?? ''}`.trim() : c.text))
  const scores = await rerank(query, docs)
  if (!scores) return candidates

  const reordered = pool
    .map((c, i) => ({ c, s: scores[i] ?? -Infinity }))
    .sort((a, b) => b.s - a.s)
    .map((x) => x.c)
  return [...reordered, ...candidates.slice(RERANK_POOL)]
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
