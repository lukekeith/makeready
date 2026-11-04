/**
 * master-search-query: pure query parsing for C1/C2 — parameters, tsquery tokens, LIKE escaping, the
 * paging cursor, phone detection and tag spellings. No database (SPEC D17, D18, D31, D35, D38, D39).
 */
import { normalizeTag, type TagCategoryDTO } from './tag-categories.js'

/** D5: the closed list of searchable types. */
export const SEARCH_TYPES = ['PROGRAM', 'TEMPLATE', 'MEMBER', 'GROUP', 'LESSON', 'EVENT', 'POST', 'VIDEO', 'PHOTO'] as const
export type SearchType = (typeof SEARCH_TYPES)[number]

const MAX_LIST = 50
const MAX_LIMIT = 50
const DEFAULT_RANKED_LIMIT = 20
const DEFAULT_RECENT_LIMIT = 50

/** Its message is the 400's `error`. */
export class SearchParamError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'SearchParamError'
  }
}

export interface ListFilters {
  types?: SearchType[]
  orgIds?: string[]
  groupIds?: string[]
  leaderIds?: string[]
  tags?: string[]
}

export interface RankedParams extends ListFilters {
  q: string
  limit: number
  cursor?: { score: string; createdAt: string; id: string }
}

type RawQuery = Record<string, unknown>

/** A comma list (or a repeated parameter) with empty items dropped; undefined when absent. */
function parseList(raw: unknown, name: string): string[] | undefined {
  if (raw === undefined || raw === null) return undefined
  const parts = Array.isArray(raw) ? raw : [raw]
  const out: string[] = []
  for (const part of parts) {
    if (typeof part !== 'string') throw new SearchParamError(`Invalid ${name}`)
    for (const item of part.split(',')) {
      const trimmed = item.trim()
      if (trimmed) out.push(trimmed)
    }
  }
  if (out.length > MAX_LIST) throw new SearchParamError(`${name} accepts at most ${MAX_LIST} values`)
  return out
}

/** D38: types must be in the closed list; ids and tags are kept as given, since they only narrow. */
export function parseListFilters(query: RawQuery): ListFilters {
  const types = parseList(query.types, 'types')
  if (types) {
    for (const t of types) {
      if (!(SEARCH_TYPES as readonly string[]).includes(t)) throw new SearchParamError(`Invalid type: ${t}`)
    }
  }
  return {
    types: types as SearchType[] | undefined,
    orgIds: parseList(query.orgIds, 'orgIds'),
    groupIds: parseList(query.groupIds, 'groupIds'),
    leaderIds: parseList(query.leaderIds, 'leaderIds'),
    tags: parseList(query.tags, 'tags'),
  }
}

function parseLimit(raw: unknown, fallback: number): number {
  if (raw === undefined || raw === null || raw === '') return fallback
  if (typeof raw !== 'string' || !/^\d+$/.test(raw)) throw new SearchParamError('limit must be an integer from 1 to 50')
  const n = Number(raw)
  if (n < 1 || n > MAX_LIMIT) throw new SearchParamError('limit must be an integer from 1 to 50')
  return n
}

/** C1's parameters (D17, D18). */
export function parseRankedParams(query: RawQuery): RankedParams {
  const rawQ = query.q
  if (typeof rawQ !== 'string') throw new SearchParamError('q is required')
  const q = rawQ.trim()
  if (q.length < 2) throw new SearchParamError('q must be at least 2 characters')
  if (q.length > 200) throw new SearchParamError('q must be at most 200 characters')
  if (q.includes('\u0000')) throw new SearchParamError('q contains an invalid character')
  const rawCursor = query.cursor
  if (rawCursor !== undefined && typeof rawCursor !== 'string') throw new SearchParamError('Invalid cursor')
  return {
    q,
    ...parseListFilters(query),
    limit: parseLimit(query.limit, DEFAULT_RANKED_LIMIT),
    cursor: rawCursor ? decodeCursor(rawCursor) : undefined,
  }
}

/** C2's limit (D12): 1–50, default 50. */
export function parseRecentLimit(query: RawQuery): number {
  return parseLimit(query.limit, DEFAULT_RECENT_LIMIT)
}

/** D39: letter and digit runs only. */
export function tokenizeQuery(q: string): string[] {
  return q.match(/[\p{L}\p{N}]+/gu) ?? []
}

/** D39: each token quoted, joined with `&`, the last a prefix; bound as one `to_tsquery` parameter. */
export function buildTsQuery(tokens: string[]): string | null {
  if (tokens.length === 0) return null
  return tokens.map((t, i) => `'${t}'${i === tokens.length - 1 ? ':*' : ''}`).join(' & ')
}

/** D39: escapes `%`, `_` and `\` for a LIKE pattern. */
export function escapeLike(text: string): string {
  return text.replace(/[\\%_]/g, (c) => `\\${c}`)
}

export interface SearchCursor {
  score: string
  createdAt: string
  id: string
}

export function encodeCursor(c: SearchCursor): string {
  return Buffer.from(JSON.stringify({ s: c.score, c: c.createdAt, i: c.id })).toString('base64url')
}

const TIMESTAMP = /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}(:?\d{2})?)?$/

export function decodeCursor(raw: string): SearchCursor {
  const bad = () => new SearchParamError('Invalid cursor')
  let parsed: unknown
  try {
    parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'))
  } catch {
    throw bad()
  }
  if (!parsed || typeof parsed !== 'object') throw bad()
  const { s, c, i } = parsed as Record<string, unknown>
  if (typeof s !== 'string' || s.trim() === '' || !Number.isFinite(Number(s))) throw bad()
  if (typeof c !== 'string' || !TIMESTAMP.test(c)) throw bad()
  if (typeof i !== 'string' || i === '') throw bad()
  return { score: s, createdAt: c, id: i }
}

/** D35: the digits of a phone-looking query (digits and `+ - ( ) .` and spaces, 4+ digits), else null. */
export function phoneDigits(q: string): string | null {
  if (!/^[\d\s+\-().]+$/.test(q)) return null
  const digits = q.replace(/\D/g, '')
  return digits.length >= 4 ? digits : null
}

/**
 * D31: each pick is normalized; a pick that is a category member expands to every spelling sharing that
 * member's position in its category, each normalized.
 */
export function expandTagPicks(picks: string[], categories: TagCategoryDTO[]): string[] {
  const out = new Set<string>()
  for (const pick of picks) {
    const n = normalizeTag(pick)
    if (!n) continue
    out.add(n)
    for (const cat of categories) {
      const member = cat.tags.find((t) => normalizeTag(t.tag) === n)
      if (!member) continue
      for (const t of cat.tags) if (t.position === member.position) out.add(normalizeTag(t.tag))
    }
  }
  return [...out]
}
