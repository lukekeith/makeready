/**
 * The one-time export's mapping (activity-viewer 05 s6): an old `LessonActivity` with its read blocks,
 * highlights and source references becomes one or more new-model activities. Pure — no database — and
 * shared by `content-export.ts` and `content-import.ts`. It also holds the production-URL guard both
 * scripts apply before they touch a database.
 */
import { createHash } from 'node:crypto'
import { documentText } from '../src/services/activity-document.js'

export interface OldHighlight {
  orderNumber: number
  start: number
  end: number
  noteMarkdown: string | null
  style: string
}

export interface OldBlock {
  id: string
  orderNumber: number
  title: string | null
  content: string | null
  isLocked: boolean
  contentFormat: string
  sourceReferenceId: string | null
  themeId?: string | null
  backgroundImageUrl: string | null
  backgroundColor: string | null
  backgroundOverlayOpacity: number | null
  fontSize: string | null
  highlights: OldHighlight[]
}

export interface OldSourceRef {
  id: string
  sourceType: string
  passageReference: string | null
  bookNumber: number | null
  chapterStart: number | null
  chapterEnd: number | null
  verseStart: number | null
  verseEnd: number | null
}

export interface OldActivity {
  id: string
  activityType: string
  orderNumber: number
  title: string
  helpTitle?: string | null
  helpDescription?: string | null
  placeholder?: string | null
  referenceTitle?: string | null
  readContent?: string | null
  videoId?: string | null
  youtubeUrl?: string | null
  youtubeVideoId?: string | null
  youtubeStartSeconds?: number | null
  youtubeEndSeconds?: number | null
  themeId?: string | null
  readBlocks: OldBlock[]
  sourceReferences: OldSourceRef[]
}

export interface ConvertedActivity {
  activityKey: string
  kind: 'text' | 'bible' | 'video' | 'youtube' | 'write'
  title: string
  document: Record<string, any>
}

export interface ConvertResult {
  activities: ConvertedActivity[]
  losses: string[]
}

export interface ConvertContext {
  /** The `Media` id for a background image URL; `undefined` leaves the image out (unresolved). */
  mediaIdForUrl?: (url: string) => string | undefined
}

// ---- production guard -------------------------------------------------------------------------------------------

/** Neither script accepts a `DATABASE_URL` that is not local or a lease unless `--confirm-production` is passed. */
export function assertDatabaseAllowed(databaseUrl: string, opts: { confirmProduction?: boolean }): void {
  let host = ''
  try {
    host = new URL(databaseUrl).hostname
  } catch {
    throw new Error('DATABASE_URL is not a valid URL')
  }
  const local = host === 'localhost' || host === '127.0.0.1' || host.startsWith('postgres_vt_')
  if (!local && !opts.confirmProduction) {
    throw new Error(`Refusing database host "${host}": it is not local. Pass --confirm-production to run against it.`)
  }
}

// ---- media ids ---------------------------------------------------------------------------------------------------

