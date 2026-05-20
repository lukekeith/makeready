/**
 * Bible Metadata Service
 *
 * Manages the cached list of available Bible versions and their metadata.
 * Uses ApiBibleVersion table with 24h TTL.
 */

import { prisma } from '../lib/prisma.js'
import * as apiBible from './api-bible.js'
import { getAllBooks } from '../utils/bible-id-map.js'
import type { ApiBibleBook } from '../types/api-bible.js'

const METADATA_TTL_HOURS = 24

/**
 * Deduplicate Bible versions by abbreviation.
 * API.Bible returns multiple entries for the same translation (OT, NT, Apocrypha parts).
 * Keep the -01 ID (full Bible) when there are duplicates.
 */
function deduplicateVersions<T extends { abbreviation: string; apiBibleId: string }>(versions: T[]): T[] {
  const seen = new Map<string, T>()
  for (const v of versions) {
    const key = v.abbreviation.toUpperCase()
    const existing = seen.get(key)
    if (!existing || v.apiBibleId.endsWith('-01')) {
      seen.set(key, v)
    }
  }
  return Array.from(seen.values())
}

// In-memory abbreviation → bibleId cache (refreshed from DB)
let bibleIdCache: Map<string, string> | null = null
let bibleIdCacheExpiry = 0

/**
 * Popularity scores based on ECPA Bible Translation Bestseller rankings (Oct 2025).
 * Maps abbreviation patterns to scores (100 = #1 bestseller).
 * Translations not on API.Bible (ESV, NLT, NKJV, CSB, NRSV) are excluded.
 */
const POPULARITY_SCORES: Record<string, number> = {
  // ECPA Top 10 (mapped to API.Bible codes)
  'NIV11': 100,        // #1 NIV
  'ENGKJV': 80,        // #3 KJV
  'NASB': 60,          // #9 NASB
  'NASB1995': 55,      // NASB older edition
  // Well-known translations
  'ASV': 40,           // Classic, widely referenced
  'WEB': 35,           // Public domain, widely used in apps
  'ENGWEBU': 35,       // World English Bible Updated
  'LSV': 30,           // Literal Standard Version
  'FBV': 25,           // Free Bible Version
  'ENGDRA': 20,        // Douay-Rheims (Catholic)
  'TOJB2011': 20,      // Orthodox Jewish Bible
  'ENGKJVCPB': 15,     // Cambridge Paragraph KJV
  'ENGGNV': 15,        // Geneva Bible (historical)
  'ENGRV': 10,         // Revised Version 1885
  'WEBBE': 10,         // WEB British Edition
  'ENGWEBUS': 10,      // WEB American without Strong's
  'WMB': 10,           // World Messianic Bible
}

function getPopularity(abbreviation: string): number {
  const key = abbreviation.toUpperCase()
  return POPULARITY_SCORES[key] ?? 5
}

/**
 * Get all available Bible versions, refreshing from API.Bible if cache expired.
 */
export async function getAvailableBibles(language: string = 'eng') {
  // Check if we have unexpired cached versions
  const now = new Date()
  const cached = await prisma.apiBibleVersion.findMany({
    where: {
      language,
      isActive: true,
      expiresAt: { gt: now },
    },
    orderBy: { popularity: 'desc' },
  })

  if (cached.length > 0) {
    return deduplicateVersions(cached)
  }

  // Cache miss or expired — fetch from API.Bible
  console.log('[bible-metadata] Refreshing Bible version cache from API.Bible...')
  const { data: bibles } = await apiBible.getBibles(language)

  const expiresAt = new Date(Date.now() + METADATA_TTL_HOURS * 60 * 60 * 1000)

  // Upsert all versions
  for (const bible of bibles) {
    await prisma.apiBibleVersion.upsert({
      where: { apiBibleId: bible.id },
      create: {
        apiBibleId: bible.id,
        abbreviation: bible.abbreviation,
        name: bible.name,
        language: bible.language.id,
        description: bible.description || null,
        copyright: null,
        popularity: getPopularity(bible.abbreviation),
        isActive: true,
        cachedAt: now,
        expiresAt,
      },
      update: {
        abbreviation: bible.abbreviation,
        name: bible.name,
        description: bible.description || null,
        popularity: getPopularity(bible.abbreviation),
        isActive: true,
        cachedAt: now,
        expiresAt,
      },
    })
  }

  // Invalidate in-memory cache
  bibleIdCache = null

  console.log(`[bible-metadata] Cached ${bibles.length} Bible versions (TTL: ${METADATA_TTL_HOURS}h)`)

  return deduplicateVersions(
    await prisma.apiBibleVersion.findMany({
      where: { language, isActive: true },
      orderBy: { popularity: 'desc' },
    })
  )
}

