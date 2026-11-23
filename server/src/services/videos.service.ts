import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import type { Video } from '../generated/prisma/index.js'
import { getVideo as getCloudflareVideo } from './cloudflare.js'
import { TRANSCRIPT_MAX_ATTEMPTS } from './transcription.service.js'
import { decodeLibraryCursor, encodeLibraryCursor, getUserOrgId, syncVideoStatus } from './media-library.js'
import { videoActivityUseCount } from './content-media.service.js'
import { deriveVideoMetadata } from './media-metadata.js'
import { trackActivity } from './activity.js'

const segment = z
  .object({
    text: z.string().max(1000),
    startMs: z.number().int().min(0),
    endMs: z.number().int().min(0),
  })
  .strict()
  .refine((s) => s.startMs <= s.endMs, { message: 'segment startMs must not exceed endMs' })

/** Body of POST /api/videos (D22, D24). `.extend().strict()` — unknown keys are a 400, never stripped. */
export const createVideoBody = z
  .object({
    cloudflareUid: z.string().min(1, 'Cloudflare UID is required'),
    title: z.string().optional(),
    description: z.string().optional(),
    transcript: z.string().max(20_000).optional(),
    transcriptSegments: z.array(segment).max(2000).optional(),
    source: z.enum(['recording', 'import']).optional(),
  })
  .strict()

export type CreateVideoInput = z.infer<typeof createVideoBody>

export class VideoServiceError extends Error {
  constructor(public status: 400 | 403 | 404 | 409 | 500, message: string) {
    super(message)
    this.name = 'VideoServiceError'
  }
}

export interface CreateVideoResult {
  status: 200 | 201
  video: Video
}

/** The existing row answers the caller (200) when theirs, 409 when another user's (D22). */
function answerExisting(userId: string, existing: Video): CreateVideoResult {
  if (existing.userId !== userId) throw new VideoServiceError(409, 'Video already exists')
  return { status: 200, video: existing }
}

/**
 * Creates the Video and, for a caller with an org, its Media row in one transaction (D21), so the returned
 * `Video.id` is at once valid as an activity's `content.videoId`. Idempotent per `cloudflareUid` (D22).
 */
export async function createVideo(userId: string, body: CreateVideoInput): Promise<CreateVideoResult> {
  const { cloudflareUid, title, description, transcript, transcriptSegments, source } = body

  const existing = await prisma.video.findUnique({ where: { cloudflareUid } })
  if (existing) return answerExisting(userId, existing)

  const cloudflareResult = await getCloudflareVideo(cloudflareUid)
  const cfVideo = cloudflareResult.success ? cloudflareResult.video : undefined

  const streamOwner = cfVideo?.meta?.userId
  if (streamOwner && streamOwner !== userId) throw new VideoServiceError(403, 'Video was not uploaded by this user')

  let status = 'pending'
  let playbackUrl = ''
  let thumbnailUrl: string | null = null
  let duration: number | null = null
  if (cfVideo) {
    if (cfVideo.status.state === 'ready') {
      status = 'ready'
      duration = cfVideo.duration ? Math.round(cfVideo.duration) : null
      thumbnailUrl = cfVideo.thumbnail || null
      playbackUrl = cfVideo.playback?.hls || ''
    } else if (cfVideo.status.state === 'error') {
      status = 'error'
    }
  }

  const transcriptFields =
    transcript !== undefined
      ? { transcript, transcriptSegments, transcriptStatus: 'ready', transcriptSource: 'on_device' }
      : { transcriptStatus: source ? 'pending' : 'none' }

  const orgId = await getUserOrgId(userId)
  const videoMeta = deriveVideoMetadata({ width: cfVideo?.input?.width, height: cfVideo?.input?.height })

  let video: Video
  try {
    video = await prisma.$transaction(async (tx) => {
      const created = await tx.video.create({
        data: { cloudflareUid, title, description, playbackUrl, thumbnailUrl, duration, status, userId, ...transcriptFields },
      })
      if (orgId) {
        await tx.media.create({
          data: {
            title: created.title || 'Untitled video',
            url: created.playbackUrl,
            type: 'video',
            mimeType: 'video/mp4',
            thumbnailUrl: created.thumbnailUrl ?? undefined,
            organizationId: orgId,
            uploadedBy: userId,
            videoId: created.id,
            source: 'auto_capture',
            uploadStatus: created.status === 'ready' ? 'ready' : 'pending',
            duration: created.duration ?? undefined,
            visibility: 'members',
            ...videoMeta,
          },
        })
      }
      return created
    })
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      const winner = await prisma.video.findUnique({ where: { cloudflareUid } })
      if (winner) return answerExisting(userId, winner)
    }
    throw error
  }

  trackActivity({
    actorId: userId,
    action: 'CREATED',
    resourceType: 'VIDEO',
    resourceId: video.id,
    resourceName: video.title || 'Untitled video',
  })

  return { status: 201, video }
}

