/**
 * Media Library Service
 *
 * Automatically captures media into the org library when uploads happen
 * anywhere in the system (videos, cover images, etc.).
 *
 * Fire-and-forget functions (captureToLibrary, recordMediaUsage, syncVideoStatus)
 * follow the same pattern as trackActivity() — they never block the main request.
 */

import { prisma } from '../lib/prisma.js'
import { analyzeImage } from './claude.js'
import { parseTakenAt } from './media-metadata.js'
import { ensureMakeReadyOrg, MAKEREADY_ORG_ID } from './makeready-library.js'
import { getUserOrganizations } from './organization.js'
import { hasPermission } from './permission.js'

// ============================================================================
// Types
// ============================================================================

export interface CaptureToLibraryParams {
  title: string
  url: string
  type: string // photo, video, document
  mimeType?: string
  fileSize?: number
  thumbnailUrl?: string
  organizationId: string
  uploadedBy: string
  videoId?: string
  source?: string // direct, auto_capture, import
  uploadStatus?: string // pending, processing, ready, error
  duration?: number
  width?: number
  height?: number
  aspectRatio?: string
  dominantColor?: string
  fileHash?: string
  exifData?: Record<string, unknown>
  /** media-page D3/D4: the capture date the client read from the picked file (ISO 8601 with offset). */
  takenAt?: string
  videoResolution?: string
  usageType?: string // LESSON_ACTIVITY, PROGRAM_COVER, GROUP_COVER, POST
  resourceId?: string
  resourceName?: string
}

export interface LibraryFilters {
  /// One org, or (media-library /media/browse) several.
  organizationId: string | string[]
  uploadedBy?: string
  /// Multi-leader filter — when set, narrows to media uploaded by any of these
  /// user IDs. Used by the library "Group leaders" dropdown. Coexists with
  /// `uploadedBy`; if both are set, `uploadedByIn` takes precedence.
  uploadedByIn?: string[]
  type?: string
  tags?: string[]
  search?: string
  q?: string // generalized search across all fields + tags
  uploadStatus?: string
  isActive?: boolean
  page?: number
  limit?: number
  /// Keyset cursor (media plan M1.2): opaque base64 of `createdAt|id` from a
  /// previous response's `nextCursor`. When set, `page` is ignored and the
  /// response carries exact `hasMore` and omits `total` — clients keep the
  /// exact total from their initial page-1 response (M1.4: this keeps
  /// count(*) off the hot deep-paging path entirely).
  cursor?: string
}

// MARK: Keyset cursor codec (M1.2). Opaque to clients; composes with every
// filter because it's just an AND'd range predicate on the sort key.

const CURSOR_SEPARATOR = '|'

export function encodeLibraryCursor(createdAt: Date, id: string): string {
  return Buffer.from(`${createdAt.toISOString()}${CURSOR_SEPARATOR}${id}`).toString('base64url')
}

export function decodeLibraryCursor(cursor: string): { createdAt: Date; id: string } | null {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8')
    const sep = raw.indexOf(CURSOR_SEPARATOR)
    if (sep < 0) return null
    const createdAt = new Date(raw.slice(0, sep))
    const id = raw.slice(sep + 1)
    if (Number.isNaN(createdAt.getTime()) || !id) return null
    return { createdAt, id }
  } catch {
    return null
  }
}


// ============================================================================
// Org Resolution Helper
// ============================================================================

/**
 * Resolve the organization a user belongs to for org-scoped content access.
 *
 * Resolution order (first match wins):
 *   1. `User.organizationId` (deprecated but still populated for org members).
 *   2. Legacy `Organization.ownerId` (org owners).
 *   3. Any `UserRole` row — covers Group Leaders, Admins, Contributors, etc.,
 *      so non-owner role-holders also see org-scoped content (study programs
 *      and media library) shared by their org.
 *
 * Returns undefined if the user has no org affiliation, in which case
 * callers fall back to creator-scoped filtering.
 */
