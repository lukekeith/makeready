/**
 * themes/base/parseMarkdown.ts
 *
 * Single canonical content parser for the theme system.
 *
 * Every consumer (ActivityPreviewPlayer, ThemePlayer, slides-island, future
 * web previewers) calls this so themes only ever see consistent `Token[]`
 * structure and never have to think about markdown vs HTML, list numbering,
 * blockquote shape, or whitespace cleanup.
 *
 * Input may be:
 *   - Plain markdown ("# Title\n\nBody")
 *   - Inline HTML (e.g. content from the rich-text editor or scripture blocks)
 *
 * HTML inputs are stripped to plain text first, then re-lexed as markdown so
 * downstream themes get a uniform token shape.
 */

import { marked } from 'marked'
import type { Token, ReadBlockSelection } from './types'

// ─── Selection sentinels ─────────────────────────────────────────────────────
//
// To render `selections` (bold / highlight spans stored as { start, end, style }
// offsets over the raw content), we splice private-use unicode markers into
// the content string before lexing, then convert markers back to <span> tags
// in each token's html post-parse. Private-use chars survive marked's lexer
// and parseInline as plain text without HTML-escaping or being treated as
// markdown syntax.
//
//   \uE000  open marker prefix (next char encodes style)
//   \uE001  close marker
//
// Style → marker char map. Unknown style names fall back to '?' which still
// emits a `ThemePlayer__selection--{style}` class in the html so editing the
// .scss is enough to introduce a new style; the rendering pipeline doesn't
// need to know about it.

const SEL_OPEN = '\uE000'
const SEL_CLOSE = '\uE001'

/** Style name → single-char marker. Reserved chars must not collide with
 *  literal characters that could appear naturally inside content; alphabetic
 *  letters are fine because the lookup table is scoped to known style names. */
const STYLE_TO_MARKER: Record<string, string> = {
  bold: 'b',
  highlight: 'h',
}
const MARKER_TO_STYLE: Record<string, string> = Object.fromEntries(
  Object.entries(STYLE_TO_MARKER).map(([k, v]) => [v, k]),
)

// ─── HTML → plain text ───────────────────────────────────────────────────────

/** Strip HTML tags & decode the small set of entities our content uses. */
export function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<sup>(\d+)<\/sup>/gi, '$1 ')   // <sup>verse-number</sup>
    .replace(/<[^>]+>/g, '')                 // strip all remaining tags
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

// ─── Selection injection ─────────────────────────────────────────────────────

/**
 * Splice sentinel markers into `content` at each selection's start/end.
 * Returns the marked-up content string ready to feed into the lexer.
 *
 * Selections are inserted in start-descending order so earlier insertions
 * never shift later offsets. Out-of-range or empty selections are skipped.
 * Unknown style names fall back to a single-char hash so the post-parse
 * pass can still emit a `ThemePlayer__selection--{style}` class for them.
 */
function insertSelectionMarkers(
  content: string,
  selections: ReadBlockSelection[],
): string {
  if (selections.length === 0) return content
  const sorted = [...selections]
    .filter(s => s.start >= 0 && s.end > s.start && s.end <= content.length)
    .sort((a, b) => b.start - a.start)
  let out = content
  for (const sel of sorted) {
    const marker = STYLE_TO_MARKER[sel.style] ?? (sel.style.charAt(0).toLowerCase() || '?')
    // Cache unknown styles so the close-side reverse lookup still resolves.
    if (!MARKER_TO_STYLE[marker]) MARKER_TO_STYLE[marker] = sel.style
    out =
      out.slice(0, sel.start) +
      SEL_OPEN + marker +
      out.slice(sel.start, sel.end) +
      SEL_CLOSE +
      out.slice(sel.end)
  }
  return out
}

/**
 * Walk each token's html, replacing sentinel markers with `<span>` tags.
 * State carries across tokens so a selection that begins in one block and
 * ends in another renders as wrapping spans on every token in between
 * (closed at end-of-token, reopened at start-of-next).
 *
 * Mutates tokens in place.
 */
