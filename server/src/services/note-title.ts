/**
 * Note title and preview derivation (notes D11). Pure: the service calls it on every write of `content`,
 * so the list never parses markdown.
 */

const MAX_CODE_POINTS = 120

const LEADING_MARKER = /^(?:#{1,6} |- |\* |\+ |\d+\. |> )/

/**
 * One markdown line, stripped of block markers and inline marks, unescaped and trimmed. The codec writes edge
 * whitespace as `&#32;`/`&#9;` (a typed `&` is always `\&`), so those two are decoded before the trim.
 */
export function stripMarkdownLine(line: string): string {
  let s = line.replace(LEADING_MARKER, '')
  s = s.replace(/\*\*|__|~~|==|<u>|<\/u>/g, '')
  s = s.replace(/(?<!\\)\*([^*]*?)(?<!\\)\*/g, '$1')
  s = s.replace(/(?<!\\)_([^_]*?)(?<!\\)_/g, '$1')
  s = s.replace(/(?<!\\)&#(32|9);/g, (_, code) => (code === '32' ? ' ' : '\t'))
  s = s.replace(/\\(.)/gu, '$1')
  return s.trim()
}

const cut = (s: string) => Array.from(s).slice(0, MAX_CODE_POINTS).join('')

/** title = first non-empty stripped line, preview = the next one; each null when absent. */
export function deriveTitlePreview(content: string): { title: string | null; preview: string | null } {
  const lines: string[] = []
  for (const raw of content.split(/\r?\n/)) {
    const stripped = stripMarkdownLine(raw)
    if (stripped) lines.push(stripped)
    if (lines.length === 2) break
  }
  return {
    title: lines[0] !== undefined ? cut(lines[0]) : null,
    preview: lines[1] !== undefined ? cut(lines[1]) : null,
  }
}
