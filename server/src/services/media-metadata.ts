/**
 * Media Metadata Extraction Service
 *
 * Extracts rich metadata from images (via sharp) and computes file hashes.
 */

import sharp from 'sharp'
import { createHash } from 'crypto'

export interface ImageMetadata {
  width: number
  height: number
  aspectRatio: string
  dominantColor: string | null
  fileHash: string
  exifData: Record<string, unknown> | null
}

export interface VideoMetadata {
  width?: number
  height?: number
  aspectRatio?: string
  videoResolution?: string
}

/**
 * Compute the greatest common divisor for aspect ratio calculation.
 */
function gcd(a: number, b: number): number {
  return b === 0 ? a : gcd(b, a % b)
}

/**
 * Compute a human-readable aspect ratio string.
 */
function computeAspectRatio(width: number, height: number): string {
  const divisor = gcd(width, height)
  const w = width / divisor
  const h = height / divisor
  // Simplify common ratios
  if ((w === 16 && h === 9) || (w === 32 && h === 18)) return '16:9'
  if ((w === 4 && h === 3) || (w === 8 && h === 6)) return '4:3'
  if (w === h) return '1:1'
  if ((w === 3 && h === 2) || (w === 6 && h === 4)) return '3:2'
  if ((w === 21 && h === 9) || (w === 7 && h === 3)) return '21:9'
  if (w === 9 && h === 16) return '9:16'
  if (w === 3 && h === 4) return '3:4'
  if (w === 2 && h === 3) return '2:3'
  return `${w}:${h}`
}

/**
 * Compute SHA-256 hash of a buffer.
 */
export function computeFileHash(buffer: Buffer): string {
  return createHash('sha256').update(buffer).digest('hex')
}

/**
 * Extract dominant color from an image buffer using sharp's stats.
 * Returns hex color string like "#3a5f8c".
 */
async function extractDominantColor(buffer: Buffer): Promise<string | null> {
  try {
    const { dominant } = await sharp(buffer).stats()
    const r = Math.round(dominant.r).toString(16).padStart(2, '0')
    const g = Math.round(dominant.g).toString(16).padStart(2, '0')
    const b = Math.round(dominant.b).toString(16).padStart(2, '0')
    return `#${r}${g}${b}`
  } catch {
    return null
  }
}

/**
 * Extract EXIF data from an image buffer.
 * Returns a cleaned object with useful fields.
 */
async function extractExifData(buffer: Buffer): Promise<Record<string, unknown> | null> {
  try {
    const metadata = await sharp(buffer).metadata()
    if (!metadata.exif) return null

    // sharp exposes raw EXIF as a buffer; use metadata fields instead
    const exif: Record<string, unknown> = {}

    if (metadata.density) exif.dpi = metadata.density
    if (metadata.space) exif.colorSpace = metadata.space
    if (metadata.hasAlpha !== undefined) exif.hasAlpha = metadata.hasAlpha
    if (metadata.orientation) exif.orientation = metadata.orientation
    if (metadata.chromaSubsampling) exif.chromaSubsampling = metadata.chromaSubsampling

    // Try to parse EXIF buffer for camera/GPS info
    try {
      const exifParser = await import('exif-reader')
      const parsed = exifParser.default(metadata.exif)
      if (parsed) {
        if (parsed.Image) {
          if (parsed.Image.Make) exif.cameraMake = parsed.Image.Make
          if (parsed.Image.Model) exif.cameraModel = parsed.Image.Model
          if (parsed.Image.Software) exif.software = parsed.Image.Software
        }
        // exif-reader v2 uses 'Photo' for EXIF IFD
        const photoData = (parsed as any).Photo || (parsed as any).Exif
        if (photoData) {
          if (photoData.DateTimeOriginal) exif.dateTaken = photoData.DateTimeOriginal
          if (photoData.ExposureTime) exif.exposureTime = photoData.ExposureTime
          if (photoData.FNumber) exif.fNumber = photoData.FNumber
          if (photoData.ISOSpeedRatings) exif.iso = photoData.ISOSpeedRatings
          if (photoData.FocalLength) exif.focalLength = photoData.FocalLength
        }
        if (parsed.GPSInfo || (parsed as any).GPS) {
          const gps = parsed.GPSInfo || (parsed as any).GPS
          if (gps.GPSLatitude && gps.GPSLongitude) {
            exif.gps = {
              latitude: gps.GPSLatitude,
              latitudeRef: gps.GPSLatitudeRef,
              longitude: gps.GPSLongitude,
              longitudeRef: gps.GPSLongitudeRef,
              altitude: gps.GPSAltitude,
            }
          }
        }
      }
    } catch {
      // exif-reader not available or parse failed — keep what we have from sharp
    }

    return Object.keys(exif).length > 0 ? exif : null
  } catch {
    return null
  }
}

/**
 * Extract full metadata from an image buffer.
 */
export async function extractImageMetadata(buffer: Buffer): Promise<ImageMetadata> {
  const metadata = await sharp(buffer).metadata()
  const width = metadata.width || 0
  const height = metadata.height || 0

  const [dominantColor, exifData] = await Promise.all([
    extractDominantColor(buffer),
    extractExifData(buffer),
  ])

  return {
    width,
    height,
    aspectRatio: width && height ? computeAspectRatio(width, height) : '1:1',
    dominantColor,
    fileHash: computeFileHash(buffer),
    exifData,
  }
}

/**
 * Derive video metadata from Cloudflare Stream dimensions.
 */
export function deriveVideoMetadata(input: {
  width?: number
  height?: number
}): VideoMetadata {
  const { width, height } = input
  const result: VideoMetadata = {}

  if (width) result.width = width
  if (height) result.height = height

  if (width && height) {
    result.aspectRatio = computeAspectRatio(width, height)

    // Classify resolution by height
    if (height >= 2160) result.videoResolution = '4k'
    else if (height >= 1440) result.videoResolution = '1440p'
    else if (height >= 1080) result.videoResolution = '1080p'
    else if (height >= 720) result.videoResolution = '720p'
    else if (height >= 480) result.videoResolution = '480p'
    else result.videoResolution = `${height}p`
  }

  return result
}