/**
 * Match a translation code against a cache map.
 * Tries: exact match → eng-prefixed → partial match (code in abbreviation).
 */
function matchCode(code: string, cache: Map<string, string>): string | null {
  // Exact match
  const exact = cache.get(code)
  if (exact) return exact

  // Eng-prefixed (KJV -> ENGKJV)
  const prefixed = cache.get(`ENG${code}`)
  if (prefixed) return prefixed

  // Partial match (code appears anywhere in abbreviation)
  for (const [abbrev, id] of cache) {
    if (abbrev.includes(code)) return id
  }

  return null
}

/**
 * Resolve a translation code (e.g., "NASB", "KJV") to an API.Bible bibleId.
 * Searches by abbreviation (case-insensitive).
 *
 * Returns null if not found — caller should call getAvailableBibles() to refresh.
 */
export async function resolveBibleId(translationCode: string): Promise<string | null> {
  const code = translationCode.toUpperCase()

  // Rebuild from DB if cache is empty or expired
  if (!bibleIdCache || Date.now() >= bibleIdCacheExpiry) {
    const versions = await prisma.apiBibleVersion.findMany({
      where: { isActive: true },
      select: { abbreviation: true, apiBibleId: true },
    })

    bibleIdCache = new Map()
    for (const v of versions) {
      bibleIdCache.set(v.abbreviation.toUpperCase(), v.apiBibleId)
    }
    bibleIdCacheExpiry = Date.now() + 5 * 60 * 1000 // 5 min in-memory TTL
  }

  // Try exact match, then eng-prefixed, then partial match
  const fromCache = matchCode(code, bibleIdCache)
  if (fromCache) return fromCache

  // Not in cache — refresh from API.Bible and retry
  await getAvailableBibles('eng')
  bibleIdCache = null // Force cache rebuild on next call
  const versions = await prisma.apiBibleVersion.findMany({
    where: { isActive: true },
    select: { abbreviation: true, apiBibleId: true },
  })
  const freshMap = new Map<string, string>()
  for (const v of versions) {
    freshMap.set(v.abbreviation.toUpperCase(), v.apiBibleId)
  }
  bibleIdCache = freshMap
  bibleIdCacheExpiry = Date.now() + 5 * 60 * 1000

  return matchCode(code, freshMap)
}

/**
 * Get books for a Bible, mapping to our numeric book numbers.
 * Returns books in canonical order (1-66).
 */
export async function getBooksForBible(bibleId: string) {
  const { data: apiBooks } = await apiBible.getBooks(bibleId, true)

  const canonicalBooks = getAllBooks()
  const apiBookMap = new Map<string, ApiBibleBook>(apiBooks.map((b) => [b.id, b]))

  return canonicalBooks
    .map((canonical) => {
      const apiBook = apiBookMap.get(canonical.apiBibleId)
      if (!apiBook) return null

      // Chapter count: API.Bible includes an "intro" chapter, so subtract 1
      // unless it's only the intro (shouldn't happen for canonical books)
      const chapterCount = apiBook.chapters
        ? apiBook.chapters.filter((c) => c.number !== 'intro').length
        : 0

      return {
        bookNumber: canonical.bookNumber,
        bookName: apiBook.name,
        bookAbbrev: canonical.abbrev,
        testament: canonical.testament,
        chapters: chapterCount,
      }
    })
    .filter(Boolean)
}
