/**
 * Bible Content Parser
 *
 * Parses API.Bible chapter content (text format) into individual verse objects.
 * API.Bible returns chapter content as a single text blob with [N] verse markers.
 *
 * Example input:
 *   "The New Birth\n     [1] Now there was a man...  [2] this man came..."
 *
 * Example output:
 *   [
 *     { verse: 1, text: "Now there was a man..." },
 *     { verse: 2, text: "this man came..." },
 *   ]
 */

export interface ParsedVerse {
  verse: number
  text: string
}

/**
 * Parse chapter content text into individual verse objects.
 *
 * Handles:
 * - [N] verse markers (e.g., [1], [16], [150])
 * - Section headings (text before first marker or between markers without [N])
 * - Multi-line verses
 * - Leading/trailing whitespace cleanup
 */
export function parseChapterContent(content: string): ParsedVerse[] {
  if (!content || typeof content !== 'string') return []

  const verses: ParsedVerse[] = []

  // Split on verse markers [N], keeping the marker as a delimiter
  // This regex captures the verse number from [N] markers
  const segments = content.split(/\[(\d+)\]/)

  // segments alternates between:
  //   [0] text before first marker (section heading, discard)
  //   [1] verse number "1"
  //   [2] verse text for verse 1
  //   [3] verse number "2"
  //   [4] verse text for verse 2
  //   etc.

  for (let i = 1; i < segments.length; i += 2) {
    const verseNumber = parseInt(segments[i], 10)
    const rawText = segments[i + 1] || ''

    // Clean the verse text
    const text = cleanVerseText(rawText)

    if (!isNaN(verseNumber) && text) {
      verses.push({ verse: verseNumber, text })
    }
  }

  return verses
}

/**
 * Clean up verse text from API.Bible formatting
 */
function cleanVerseText(raw: string): string {
  let text = raw

  // Remove section headings that appear within verse text
  // These are typically on their own line(s) at the start
  // We keep them since they're part of the reading experience

  // Collapse multiple whitespace/newlines into single space
  text = text.replace(/\s+/g, ' ')

  // Trim leading/trailing whitespace
  text = text.trim()

  return text
}

/**
 * Parse individual verse content text (single verse from API.Bible).
 * Simpler than chapter parsing — just clean the text.
 */
export function parseVerseContent(content: string): string {
  if (!content || typeof content !== 'string') return ''
  return content.replace(/\s+/g, ' ').trim()
}

/**
 * Parse passage content into verse objects.
 * Passage content uses the same [N] marker format as chapters.
 */
export function parsePassageContent(content: string): ParsedVerse[] {
  return parseChapterContent(content)
}
