import { describe, expect, it } from 'vitest'
import { activityThumbnailUrl, type ThumbnailSource } from '../next-study-thumbnail.js'

const src = (over: Partial<ThumbnailSource>): ThumbnailSource => ({
  type: 'READ',
  youtubeThumbnailUrl: null,
  video: null,
  readBlocks: [],
  ...over,
})

describe('activityThumbnailUrl (D17, T6)', () => {
  it('prefers the YouTube thumbnail', () => {
    expect(
      activityThumbnailUrl(src({ type: 'YOUTUBE', youtubeThumbnailUrl: 'https://yt/1.jpg', video: { thumbnailUrl: 'https://v/1.jpg' } }))
    ).toBe('https://yt/1.jpg')
  })

  it('falls back to the uploaded video’s thumbnail', () => {
    expect(activityThumbnailUrl(src({ type: 'VIDEO', video: { thumbnailUrl: 'https://v/1.jpg' } }))).toBe('https://v/1.jpg')
  })

  it('uses the first read block image of a READ activity', () => {
    expect(
      activityThumbnailUrl(src({ type: 'READ', readBlocks: [{ backgroundImageUrl: null }, { backgroundImageUrl: 'https://r/2.jpg' }] }))
    ).toBe('https://r/2.jpg')
  })

  it('ignores read blocks on a non-READ activity', () => {
    expect(activityThumbnailUrl(src({ type: 'USER_INPUT', readBlocks: [{ backgroundImageUrl: 'https://r/2.jpg' }] }))).toBeNull()
  })

  it('is null with no source (incl. a video without a thumbnail)', () => {
    expect(activityThumbnailUrl(src({ type: 'VIDEO', video: { thumbnailUrl: null } }))).toBeNull()
    expect(activityThumbnailUrl(src({ type: 'READ' }))).toBeNull()
  })
})
