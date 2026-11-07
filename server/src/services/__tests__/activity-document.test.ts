import { describe, expect, it } from 'vitest'
import {
  documentMediaRefs,
  documentText,
  hashLessonContent,
  parseActivityDocument,
} from '../activity-document.js'

const text = (): any => ({
  schemaVersion: 1,
  kind: 'text',
  background: { color: '#0E4A4D', motion: { mode: 'scroll', rate: 1 } },
  content: {
    type: 'canvas',
    verticalAnchor: 'center',
    objects: [
      { id: 'o1', role: 'eyebrow', text: 'PRAYER', font: 'sans', weight: 700, size: 11,
        lineHeight: 1.2, tracking: 0.12, color: '#FFFFFF', alignment: 'left',
        transform: { x: 220, y: 182, width: 392, scale: 1, rotation: 0 } },
      { id: 'o2', role: 'prayer', text: "God, sometimes it's hard to focus my mind on good things…",
        font: 'sans', weight: 700, size: 28, lineHeight: 1.3, color: '#FFFFFF', alignment: 'left',
        transform: { x: 220, y: 470, width: 392, scale: 1, rotation: 0 } },
    ],
  },
  actions: [
    { id: 'a1', kind: 'addToPrayerList', label: 'Add to Prayer List', placement: 'inline',
      payload: { title: 'A Prayer to Focus My Mind on God', body: "God, sometimes it's hard…" } },
  ],
  chrome: { topAction: 'share' },
  fallback: { title: 'A prayer', body: 'Update the app to see this.' },
})

const envelope = (kind: string, content: unknown): any => ({
  schemaVersion: 1,
  kind,
  background: { color: '#112233' },
  content,
  actions: [],
  chrome: { topAction: 'none' },
  fallback: { title: 'x', body: 'y' },
})

const promptObject = {
  id: 'p', text: 'Prompt', font: 'serif', weight: 400, size: 20, color: '#FFFFFF', alignment: 'center',
  transform: { x: 220, y: 300, width: 392, scale: 1, rotation: 0 },
}

const EXAMPLES: Record<string, any> = {
  text: text(),
  bible: envelope('bible', {
    ...text().content,
    passages: [{ bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 17 }],
  }),
  video: envelope('video', {
    type: 'video', videoId: 'vid1', posterMediaId: 'poster1', captionsTrack: null,
    presenter: { name: 'Pastor Sam', avatarMediaId: 'avatar1', subtitle: 'Teaching' },
  }),
  youtube: envelope('youtube', { type: 'youtube', youtubeVideoId: 'abc123', startSeconds: 5, endSeconds: 60 }),
  write: envelope('write', { type: 'write', prompt: promptObject, placeholder: 'Write your thoughts' }),
  poll: envelope('poll', {
    type: 'poll', prompt: promptObject, options: [{ id: 'a', label: 'Yes' }, { id: 'b', label: 'No' }], multiple: false,
  }),
}

const withImage = (doc: any, mediaId: string) => ({
  ...doc,
  background: { ...doc.background, image: { mediaId, focal: { x: 0.5, y: 0.4 } } },
})

function padToBytes(doc: any, bytes: number) {
  const copy = JSON.parse(JSON.stringify(doc))
  copy.fallback.body = ''
  const base = Buffer.byteLength(JSON.stringify(copy))
  copy.fallback.body = 'a'.repeat(bytes - base)
  expect(Buffer.byteLength(JSON.stringify(copy))).toBe(bytes)
  return copy
}

describe('activity document', () => {
  it('accepts the 02 §11 example and one example of every other kind', () => {
    for (const [kind, doc] of Object.entries(EXAMPLES)) expect(parseActivityDocument(doc, kind)).toMatchObject({ ok: true })
  })

  it('keeps unknown fields at every level', () => {
    const doc = { ...text(), futureField: { a: 1 } }
    doc.content.objects[0] = { ...doc.content.objects[0], glow: 'soft' }
    const r: any = parseActivityDocument(doc, 'text')
    expect(r.ok && r.document.futureField).toEqual({ a: 1 })
    expect(r.ok && r.document.content.objects[0].glow).toBe('soft')
  })

  it('refuses a kind mismatch, an unknown kind and a higher schemaVersion', () => {
    expect(parseActivityDocument(text(), 'bible')).toMatchObject({ ok: false, code: 'VALIDATION' })
    expect(parseActivityDocument({ ...text(), kind: 'quiz' }, 'quiz')).toMatchObject({ ok: false, code: 'VALIDATION' })
    expect(parseActivityDocument({ ...text(), schemaVersion: 2 }, 'text')).toMatchObject({ ok: false, code: 'VALIDATION' })
  })

  it('refuses two pinned actions', () => {
    const a = { id: 'a', kind: 'openUrl', label: 'Go', placement: 'pinned', payload: { url: 'https://x.org' } }
    const r = parseActivityDocument({ ...text(), actions: [a, { ...a, id: 'b' }] }, 'text')
    expect(r).toMatchObject({ ok: false, code: 'VALIDATION', error: 'At most one pinned action per page' })
  })

  it('accepts exactly 256 KB and refuses one byte more', () => {
    const at = padToBytes(text(), 262144)
    expect(parseActivityDocument(at, 'text')).toMatchObject({ ok: true })
    expect(parseActivityDocument(padToBytes(text(), 262145), 'text')).toMatchObject({
      ok: false, code: 'TOO_LARGE', error: 'Activity document exceeds 256 KB',
    })
  })

  it('collects media and video refs', () => {
    expect(documentMediaRefs(withImage(text(), 'm1'))).toEqual({ mediaIds: ['m1'], videoIds: [] })
    expect(documentMediaRefs(EXAMPLES.video)).toEqual({ mediaIds: ['poster1', 'avatar1'], videoIds: ['vid1'] })
  })

  it('reads text top to bottom', () => {
    expect(documentText(text())).toBe("PRAYER\nGod, sometimes it's hard to focus my mind on good things…")
  })

  it('orders objects by y, ties by array index', () => {
    const doc = text()
    const [eyebrow, prayer] = doc.content.objects
    doc.content.objects = [prayer, { ...eyebrow, text: 'B', transform: { ...eyebrow.transform, y: 470 } }, eyebrow]
    expect(documentText(doc).split('\n').slice(1)).toEqual([prayer.text, 'B'])
  })

  it('hash ignores key order and sees a position change', () => {
    const a = { activityKey: 'k1', position: 0, kind: 'text', title: 'Text', document: { b: 1, a: 2 } }
    const h = hashLessonContent({ title: 'Day 1', activities: [a] })
    expect(h).toMatch(/^[0-9a-f]{64}$/)
    expect(hashLessonContent({ title: 'Day 1', activities: [{ ...a, document: { a: 2, b: 1 } }] })).toBe(h)
    expect(hashLessonContent({ title: 'Day 1', activities: [{ ...a, position: 1 }] })).not.toBe(h)
  })
})
