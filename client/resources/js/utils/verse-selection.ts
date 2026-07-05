// Verse-selection logic — web port of iphone/MakeReady/Utilities/
// VerseSelectionLogic.swift (parseVersePositions + the Bible-reader tap
// mechanics shared by the READ-editor highlighter and the passage picker).
//
// Offsets are UTF-16 code-unit indices into the normalized plain text
// (normalizeScriptureMarkdown output) — the same basis as NSString ranges on
// iOS, so ReadBlockSelection {start,end} round-trips between platforms.

export interface CharRange {
  start: number
  end: number // exclusive
}

export interface VerseRange {
  verse: number
  range: CharRange
}

export interface ParsedVerses {
  verseRanges: VerseRange[]
  /** The "N. " marker runs (renderers hide these / hang them in the gutter). */
  numberRanges: VerseRange[]
}

/**
 * Parse verse positions from plain text with inline verse numbers like
 * "1. In the beginning...\n2. And the earth...". Mirrors iOS: the first
 * marker starts the chain, then only consecutive numbers extend it.
 */
export function parseVersePositions(text: string): ParsedVerses {
  if (!text) return { verseRanges: [], numberRanges: [] }

  const regex = /(?:^|(?<=\n))(\d+)\.?\s/g
  const positions: Array<{ number: number; matchStart: number; matchEnd: number }> = []
  let expectedNext = 0
  let match: RegExpExecArray | null

  while ((match = regex.exec(text)) != null) {
    const num = Number.parseInt(match[1], 10)
    if (!Number.isFinite(num)) continue
    if (expectedNext === 0 || num === expectedNext) {
      positions.push({ number: num, matchStart: match.index, matchEnd: match.index + match[0].length })
      expectedNext = num + 1
    }
  }

  const verseRanges: VerseRange[] = []
  const numberRanges: VerseRange[] = []
  for (let i = 0; i < positions.length; i += 1) {
    const pos = positions[i]
    const end = i + 1 < positions.length ? positions[i + 1].matchStart : text.length
    verseRanges.push({ verse: pos.number, range: { start: pos.matchStart, end } })
    numberRanges.push({ verse: pos.number, range: { start: pos.matchStart, end: pos.matchEnd } })
  }
  return { verseRanges, numberRanges }
}

/** Sorted verse numbers overlapping [start, end). */
export function versesOverlapping(range: CharRange, verseRanges: VerseRange[]): number[] {
  if (range.end <= range.start) return []
  return verseRanges
    .filter((entry) => entry.range.start < range.end && entry.range.end > range.start)
    .map((entry) => entry.verse)
    .sort((a, b) => a - b)
}

/** Character range spanning verses `from`..`to` inclusive. */
export function rangeForVerses(from: number, to: number, verseRanges: VerseRange[]): CharRange | null {
  const startEntry = verseRanges.find((entry) => entry.verse === from)
  const endEntry = verseRanges.find((entry) => entry.verse === to)
  if (!startEntry || !endEntry) return null
  return { start: startEntry.range.start, end: endEntry.range.end }
}

/**
 * The Bible-reader verse tap (iOS applyVerseTap):
 * - no selection → select the tapped verse
 * - tap outside the selection → extend the contiguous range to include it
 * - tap inside the selection → clear, CONFIRMING the cleared range
 */
export function applyVerseTap(
  tappedVerse: number,
  current: CharRange | null,
  verseRanges: VerseRange[],
): { next: CharRange | null; confirmed: CharRange | null } {
  const overlapping = current ? versesOverlapping(current, verseRanges) : []
  const currentMin = overlapping[0]
  const currentMax = overlapping[overlapping.length - 1]

  if (currentMin != null && currentMax != null && tappedVerse >= currentMin && tappedVerse <= currentMax) {
    const cleared = rangeForVerses(currentMin, currentMax, verseRanges)
    return { next: null, confirmed: cleared && cleared.end > cleared.start ? cleared : null }
  }

  const newMin = Math.min(currentMin ?? tappedVerse, tappedVerse)
  const newMax = Math.max(currentMax ?? tappedVerse, tappedVerse)
  return { next: rangeForVerses(newMin, newMax, verseRanges), confirmed: null }
}
