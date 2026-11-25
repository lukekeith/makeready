import { describe, expect, it } from 'vitest'
import { thumbnailFromDocument } from '../next-study-thumbnail.js'
import type { MediaMap } from '../content-media.service.js'

const still = 'https://img.test/still.jpg'

const media: MediaMap = {
  bg: { url: 'https://img.test/bg.jpg', kind: 'image' },
  poster: { url: 'https://img.test/poster.jpg', kind: 'image' },
  vid: { url: 'https://stream.test/vid.m3u8', kind: 'video', posterUrl: still },
  bare: { url: 'https://stream.test/bare.m3u8', kind: 'video' },
}

const thumb = (videoId: string, posterMediaId?: string | null, backgroundId?: string | null) =>
  thumbnailFromDocument(
    { background: backgroundId ? { image: { mediaId: backgroundId } } : { color: '#000' }, content: { type: 'video', videoId, posterMediaId } },
    media,
  )

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

  it('falls back to the video still', () => {
    expect(thumb('vid')).toBe(still)
  })

  it('the poster wins over the still', () => {
    expect(thumb('vid', 'poster')).toBe('https://img.test/poster.jpg')
    expect(thumb('vid', 'poster', 'bg')).toBe('https://img.test/bg.jpg')
  })

  it('never returns a stream url', () => {
    expect(thumb('bare')).toBeNull()
    expect(thumb('bare', 'vid')).toBe(still)
    expect(thumb('bare', null, 'vid')).toBe(still)
    expect(thumb('vid', null, 'bare')).toBe(still)
  })
})