/** A stable uuid-shaped id for a `Media` row the import registers, so a re-run finds the same row. */
export function deterministicMediaId(url: string): string {
  const h = createHash('sha1').update(`media:${url}`).digest('hex')
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-5${h.slice(13, 16)}-a${h.slice(17, 20)}-${h.slice(20, 32)}`
}

// ---- layout constants (02 s4, 05 s6, F3) ---------------------------------------------------------------------------

const CENTER_X = 220
const COLUMN_WIDTH = 392
const TOP = 107
const GAP = 24
const LINE_HEIGHT = 1.3
const SIZE_BY_FONT_SCALE: Record<string, number> = { xs: 14, s: 16, m: 18, lg: 22, xl: 26 }
const DEFAULT_SIZE = 18
const DARK_TEXT = '#111111'
const LIGHT_TEXT = '#FFFFFF'

// ---- markdown -> text + marks -----------------------------------------------------------------------------------

interface Mark { start: number; end: number; kind: 'bold' | 'italic' | 'link'; href?: string }
interface Plain { text: string; marks: Mark[] }

const ENTITIES: Record<string, string> = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&nbsp;': ' ' }

function htmlToMarkdown(html: string, losses: string[], label: string): string {
  let dropped = false
  const out = html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|h[1-6]|li)>/gi, '\n')
    .replace(/<\/?(strong|b)>/gi, '**')
    .replace(/<\/?(em|i)>/gi, '*')
    .replace(/<[^>]+>/g, () => { dropped = true; return '' })
    .replace(/&(amp|lt|gt|quot|nbsp|#39);/g, (m) => ENTITIES[m] ?? m)
  if (dropped) losses.push(`${label}: HTML the converter cannot map was dropped`)
  return out
}

const INLINE = /(\*\*|__)(.+?)\1|\*(.+?)\*|(?<!\w)_(.+?)_(?!\w)|\[([^\]]+)\]\(([^)\s]+)\)/

/** Appends `source`'s plain text to `out`, adding marks at offsets relative to the whole text. */
function inline(source: string, base: number, marks: Mark[]): string {
  let rest = source
  let out = ''
  for (;;) {
    const m = INLINE.exec(rest)
    if (!m) return out + rest
    out += rest.slice(0, m.index)
    const start = base + out.length
    if (m[2] !== undefined) {
      out += inline(m[2], start, marks)
      marks.push({ start, end: base + out.length, kind: 'bold' })
    } else if (m[3] !== undefined || m[4] !== undefined) {
      out += inline(m[3] ?? m[4], start, marks)
      marks.push({ start, end: base + out.length, kind: 'italic' })
    } else {
      out += inline(m[5], start, marks)
      marks.push({ start, end: base + out.length, kind: 'link', href: m[6] })
    }
    rest = rest.slice(m.index + m[0].length)
  }
}

function markdownToPlain(markdown: string, base: number): Plain {
  const marks: Mark[] = []
  let text = ''
  const lines = markdown.replace(/\r\n?/g, '\n').split('\n')
  lines.forEach((raw, i) => {
    let line = raw.replace(/^\s*>\s?/, '')
    const heading = /^#{1,6}\s+(.*)$/.exec(line)
    if (heading) line = heading[1]
    line = line.replace(/^\s*[-*+]\s+/, '• ')
    const lineStart = base + text.length
    text += inline(line, lineStart, marks)
    if (heading && base + text.length > lineStart) marks.push({ start: lineStart, end: base + text.length, kind: 'bold' })
    if (i < lines.length - 1) text += '\n'
  })
  return { text, marks }
}

/** Converts a block's content to text with marks starting at offset `base`, recording losses. */
function blockToPlain(block: OldBlock, base: number, losses: string[]): Plain {
  let source = block.content ?? ''
  if (block.contentFormat === 'html' || /<\/?[a-z][^>]*>/i.test(source)) {
    source = htmlToMarkdown(source, losses, `block ${block.id}`)
  }
  return markdownToPlain(source, base)
}

// ---- text objects and documents ----------------------------------------------------------------------------------

interface ObjectSpec {
  id: string
  role: 'heading' | 'body' | 'scripture' | 'citation'
  text: string
  size: number
  color: string
  weight?: 400 | 500 | 700
  font?: 'display' | 'sans' | 'serif' | 'mono'
  marks?: Mark[]
  highlights?: { id: string; start: number; end: number; noteMarkdown: string | null }[]
}

function estimateHeight(text: string, size: number): number {
  const perLine = Math.max(1, Math.floor(COLUMN_WIDTH / (size * 0.55)))
  const lines = text.split('\n').reduce((n, p) => n + Math.max(1, Math.ceil(p.length / perLine)), 0)
  return lines * size * LINE_HEIGHT
}

/** One column from the top, in order: each object's centre y follows the estimated height of those above. */
function layout(specs: ObjectSpec[]): any[] {
  let cursor = TOP
  return specs.map((s) => {
    const height = estimateHeight(s.text, s.size)
    const y = Math.round(cursor + height / 2)
    cursor += height + GAP
    const object: Record<string, any> = {
      id: s.id, role: s.role, text: s.text, font: s.font ?? 'sans', weight: s.weight ?? 400, size: s.size,
      lineHeight: LINE_HEIGHT, color: s.color, alignment: 'left',
      transform: { x: CENTER_X, y, width: COLUMN_WIDTH, scale: 1, rotation: 0 },
    }
    if (s.marks?.length) object.marks = s.marks.map((m) => ({ ...m }))
    if (s.highlights?.length) object.highlights = s.highlights
    return object
  })
}

interface Paint { background: Record<string, any>; textColor: string }

function normalizeHex(value: string | null | undefined): string | null {
  if (!value) return null
  const v = value.trim()
  if (/^#[0-9a-f]{6}$/i.test(v)) return v.toUpperCase()
  if (/^#[0-9a-f]{3}$/i.test(v)) return `#${v[1]}${v[1]}${v[2]}${v[2]}${v[3]}${v[3]}`.toUpperCase()
  return null
}