export async function getUserOrgId(userId: string): Promise<string | undefined> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { organizationId: true },
  })
  if (user?.organizationId) return user.organizationId

  const owned = await prisma.organization.findFirst({
    where: { ownerId: userId },
    select: { id: true },
  })
  if (owned) return owned.id

  const role = await prisma.userRole.findFirst({
    where: { userId },
    select: { organizationId: true },
  })
  return role?.organizationId
}

// ============================================================================
// Fire-and-Forget Functions
// ============================================================================

/**
 * Auto-capture media into the library.
 * Deduplicates by URL + organizationId to avoid double entries.
 * Catches its own errors so callers can fire-and-forget.
 */
export function captureToLibrary(params: CaptureToLibraryParams): void {
  prisma.media
    .findFirst({
      where: {
        url: params.url,
        organizationId: params.organizationId,
      },
    })
    .then((existing) => {
      if (existing) {
        if (params.usageType && params.resourceId) {
          recordMediaUsage(existing.id, params.usageType, params.resourceId, params.resourceName)
        }
        return existing
      }
      return prisma.media
        .create({
          data: {
            title: params.title,
            url: params.url,
            type: params.type,
            mimeType: params.mimeType ?? undefined,
            fileSize: params.fileSize ?? undefined,
            thumbnailUrl: params.thumbnailUrl ?? undefined,
            organizationId: params.organizationId,
            uploadedBy: params.uploadedBy,
            videoId: params.videoId ?? undefined,
            source: params.source ?? 'auto_capture',
            uploadStatus: params.uploadStatus ?? 'ready',
            duration: params.duration ?? undefined,
            width: params.width ?? undefined,
            height: params.height ?? undefined,
            aspectRatio: params.aspectRatio ?? undefined,
            dominantColor: params.dominantColor ?? undefined,
            fileHash: params.fileHash ?? undefined,
            exifData: (params.exifData as any) ?? undefined,
            takenAt: parseTakenAt(params.takenAt, params.exifData),
            videoResolution: params.videoResolution ?? undefined,
            visibility: 'members',
          },
        })
        .then((media) => {
          if (params.usageType && params.resourceId) {
            recordMediaUsage(media.id, params.usageType, params.resourceId, params.resourceName)
          }
          // Auto-enrich images with AI alt text and tags
          if (params.type === 'photo' && params.url && params.uploadStatus !== 'pending') {
            enrichMediaWithAI(media.id, params.url, {
              title: params.title,
              usageContext: params.usageType,
            })
          }
          return media
        })
    })
    .catch((error) => {
      console.error('Failed to capture media to library:', error)
    })
}

/**
 * Record where a media item is used (activity, program cover, etc.).
 * Fire-and-forget — catches its own errors.
 */
export function recordMediaUsage(
  mediaId: string,
  usageType: string,
  resourceId: string,
  resourceName?: string
): void {
  prisma.mediaUsage
    .upsert({
      where: {
        mediaId_usageType_resourceId: {
          mediaId,
          usageType,
          resourceId,
        },
      },
      update: {
        resourceName: resourceName ?? undefined,
      },
      create: {
        mediaId,
        usageType,
        resourceId,
        resourceName: resourceName ?? undefined,
      },
    })
    .catch((error) => {
      console.error('Failed to record media usage:', error)
    })
}

/**
 * Sync video processing status to the linked Media record.
 * Called when a video's Cloudflare status changes (e.g. pending -> ready).
 * Fire-and-forget.
 */
