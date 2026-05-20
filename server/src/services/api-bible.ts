/**
 * API.Bible Client Service
 *
 * HTTP client wrapping all API.Bible v1 endpoints.
 * Base URL: https://rest.api.bible/v1
 * Auth: api-key header
 *
 * Features:
 * - Rate tracking (5,000/day limit, warns at 4,000)
 * - Retry with exponential backoff on 429/5xx
 * - FUMS v3 tokens on all scripture content requests
 * - Typed responses for all endpoints
 */

import type {
  ApiBibleResponse,
  ApiBibleMeta,
  ApiBibleSummary,
  ApiBible,
  ApiBibleBook,
  ApiBibleChapter,
  ApiBibleVerseSummary,
  ApiBibleVerse,
  ApiBiblePassage,
  ApiBibleSearchOptions,
  ApiBibleSearchResponse,
} from '../types/api-bible.js'

const BASE_URL = 'https://rest.api.bible/v1'
const MAX_RETRIES = 3
const INITIAL_BACKOFF_MS = 500

// ============================================
// Rate tracking
// ============================================

interface RateState {
  date: string // YYYY-MM-DD
  count: number
}

const rateState: RateState = {
  date: new Date().toISOString().slice(0, 10),
  count: 0,
}

const DAILY_LIMIT = 5000
const WARN_THRESHOLD = 4000
const ERROR_THRESHOLD = 4900

function incrementRateCounter(): void {
  const today = new Date().toISOString().slice(0, 10)
  if (rateState.date !== today) {
    rateState.date = today
    rateState.count = 0
  }
  rateState.count++

  if (rateState.count === WARN_THRESHOLD) {
    console.warn(
      `[api-bible] Rate warning: ${rateState.count}/${DAILY_LIMIT} daily API calls used`
    )
  }
  if (rateState.count >= ERROR_THRESHOLD) {
    console.error(
      `[api-bible] Rate critical: ${rateState.count}/${DAILY_LIMIT} daily API calls — approaching limit`
    )
  }
}

/** Get the current daily rate counter state */
export function getRateStats(): { date: string; count: number; limit: number; remaining: number } {
  const today = new Date().toISOString().slice(0, 10)
  if (rateState.date !== today) {
    return { date: today, count: 0, limit: DAILY_LIMIT, remaining: DAILY_LIMIT }
  }
  return {
    date: rateState.date,
    count: rateState.count,
    limit: DAILY_LIMIT,
    remaining: Math.max(0, DAILY_LIMIT - rateState.count),
  }
}

// ============================================
// HTTP helper
// ============================================

function getApiKey(): string {
  const key = process.env.API_BIBLE_KEY
  if (!key) {
    throw new Error('[api-bible] API_BIBLE_KEY environment variable is not set')
  }
  return key
}

async function apiBibleFetch<T>(
  path: string,
  params?: Record<string, string | number | boolean | undefined>
): Promise<ApiBibleResponse<T>> {
  const url = new URL(`${BASE_URL}${path}`)

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined) {
        url.searchParams.set(key, String(value))
      }
    }
  }

  let lastError: Error | null = null

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    if (attempt > 0) {
      const delay = INITIAL_BACKOFF_MS * Math.pow(2, attempt - 1)
      await new Promise((resolve) => setTimeout(resolve, delay))
    }

    incrementRateCounter()

    try {
      const response = await fetch(url.toString(), {
        method: 'GET',
        headers: {
          'api-key': getApiKey(),
          'Accept': 'application/json',
        },
      })

      if (response.ok) {
        const json = await response.json()
        return json as ApiBibleResponse<T>
      }

      // Retry on 429 (rate limited) and 5xx (server errors)
      if (response.status === 429 || response.status >= 500) {
        lastError = new Error(
          `[api-bible] ${response.status} ${response.statusText} for ${path}`
        )
        console.warn(
          `[api-bible] Retrying (${attempt + 1}/${MAX_RETRIES}): ${response.status} for ${path}`
        )
        continue
      }

      // Non-retryable client errors
      const errorBody = await response.text().catch(() => '')
      throw new Error(
        `[api-bible] ${response.status} ${response.statusText} for ${path}: ${errorBody}`
      )
    } catch (error) {
      if (error instanceof TypeError && error.message.includes('fetch')) {
        // Network error — retryable
        lastError = error
        console.warn(
          `[api-bible] Network error (${attempt + 1}/${MAX_RETRIES}): ${error.message}`
        )
        continue
      }
      throw error
    }
  }

  throw lastError || new Error(`[api-bible] Failed after ${MAX_RETRIES} retries for ${path}`)
}

