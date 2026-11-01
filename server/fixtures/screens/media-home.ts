/**
 * media-home layer (media-page D14): 360 photos in the fixture org's library, so the Media page has
 * a grid to zoom through. They reuse the base layer's `source: 'direct'` library images (cycled), so
 * the layer is empty whenever base placed no images (vitest, or no storage configured — the same
 * switches as placeProgramCovers). Dates spread over the last 3 calendar years with month gaps; the
 * last 20 rows have no takenAt and sort by createdAt. Two uploaders and six tags, so every chip has
 * results. Never touches ctx.rand. Creates no org, user or group; the org's deletion removes the rows.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_USER_ID, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const MEDIA_HOME_ROW_COUNT = 360
export const MEDIA_HOME_UNDATED = 20
export const MEDIA_HOME_FIRST_N = 1000
export const MEDIA_HOME_TAGS = ['baptism', 'family', 'outreach', 'retreat', 'worship', 'youth'] as const

export interface MediaHomeSource {
  url: string
  thumbnailUrl: string | null
  width: number | null
  height: number | null
  aspectRatio: string | null
  dominantColor: string | null
}

export interface MediaHomeRow {
  media: {
    id: string; title: string; url: string; thumbnailUrl: string | null; type: 'photo'; mimeType: 'image/jpeg'
    organizationId: string; uploadedBy: string; visibility: 'members'; uploadStatus: 'ready'; source: 'direct'
    width: number | null; height: number | null; aspectRatio: string | null; dominantColor: string | null
    takenAt: Date | null; createdAt: Date
  }
  tags: string[]
  tagIds: string[]
}

/** Months back from now's month that hold photos: every month of the last 36 except each 5th (gaps). */
const DATED_MONTHS = Array.from({ length: 36 }, (_, m) => m).filter((m) => m % 5 !== 3)

export function mediaHomeRows(now: Date, sources: MediaHomeSource[], daysAgo: (n: number) => Date): MediaHomeRow[] {
  const dated = MEDIA_HOME_ROW_COUNT - MEDIA_HOME_UNDATED
  let tagN = 0
  return Array.from({ length: MEDIA_HOME_ROW_COUNT }, (_, i) => {
    const src = sources[i % sources.length]
    let takenAt: Date | null = null
    if (i < dated) {
      const monthsBack = DATED_MONTHS[i % DATED_MONTHS.length]
      const t = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - monthsBack, 1 + ((i * 7) % 27), 8 + (i % 10), (i * 13) % 60))
      takenAt = t.getTime() > now.getTime() ? new Date(now.getTime() - (i + 1) * 3_600_000) : t
    }
    const tags = i % 4 === 0
      ? [MEDIA_HOME_TAGS[i % MEDIA_HOME_TAGS.length], MEDIA_HOME_TAGS[(i + 3) % MEDIA_HOME_TAGS.length]]
      : [MEDIA_HOME_TAGS[i % MEDIA_HOME_TAGS.length]]
    return {
      media: {
        id: fixtureId('media', MEDIA_HOME_FIRST_N + i),
        title: `Library photo ${i + 1}`,
        url: src.url,
        thumbnailUrl: src.thumbnailUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        organizationId: FIXTURE_ORG_ID,
        uploadedBy: i % 3 === 0 ? FIXTURE_LEADER_USER_ID : FIXTURE_USER_ID,
        visibility: 'members',
        uploadStatus: 'ready',
        source: 'direct',
        width: src.width,
        height: src.height,
        aspectRatio: src.aspectRatio,
        dominantColor: src.dominantColor,
        takenAt,
        createdAt: daysAgo(i % 30),
      },
      tags,
      tagIds: tags.map(() => fixtureId('mediaTag', ++tagN)),
    }
  })
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const sources = await prisma.media.findMany({
    where: { organizationId: FIXTURE_ORG_ID, source: 'direct' },
    orderBy: { id: 'asc' },
    select: { url: true, thumbnailUrl: true, width: true, height: true, aspectRatio: true, dominantColor: true },
  })
  if (sources.length === 0) return // base placed no images: Media stays empty (R3)
  const rows = mediaHomeRows(ctx.now, sources, (n) => ctx.daysAgo(n))
  await prisma.media.createMany({ data: rows.map((r) => r.media) })
  await prisma.mediaTag.createMany({
    data: rows.flatMap((r) => r.tags.map((tag, k) => ({ id: r.tagIds[k], mediaId: r.media.id, tag }))),
  })
}