export function syncVideoStatus(
  videoId: string,
  status: string,
  playbackUrl?: string,
  thumbnailUrl?: string,
  duration?: number,
  videoMeta?: { width?: number; height?: number; aspectRatio?: string; videoResolution?: string }
): void {
  const uploadStatus = status === 'ready' ? 'ready' : status === 'error' ? 'error' : 'processing'

  prisma.media
    .updateMany({
      where: { videoId },
      data: {
        uploadStatus,
        ...(playbackUrl && { url: playbackUrl }),
        ...(thumbnailUrl && { thumbnailUrl }),
        ...(duration && { duration }),
        ...(videoMeta?.width && { width: videoMeta.width }),
        ...(videoMeta?.height && { height: videoMeta.height }),
        ...(videoMeta?.aspectRatio && { aspectRatio: videoMeta.aspectRatio }),
        ...(videoMeta?.videoResolution && { videoResolution: videoMeta.videoResolution }),
      },
    })
    .catch((error) => {
      console.error('Failed to sync video status to media library:', error)
    })
}

// ============================================================================
// AI Enrichment
// ============================================================================

/**
 * Enrich a media record with AI-generated alt text and tags.
 * Sends the image to Claude Haiku for vision analysis.
 * Fire-and-forget — catches its own errors.
 *
 * Only processes images with a valid URL. Skips videos and pending uploads.
 */
export function enrichMediaWithAI(
  mediaId: string,
  imageUrl: string,
  context?: { title?: string; usageContext?: string }
): void {
  if (!imageUrl || !process.env.ANTHROPIC_API_KEY) return

  analyzeImage(imageUrl, context)
    .then((analysis) => {
      if (!analysis.altText && analysis.tags.length === 0) return

      const updates: Promise<unknown>[] = []

      // Update alt text on the media record
      if (analysis.altText) {
        updates.push(
          prisma.media.update({
            where: { id: mediaId },
            data: { altText: analysis.altText },
          })
        )
      }

      // Add AI-generated tags
      if (analysis.tags.length > 0) {
        updates.push(
          ...analysis.tags.map((tag) =>
            prisma.mediaTag.upsert({
              where: { mediaId_tag: { mediaId, tag } },
              update: {},
              create: { mediaId, tag },
            })
          )
        )
      }

      return Promise.all(updates)
    })
    .then(() => {
      console.log(`🤖 AI enrichment complete for media ${mediaId}`)
    })
    .catch((error) => {
      console.error(`Failed to enrich media ${mediaId} with AI:`, error)
    })
}

// ============================================================================
// Library Query Functions
// ============================================================================

