/**
 * Voice Memo Maintenance Job (D26)
 *
 * Every 15 minutes, in order: (1) expire stale pending uploads, (2) retry
 * transcription, (3) purge memos soft-deleted over 30 days ago. Each step
 * catches its own errors; a pass runs under an advisory lock (D32) so only
 * one server instance runs it.
 */

import pg from 'pg'
import {
  expireStalePendingUploads,
  memoIdsDueForTranscriptRetry,
  purgeDeletedMemos,
} from '../services/memos.service.js'
import { transcribeMemo } from '../services/transcription.service.js'

export const MEMO_MAINTENANCE_INTERVAL_MS = 900_000
export const MEMO_MAINTENANCE_LOCK_KEY = 727201002
const STARTUP_DELAY_MS = 10_000

export interface MemoMaintenanceDeps {
  now?: () => Date
  transcribe?: (memoId: string) => Promise<unknown>
  env?: NodeJS.ProcessEnv
}

export type MemoMaintenanceResult = { expired: number; retried: number; purged: number } | { skippedLockHeld: true }

async function runSteps(deps: MemoMaintenanceDeps): Promise<{ expired: number; retried: number; purged: number }> {
  const now = deps.now ?? (() => new Date())
  const transcribe = deps.transcribe ?? transcribeMemo
  const env = deps.env ?? process.env
  const out = { expired: 0, retried: 0, purged: 0 }

  try {
    out.expired = await expireStalePendingUploads(now())
  } catch (error) {
    console.error('[memo-maintenance] Error expiring pending uploads:', error)
  }

  // Without a key nothing can transcribe; skip so memos retry once it is set (D33).
  if (env.GROQ_API_KEY) {
    try {
      for (const id of await memoIdsDueForTranscriptRetry()) {
        try {
          await transcribe(id)
          out.retried++
        } catch (error) {
          console.error(`[memo-maintenance] Transcription retry failed for memo ${id}:`, error)
        }
      }
    } catch (error) {
      console.error('[memo-maintenance] Error retrying transcripts:', error)
    }
  }

  try {
    out.purged = await purgeDeletedMemos(now())
  } catch (error) {
    console.error('[memo-maintenance] Error purging deleted memos:', error)
  }

  return out
}

/** Run one pass under the advisory lock. Never throws. */
export async function runMemoMaintenance(deps: MemoMaintenanceDeps = {}): Promise<MemoMaintenanceResult> {
  const pool = new pg.Pool({ connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL, max: 1 })
  pool.on('error', (err) => console.error('[memo-maintenance] pool error:', err.message))
  let client: pg.PoolClient | null = null
  let locked = false
  try {
    client = await pool.connect()
    const lock = await client.query<{ locked: boolean }>('SELECT pg_try_advisory_lock($1) AS locked', [MEMO_MAINTENANCE_LOCK_KEY])
    locked = !!lock.rows[0]?.locked
    if (!locked) return { skippedLockHeld: true }

    const result = await runSteps(deps)
    console.log(
      `[memo-maintenance] expired ${result.expired}, retried ${result.retried}, purged ${result.purged}`
    )
    return result
  } catch (error) {
    console.error('[memo-maintenance] Error during pass:', error)
    return { expired: 0, retried: 0, purged: 0 }
  } finally {
    if (client) {
      if (locked) {
        await client.query('SELECT pg_advisory_unlock($1)', [MEMO_MAINTENANCE_LOCK_KEY]).catch((err) =>
          console.error('[memo-maintenance] unlock failed:', err.message)
        )
      }
      client.release()
    }
    await pool.end().catch(() => {})
  }
}

let timer: ReturnType<typeof setInterval> | null = null

/** Start the job: one pass 10 s after start, then every 15 min. */
export function startMemoMaintenanceJob(): void {
  if (timer) {
    console.warn('[memo-maintenance] Job already running')
    return
  }

  console.log('[memo-maintenance] Starting memo maintenance job')

  setTimeout(() => {
    runMemoMaintenance()
  }, STARTUP_DELAY_MS).unref()

  timer = setInterval(() => {
    runMemoMaintenance()
  }, MEMO_MAINTENANCE_INTERVAL_MS)
  timer.unref()
}

export function stopMemoMaintenanceJob(): void {
  if (timer) {
    clearInterval(timer)
    timer = null
    console.log('[memo-maintenance] Stopped memo maintenance job')
  }
}
