export interface ScriptureVerseInput {
  verse?: number | null
  number?: number | null
  text: string | null
}

interface VerseMarkerCandidate {
  number: number
  markerStart: number
  markerEnd: number
  hasExplicitSeparator: boolean
}

export interface NormalizedScriptureVerse {
  number: number
  text: string
}

const NAMED_ENTITIES: Record<string, string> = {
  '&nbsp;': ' ',
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
}

const SUPERSCRIPT_DIGITS: Record<string, string> = {
  '⁰': '0',
  '¹': '1',
  '²': '2',
  '³': '3',
  '⁴': '4',
  '⁵': '5',
  '⁶': '6',
  '⁷': '7',
  '⁸': '8',
  '⁹': '9',
}

/** Canonical scripture content formatter shared by member READ/EXEGESIS rendering. */
export function normalizeScriptureMarkdown(input: string | null | undefined): string | null {
  if (input == null) return null
  const verses = parseScriptureVerses(input)
  if (verses.length === 0) return collapseWhitespace(markdownAndHtmlToText(input))
  return verses.map((verse) => `${verse.number}. ${verse.text}`).join('\n')
}

export function normalizeScriptureVerses(verses: ScriptureVerseInput[]): string {
  return verses
    .map((verse) => {
      const number = verse.verse ?? verse.number
      const text = collapseWhitespace(decodeEntities(verse.text ?? ''))
      if (number == null || !text) return null
      return `${number}. ${text}`
    })
    .filter((line): line is string => line != null)
    .join('\n')
}

export function isStableNumberedScriptureMarkdown(input: string | null | undefined): boolean {
  if (!input?.trim()) return false
  return normalizeScriptureMarkdown(input) === input.trim()
}

export function parseScriptureVerses(input: string): NormalizedScriptureVerse[] {
  const text = markdownAndHtmlToText(input)
  const candidates = verseMarkerCandidates(text)
  if (candidates.length === 0) return []

  const verses: NormalizedScriptureVerse[] = []
  for (let index = 0; index < candidates.length; index += 1) {
    const candidate = candidates[index]
    const next = candidates[index + 1]
    const cleaned = collapseWhitespace(text.slice(candidate.markerEnd, next ? next.markerStart : text.length))
    if (!cleaned) continue
    verses.push({ number: candidate.number, text: cleaned })
  }
  return verses
}

export function markdownAndHtmlToText(input: string): string {
  let text = input
    .replace(/\\r\\n/g, '\n')
    .replace(/\\n/g, '\n')
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')

  text = text
    .replace(/<sup[^>]*>\s*(\d{1,3})\s*<\/sup>/gi, '\n$1. ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|li|tr|h[1-6])>/gi, '\n')
    .replace(/<[^>]+>/g, '')

  text = decodeEntities(text)
  text = normalizeSuperscriptVerseMarkers(text)

  return text
    .replace(/^\s{0,3}#{1,6}\s+/gm, '')
    .replace(/^\s{0,3}>\s?/gm, '')
    .replace(/^\s*[-*+]\s+/gm, '')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/__([^_]+)__/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/_([^_]+)_/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .trim()
}

export function decodeEntities(input: string): string {
  let text = input
  for (const [entity, value] of Object.entries(NAMED_ENTITIES)) text = text.split(entity).join(value)
  text = text.replace(/&#(\d+);/g, (_match, raw: string) => {
    const codePoint = Number.parseInt(raw, 10)
    return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : _match
  })
  text = text.replace(/&#x([0-9a-fA-F]+);/g, (_match, raw: string) => {
    const codePoint = Number.parseInt(raw, 16)
    return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : _match
  })
  return text
}

function normalizeSuperscriptVerseMarkers(input: string): string {
  return input.replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹]+/g, (match, offset: number, source: string) => {
    const previous = offset === 0 ? '\n' : source[offset - 1]
    if (offset !== 0 && previous !== '\n' && !/\s/.test(previous)) return match
    const digits = [...match].map((digit) => SUPERSCRIPT_DIGITS[digit] ?? digit).join('')
    return `${offset === 0 || previous === '\n' ? '' : '\n'}${digits} `
  })
}

function verseMarkerCandidates(text: string): VerseMarkerCandidate[] {
  const rawCandidates: VerseMarkerCandidate[] = []
  const regex = /(?:^|\n)\s*(\d{1,3})([.)]?)\s+/g
  let match: RegExpExecArray | null

  while ((match = regex.exec(text)) != null) {
    const rawNumber = match[1]
    const number = Number.parseInt(rawNumber, 10)
    if (!Number.isFinite(number)) continue
    const markerStart = match.index + match[0].indexOf(rawNumber)
    rawCandidates.push({
      number,
      markerStart,
      markerEnd: match.index + match[0].length,
      hasExplicitSeparator: match[2].length > 0,
    })
  }

  let best: VerseMarkerCandidate[] = []
  let bestSeparatorCount = -1
  for (let startIndex = 0; startIndex < rawCandidates.length; startIndex += 1) {
    const chain = [rawCandidates[startIndex]]
    let expectedNext = rawCandidates[startIndex].number + 1
    for (const candidate of rawCandidates.slice(startIndex + 1)) {
      if (candidate.number !== expectedNext) continue
      chain.push(candidate)
      expectedNext += 1
    }
    const separatorCount = chain.filter((candidate) => candidate.hasExplicitSeparator).length
    if (chain.length > best.length || (chain.length === best.length && separatorCount > bestSeparatorCount)) {
      best = chain
      bestSeparatorCount = separatorCount
    }
  }
  return best
}

function collapseWhitespace(input: string): string {
  return input
    .replace(/\\n/g, ' ')
    .replace(/\\r/g, ' ')
    .replace(/[\n\r\t\u00A0]/g, ' ')
    .replace(/¶/g, '')
    .replace(/ {2,}/g, ' ')
    .trim()
}
