/**
 * media-library D2/D15/D18: writing MakeReady's own media. Only the super-admin API
 * (/api/makeready/media) and the import command call these; every generic write route refuses the
 * MakeReady org (routes/media.ts refuseMakeReady).
 */
import sharp from 'sharp'
import { prisma } from '../lib/prisma.js'
import { ensureMakeReadyOrg, MAKEREADY_ORG_ID, MAKEREADY_SYSTEM_USER_ID } from './makeready-library.js'
import { extractImageMetadata } from './media-metadata.js'
import { extractKeyFromUrl, objectExists, uploadImageVariants } from './storage.js'

export class MakeReadyMediaError extends Error {
  constructor(public status: 400 | 404 | 409, message: string) {
    super(message)
  }
}

export interface MakeReadyMediaInput {
  image: Buffer
  title: string
  description?: string | null
  altText?: string | null
  tags?: string[]
  d2mSlug?: string | null
}

const normalizeTags = (tags: string[] = []) => [...new Set(tags.map((t) => t.toLowerCase().trim()).filter(Boolean))]

/** The row already imported from d2m under `slug`, if any (slug lives in exifData.d2mSlug). */
export async function findBySlug(slug: string) {
  return prisma.media.findFirst({
    where: { organizationId: MAKEREADY_ORG_ID, exifData: { path: ['d2mSlug'], equals: slug } },
  })
}

/** Writes the JPEG ladder (+ WebP) under `makeready/<baseName>` and returns its public URL. */
async function writeVariants(baseName: string, image: Buffer): Promise<{ url: string; size: number }> {
  const [original, medium, thumb] = await Promise.all([
    sharp(image).rotate().resize(1200, 1200, { fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 85 }).toBuffer(),
    sharp(image).rotate().resize(400, null, { withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer(),
    sharp(image).rotate().resize(150, null, { withoutEnlargement: true }).jpeg({ quality: 75 }).toBuffer(),
  ])
  const { url } = await uploadImageVariants('makeready', baseName, 'jpeg', original, medium, thumb)
  return { url, size: original.length }
}

export async function createMakeReadyMedia(input: MakeReadyMediaInput) {
  await ensureMakeReadyOrg()
  if (input.d2mSlug && (await findBySlug(input.d2mSlug))) {
    throw new MakeReadyMediaError(409, `d2m image ${input.d2mSlug} is already imported`)
  }
  const stem = (input.d2mSlug ?? 'upload').replace(/[^a-z0-9-]/gi, '-').toLowerCase()
  const baseName = `${stem}-${Date.now()}`
  const [{ url, size }, meta] = await Promise.all([writeVariants(baseName, input.image), extractImageMetadata(input.image)])
  const media = await prisma.media.create({
    data: {
      title: input.title,
      description: input.description ?? undefined,
      altText: input.altText ?? undefined,
      url,
      thumbnailUrl: url.replace('.jpeg', '-thumb.jpeg'),
      type: 'photo',
      mimeType: 'image/jpeg',
      fileSize: size,
      organizationId: MAKEREADY_ORG_ID,
      uploadedBy: MAKEREADY_SYSTEM_USER_ID,
      source: 'import',
      uploadStatus: 'ready',
      visibility: 'members',
      width: meta.width,
      height: meta.height,
      aspectRatio: meta.aspectRatio,
      dominantColor: meta.dominantColor,
      fileHash: meta.fileHash,
      exifData: input.d2mSlug ? { d2mSlug: input.d2mSlug } : undefined,
    },
  })
  const tags = normalizeTags(input.tags)
  if (tags.length) await prisma.mediaTag.createMany({ data: tags.map((tag) => ({ mediaId: media.id, tag })), skipDuplicates: true })
  return { ...media, tags }
}

async function requireMakeReadyMedia(id: string) {
  const media = await prisma.media.findFirst({ where: { id, organizationId: MAKEREADY_ORG_ID } })
  if (!media) throw new MakeReadyMediaError(404, 'MakeReady media not found')
  return media
}

export interface MakeReadyMediaPatch {
  title?: string
  description?: string | null
  altText?: string | null
  tags?: string[]
}

/** Edits a MakeReady row; `tags`, when given, replace the row's tags. */
export async function updateMakeReadyMedia(id: string, patch: MakeReadyMediaPatch) {
  await requireMakeReadyMedia(id)
  const media = await prisma.media.update({
    where: { id },
    data: {
      ...(patch.title !== undefined && { title: patch.title }),
      ...(patch.description !== undefined && { description: patch.description }),
      ...(patch.altText !== undefined && { altText: patch.altText }),
    },
  })
  if (patch.tags) {
    const tags = normalizeTags(patch.tags)
    await prisma.mediaTag.deleteMany({ where: { mediaId: id } })
    if (tags.length) await prisma.mediaTag.createMany({ data: tags.map((tag) => ({ mediaId: id, tag })) })
  }
  const tags = await prisma.mediaTag.findMany({ where: { mediaId: id }, select: { tag: true } })
  return { ...media, tags: tags.map((t) => t.tag) }
}

/** D18: hides a MakeReady row (isActive false). Covers made from it keep their own rendered copy. */
export async function deleteMakeReadyMedia(id: string) {
  await requireMakeReadyMedia(id)
  await prisma.media.update({ where: { id }, data: { isActive: false } })
}

export interface CatalogItem {
  slug: string
  title: string
  alt: string
  tags: string[]
  file: Buffer
}

/**
 * D15/D20: imports d2m cover images idempotently. A slug already imported is skipped — unless its R2
 * object is gone (a walk reset empties s3mock while the rows survive), when its variants are
 * re-written under the same key.
 */
export async function importFromCatalog(items: CatalogItem[]): Promise<{ created: number; skipped: number; repaired: number }> {
  await ensureMakeReadyOrg()
  const out = { created: 0, skipped: 0, repaired: 0 }
  for (const item of items) {
    const existing = await findBySlug(item.slug)
    if (!existing) {
      await createMakeReadyMedia({ image: item.file, title: item.title, description: item.alt, altText: item.alt, tags: item.tags, d2mSlug: item.slug })
      out.created++
      continue
    }
    const key = extractKeyFromUrl(existing.url)
    if (key && !(await objectExists(key))) {
      const baseName = key.replace(/^makeready\//, '').replace(/\.jpeg$/, '')
      await writeVariants(baseName, item.file)
      out.repaired++
    } else {
      out.skipped++
    }
  }
  return out
}
