/**
 * Semantic Search Query Expansion
 *
 * Rewrites abstract concept queries into biblical-vocabulary variants so the
 * small embedding model (bge-small) can find canonical passages whose wording
 * differs from the user's phrasing. "God speaking to humanity through
 * creation" alone retrieves only literal "God spoke" + creation passages;
 * the variants ("the heavens declare the glory of God…") put Psalm 19 and
 * Romans 1:19-20 at the top.
 *
 * Design constraints:
 * - Fail-open: any error, timeout, or missing API key returns [] and the
 *   search runs on the original query only. Expansion must never break or
 *   block search.
 * - Hard timeout well under the 8s search budget (observed Haiku latency
 *   ranges 1.5-8.4s). A timed-out request keeps running in the background
 *   and still fills the cache, so a repeated search gets the variants.
 * - In-memory LRU cache: repeated queries skip the LLM entirely.
 *
 * Env:
 * - SEMANTIC_EXPANSION_ENABLED     'false' disables expansion (default on)
 * - SEMANTIC_EXPANSION_TIMEOUT_MS  LLM budget per query (default 4000)
 */

import { claudeClient, CLAUDE_MODELS } from './claude.js'

const TIMEOUT_MS = parseInt(process.env.SEMANTIC_EXPANSION_TIMEOUT_MS ?? '4000', 10)
const MAX_VARIANTS = 3
const CACHE_MAX = 500

/** LRU via Map insertion order: get() re-inserts, set() evicts the oldest. */
const cache = new Map<string, string[]>()

export function isExpansionEnabled(): boolean {
  return process.env.SEMANTIC_EXPANSION_ENABLED !== 'false' && !!process.env.ANTHROPIC_API_KEY
}

/**
 * Expand a concept query into up to 3 biblical-vocabulary variants.
 * Returns [] when disabled, on timeout, or on any API/parse failure.
 */
export async function expandQuery(query: string): Promise<string[]> {
  if (!isExpansionEnabled()) return []

  const key = query.trim().toLowerCase()
  const cached = cache.get(key)
  if (cached) {
    cache.delete(key)
    cache.set(key, cached)
    return cached
  }

  // The request itself is not cancelled on timeout: it caches on completion
  // so a retried/repeated search gets the variants even if this one didn't.
  const request = requestVariants(query)
  request
    .then((variants) => {
      if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value!)
      cache.set(key, variants)
    })
    .catch((err) => {
      console.error(`Query expansion failed for "${query}":`, err instanceof Error ? err.message : err)
    })

  try {
    return await Promise.race([request, timeout()])
  } catch {
    return []
  }
}

function timeout(): Promise<never> {
  return new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`expansion timed out after ${TIMEOUT_MS}ms`)), TIMEOUT_MS).unref()
  )
}

async function requestVariants(query: string): Promise<string[]> {
  const message = await claudeClient.messages.create({
    model: CLAUDE_MODELS.haiku,
    max_tokens: 200,
    messages: [{
      role: 'user',
      content: `A user is searching the Bible for: "${query}"

Rewrite this as ${MAX_VARIANTS} alternative search phrasings that use biblical vocabulary and canonical phrasing, so an embedding search will match the passages a pastor would cite for this concept. Each variant should target a DIFFERENT facet or canonical passage of the concept.

Return ONLY a JSON object: {"variants": ["...", "...", "..."]}`,
    }],
  })

  const text = message.content[0].type === 'text' ? message.content[0].text : ''
  const jsonMatch = text.match(/\{[\s\S]*\}/)
  if (!jsonMatch) throw new Error('no JSON in expansion response')
  const parsed = JSON.parse(jsonMatch[0])
  if (!Array.isArray(parsed.variants)) throw new Error('expansion response missing variants array')
  return parsed.variants
    .filter((v: unknown): v is string => typeof v === 'string' && v.trim().length > 0)
    .slice(0, MAX_VARIANTS)
}
