import { describe, expect, it } from 'vitest'
import { parseTakenAt } from '../src/services/media-metadata.js'

const NOW = new Date('2026-10-31T12:00:00.000Z')

describe('parseTakenAt (media-page D4)', () => {
  it('takes a body value with Z', () => {
    expect(parseTakenAt('2025-06-14T09:30:00Z', null, NOW)?.toISOString()).toBe('2025-06-14T09:30:00.000Z')
  })
  it('takes a body value with an offset, with or without the colon, and with fractions', () => {
    expect(parseTakenAt('2025-06-14T09:30:00-05:00', null, NOW)?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
    expect(parseTakenAt('2025-06-14T09:30:00+0530', null, NOW)?.toISOString()).toBe('2025-06-14T04:00:00.000Z')
    expect(parseTakenAt('2025-06-14T09:30:00.250Z', null, NOW)?.toISOString()).toBe('2025-06-14T09:30:00.250Z')
    expect(parseTakenAt('2025-06-14T09:30Z', null, NOW)?.toISOString()).toBe('2025-06-14T09:30:00.000Z')
  })
  it('ignores a date-only, offset-less or garbage body value', () => {
    expect(parseTakenAt('2025-06-14', null, NOW)).toBeNull()
    expect(parseTakenAt('2025-06-14T09:30:00', null, NOW)).toBeNull()
    expect(parseTakenAt('yesterday', null, NOW)).toBeNull()
    expect(parseTakenAt(42, null, NOW)).toBeNull()
    expect(parseTakenAt('2025-13-40T99:99:00Z', null, NOW)).toBeNull()
  })
  it('ignores a body value before 1990-01-01 or more than 24 h after now', () => {
    expect(parseTakenAt('1989-12-31T23:59:59Z', null, NOW)).toBeNull()
    expect(parseTakenAt('2026-11-01T12:00:01Z', null, NOW)).toBeNull()
    expect(parseTakenAt('2026-11-01T11:59:59Z', null, NOW)?.toISOString()).toBe('2026-11-01T11:59:59.000Z')
  })
  it('falls back to exifData.dateTaken (a Date or its ISO string) when the body has none or an invalid one', () => {
    const exifDate = new Date('2024-03-02T10:11:12.000Z')
    expect(parseTakenAt(undefined, { dateTaken: exifDate }, NOW)?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
    expect(parseTakenAt('bad', { dateTaken: '2024-03-02T10:11:12.000Z' }, NOW)?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
    expect(parseTakenAt(undefined, { dateTaken: '1970-01-01T00:00:00.000Z' }, NOW)).toBeNull()
    expect(parseTakenAt(undefined, { dateTaken: 'not a date' }, NOW)).toBeNull()
  })
  it('prefers a valid body value over EXIF', () => {
    expect(parseTakenAt('2025-06-14T09:30:00Z', { dateTaken: new Date('2024-03-02T10:11:12Z') }, NOW)?.toISOString())
      .toBe('2025-06-14T09:30:00.000Z')
  })
  it('is null with neither', () => {
    expect(parseTakenAt(undefined, null, NOW)).toBeNull()
    expect(parseTakenAt(undefined, undefined, NOW)).toBeNull()
    expect(parseTakenAt(undefined, { cameraMake: 'Apple' }, NOW)).toBeNull()
  })
})