function isLight(hex: string): boolean {
  const n = parseInt(hex.slice(1), 16)
  const lum = 0.2126 * (n >> 16) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255)
  return lum > 150
}

function paintFor(block: OldBlock | null, ctx: ConvertContext, losses: string[], label: string): Paint {
  const color = normalizeHex(block?.backgroundColor)
  if (block?.backgroundColor && !color) losses.push(`${label}: background colour "${block.backgroundColor}" is not a hex value; white used`)
  if (block?.backgroundImageUrl) {
    const mediaId = (ctx.mediaIdForUrl ?? deterministicMediaId)(block.backgroundImageUrl)
    if (mediaId) {
      return {
        background: {
          color: color ?? '#000000',
          image: { mediaId, focal: { x: 0.5, y: 0.5 } },
          wash: { color: '#000000', opacity: block.backgroundOverlayOpacity ?? 0.4 },
        },
        textColor: LIGHT_TEXT,
      }
    }
    losses.push(`${label}: background image ${block.backgroundImageUrl} has no media row and was left out`)
  }
  const bg = color ?? '#FFFFFF'
  return { background: { color: bg }, textColor: isLight(bg) ? DARK_TEXT : LIGHT_TEXT }
}

function envelope(kind: ConvertedActivity['kind'], content: Record<string, any>, background: Record<string, any>, title: string, body: string) {
  return {
    schemaVersion: 1, kind, background, content, actions: [],
    chrome: { topAction: 'none' },
    fallback: { title, body: body.trim().slice(0, 280) || title },
  }
}

const sizeFor = (block: OldBlock | null) => SIZE_BY_FONT_SCALE[block?.fontSize ?? ''] ?? DEFAULT_SIZE

function canvasContent(objects: any[]) {
  return { type: 'canvas', verticalAnchor: 'top', objects }
}

// ---- per-kind builders -------------------------------------------------------------------------------------------

function youtubeId(old: OldActivity): string | null {
  if (old.youtubeUrl) {
    const m = /(?:v=|youtu\.be\/|embed\/|shorts\/)([\w-]{6,})/.exec(old.youtubeUrl)
    if (m) return m[1]
  }
  return old.youtubeVideoId ?? null
}

function textActivity(key: string, title: string, objects: ObjectSpec[], paint: Paint): ConvertedActivity {
  const laidOut = layout(objects)
  const document = envelope('text', canvasContent(laidOut), paint.background, title, '')
  document.fallback.body = documentText(document).trim().slice(0, 280) || title
  return { activityKey: key, kind: 'text', title, document }
}

function writeActivity(old: OldActivity): ConvertedActivity {
  const prompt = [old.title, old.helpDescription].filter((s): s is string => !!s && s.trim() !== '').join('\n')
  const [object] = layout([{ id: 'prompt', role: 'heading', text: prompt, size: 28, color: DARK_TEXT, weight: 700 }])
  const content = { type: 'write', prompt: object, placeholder: old.placeholder ?? null }
  return {
    activityKey: old.id, kind: 'write', title: old.title,
    document: envelope('write', content, { color: '#FFFFFF' }, old.title, prompt),
  }
}

interface Passage { bookNumber: number; chapterStart: number; verseStart: number; chapterEnd: number; verseEnd: number }

function passageOf(ref: OldSourceRef | undefined, losses: string[], label: string): Passage | null {
  if (!ref || ref.sourceType !== 'SCRIPTURE') return null
  const { bookNumber, chapterStart, verseStart } = ref
  if (bookNumber == null || chapterStart == null || verseStart == null) {
    losses.push(`${label}: source reference ${ref.id} lacks book, chapter or verse and was dropped`)
    return null
  }
  return { bookNumber, chapterStart, verseStart, chapterEnd: ref.chapterEnd ?? chapterStart, verseEnd: ref.verseEnd ?? verseStart }
}

