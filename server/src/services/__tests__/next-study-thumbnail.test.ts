import { describe, expect, it } from 'vitest'
import { thumbnailFromDocument } from '../next-study-thumbnail.js'
import type { MediaMap } from '../content-media.service.js'

const media: MediaMap = {
  bg: { url: 'https://img.test/bg.jpg', kind: 'image' },
  poster: { url: 'https://img.test/poster.jpg', kind: 'image' },
}

describe('thumbnailFromDocument', () => {
  it('uses the background image', () => {
    expect(thumbnailFromDocument({ background: { image: { mediaId: 'bg' } }, content: { posterMediaId: 'poster' } }, media)).toBe('https://img.test/bg.jpg')
  })

  it('falls back to the video poster', () => {
    expect(thumbnailFromDocument({ background: { color: '#000' }, content: { type: 'video', posterMediaId: 'poster' } }, media)).toBe('https://img.test/poster.jpg')
  })

  it('is null with neither, or when the media is not in the map', () => {
    expect(thumbnailFromDocument({ background: { color: '#000' }, content: { type: 'canvas' } }, media)).toBeNull()
    expect(thumbnailFromDocument({ background: { image: { mediaId: 'gone' } } }, media)).toBeNull()
    expect(thumbnailFromDocument(null, media)).toBeNull()
  })
})
