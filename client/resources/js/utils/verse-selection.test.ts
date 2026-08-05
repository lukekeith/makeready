// Word-snapping tests — docs/features/highlighting/ 08 §Client + §iPhone.
//
// These exist because the web had a FOURTH copy of word snapping and it was
// wrong in two ways (09 §X-o): it treated `'` `’` `-` as boundaries, so
// "Lord’s" snapped to "Lord", and it grew the start backwards whenever a word
// character merely preceded the boundary, so a selection starting on a space
// swallowed the previous word. Both are asserted below, so the divergence
// cannot come back silently.
//
// The cases are the ones 03 §5 and 08 §iPhone name by hand, phrased against the
// web port of `HighlightSnapping.snapToWordBoundaries`. The iPhone suite asserts
// the same behaviours against the Swift original (HighlightSnappingTests) —
// that pairing IS the cross-platform guarantee, since nothing in the build can
// diff the two implementations for us.
import { describe, expect, it } from 'vitest'
import { isWordCharacter, snapToWordBoundaries } from './verse-selection'

/** Snap `[start,end)` in `text` and return the text it ends up covering. */
function snapped(text: string, start: number, end: number): string {
  const r = snapToWordBoundaries({ start, end }, text)
  return text.slice(r.start, r.end)
}

describe('isWordCharacter', () => {
  it('treats the three intra-word marks 03 §5 names as word characters', () => {
    // The straight apostrophe, the typographic apostrophe the Bible text
    // actually uses, and the hyphen.
    for (const ch of ["'", '’', '-']) {
      expect(isWordCharacter(ch, 0)).toBe(true)
    }
  })

  it('treats whitespace and other punctuation as boundaries', () => {
    for (const ch of [' ', '\n', '\t', '.', ',', ';', ':', '!', '?', '“', '”', '(', ')']) {
      expect(isWordCharacter(ch, 0)).toBe(false)
    }
  })

  it('accepts letters and digits, including non-ASCII letters', () => {
    for (const ch of ['a', 'Z', '7', 'é', 'ω']) {
      expect(isWordCharacter(ch, 0)).toBe(true)
    }
  })

  it('is false out of bounds rather than throwing', () => {
    expect(isWordCharacter('abc', -1)).toBe(false)
    expect(isWordCharacter('abc', 3)).toBe(false)
  })
})

describe('snapToWordBoundaries', () => {
  // ── The case 08 §iPhone calls "the case today's copies disagree on" ──

  it("keeps \"Lord’s\" whole when the selection lands mid-word", () => {
    const text = 'the Lord’s prayer'
    expect(snapped(text, 5, 8)).toBe('Lord’s') // "ord" → "Lord’s"
  })

  it('keeps "Lord\'s" whole with a straight apostrophe too', () => {
    const text = "the Lord's prayer"
    expect(snapped(text, 5, 8)).toBe("Lord's")
  })

  it('keeps a hyphenated word whole', () => {
    const text = 'a well-being thing'
    expect(snapped(text, 3, 7)).toBe('well-being') // "ell-" → "well-being"
  })

  // ── Grow-only, and only when genuinely mid-word ──

  it('never trims what the user covered', () => {
    const text = 'abcdef ghij'
    const r = snapToWordBoundaries({ start: 2, end: 4 }, text)
    expect(r.start).toBeLessThanOrEqual(2)
    expect(r.end).toBeGreaterThanOrEqual(4)
    expect(snapped(text, 2, 4)).toBe('abcdef')
  })

  it('does NOT grow backwards from a selection that starts on a boundary', () => {
    // The second half of 09 §X-o: the old web copy checked only the character
    // BEFORE the boundary, so this swallowed "hello".
    expect(snapped('hello world', 5, 11)).toBe(' world')
  })

  it('does not grow forwards from an end already on a boundary', () => {
    expect(snapped('hello world', 0, 5)).toBe('hello')
  })

  it('leaves an already word-aligned range alone', () => {
    expect(snapped('one two three', 4, 7)).toBe('two')
  })

  // ── The verse-boundary case: a trailing newline must not walk on ──

  it('does not walk into the next verse from a verse-terminating newline', () => {
    const text = '1. In the beginning\n2. And the earth'
    expect(snapped(text, 0, 20)).toBe('1. In the beginning\n')
  })

  // ── Degenerate input comes back untouched rather than inventing a span ──

  it('returns an empty or inverted range unchanged', () => {
    expect(snapToWordBoundaries({ start: 4, end: 4 }, 'abcdef')).toEqual({ start: 4, end: 4 })
    expect(snapToWordBoundaries({ start: 5, end: 2 }, 'abcdef')).toEqual({ start: 5, end: 2 })
  })

  it('returns an out-of-bounds range unchanged', () => {
    expect(snapToWordBoundaries({ start: -1, end: 3 }, 'abcdef')).toEqual({ start: -1, end: 3 })
    expect(snapToWordBoundaries({ start: 0, end: 99 }, 'abcdef')).toEqual({ start: 0, end: 99 })
  })
})
