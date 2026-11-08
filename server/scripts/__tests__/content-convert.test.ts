/** text-activity Task 18: the pure 05 s6 mapping from an old activity to new-model activities. */
import { describe, expect, it } from 'vitest'
import { parseActivityDocument } from '../../src/services/activity-document.js'
import { assertDatabaseAllowed, convertActivity } from '../content-convert.js'
import { OLD_ROWS } from './old-rows.js'

describe('convertActivity', () => {
  it.each(OLD_ROWS)('converts $name', ({ old, expectKinds }) => {
    const r = convertActivity(old)
    expect(r.activities.map((a) => a.kind)).toEqual(expectKinds)
    for (const a of r.activities) expect(parseActivityDocument(a.document, a.kind).ok).toBe(true)
  })

  it('the first activity keeps the old id as its key', () => {
    expect(convertActivity(OLD_ROWS[0].old).activities[0].activityKey).toBe(OLD_ROWS[0].old.id)
  })

  it('a split block gets <oldId>:<n> keys', () => {
    const row = OLD_ROWS.find((r) => r.name === 'READ block with its own background')!
    expect(convertActivity(row.old).activities.map((a) => a.activityKey)).toEqual([
      'old-read-bg', 'old-read-bg:1', 'old-read-bg:2',
    ])
  })

  it('imported text is one top-anchored 392-wide column at x = 220', () => {
    const row = OLD_ROWS.find((r) => r.name === 'READ unstyled text blocks')!
    const doc: any = convertActivity(row.old).activities[0].document
    expect(doc.content.verticalAnchor).toBe('top')
    expect(doc.content.objects).toHaveLength(1)
    expect(doc.content.objects[0].transform).toMatchObject({ x: 220, width: 392 })
  })

  it('markdown becomes plain text with marks', () => {
    const row = OLD_ROWS.find((r) => r.name === 'READ unstyled text blocks')!
    const obj: any = (convertActivity(row.old).activities[0].document as any).content.objects[0]
    expect(obj.text).not.toMatch(/[*#\[\]]/)
    const kinds = obj.marks.map((m: any) => m.kind).sort()
    expect(kinds).toEqual(['bold', 'bold', 'italic', 'link'])
    const link = obj.marks.find((m: any) => m.kind === 'link')
    expect(obj.text.slice(link.start, link.end)).toBe('notes')
    expect(link.href).toBe('https://example.com')
  })

  it('an exegesis highlight and its note move into the text object', () => {
    const row = OLD_ROWS.find((r) => r.name === 'EXEGESIS')!
    const doc: any = convertActivity(row.old).activities[0].document
    const scripture = doc.content.objects.find((o: any) => o.role === 'scripture')
    expect(scripture.highlights).toEqual([expect.objectContaining({ start: 2, end: 6, noteMarkdown: 'Paul wrote this' })])
    expect(scripture.marks).toEqual([expect.objectContaining({ start: 10, end: 17, kind: 'bold' })])
    expect(doc.content.passages).toEqual([{ bookNumber: 45, chapterStart: 1, verseStart: 1, chapterEnd: 1, verseEnd: 2 }])
  })

  it('the write prompt carries title and help text, and keeps the placeholder', () => {
    const doc: any = convertActivity(OLD_ROWS[2].old).activities[0].document
    expect(doc.content.prompt.text).toBe('Observation\nWhat stands out?')
    expect(doc.content.placeholder).toBe('Write here')
  })

  it('lists lossy conversions: dropped theme, split block, unresolved image', () => {
    const row = OLD_ROWS.find((r) => r.name === 'READ block with its own background')!
    const r = convertActivity(row.old)
    expect(r.losses.some((l) => /theme/i.test(l))).toBe(true)
    expect(r.losses.some((l) => /split/i.test(l))).toBe(true)
    const unresolved = convertActivity(row.old, { mediaIdForUrl: () => undefined })
    expect(unresolved.losses.some((l) => /background image/i.test(l))).toBe(true)
  })

  it('a video activity with no video becomes a text page and says so', () => {
    const r = convertActivity({ ...OLD_ROWS[0].old, videoId: null })
    expect(r.activities[0].kind).toBe('text')
    expect(r.losses.length).toBeGreaterThan(0)
  })
})

describe('assertDatabaseAllowed', () => {
  it.each([
    'postgresql://u:p@localhost:5434/x',
    'postgresql://u:p@127.0.0.1:5432/x',
    'postgresql://u:p@postgres_vt_ab12:5432/x',
  ])('accepts %s', (url) => {
    expect(() => assertDatabaseAllowed(url, {})).not.toThrow()
  })

  it('refuses a production host without the flag and accepts it with the flag', () => {
    const url = 'postgresql://u:p@db.railway.internal:5432/railway'
    expect(() => assertDatabaseAllowed(url, {})).toThrow(/--confirm-production/)
    expect(() => assertDatabaseAllowed(url, { confirmProduction: true })).not.toThrow()
  })
})