function applySelectionMarkers(tokens: Token[]): void {
  let openStyle: string | null = null

  for (const token of tokens) {
    const html = token.html
    let result = ''

    if (openStyle) {
      result += `<span class="ThemePlayer__selection ThemePlayer__selection--${openStyle}">`
    }

    let i = 0
    while (i < html.length) {
      const ch = html[i]
      if (ch === SEL_OPEN) {
        const markerCh = html[i + 1] ?? ''
        const style = MARKER_TO_STYLE[markerCh] ?? 'bold'
        result += `<span class="ThemePlayer__selection ThemePlayer__selection--${style}">`
        openStyle = style
        i += 2
      } else if (ch === SEL_CLOSE) {
        result += '</span>'
        openStyle = null
        i += 1
      } else {
        result += ch
        i += 1
      }
    }

    if (openStyle) {
      result += '</span>'
    }

    // Strip any sentinel chars that may have leaked into the plain `text`
    // field (e.g. for typewriter / word-by-word renderers that read .text).
    token.html = result
    token.text = stripSentinels(token.text)
  }
}

const SENTINEL_RE = new RegExp(`[${SEL_OPEN}${SEL_CLOSE}]`, 'g')
function stripSentinels(s: string): string {
  // Drop the open marker + its style char, plus any close markers.
  return s
    .replace(new RegExp(`${SEL_OPEN}.`, 'g'), '')
    .replace(SENTINEL_RE, '')
}

// ─── Public API ──────────────────────────────────────────────────────────────

/** Parse a content string (markdown or HTML) into the canonical Token[]. */
export function parseMarkdown(
  input: string,
  selections: ReadBlockSelection[] = [],
): Token[] {
  const result: Token[] = []
  if (!input || !input.trim()) return result

  // If the content starts with an HTML tag, normalise to plain text first.
  // Selection offsets target the raw stored content; for HTML inputs we
  // can't reliably remap offsets after stripping tags, so selections are
  // ignored when the input is HTML. This matches the practical reality that
  // new read blocks default to markdown content (server: contentFormat).
  const isHtml = input.trimStart().startsWith('<')
  const normalised = isHtml ? stripHtml(input) : input
  if (!normalised.trim()) return result

  const withMarkers = (!isHtml && selections.length > 0)
    ? insertSelectionMarkers(normalised, selections)
    : normalised

  const lexed = marked.lexer(withMarkers)
  let index = 0

  for (const lt of lexed) {
    switch (lt.type) {
      case 'heading': {
        const h = lt as any
        result.push({
          type: `h${h.depth}` as Token['type'],
          text: h.text,
          html: marked.parseInline(h.text) as string,
          index: index++,
        })
        break
      }
      case 'paragraph': {
        const p = lt as any
        result.push({
          type: 'p',
          text: p.text,
          html: marked.parseInline(p.text) as string,
          index: index++,
        })
        break
      }
      case 'list': {
        const list = lt as any
        for (let i = 0; i < list.items.length; i++) {
          const item = list.items[i]

          let listNumber: number | undefined
          if (list.ordered) {
            const match = item.raw?.match(/^(\d+)[.)]\s/)
            listNumber = match ? parseInt(match[1], 10) : (list.start ?? 1) + i
          }

          // Trim whitespace so list lines never start/end with spaces.
          const liText = (item.text ?? '').trim()
          if (!liText) continue

          result.push({
            type: 'li',
            text: liText,
            html: marked.parseInline(liText) as string,
            index: index++,
            ...(listNumber != null ? { listNumber } : {}),
          })
        }
        break
      }
      case 'blockquote': {
        const bq = lt as any
        const innerText = bq.tokens
          ? bq.tokens.map((t: any) => t.text ?? '').join(' ')
          : (bq.text ?? '')
        result.push({
          type: 'blockquote',
          text: innerText,
          html: marked.parseInline(innerText) as string,
          index: index++,
        })
        break
      }
      case 'space':
        // Ignore — pure whitespace separators between blocks.
        break
      default: {
        // Unknown / unsupported token type — fall back to plain paragraph
        // so nothing is silently dropped.
        const any = lt as any
        if (any.text) {
          result.push({
            type: 'p',
            text: any.text,
            html: any.text,
            index: index++,
          })
        }
      }
    }
  }

  // Convert sentinel markers in each token's html into <span> wrappers.
  // No-op when no markers were inserted; safe to always run.
  if (!isHtml && selections.length > 0) {
    applySelectionMarkers(result)
  }

  return result
}
