/**
 * master-search D17/D18/D31/D35/D38/D39: pure query parsing, tokens, cursor and tag spellings.
 */
import { describe, expect, it } from 'vitest'
import {
  SearchParamError,
  buildTsQuery,
  decodeCursor,
  encodeCursor,
  escapeLike,
  expandTagPicks,
  parseListFilters,
  parseRankedParams,
  phoneDigits,
  tokenizeQuery,
} from '../master-search-query.js'

describe('master-search-query', () => {
  it('rejects q out of bounds', () => {
    for (const q of ['', ' a ', 'x'.repeat(201), 'ab\u0000c']) expect(() => parseRankedParams({ q })).toThrow(SearchParamError)
    expect(parseRankedParams({ q: '  ab ' }).q).toBe('ab')
  })

  it('rejects unknown types, oversized lists and bad limits, keeps foreign ids', () => {
    expect(() => parseRankedParams({ q: 'ab', types: 'PROGRAM,NOPE' })).toThrow(SearchParamError)
    expect(() => parseRankedParams({ q: 'ab', orgIds: Array(51).fill('x').join(',') })).toThrow(SearchParamError)
    expect(() => parseRankedParams({ q: 'ab', limit: '51' })).toThrow(SearchParamError)
    expect(parseRankedParams({ q: 'ab', orgIds: 'not-a-uuid,' }).orgIds).toEqual(['not-a-uuid'])
    expect(parseRankedParams({ q: 'ab' }).limit).toBe(20)
    expect(parseListFilters({}).types).toBeUndefined()
  })

  it('builds a prefix tsquery and survives punctuation', () => {
    expect(buildTsQuery(tokenizeQuery('romans 8'))).toBe("'romans' & '8':*")
    expect(buildTsQuery(tokenizeQuery("o'brien"))).toBe("'o' & 'brien':*")
    for (const q of ["'", ':', '&', '!', '%', '_']) expect(buildTsQuery(tokenizeQuery(q))).toBeNull()
  })

  it('escapes LIKE metacharacters', () => {
    expect(escapeLike('50%_a\\')).toBe('50\\%\\_a\\\\')
  })

  it('round-trips a cursor without losing precision and refuses garbage', () => {
    const c = { score: '4.0607927101', createdAt: '2026-10-03 12:00:00.123456', id: 'abc' }
    expect(decodeCursor(encodeCursor(c))).toEqual(c)
    for (const bad of ['nope', Buffer.from('{"s":"NaN","c":"x","i":"y"}').toString('base64url')]) expect(() => decodeCursor(bad)).toThrow(SearchParamError)
  })

  it('recognizes formatted and partial phones only', () => {
    expect(phoneDigits('(555) 010-0')).toBe('5550100')
    expect(phoneDigits('555')).toBeNull()
    expect(phoneDigits('grace 5550')).toBeNull()
  })

  it('expands a picked category member to all its spellings', () => {
    const cats = [{ key: 'b', name: 'Books', position: 0, tags: [{ tag: '1 samuel', label: '1 Samuel', position: 0 }, { tag: '1samuel', label: '1 Samuel', position: 0 }, { tag: 'mark', label: 'Mark', position: 1 }] }]
    expect(new Set(expandTagPicks(['1 Samuel'], cats))).toEqual(new Set(['1samuel']))
    expect(new Set(expandTagPicks(['Mark', 'Lent Plan'], cats))).toEqual(new Set(['mark', 'lentplan']))
  })
})
