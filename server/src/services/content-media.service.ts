/**
 * text-activity D34 / SC7: the media an activity document names. Access (the leader's orgs or the MakeReady
 * library), the `MediaUsage` rows derived from every version holding an `activityKey`, and the `MediaMap`
 * a response carries so a client can render the document.
 */
import type { Prisma } from '../generated/prisma/index.js'
import { documentMediaRefs } from './activity-document.js'
import { ContentError } from './content-errors.js'
import { MAKEREADY_ORG_ID } from './makeready-library.js'
import { canManageOrgContent } from './permission.js'

type Tx = Prisma.TransactionClient

export const ACTIVITY_USAGE_TYPE = 'ACTIVITY'

export interface MediaMapEntry {
  url: string
  width?: number
  height?: number
  kind: 'image' | 'video'
  playbackUrl?: string
  posterUrl?: string
  durationSeconds?: number
  uploaderName?: string
}
export type MediaMap = Record<string, MediaMapEntry>

/** Whether `userId` may put media of `organizationId` in a document (D34). */
async function orgAllowed(userId: string, organizationId: string, cache: Map<string, boolean>): Promise<boolean> {
  if (organizationId === MAKEREADY_ORG_ID) return true
  let allowed = cache.get(organizationId)
  if (allowed === undefined) {
    allowed = await canManageOrgContent(userId, organizationId, null)
    cache.set(organizationId, allowed)
  }
  return allowed
}

/** Throws `ContentError(400, 'VALIDATION')` naming the first media or video id the user may not use. */
export async function assertDocumentMediaAllowed(
  tx: Tx,
  userId: string,
  refs: { mediaIds: string[]; videoIds: string[] },
): Promise<void> {
  const cache = new Map<string, boolean>()
  if (refs.mediaIds.length) {
    const rows = await tx.media.findMany({ where: { id: { in: refs.mediaIds } }, select: { id: true, organizationId: true } })
    const byId = new Map(rows.map((r) => [r.id, r.organizationId]))
    for (const id of refs.mediaIds) {
      const orgId = byId.get(id)
      if (!orgId || !(await orgAllowed(userId, orgId, cache))) {
        throw new ContentError(400, 'VALIDATION', `mediaId ${id} is not available`)
      }
    }
  }
  if (refs.videoIds.length) {
    const rows = await tx.media.findMany({ where: { videoId: { in: refs.videoIds } }, select: { videoId: true, organizationId: true } })
    for (const id of refs.videoIds) {
      const owners = rows.filter((r) => r.videoId === id)
      let allowed = false
      for (const row of owners) if (await orgAllowed(userId, row.organizationId, cache)) allowed = true
      if (!allowed) throw new ContentError(400, 'VALIDATION', `videoId ${id} is not available`)
    }
  }
}

/** Media ids (a video resolved through `Media.videoId`) named by any activity with `activityKey`, in any version. */
async function mediaIdsForKey(tx: Tx, activityKey: string): Promise<string[]> {
  const activities = await tx.contentActivity.findMany({ where: { activityKey }, select: { document: true } })
  const mediaIds = new Set<string>()
  const videoIds = new Set<string>()
  for (const { document } of activities) {
    const refs = documentMediaRefs(document)
    refs.mediaIds.forEach((id) => mediaIds.add(id))
    refs.videoIds.forEach((id) => videoIds.add(id))
  }
  if (videoIds.size) {
    const linked = await tx.media.findMany({ where: { videoId: { in: [...videoIds] } }, select: { id: true } })
    linked.forEach((m) => mediaIds.add(m.id))
  }
  if (!mediaIds.size) return []
  // Only rows that exist: a usage row for a missing media would break the foreign key.
  const existing = await tx.media.findMany({ where: { id: { in: [...mediaIds] } }, select: { id: true } })
  return existing.map((m) => m.id)
}

/** Replaces the `ACTIVITY` usage rows of `activityKey` with the union over every version holding the key (SC7). */
export async function syncActivityMediaUsage(tx: Tx, activityKey: string): Promise<void> {
  const mediaIds = await mediaIdsForKey(tx, activityKey)
  await tx.mediaUsage.deleteMany({ where: { usageType: ACTIVITY_USAGE_TYPE, resourceId: activityKey } })
  if (mediaIds.length) {
    await tx.mediaUsage.createMany({
      data: mediaIds.map((mediaId) => ({ mediaId, usageType: ACTIVITY_USAGE_TYPE, resourceId: activityKey })),
    })
  }
}

/** The `MediaMap` for every media id and every video's media id the documents name. */
export async function buildMediaMap(tx: Tx, documents: unknown[]): Promise<MediaMap> {
  const mediaIds = new Set<string>()
  const videoIds = new Set<string>()
  for (const doc of documents) {
    const refs = documentMediaRefs(doc)
    refs.mediaIds.forEach((id) => mediaIds.add(id))
    refs.videoIds.forEach((id) => videoIds.add(id))
  }
  const where: Prisma.MediaWhereInput[] = []
  if (mediaIds.size) where.push({ id: { in: [...mediaIds] } })
  if (videoIds.size) where.push({ videoId: { in: [...videoIds] } })
  if (!where.length) return {}

  const rows = await tx.media.findMany({
    where: { OR: where },
    include: { uploader: { select: { name: true } }, video: { select: { playbackUrl: true } } },
  })
  const map: MediaMap = {}
  for (const m of rows) {
    const entry: MediaMapEntry = { url: m.url, kind: m.type === 'video' ? 'video' : 'image' }
    if (m.width != null) entry.width = m.width
    if (m.height != null) entry.height = m.height
    if (m.thumbnailUrl) entry.posterUrl = m.thumbnailUrl
    if (m.duration != null) entry.durationSeconds = m.duration
    if (m.uploader?.name) entry.uploaderName = m.uploader.name
    if (m.video?.playbackUrl) entry.playbackUrl = m.video.playbackUrl
    map[m.id] = entry
  }
  return map
}

/** Whether an `ACTIVITY` usage row names any of `mediaIds` (D34's delete guard). */
export async function isUsedByActivity(db: Pick<Tx, 'mediaUsage'>, mediaIds: string[]): Promise<boolean> {
  if (!mediaIds.length) return false
  const row = await db.mediaUsage.findFirst({
    where: { usageType: ACTIVITY_USAGE_TYPE, mediaId: { in: mediaIds } },
    select: { id: true },
  })
  return row !== null
}
