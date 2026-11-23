import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import type { Video } from '../generated/prisma/index.js'
import { getVideo as getCloudflareVideo } from './cloudflare.js'
import { getUserOrgId } from './media-library.js'
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
  constructor(public status: 400 | 403 | 409, message: string) {
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