const PREVIEW_CHARS = 160

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Whether `id` can name a `videos.id`; the column is `uuid`, so any other string would error in the database instead of finding nothing. */
export const isVideoId = (id: string): boolean => UUID.test(id)

export interface VideoSummary {
  id: string
  title: string | null
  thumbnailUrl: string | null
  playbackUrl: string
  duration: number | null
  status: string
  transcriptStatus: string
  transcriptPreview: string | null
  createdAt: Date
}

export interface ListLibraryVideosOptions { limit: number; cursor?: string; q?: string }

/**
 * The caller's live Library videos, newest first, keyset-paged on `(createdAt, id)` (D20). `q` is a literal,
 * case-insensitive substring of title or transcript; the transcript itself is never returned, only its first 160 characters.
 */
export async function listLibraryVideos(userId: string, { limit, cursor, q }: ListLibraryVideosOptions) {
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) throw new VideoServiceError(400, 'limit must be an integer from 1 to 100')
  const decoded = cursor === undefined ? null : decodeLibraryCursor(cursor)
  if (cursor !== undefined && (!decoded || !isVideoId(decoded.id))) throw new VideoServiceError(400, 'Invalid cursor')

  const pattern = q ? '%' + q.replace(/[\\%_]/g, '\\$&') + '%' : null
  const search = pattern
    ? Prisma.sql`AND (title ILIKE ${pattern} ESCAPE '\\' OR transcript ILIKE ${pattern} ESCAPE '\\')`
    : Prisma.empty
  const after = decoded
    ? Prisma.sql`AND ("createdAt", id) < (${decoded.createdAt.toISOString()}::timestamp, ${decoded.id}::uuid)`
    : Prisma.empty

  const rows = await prisma.$queryRaw<VideoSummary[]>`
    SELECT id, title, "thumbnailUrl", "playbackUrl", duration, status, "transcriptStatus",
           left(transcript, ${PREVIEW_CHARS}::int) AS "transcriptPreview", "createdAt"
    FROM videos
    WHERE "userId"::text = ${userId} AND "isActive" = true AND "libraryRemovedAt" IS NULL ${search} ${after}
    ORDER BY "createdAt" DESC, id DESC
    LIMIT ${limit + 1}::int`

  const hasMore = rows.length > limit
  const data = hasMore ? rows.slice(0, limit) : rows
  const last = data[data.length - 1]
  return { data, hasMore, nextCursor: hasMore && last ? encodeLibraryCursor(last.createdAt, last.id) : null }
}

/** Takes a video out of its owner's Library while lessons keep playing it (D17). Owner only; the first call's timestamp stays. */
export async function removeFromLibrary(userId: string, id: string): Promise<{ id: string; libraryRemovedAt: Date }> {
  const video = isVideoId(id)
    ? await prisma.video.findUnique({ where: { id }, select: { id: true, userId: true, libraryRemovedAt: true } })
    : null
  if (!video) throw new VideoServiceError(404, 'Video not found')
  if (video.userId !== userId) throw new VideoServiceError(403, 'Not authorized to remove this video')
  if (video.libraryRemovedAt) return { id, libraryRemovedAt: video.libraryRemovedAt }

  // A concurrent first call may win the null guard; re-read so both answer with the stored timestamp.
  await prisma.video.updateMany({ where: { id, libraryRemovedAt: null }, data: { libraryRemovedAt: new Date() } })
  const stored = await prisma.video.findUniqueOrThrow({ where: { id }, select: { libraryRemovedAt: true } })
  return { id, libraryRemovedAt: stored.libraryRemovedAt! }
}

