/**
 * Activity documents the fixtures write (text-activity 02-content-schema §2–§8). Every builder returns an
 * envelope `parseActivityDocument` accepts for its kind; the one deliberate exception, an unknown kind, is
 * written by the player fixture directly (D11's fallback row).
 */

export const REFERENCE_WIDTH = 440

interface TextObjectInput {
  id: string
  text: string
  role?: 'eyebrow' | 'heading' | 'body' | 'scripture' | 'citation' | 'prayer'
  font?: 'display' | 'sans' | 'serif' | 'mono'
  weight?: 400 | 500 | 700
  size?: number
  color?: string
  alignment?: 'left' | 'center' | 'right'
  /** Object center, in width units (02 §4). */
  x?: number
  y?: number
  width?: number
}

export function textObject(o: TextObjectInput) {
  return {
    id: o.id,
    role: o.role ?? 'body',
    text: o.text,
    font: o.font ?? 'sans',
    weight: o.weight ?? 400,
    size: o.size ?? 20,
    lineHeight: 1.3,
    color: o.color ?? '#FFFFFF',
    alignment: o.alignment ?? 'left',
    transform: { x: o.x ?? 220, y: o.y ?? 478, width: o.width ?? 392, scale: 1, rotation: 0 },
  }
}

interface Envelope {
  /** Background color; always present (02 §5). */
  color?: string
  imageMediaId?: string
  actions?: unknown[]
  fallbackTitle?: string
}

function envelope(kind: string, content: unknown, e: Envelope = {}) {
  return {
    schemaVersion: 1,
    kind,
    background: {
      color: e.color ?? '#0E4A4D',
      ...(e.imageMediaId ? { image: { mediaId: e.imageMediaId, focal: { x: 0.5, y: 0.4 } } } : {}),
    },
    content,
    ...(e.actions ? { actions: e.actions } : {}),
    chrome: { topAction: 'none' },
    fallback: { title: e.fallbackTitle ?? 'A new activity', body: 'Update the app to see this.' },
  }
}

export const canvas = (objects: ReturnType<typeof textObject>[], anchor: 'center' | 'top' = 'center') => ({
  type: 'canvas',
  verticalAnchor: anchor,
  objects,
})

export function textDocument(objects: ReturnType<typeof textObject>[], e: Envelope & { anchor?: 'center' | 'top' } = {}) {
  return envelope('text', canvas(objects, e.anchor), e)
}

export function bibleDocument(
  objects: Array<ReturnType<typeof textObject> & { listStyle?: string; startNumber?: number; reference?: unknown; highlights?: unknown[] }>,
  passages: Array<{
    bookNumber: number
    chapterStart: number
    verseStart: number
    chapterEnd: number
    verseEnd: number
    startOffset?: number
    endOffset?: number
    translation?: string
  }>,
  e: Envelope = {},
) {
  return envelope('bible', { ...canvas(objects), passages }, e)
}

export function videoDocument(videoId: string, e: Envelope & { posterMediaId?: string; presenterName?: string } = {}) {
  return envelope(
    'video',
    {
      type: 'video',
      videoId,
      posterMediaId: e.posterMediaId ?? null,
      presenter: e.presenterName ? { name: e.presenterName, subtitle: 'Your leader' } : null,
    },
    e,
  )
}

export function youtubeDocument(youtubeVideoId: string, e: Envelope = {}) {
  return envelope('youtube', { type: 'youtube', youtubeVideoId, startSeconds: null, endSeconds: null }, e)
}

export function writeDocument(prompt: string, e: Envelope & { placeholder?: string } = {}) {
  return envelope(
    'write',
    { type: 'write', prompt: textObject({ id: 'p1', role: 'heading', text: prompt, size: 26, weight: 700, y: 300 }), placeholder: e.placeholder ?? null },
    e,
  )
}

export function inlineAction(id: string, label: string) {
  return { id, kind: 'addToPrayerList', label, placement: 'inline', payload: { title: label, body: 'God, thank you for today.' } }
}

export function pinnedAction(id: string, label: string) {
  return { id, kind: 'nextLesson', label, placement: 'pinned', payload: {} }
}