/** Extract fumsToken from API.Bible meta response */
export function extractFumsToken(meta?: ApiBibleMeta): string | null {
  if (!meta) return null
  return meta.fumsToken || meta.fumsId || null
}

// ============================================
// API methods
// ============================================

/**
 * Get all Bibles available for this API key
 * @param language - ISO 639-3 language code (e.g., "eng")
 */
export async function getBibles(
  language?: string
): Promise<{ data: ApiBibleSummary[]; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBibleSummary[]>('/bibles', { language })
}

/**
 * Get a single Bible by ID
 */
export async function getBible(
  bibleId: string
): Promise<{ data: ApiBible; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBible>(`/bibles/${bibleId}`)
}

/**
 * Get all books for a Bible
 * @param includeChapters - include chapter summaries in response
 */
export async function getBooks(
  bibleId: string,
  includeChapters: boolean = false
): Promise<{ data: ApiBibleBook[]; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBibleBook[]>(`/bibles/${bibleId}/books`, {
    'include-chapters': includeChapters || undefined,
  })
}

/**
 * Get a single chapter with full content
 * @param contentType - "text", "html", or "json" (default: "text")
 */
export async function getChapter(
  bibleId: string,
  chapterId: string,
  contentType: string = 'text'
): Promise<{ data: ApiBibleChapter; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBibleChapter>(`/bibles/${bibleId}/chapters/${chapterId}`, {
    'content-type': contentType,
    'include-verse-numbers': true,
    'include-titles': true,
    'fums-version': 3,
  })
}

/**
 * Get all verse summaries for a chapter (IDs and references only, no content)
 */
export async function getVerseList(
  bibleId: string,
  chapterId: string
): Promise<{ data: ApiBibleVerseSummary[]; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBibleVerseSummary[]>(
    `/bibles/${bibleId}/chapters/${chapterId}/verses`
  )
}

/**
 * Get a single verse with full content
 * @param contentType - "text", "html", or "json" (default: "text")
 */
export async function getVerse(
  bibleId: string,
  verseId: string,
  contentType: string = 'text'
): Promise<{ data: ApiBibleVerse; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBibleVerse>(`/bibles/${bibleId}/verses/${verseId}`, {
    'content-type': contentType,
    'include-verse-numbers': false,
    'include-titles': false,
    'fums-version': 3,
  })
}

/**
 * Get a passage (range of verses) with full content
 * @param passageId - e.g., "JHN.3.16-JHN.3.18"
 * @param contentType - "text", "html", or "json" (default: "text")
 */
export async function getPassage(
  bibleId: string,
  passageId: string,
  contentType: string = 'text'
): Promise<{ data: ApiBiblePassage; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBiblePassage>(`/bibles/${bibleId}/passages/${passageId}`, {
    'content-type': contentType,
    'include-verse-numbers': true,
    'include-titles': true,
    'fums-version': 3,
  })
}

/**
 * Search a Bible by keyword or reference
 */
export async function searchBible(
  bibleId: string,
  options: ApiBibleSearchOptions
): Promise<{ data: ApiBibleSearchResponse; meta?: ApiBibleMeta }> {
  return apiBibleFetch<ApiBibleSearchResponse>(`/bibles/${bibleId}/search`, {
    query: options.query,
    limit: options.limit,
    offset: options.offset,
    sort: options.sort,
    range: options.range,
    fuzziness: options.fuzziness,
    'fums-version': 3,
  })
}
