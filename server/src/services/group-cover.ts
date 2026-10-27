/**
 * group-cover-image: the non-destructive group cover — the framing shape (D11) and the upload
 * service (D10, D17).
 */
import { z } from 'zod'
import sharp from 'sharp'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import { deleteFromR2, extractKeyFromUrl, uploadImageVariants, uploadToR2 } from './storage.js'

/**
 * D11 + D21: all finite; scale relative to the zoom floor (1…8), fine rotation in degrees (-45…45
 * after quarter turns), fractions of the frame; `flipped` (mirror) and `quarterTurns` (CCW 90° steps)
 * are optional and default to false / 0 so a D11-shaped body stays valid.
 */
export const coverFramingSchema = z
  .object({
    scale: z.number().finite().min(1).max(8),
    rotation: z.number().finite().min(-45).max(45),
    offsetX: z.number().finite().min(-1).max(1),
    offsetY: z.number().finite().min(-1).max(1),
    flipped: z.boolean().default(false),
    quarterTurns: z.number().int().min(0).max(3).default(0),
  })
  .strict()

export type CoverFraming = z.infer<typeof coverFramingSchema>

/** A stored `coverFraming` as the payload returns it — null when absent or not D21-shaped. */
export function parseStoredFraming(value: unknown): CoverFraming | null {
  const parsed = coverFramingSchema.safeParse(value)
  return parsed.success ? parsed.data : null
}

/** D10: the original's longest side, re-enforced server-side (D16). */
export const ORIGINAL_MAX_PX = 2400

/** A client error the route maps to its status (D10: a bad image is a 400, not a 500). */
export class CoverUploadError extends Error {
  readonly status = 400 as const
}

export interface SaveGroupCoverInput {
  group: { id: string; coverOriginalUrl: string | null }
  /** D10: the rendered cover, JPEG base64 (a data-URL prefix is tolerated). */
  imageData: string
  framing?: CoverFraming
  originalData?: string
}

export interface SaveGroupCoverResult {
  coverImageUrl: string
  coverOriginalUrl: string | null
  coverFraming: CoverFraming | null
  /** The decoded rendered cover — the route's media-library capture reads it (D18). */
  renderedBuffer: Buffer
  /** Bytes of the 1200px rendered JPEG uploaded (the capture's fileSize). */
  renderedSize: number
  /** D18: a new image (an original, or no framing) rather than a re-edit. */
  isNewImage: boolean
}

function decodeBase64(data: string): Buffer {
  return Buffer.from(data.replace(/^data:image\/\w+;base64,/, ''), 'base64')
}

/** D10: either image failing sharp's metadata read is a 400. */
async function assertDecodable(buffer: Buffer, label: string): Promise<void> {
  try {
    const meta = await sharp(buffer).metadata()
    if (!meta.format) throw new Error('no format')
  } catch {
    throw new CoverUploadError(`The ${label} could not be decoded as an image`)
  }
}

/**
 * D10 / D17: decode + validate both images, upload the rendered ladder (1200/400/150, as before)
 * and the re-encoded original, then ONE group update writing all three cover columns. D9: no
 * framing clears the original and the framing. D19: a replaced or cleared original is deleted
 * from R2 after the write, best-effort. Any R2 failure rejects before the write (orphans accepted).
 */
export async function saveGroupCover(input: SaveGroupCoverInput): Promise<SaveGroupCoverResult> {
  const { group, framing } = input
  if (input.originalData !== undefined && framing === undefined) {
    throw new CoverUploadError('originalData requires framing')
  }

  const rendered = decodeBase64(input.imageData)
  const original = input.originalData !== undefined ? decodeBase64(input.originalData) : null
  await assertDecodable(rendered, 'cover image')
  if (original) await assertDecodable(original, 'original image')

  const timestamp = Date.now()
  const baseName = `group-${group.id}-${timestamp}`

  const [large, medium, thumb, originalJpeg] = await Promise.all([
    sharp(rendered).resize(1200, null, { withoutEnlargement: true }).jpeg({ quality: 85 }).toBuffer(),
    sharp(rendered).resize(400, null, { withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer(),
    sharp(rendered).resize(150, null, { withoutEnlargement: true }).jpeg({ quality: 75 }).toBuffer(),
    original
      ? sharp(original)
          .rotate()
          .resize(ORIGINAL_MAX_PX, ORIGINAL_MAX_PX, { fit: 'inside', withoutEnlargement: true })
          .jpeg({ quality: 90 })
          .toBuffer()
      : Promise.resolve(null),
  ])

  const [{ url: coverImageUrl }, uploadedOriginalUrl] = await Promise.all([
    uploadImageVariants('groups', baseName, 'jpeg', large, medium, thumb),
    originalJpeg ? uploadToR2(`groups/${baseName}-original.jpeg`, originalJpeg, 'image/jpeg') : Promise.resolve(null),
  ])

  const coverOriginalUrl = framing ? (uploadedOriginalUrl ?? group.coverOriginalUrl) : null
  const coverFraming = framing ?? null

  await prisma.group.update({
    where: { id: group.id },
    data: { coverImageUrl, coverOriginalUrl, coverFraming: coverFraming ?? Prisma.DbNull },
  })

  const previous = group.coverOriginalUrl
  if (previous && previous !== coverOriginalUrl) {
    const key = extractKeyFromUrl(previous)
    if (key) {
      try {
        await deleteFromR2(key)
      } catch (error) {
        console.warn(`saveGroupCover: could not delete the old original ${key}:`, error)
      }
    }
  }

  return {
    coverImageUrl,
    coverOriginalUrl,
    coverFraming,
    renderedBuffer: rendered,
    renderedSize: large.length,
    isNewImage: original !== null || framing === undefined,
  }
}
