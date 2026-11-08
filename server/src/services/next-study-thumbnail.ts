/**
 * One image per lesson activity (ui2-groups-browse D17, text-activity §Contract): the document's background
 * image, else a video page's poster, else none. Both resolve through the `MediaMap` the response carries.
 */
import type { MediaMap } from './content-media.service.js'

export function thumbnailFromDocument(doc: unknown, media: MediaMap): string | null {
  const d = doc as { background?: { image?: { mediaId?: unknown } }; content?: { posterMediaId?: unknown } } | null
  const urlOf = (id: unknown): string | null => (typeof id === 'string' && id !== '' ? (media[id]?.url ?? null) : null)
  return urlOf(d?.background?.image?.mediaId) ?? urlOf(d?.content?.posterMediaId)
}
