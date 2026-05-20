/**
 * Bible Content Cache Service
 *
 * Caches API.Bible chapter/verse/passage content in Postgres with 14-day TTL.
 * Compliant with API.Bible fair use policy.
 */

import { prisma } from '../lib/prisma.js'

const CACHE_TTL_DAYS = 14

/**
 * Get cached content by cache key.
 * Returns null if not found or expired.
 * Increments access count on hit.
 */
export async function getCached(cacheKey: string): Promise<{
  responseJson: string
  copyright: string | null
  verseCount: number
} | null> {
  const now = new Date()

  const entry = await prisma.bibleContentCache.findUnique({
    where: { cacheKey },
  })

  if (!entry || entry.expiresAt <= now) {
    return null
  }

  // Increment access count (fire-and-forget)
  prisma.bibleContentCache
    .update({
      where: { cacheKey },
      data: {
        accessCount: { increment: 1 },
        lastAccessed: now,
      },
    })
    .catch(() => {}) // Swallow errors — this is best-effort

  return {
    responseJson: entry.responseJson,
    copyright: entry.copyright,
    verseCount: entry.verseCount,
  }
}

/**
 * Store content in cache with 14-day TTL.
 * Upserts — safe to call on existing keys.
 */
export async function setCache(
  cacheKey: string,
  bibleId: string,
  contentType: string,
  data: unknown,
  copyright: string | null,
  verseCount: number = 0
): Promise<void> {
  const now = new Date()
  const expiresAt = new Date(now.getTime() + CACHE_TTL_DAYS * 24 * 60 * 60 * 1000)
  const responseJson = JSON.stringify(data)

  await prisma.bibleContentCache.upsert({
    where: { cacheKey },
    create: {
      cacheKey,
      bibleId,
      contentType,
      responseJson,
      copyright,
      verseCount,
      cachedAt: now,
      expiresAt,
      accessCount: 1,
      lastAccessed: now,
    },
    update: {
      responseJson,
      copyright,
      verseCount,
      cachedAt: now,
      expiresAt,
      accessCount: 1,
      lastAccessed: now,
    },
  })
}

/**
 * Delete all expired cache entries.
 * Returns the count of deleted entries.
 */
export async function evictExpired(): Promise<number> {
  const now = new Date()
  const result = await prisma.bibleContentCache.deleteMany({
    where: { expiresAt: { lte: now } },
  })

  if (result.count > 0) {
    console.log(`[bible-cache] Evicted ${result.count} expired cache entries`)
  }

  return result.count
}

/**
 * Get cache statistics.
 */
export async function getStats(): Promise<{
  totalEntries: number
  expiredEntries: number
  totalVersesCached: number
}> {
  const now = new Date()

  const [total, expired, verseSum] = await Promise.all([
    prisma.bibleContentCache.count(),
    prisma.bibleContentCache.count({
      where: { expiresAt: { lte: now } },
    }),
    prisma.bibleContentCache.aggregate({
      _sum: { verseCount: true },
    }),
  ])

  return {
    totalEntries: total,
    expiredEntries: expired,
    totalVersesCached: verseSum._sum.verseCount || 0,
  }
}

/**
 * Delete a specific cache entry by key.
 * Returns true if the entry was found and deleted.
 */
export async function clearCacheEntry(cacheKey: string): Promise<boolean> {
  try {
    await prisma.bibleContentCache.delete({
      where: { cacheKey },
    })
    return true
  } catch {
    return false // Entry not found
  }
}

/**
 * Delete all cache entries matching a prefix (e.g., "chapter:bibleId:").
 * Returns the count of deleted entries.
 */
export async function clearCacheByPrefix(prefix: string): Promise<number> {
  const result = await prisma.bibleContentCache.deleteMany({
    where: { cacheKey: { startsWith: prefix } },
  })
  return result.count
}

/**
 * Get the most accessed chapters (for proactive re-warming).
 */
export async function getTopChapters(limit: number = 50): Promise<string[]> {
  const entries = await prisma.bibleContentCache.findMany({
    where: { contentType: 'chapter' },
    orderBy: { accessCount: 'desc' },
    take: limit,
    select: { cacheKey: true },
  })

  return entries.map((e) => e.cacheKey)
}
