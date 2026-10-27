/**
 * One image per next-lesson activity (ui2-groups-browse D17, T6): the YouTube thumbnail, else the
 * uploaded video's thumbnail, else (READ only) the first read block with a background image.
 */
export interface ThumbnailSource {
  type: string
  youtubeThumbnailUrl: string | null
  video: { thumbnailUrl: string | null } | null
  /** Ordered by orderNumber; the route asks only for blocks that have an image. */
  readBlocks: Array<{ backgroundImageUrl: string | null }>
}

export function activityThumbnailUrl(activity: ThumbnailSource): string | null {
  if (activity.youtubeThumbnailUrl) return activity.youtubeThumbnailUrl
  if (activity.video?.thumbnailUrl) return activity.video.thumbnailUrl
  if (activity.type === 'READ') {
    return activity.readBlocks.find((block) => block.backgroundImageUrl)?.backgroundImageUrl ?? null
  }
  return null
}
