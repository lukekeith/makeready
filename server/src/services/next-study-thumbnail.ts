/**
 * One image per lesson activity (ui2-groups-browse D17, text-activity §Contract): the document's background
 * image, else a video page's poster, else the video's still, else none. Both resolve through the `MediaMap` the response carries.
 */
import type { MediaMap } from './content-media.service.js'

export function thumbnailFromDocument(doc: unknown, media: MediaMap): string | null {
  const d = doc as {
    background?: { image?: { mediaId?: unknown } }
    content?: { posterMediaId?: unknown; videoId?: unknown }
  } | null
  // An id naming a video yields its still, never its stream `url` (video-activity-basics D8).
  const imageOf = (id: unknown): string | null => {
    const entry = typeof id === 'string' && id !== '' ? media[id] : undefined
    if (!entry) return null
    return entry.kind === 'video' ? (entry.posterUrl ?? null) : (entry.url ?? null)
  }
  return imageOf(d?.background?.image?.mediaId) ?? imageOf(d?.content?.posterMediaId) ?? imageOf(d?.content?.videoId)
}
