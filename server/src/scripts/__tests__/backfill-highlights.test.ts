/**
 * Backfill logic — the decisions the script makes, tested in isolation.
 *
 * WHAT THIS COVERS AND WHAT IT DOESN'T. The script itself is a top-level program that talks to the
 * database, so these tests exercise the *rules* it applies rather than driving the whole run:
 * which blocks are candidates, what rows a block's spans become, whether the projection round-trips,
 * and — the part with teeth — the condition that decides whether a stored hash baseline may be
 * re-stamped. That condition is the one place where a wrong answer silently marks a leader's real
 * edit as synced, which is why it gets the most cases here.
 *
 * The end-to-end behaviour (49 blocks migrated, 67 rows created, baselines re-stamped, rollback
 * restoring the exact pre-run fingerprint) was verified by running it against production-synced
 * local data; see docs/features/highlighting/12 §3.9 and the recorded fingerprints.
 */

import { describe, it, expect } from 'vitest'

interface Span { start: number; end: number; style?: string }

// ── The rules under test, extracted verbatim from src/scripts/backfill-highlights.ts ──────────
// Kept as local copies deliberately: the script is a program, not a module, and importing it
// would execute it. If the script's logic changes, these must be updated in step — the header
// of the script says so.

/** A block is a candidate iff it has spans and no rows yet. */
function isCandidate(selections: unknown, existingRowCount: number): boolean {
  return Array.isArray(selections) && selections.length > 0 && existingRowCount === 0
}

/** orderNumber = index in the existing array, so the sorted projection re-emits the same order. */
function rowsFor(blockId: string, spans: Span[]) {
  return spans.map((s, i) => ({
    readBlockId: blockId,
    orderNumber: i,
    start: s.start,
    end: s.end,
    style: s.style ?? 'highlight',
    noteMarkdown: '',
  }))
}

/** What syncSelectionsForBlock would regenerate from those rows. */
function projectionFrom(rows: ReturnType<typeof rowsFor>) {
  return [...rows]
    .sort((a, b) => a.orderNumber - b.orderNumber)
    .map((r) => ({ start: r.start, end: r.end, style: r.style }))
}

/** May this stored baseline be re-stamped? Only if it still records the pre-backfill hash. */
function mayRestamp(storedHash: string | null | undefined, hashBefore: string): boolean {
  return storedHash === hashBefore
}

describe('backfill candidate selection', () => {
  it('takes a block with spans and no rows', () => {
    expect(isCandidate([{ start: 0, end: 5 }], 0)).toBe(true)
  })

  it('skips a block that already has rows — this is what makes a re-run a no-op', () => {
    expect(isCandidate([{ start: 0, end: 5 }], 3)).toBe(false)
  })

  it('skips a block with an empty array, and one with no selections at all', () => {
    expect(isCandidate([], 0)).toBe(false)
    expect(isCandidate(null, 0)).toBe(false)
    // A JSON null (not SQL NULL) reads back as a scalar, not an array — must not throw.
    expect(isCandidate('null', 0)).toBe(false)
  })
})

describe('span → row conversion', () => {
  it('numbers rows by array index so document order survives', () => {
    const rows = rowsFor('block-1', [{ start: 10, end: 20 }, { start: 0, end: 5 }])
    // Note the spans are NOT sorted — insertion order is the order, and index preserves it.
    expect(rows.map((r) => r.orderNumber)).toEqual([0, 1])
    expect(rows.map((r) => r.start)).toEqual([10, 0])
  })

  it('defaults a span with no style to "highlight"', () => {
    expect(rowsFor('b', [{ start: 0, end: 5 }])[0].style).toBe('highlight')
  })

  it('preserves an explicit style', () => {
    expect(rowsFor('b', [{ start: 0, end: 5, style: 'bold' }])[0].style).toBe('bold')
  })

  it('gives Read spans an empty note — they never had one', () => {
    expect(rowsFor('b', [{ start: 0, end: 5 }])[0].noteMarkdown).toBe('')
  })

  it('copies overlapping spans as-is, without merging', () => {
    // The backfill is a copy, not a normalisation of user intent (03 §4). Merging only ever
    // happens on a user action.
    const rows = rowsFor('b', [{ start: 0, end: 10 }, { start: 5, end: 15 }])
    expect(rows).toHaveLength(2)
    expect(rows.map((r) => [r.start, r.end])).toEqual([[0, 10], [5, 15]])
  })
})

describe('projection round-trip — selections must not move', () => {
  it('regenerates the original array exactly, including order', () => {
    const spans: Span[] = [
      { start: 231, end: 256, style: 'highlight' },
      { start: 584, end: 609, style: 'highlight' },
    ]
    expect(projectionFrom(rowsFor('b', spans))).toEqual(spans)
  })

  it('round-trips an unsorted array without reordering it', () => {
    const spans: Span[] = [{ start: 90, end: 99 }, { start: 1, end: 5 }]
    expect(projectionFrom(rowsFor('b', spans)))
      .toEqual([{ start: 90, end: 99, style: 'highlight' }, { start: 1, end: 5, style: 'highlight' }])
  })

  it('materialises the default style into the projection', () => {
    // The stored column already carries an explicit style on every span, so this is what keeps
    // the regenerated JSON identical rather than gaining or losing a key.
    expect(projectionFrom(rowsFor('b', [{ start: 0, end: 3 }])))
      .toEqual([{ start: 0, end: 3, style: 'highlight' }])
  })
})

describe('the re-stamp condition — the one that can corrupt sync state', () => {
  const BEFORE = 'v1:aaa'

  it('re-stamps a baseline that still records the pre-backfill hash', () => {
    expect(mayRestamp(BEFORE, BEFORE)).toBe(true)
  })

  it('REFUSES a baseline recording anything else — that lesson was genuinely edited', () => {
    // Re-stamping here would tell an enrolled group its lesson is up to date when a leader has
    // actually changed it. This is the failure the condition exists to prevent.
    expect(mayRestamp('v1:something-else', BEFORE)).toBe(false)
  })

  it('refuses a null baseline rather than treating absence as a match', () => {
    expect(mayRestamp(null, BEFORE)).toBe(false)
    expect(mayRestamp(undefined, BEFORE)).toBe(false)
  })

  it('is exact — a hash differing only by its version prefix does not match', () => {
    expect(mayRestamp('v2:aaa', BEFORE)).toBe(false)
  })
})

describe('duplicate-span detection', () => {
  // content_highlights has a UNIQUE(readBlockId, start, end), so two identical spans in one
  // array cannot both be inserted. The script refuses to apply rather than half-migrating.
  const hasDuplicate = (spans: Span[]) => {
    const seen = new Set<string>()
    return spans.some((s) => {
      const key = `${s.start}:${s.end}`
      if (seen.has(key)) return true
      seen.add(key)
      return false
    })
  }

  it('spots an exact duplicate', () => {
    expect(hasDuplicate([{ start: 0, end: 5 }, { start: 0, end: 5 }])).toBe(true)
  })

  it('does not flag overlapping-but-distinct spans', () => {
    expect(hasDuplicate([{ start: 0, end: 10 }, { start: 5, end: 15 }])).toBe(false)
  })

  it('does not flag spans that share only a start or only an end', () => {
    expect(hasDuplicate([{ start: 0, end: 5 }, { start: 0, end: 6 }])).toBe(false)
    expect(hasDuplicate([{ start: 1, end: 5 }, { start: 2, end: 5 }])).toBe(false)
  })
})
