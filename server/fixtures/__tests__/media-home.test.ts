import { describe, expect, it } from 'vitest'
import { FIXTURE_LEADER_USER_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { MEDIA_HOME_ROW_COUNT, MEDIA_HOME_TAGS, MEDIA_HOME_UNDATED, mediaHomeRows } from '../screens/media-home.js'

const NOW = new Date('2026-10-31T17:00:00.000Z')
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)
const sources = Array.from({ length: 12 }, (_, i) => ({
  url: `https://img.test/library/l${i}.jpeg`, thumbnailUrl: `https://img.test/library/l${i}-thumb.jpeg`,
  width: 1200, height: 900, aspectRatio: '4:3', dominantColor: '#334455',
}))

describe('media-home layer rows (media-page D14)', () => {
  const rows = mediaHomeRows(NOW, sources, daysAgo)

  it('makes 360 rows with ids from n 1000, unique', () => {
    expect(rows).toHaveLength(MEDIA_HOME_ROW_COUNT)
    expect(rows[0].media.id).toBe(fixtureId('media', 1000))
    expect(new Set(rows.map((r) => r.media.id)).size).toBe(MEDIA_HOME_ROW_COUNT)
  })

  it('reuses the base library URLs, cycled', () => {
    expect(rows[0].media.url).toBe(sources[0].url)
    expect(rows[12].media.url).toBe(sources[0].url)
    expect(rows[13].media.thumbnailUrl).toBe(sources[1].thumbnailUrl)
  })

  it('leaves 20 rows undated and dates the rest within the last 3 calendar years, none in the future', () => {
    const undated = rows.filter((r) => r.media.takenAt === null)
    expect(undated).toHaveLength(MEDIA_HOME_UNDATED)
    const floor = Date.UTC(NOW.getUTCFullYear() - 3, 0, 1)
    for (const r of rows) {
      if (r.media.takenAt === null) continue
      expect(r.media.takenAt.getTime()).toBeGreaterThanOrEqual(floor)
      expect(r.media.takenAt.getTime()).toBeLessThanOrEqual(NOW.getTime())
    }
  })

  it('leaves month-to-month gaps: some of the last 36 months have no photo', () => {
    const months = new Set(rows.filter((r) => r.media.takenAt).map((r) => r.media.takenAt!.toISOString().slice(0, 7)))
    expect(months.size).toBeGreaterThan(12)
    expect(months.size).toBeLessThan(36)
  })

  it('splits uploads between the two fixture leaders and uses every tag', () => {
    expect(new Set(rows.map((r) => r.media.uploadedBy))).toEqual(new Set([FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID]))
    expect(new Set(rows.flatMap((r) => r.tags))).toEqual(new Set(MEDIA_HOME_TAGS))
  })

  it('gives each tag a fixed mediaTag id', () => {
    const ids = rows.flatMap((r) => r.tagIds)
    expect(new Set(ids).size).toBe(ids.length)
    expect(ids[0].split('-')[1]).toBe('001c')
  })
})