function bibleActivity(
  key: string, title: string, blocks: OldBlock[], refs: OldSourceRef[], ctx: ConvertContext, losses: string[],
): ConvertedActivity {
  const paint = paintFor(blocks.find((b) => b.backgroundImageUrl || b.backgroundColor) ?? null, ctx, losses, `block ${blocks[0]?.id}`)
  const specs: ObjectSpec[] = []
  const passages: Passage[] = []
  blocks.forEach((block, n) => {
    const label = `block ${block.id}`
    let text = block.content ?? ''
    if (block.contentFormat === 'html' || /<\/?[a-z][^>]*>/i.test(text)) {
      text = htmlToMarkdown(text, losses, label)
      if (block.highlights.length) losses.push(`${label}: HTML stripped, so highlight offsets may have shifted`)
    }
    const marks: Mark[] = []
    const highlights: NonNullable<ObjectSpec['highlights']> = []
    for (const h of block.highlights) {
      if (!(h.start >= 0 && h.start < h.end && h.end <= text.length)) {
        losses.push(`${label}: highlight ${h.start}-${h.end} is outside the text and was dropped`)
        continue
      }
      if (h.style === 'bold') marks.push({ start: h.start, end: h.end, kind: 'bold' })
      else highlights.push({ id: `h${highlights.length + 1}`, start: h.start, end: h.end, noteMarkdown: h.noteMarkdown?.trim() ? h.noteMarkdown : null })
    }
    specs.push({
      id: `o${n * 2 + 1}`, role: 'scripture', text, size: sizeFor(block), color: paint.textColor, font: 'serif', marks, highlights,
    })
    const ref = refs.find((r) => r.id === block.sourceReferenceId)
    const citation = block.title ?? ref?.passageReference
    if (citation) specs.push({ id: `o${n * 2 + 2}`, role: 'citation', text: citation, size: 14, color: paint.textColor, weight: 700 })
    const passage = passageOf(ref, losses, label)
    if (passage) passages.push(passage)
  })
  if (!blocks.length) {
    for (const ref of refs) {
      const passage = passageOf(ref, losses, `activity ${key}`)
      if (passage) passages.push(passage)
    }
  }
  const unique = passages.filter((p, i) => passages.findIndex((q) => JSON.stringify(q) === JSON.stringify(p)) === i)
  const content: Record<string, any> = canvasContent(layout(specs))
  if (unique.length) content.passages = unique
  const document = envelope('bible', content, paint.background, title, '')
  document.fallback.body = documentText(document).trim().slice(0, 280) || title
  return { activityKey: key, kind: 'bible', title, document }
}

// ---- READ and EXEGESIS -------------------------------------------------------------------------------------------

type Unit =
  | { type: 'text'; blocks: OldBlock[] }
  | { type: 'styled'; block: OldBlock }
  | { type: 'bible'; blocks: OldBlock[] }

const hasBackground = (b: OldBlock) => !!(b.backgroundImageUrl || b.backgroundColor)
const isScripture = (b: OldBlock) => b.isLocked || !!b.sourceReferenceId

function unitsOf(old: OldActivity): Unit[] {
  const blocks = [...old.readBlocks].sort((a, b) => a.orderNumber - b.orderNumber)
  if (old.activityType === 'EXEGESIS') return [{ type: 'bible', blocks }]
  const units: Unit[] = []
  for (const block of blocks) {
    if (isScripture(block)) units.push({ type: 'bible', blocks: [block] })
    else if (!(block.content ?? '').trim()) continue
    else if (hasBackground(block)) units.push({ type: 'styled', block })
    else {
      const last = units[units.length - 1]
      if (last?.type === 'text') last.blocks.push(block)
      else units.push({ type: 'text', blocks: [block] })
    }
  }
  return units
}

function textFromBlocks(blocks: OldBlock[], color: string, losses: string[]): ObjectSpec {
  let text = ''
  const marks: Mark[] = []
  blocks.forEach((block, i) => {
    if (block.highlights.length) losses.push(`block ${block.id}: highlights on an unlocked block were dropped`)
    if (i > 0) text += '\n\n'
    const plain = blockToPlain(block, text.length, losses)
    text += plain.text
    marks.push(...plain.marks)
  })
  const trimmed = text.replace(/\s+$/, '')
  const kept = marks.filter((m) => m.start < trimmed.length).map((m) => ({ ...m, end: Math.min(m.end, trimmed.length) }))
  const whole = kept.findIndex((m) => m.kind === 'bold' && m.start === 0 && m.end === trimmed.length)
  let weight: 400 | 700 = 400
  if (whole >= 0) {
    weight = 700
    kept.splice(whole, 1)
  }
  return { id: 'o1', role: 'body', text: trimmed, size: sizeFor(blocks[0]), color, weight, marks: kept }
}

