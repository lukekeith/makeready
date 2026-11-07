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

/**
 * The 1.0 thumbnail rule over `ScheduledLessonActivity` rows. Only `fixtures/__tests__/groups-browse.db.test.ts`
 * still calls it, on the fixture rows it reads straight from the old tables; Task 17 moves that test to
 * `thumbnailFromDocument` and deletes this.
 */
export interface LegacyThumbnailSource {
  type: string
  youtubeThumbnailUrl: string | null
  video: { thumbnailUrl: string | null } | null
  readBlocks: Array<{ backgroundImageUrl: string | null }>
}

export function activityThumbnailUrl(activity: LegacyThumbnailSource): string | null {
  if (activity.youtubeThumbnailUrl) return activity.youtubeThumbnailUrl
  if (activity.video?.thumbnailUrl) return activity.video.thumbnailUrl
  if (activity.type === 'READ') return activity.readBlocks.find((block) => block.backgroundImageUrl)?.backgroundImageUrl ?? null
  return null
}
