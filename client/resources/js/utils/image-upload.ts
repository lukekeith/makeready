// Client-side photo preparation for base64 JSON uploads — web equivalent of
// iOS MediaActions.uploadPhoto's preprocessing (MediaActions.swift):
// downscale the longest side to ≤2000px, re-encode as JPEG at quality 0.85
// (canvas re-encode strips EXIF, same as the ImageIO path on iOS).

const MAX_DIMENSION = 2000
const JPEG_QUALITY = 0.85

/**
 * Read a picked File, downscale if needed, and return the bare base64 JPEG
 * payload (no `data:` prefix) — the shape the media upload endpoint expects.
 */
export async function fileToResizedJpegBase64(file: File): Promise<string> {
  const bitmap = await loadImage(file)
  const scale = Math.min(1, MAX_DIMENSION / Math.max(bitmap.width, bitmap.height))
  const width = Math.round(bitmap.width * scale)
  const height = Math.round(bitmap.height * scale)

  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('Canvas unavailable')
  ctx.drawImage(bitmap, 0, 0, width, height)
  if ('close' in bitmap) bitmap.close()

  const dataUrl = canvas.toDataURL('image/jpeg', JPEG_QUALITY)
  const comma = dataUrl.indexOf(',')
  if (comma === -1) throw new Error('Failed to encode image')
  return dataUrl.slice(comma + 1)
}

async function loadImage(file: File): Promise<ImageBitmap | HTMLImageElement> {
  if ('createImageBitmap' in window) {
    // imageOrientation applies EXIF rotation before we strip it.
    return createImageBitmap(file, { imageOrientation: 'from-image' })
  }
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      resolve(img)
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('Failed to read image'))
    }
    img.src = url
  })
}
