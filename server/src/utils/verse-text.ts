/**
 * Canonical verse text (D9). Offsets, stored scripture and highlights all
 * index into exactly this string; clients never re-normalize.
 */
export function normalizeVerseText(text: string): string {
  return text
    .replace(/¶/g, '')
    .replace(/\\[rn]|[\r\n]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}
