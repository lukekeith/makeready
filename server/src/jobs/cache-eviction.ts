/**
 * Bible Cache Eviction Job
 *
 * Runs daily to delete expired Bible content cache entries.
 * API.Bible requires cache refresh every 14 days.
 */

import { evictExpired, getStats } from '../services/bible-cache.js'

const EVICTION_INTERVAL_MS = 24 * 60 * 60 * 1000 // 24 hours

let evictionTimer: ReturnType<typeof setInterval> | null = null

/**
 * Run a single eviction pass.
 */
async function runEviction(): Promise<void> {
  try {
    const evicted = await evictExpired()
    const stats = await getStats()
    console.log(
      `[cache-eviction] Evicted ${evicted} expired entries. ` +
      `Remaining: ${stats.totalEntries} entries, ${stats.totalVersesCached} verses cached.`
    )
  } catch (error) {
    console.error('[cache-eviction] Error during eviction:', error)
  }
}

/**
 * Start the scheduled cache eviction job.
 * Runs immediately on start, then every 24 hours.
 */
export function startCacheEvictionJob(): void {
  if (evictionTimer) {
    console.warn('[cache-eviction] Job already running')
    return
  }

  console.log('[cache-eviction] Starting daily cache eviction job')

  // Run initial eviction after a short delay (let the server start up)
  setTimeout(() => {
    runEviction()
  }, 10_000)

  // Schedule recurring eviction
  evictionTimer = setInterval(runEviction, EVICTION_INTERVAL_MS)

  // Don't let the timer keep the process alive
  if (evictionTimer.unref) {
    evictionTimer.unref()
  }
}

/**
 * Stop the cache eviction job.
 */
export function stopCacheEvictionJob(): void {
  if (evictionTimer) {
    clearInterval(evictionTimer)
    evictionTimer = null
    console.log('[cache-eviction] Stopped cache eviction job')
  }
}
