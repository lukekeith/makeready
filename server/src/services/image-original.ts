/**
 * image-framing-editor D8 (hoisted from group-cover-image D10/D19): what every framed image's
 * upload shares — the decode check, the original's re-encode and the best-effort delete of a
 * replaced original. The group cover (group-cover.ts) and the member avatar (member-avatar.ts) use it.
 */
import sharp from 'sharp'
import { deleteFromR2, extractKeyFromUrl } from './storage.js'

/** The original's longest side, re-enforced server-side. */
export const ORIGINAL_MAX_PX = 2400

/** A client error the route maps to its status (a bad image or body is a 400, not a 500). */
export class ImageUploadError extends Error {
  readonly status = 400 as const
}

/** An image failing sharp's metadata read is a 400. */
export async function assertDecodable(buffer: Buffer, label: string): Promise<void> {
  try {
    const meta = await sharp(buffer).metadata()
    if (!meta.format) throw new Error('no format')
  } catch {
    throw new ImageUploadError(`The ${label} could not be decoded as an image`)
  }
}

/** The stored original: EXIF orientation applied, longest side ≤ 2400px, JPEG 90, metadata stripped. */
export function encodeOriginal(buffer: Buffer): Promise<Buffer> {
  return sharp(buffer)
    .rotate()
    .resize(ORIGINAL_MAX_PX, ORIGINAL_MAX_PX, { fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 90 })
    .toBuffer()
}

/** Deletes a replaced or cleared original after the write; a failure is logged, never thrown. */
export async function deleteOriginalBestEffort(url: string, context: string): Promise<void> {
  const key = extractKeyFromUrl(url)
  if (!key) return
  try {
    await deleteFromR2(key)
  } catch (error) {
    console.warn(`${context}: could not delete the old original ${key}:`, error)
  }
}