/** Distinct lesson activities that use this video, the count behind DELETE's 409 guard (F2, D17). */
export function lessonUseCount(videoId: string): Promise<number> {
  return videoActivityUseCount(prisma, videoId)
}

/** Pulls the video's latest state from Stream into its row and the Media library (D23). Throws a 500 VideoServiceError when Stream cannot be read. */
export async function refreshFromStream(video: Video): Promise<Video> {
  const cloudflareResult = await getCloudflareVideo(video.cloudflareUid)
  if (!cloudflareResult.success) {
    throw new VideoServiceError(500, cloudflareResult.error || 'Failed to get video status')
  }
  const cfVideo = cloudflareResult.video!

  let status = video.status
  let playbackUrl = video.playbackUrl
  let thumbnailUrl = video.thumbnailUrl
  let duration = video.duration

  if (cfVideo.status.state === 'ready') {
    status = 'ready'
    duration = cfVideo.duration ? Math.round(cfVideo.duration) : null
    // Use Cloudflare's actual URLs (includes correct customer subdomain)
    thumbnailUrl = cfVideo.thumbnail || null
    playbackUrl = cfVideo.playback?.hls || video.playbackUrl
  } else if (cfVideo.status.state === 'error') {
    status = 'error'
  }

  const updatedVideo = await prisma.video.update({
    where: { id: video.id },
    data: { status, playbackUrl, thumbnailUrl, duration },
  })

  if (status !== video.status) {
    const videoMeta = deriveVideoMetadata({ width: cfVideo.input?.width, height: cfVideo.input?.height })
    syncVideoStatus(video.id, status, playbackUrl, thumbnailUrl ?? undefined, duration ?? undefined, videoMeta)
  }
  return updatedVideo
}

const PENDING_VIDEO_WINDOW_MS = 24 * 3_600_000

/** The job's Stream sync (D23): refreshes pending videos from the last 24 h, errors the older ones. One failure never stops the rest. */
export async function syncPendingVideos(now: Date): Promise<{ refreshed: number; expired: number }> {
  const cutoff = new Date(now.getTime() - PENDING_VIDEO_WINDOW_MS)
  let refreshed = 0

  const recent = await prisma.video.findMany({ where: { status: 'pending', createdAt: { gte: cutoff } } })
  for (const video of recent) {
    try {
      await refreshFromStream(video)
      refreshed++
    } catch (error) {
      console.error(`[videos] Stream refresh failed for video ${video.id}:`, error)
    }
  }

  // Two statements so a pending transcript fails with its video; each is guarded on the row still being pending.
  await prisma.video.updateMany({
    where: { status: 'pending', createdAt: { lt: cutoff }, transcriptStatus: 'pending' },
    data: { transcriptStatus: 'failed' },
  })
  const { count: expired } = await prisma.video.updateMany({
    where: { status: 'pending', createdAt: { lt: cutoff } },
    data: { status: 'error' },
  })
  return { refreshed, expired }
}

/** Ids of ready videos waiting on the server fallback transcript: the claim's predicate without its timestamp (D11). `libraryRemovedAt` rows are included. */
export async function videoIdsDueForTranscript(): Promise<string[]> {
  const rows = await prisma.video.findMany({
    where: { isActive: true, status: 'ready', transcriptStatus: { in: ['pending', 'failed'] }, transcriptAttempts: { lt: TRANSCRIPT_MAX_ATTEMPTS } },
    select: { id: true },
    orderBy: { createdAt: 'asc' },
  })
  return rows.map((r) => r.id)
}
