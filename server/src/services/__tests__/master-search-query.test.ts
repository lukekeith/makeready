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
  prefixUpperBound,
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

  it('refuses cursor values Postgres would reject, and NUL bytes in ids', () => {
    const enc = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url')
    const ok = { s: '1.5', c: '2026-10-03 12:00:00', i: 'abc' }
    expect(() => decodeCursor(enc(ok))).not.toThrow()
    for (const s of ['0x10', '0b1', '1_0']) expect(() => decodeCursor(enc({ ...ok, s }))).toThrow(SearchParamError)
    expect(() => decodeCursor(enc({ ...ok, c: '2026-13-45 99:99:99' }))).toThrow(SearchParamError)
    expect(() => decodeCursor(enc({ ...ok, c: '2026-02-30 10:00:00' }))).toThrow(SearchParamError)
    expect(() => decodeCursor(enc({ ...ok, i: 'a\u0000b' }))).toThrow(SearchParamError)
    expect(() => parseRankedParams({ q: 'ab', orgIds: 'a\u0000b' })).toThrow(SearchParamError)
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

  it('bounds a prefix range by incrementing the last code point (F14)', () => {
    expect(prefixUpperBound('grace')).toBe('gracf')
    expect(prefixUpperBound('𝒜')).toBe('𝒝')
    expect(prefixUpperBound('\uD7FF')).toBe('\uE000')
  })

  it('carries past U+10FFFF, and an empty or all-U+10FFFF prefix has no upper bound (F14)', () => {
    expect(prefixUpperBound('a\u{10FFFF}')).toBe('b')
    expect(prefixUpperBound('a\u{10FFFF}\u{10FFFF}')).toBe('b')
    expect(prefixUpperBound('\u{10FFFF}')).toBeNull()
    expect(prefixUpperBound('')).toBeNull()
  })
})