function convertRead(old: OldActivity, ctx: ConvertContext, losses: string[]): ConvertedActivity[] {
  const readContent = (old.readContent ?? '').trim()
  const legacy: OldBlock | null = old.readBlocks.length || !readContent ? null : {
    id: `${old.id}:content`, orderNumber: 1, title: null, content: readContent, isLocked: false, contentFormat: 'markdown',
    sourceReferenceId: null, backgroundImageUrl: null, backgroundColor: null, backgroundOverlayOpacity: null, fontSize: null, highlights: [],
  }
  const source: OldActivity = legacy ? { ...old, readBlocks: [legacy] } : old
  const units = unitsOf(source)

  if (!units.length) {
    const reference = old.referenceTitle?.trim()
    if (!reference) losses.push(`activity ${old.id}: READ activity has no content`)
    const paint = paintFor(null, ctx, losses, `activity ${old.id}`)
    const objects: ObjectSpec[] = reference ? [{ id: 'o1', role: 'body', text: reference, size: DEFAULT_SIZE, color: paint.textColor }] : []
    return [textActivity(old.id, old.title, objects, paint)]
  }

  return units.map((unit, i) => {
    const key = i === 0 ? old.id : `${old.id}:${i}`
    if (unit.type === 'bible') {
      const title = unit.blocks.length === 1 && unit.blocks[0].title ? unit.blocks[0].title : old.title
      return bibleActivity(key, i === 0 ? old.title : title, unit.blocks, old.sourceReferences, ctx, losses)
    }
    const blocks = unit.type === 'text' ? unit.blocks : [unit.block]
    const paint = paintFor(unit.type === 'styled' ? unit.block : null, ctx, losses, `block ${blocks[0].id}`)
    return textActivity(key, i === 0 ? old.title : `${old.title} (${i + 1})`, [textFromBlocks(blocks, paint.textColor, losses)], paint)
  })
}

// ---- entry point ---------------------------------------------------------------------------------------------------

/** The 05 s6 mapping. The first activity keeps `old.id` as its key; a split block's extras are `<oldId>:<n>`. */
export function convertActivity(old: OldActivity, ctx: ConvertContext = {}): ConvertResult {
  const losses: string[] = []
  const themes = new Set<string>()
  if (old.themeId) themes.add(old.themeId)
  for (const b of old.readBlocks) if (b.themeId) themes.add(b.themeId)
  for (const id of themes) losses.push(`activity ${old.id}: theme ${id} dropped; any animation imports static`)

  let activities: ConvertedActivity[]
  switch (old.activityType) {
    case 'VIDEO':
      if (old.videoId) {
        const content = { type: 'video', videoId: old.videoId, posterMediaId: null }
        activities = [{ activityKey: old.id, kind: 'video', title: old.title, document: envelope('video', content, { color: '#000000' }, old.title, old.title) }]
      } else {
        losses.push(`activity ${old.id}: VIDEO activity names no video; imported as an empty text page`)
        activities = [textActivity(old.id, old.title, [], paintFor(null, ctx, losses, `activity ${old.id}`))]
      }
      break
    case 'YOUTUBE': {
      const id = youtubeId(old)
      if (id) {
        const content = { type: 'youtube', youtubeVideoId: id, startSeconds: old.youtubeStartSeconds ?? null, endSeconds: old.youtubeEndSeconds ?? null }
        activities = [{ activityKey: old.id, kind: 'youtube', title: old.title, document: envelope('youtube', content, { color: '#000000' }, old.title, old.title) }]
      } else {
        losses.push(`activity ${old.id}: YOUTUBE activity names no video; imported as an empty text page`)
        activities = [textActivity(old.id, old.title, [], paintFor(null, ctx, losses, `activity ${old.id}`))]
      }
      break
    }
    case 'USER_INPUT':
      activities = [writeActivity(old)]
      break
    case 'READ':
    case 'EXEGESIS':
      activities = convertRead(old, ctx, losses)
      break
    default:
      losses.push(`activity ${old.id}: unknown type ${old.activityType}; imported as an empty text page`)
      activities = [textActivity(old.id, old.title, [], paintFor(null, ctx, losses, `activity ${old.id}`))]
  }
  if (activities.length > 1) {
    losses.push(`activity ${old.id}: split into ${activities.length} activities (a document has one background)`)
  }
  return { activities, losses }
}