export async function listLibrary(filters: LibraryFilters) {
  const {
    organizationId,
    uploadedBy,
    uploadedByIn,
    type,
    tags,
    search,
    q,
    uploadStatus,
    isActive = true,
    page = 1,
    limit = 20,
    cursor,
  } = filters

  const skip = (page - 1) * limit

  // `uploadedByIn` (multi-leader filter) takes precedence over the single
  // `uploadedBy` so the new dropdown UI always wins when both are sent.
  const uploadedByClause = uploadedByIn && uploadedByIn.length > 0
    ? { uploadedBy: { in: uploadedByIn } }
    : uploadedBy ? { uploadedBy } : {}

  const where: any = {
    organizationId: Array.isArray(organizationId) ? { in: organizationId } : organizationId,
    isActive,
    ...uploadedByClause,
    ...(type && { type }),
    ...(uploadStatus && { uploadStatus }),
    ...(search && {
      OR: [
        { title: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
      ],
    }),
    ...(tags && tags.length > 0 && {
      tags: {
        some: {
          tag: { in: tags.map((t) => t.toLowerCase().trim()) },
        },
      },
    }),
  }

  // Generalized search: matches across title, description, altText, type, mimeType, and tags
  if (q) {
    const term = q.trim()
    where.OR = [
      { title: { contains: term, mode: 'insensitive' } },
      { description: { contains: term, mode: 'insensitive' } },
      { altText: { contains: term, mode: 'insensitive' } },
      { type: { contains: term, mode: 'insensitive' } },
      { mimeType: { contains: term, mode: 'insensitive' } },
      { tags: { some: { tag: { contains: term.toLowerCase(), mode: 'insensitive' } } } },
    ]
  }

  // Keyset predicate (M1.2): strictly-after the cursor row in
  // (createdAt DESC, id DESC) order. AND'd so it composes with every filter
  // above — including the q/search OR clauses — without clobbering them.
  const decodedCursor = cursor ? decodeLibraryCursor(cursor) : null
  if (decodedCursor) {
    where.AND = [
      ...(where.AND ?? []),
      // Redundant upper bound that the planner CAN push into the index
      // condition — without it the OR below is only a post-scan filter and
      // the backward index scan restarts from the newest row every page,
      // degrading O(depth). With it, the scan starts at the cursor position.
      { createdAt: { lte: decodedCursor.createdAt } },
      {
        OR: [
          { createdAt: { lt: decodedCursor.createdAt } },
          { createdAt: decodedCursor.createdAt, id: { lt: decodedCursor.id } },
        ],
      },
    ]
  }

  const include = {
    uploader: { select: { id: true, name: true, email: true } },
    tags: { select: { tag: true } },
    video: { select: { id: true, status: true, duration: true, playbackUrl: true } },
    _count: { select: { usages: true } },
  } as const

  // `id` tiebreaker added to both modes: createdAt alone isn't unique, so
  // without it rows with identical timestamps could repeat/skip across pages.
  const orderBy = [{ createdAt: 'desc' as const }, { id: 'desc' as const }]

  const mapRow = (m: any) => ({
    ...m,
    tags: m.tags.map((t: any) => t.tag),
    usageCount: m._count.usages,
    _count: undefined,
  })

  if (decodedCursor) {
    // Cursor mode (M1.2): fetch limit+1 to derive an exact hasMore without
    // any count(*) — `total` is intentionally omitted (clients keep the
    // exact total from their initial page-1 response; M1.4).
    const rows = await prisma.media.findMany({ where, include, orderBy, take: limit + 1 })
    const hasMore = rows.length > limit
    const pageRows = hasMore ? rows.slice(0, limit) : rows
    const last = pageRows[pageRows.length - 1]

    return {
      data: pageRows.map(mapRow),
      limit,
      hasMore,
      nextCursor: hasMore && last ? encodeLibraryCursor(last.createdAt, last.id) : null,
    }
  }

  // Page mode — unchanged behavior for existing clients (web admin), plus
  // nextCursor/hasMore so cursor-capable clients can switch to keyset
  // paging after their first page-mode request.
  const [media, total] = await Promise.all([
    prisma.media.findMany({ where, include, orderBy, skip, take: limit }),
    prisma.media.count({ where }),
  ])

  const last = media[media.length - 1]
  const hasMore = skip + media.length < total

  return {
    data: media.map(mapRow),
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
    hasMore,
    nextCursor: hasMore && last ? encodeLibraryCursor(last.createdAt, last.id) : null,
  }
}

export async function getLibraryItem(mediaId: string) {
  const media = await prisma.media.findUnique({
    where: { id: mediaId },
    include: {
      organization: { select: { id: true, name: true } },
      uploader: { select: { id: true, name: true, email: true } },
      tags: { select: { id: true, tag: true } },
      usages: {
        select: { id: true, usageType: true, resourceId: true, resourceName: true, createdAt: true },
        orderBy: { createdAt: 'desc' },
      },
      video: {
        select: {
          id: true,
          cloudflareUid: true,
          playbackUrl: true,
          thumbnailUrl: true,
          duration: true,
          status: true,
        },
      },
    },
  })

  if (!media) return null

  return {
    ...media,
    tags: media.tags.map((t) => t.tag),
  }
}

// ============================================================================
// Tag Management
// ============================================================================

export async function addTags(mediaId: string, tags: string[]) {
  const normalized = tags.map((t) => t.toLowerCase().trim()).filter(Boolean)
  if (normalized.length === 0) return []

  const operations = normalized.map((tag) =>
    prisma.mediaTag.upsert({
      where: { mediaId_tag: { mediaId, tag } },
      update: {},
      create: { mediaId, tag },
    })
  )

  return Promise.all(operations)
}

export async function removeTags(mediaId: string, tags: string[]) {
  const normalized = tags.map((t) => t.toLowerCase().trim()).filter(Boolean)
  if (normalized.length === 0) return

  await prisma.mediaTag.deleteMany({
    where: {
      mediaId,
      tag: { in: normalized },
    },
  })
}

export async function listUsages(mediaId: string) {
  return prisma.mediaUsage.findMany({
    where: { mediaId },
    orderBy: { createdAt: 'desc' },
  })
}

// ============================================================================
// media-library: browse across MakeReady + the caller's orgs
// ============================================================================

export interface MediaSource {
  id: string
  name: string
  isMakeReady: boolean
  canUpload: boolean
}

/** D4/D16: MakeReady first, then the caller's orgs by name; canUpload = media.create there. */
export async function listSources(userId: string): Promise<MediaSource[]> {
  await ensureMakeReadyOrg()
  const orgs = ((await getUserOrganizations(userId)).data ?? []).slice().sort((a, b) => a.name.localeCompare(b.name))
  const own = await Promise.all(
    orgs.map(async (o) => ({
      id: o.id,
      name: o.name,
      isMakeReady: false,
      canUpload: await hasPermission({ userId }, 'media.create', 'organization', o.id),
    })),
  )
  return [{ id: MAKEREADY_ORG_ID, name: 'MakeReady', isMakeReady: true, canUpload: false }, ...own]
}

export class BrowseError extends Error {
  constructor(public status: 400 | 403, message: string) {
    super(message)
  }
}

export interface BrowseFilters extends Omit<LibraryFilters, 'organizationId' | 'page'> {
  userId: string
  sources?: string[]
}

/** D16/D17: one cursor-paged list over MakeReady + the caller's orgs (or the given subset of them). */
export async function listBrowse(filters: BrowseFilters) {
  const { userId, sources, ...rest } = filters
  const limit = rest.limit ?? 200
  if (!Number.isInteger(limit) || limit < 1 || limit > 200) throw new BrowseError(400, 'limit must be 1-200')
  const allowed = (await listSources(userId)).map((s) => s.id)
  const ids = sources && sources.length > 0 ? sources : allowed
  if (ids.some((id) => !allowed.includes(id))) throw new BrowseError(403, 'Not a source you can browse')
  const result = await listLibrary({ ...rest, organizationId: ids, limit })
  return {
    data: result.data.map((item: any) => ({ ...item, isMakeReady: item.organizationId === MAKEREADY_ORG_ID })),
    limit: result.limit,
    hasMore: result.hasMore,
    nextCursor: result.nextCursor,
  }
}

/**
 * media-library D10: a cover chosen from the library. The source must be active MakeReady media or
 * media in the resource's own org — anything else would record a usage that names this resource to
 * another org. Throws LibraryPickError(404 | 403).
 */
export class LibraryPickError extends Error {
  constructor(public status: 403 | 404, message: string) {
    super(message)
  }
}

export async function checkLibraryPick(sourceMediaId: string, resourceOrgId: string | null): Promise<void> {
  const media = await prisma.media.findFirst({ where: { id: sourceMediaId, isActive: true }, select: { organizationId: true } })
  if (!media) throw new LibraryPickError(404, 'Library media not found')
  if (media.organizationId !== MAKEREADY_ORG_ID && media.organizationId !== resourceOrgId) {
    throw new LibraryPickError(403, 'That media is not available to this organization')
  }
}

/** media-library D10: link the cover to its library original instead of capturing a copy. */
export async function recordLibraryPick(input: { sourceMediaId: string; usageType: string; resourceId: string; resourceName: string }) {
  await prisma.mediaUsage.upsert({
    where: { mediaId_usageType_resourceId: { mediaId: input.sourceMediaId, usageType: input.usageType, resourceId: input.resourceId } },
    update: { resourceName: input.resourceName },
    create: { mediaId: input.sourceMediaId, usageType: input.usageType, resourceId: input.resourceId, resourceName: input.resourceName },
  })
}
